# 2026-08-03: llamacpp-migration Phase 1 stability envelopes

Executes Phase 1 of `specs/llamacpp-migration`. Sections are appended as stages complete.

- Environment: WSL2 + RTX 4070 (12282 MiB), stock llama.cpp b9860 (fdb1db877); pin sha256-verified unchanged.
- `llama-perplexity` was already built at the pin (`version: 9860`), so no rebuild happened.

## KV cache probe (Gemma-only KL, per spec execution revisions)

Method: `llama-perplexity --kl-divergence` on the 12B QAT canonical (`gemma-4-12B-it-qat-UD-Q4_K_XL.gguf`).
The run used one 16384-token wikitext-2-raw chunk (`-c 16384 --chunks 1 -fa on -ngl 99`).
The f16-cache base logits were saved once and reused for both comparison runs.
The f16 and q8_0 cells ran 2026-07-29 and the bf16 cells ran 2026-08-03, both against the same base file.

| Metric | q8_0 vs f16 base | bf16 vs f16 base |
|---|---|---|
| Mean KLD | 0.0722 +/- 0.0066 | 0.0702 +/- 0.0067 |
| Median KLD | 0.0056 | 0.0050 |
| 95% KLD | 0.133 | 0.136 |
| 99% KLD | 1.29 | 1.10 |
| Maximum KLD | 19.2 | 19.2 |
| Same top-1 token | 92.98% | 93.44% |
| Mean PPL ratio vs base | 1.119 | 1.136 |

- Reading: bf16 (a full 16-bit float cache) diverges from the f16 base by the same amount as q8_0 does.
  - The ~0.07-with-heavy-tail KLD is the cost of changing KV dtype at all on this stack, not q8_0 damage.
  - q8_0 vs bf16 was not measured directly; both sit equidistant from the f16 base on every statistic.
- Third-party context (docs/parameters.md): 0.108 on Gemma 31B, 0.377 on 26B-A4B, <0.04 Qwen - direction matches.
  - Gemma did not surprise, so the spec's conditional Qwen probe is not triggered.

### VRAM at fixed ctx (whole-GPU nvidia-smi after a plain 12B load-only; includes desktop baseline)

2026-07-29 sweep (baseline that day ~1.0 GiB):

| ctx | f16 total | q8_0 total | f16 premium |
|---|---|---|---|
| 16384 | 11423 | 10614 | +809 |
| 65536 | 11439 | 10341 | +1098 |
| 131072 | 11517 | 10067 | +1450 |
| 200000 | 11661 | 9841 | +1820 |

2026-08-03 re-check (baseline that day ~2.1 GiB; absolute totals shifted, deltas reproduce):

| ctx | f16 | bf16 | q8_0 |
|---|---|---|---|
| 16384 | 10544 | 10528 | 9752 |

- f16 premium reproduces (+792 vs +809); bf16 VRAM == f16 within 16 MiB (both 16-bit, as the spec noted).
- Growth is sub-linear in ctx: most Gemma-4 layers are sliding-window, and llama-server allocates SWA-sized cache.
  - `--swa-full` is the opt-out. Plain 12B fits at 200k under every type.
- MTP changes the budget: q8_0 is the only cache type that fits the 12B pair on this card.
  - The P0 log measured the pair loaded at 200k under q8_0.
  - By arithmetic (not measured), an f16 pair overflows the 12282 MiB card.
- Absolute totals are not comparable across days (desktop baseline moved ~1.1 GiB); read the deltas.

### Decision

- Decided 2026-08-03 (user): **q8_0 fleet-wide**.
  - bf16's equal divergence shows ~0.07 KLD is dtype-change noise, not quantization damage.
    - The f16 quality case is retired; no f16 A/B follow-up is filed.
  - Also cache-neutral vs what Ollama served (`KV_CACHE_TYPE=q8_0`), and the only type that fits the MTP pair.
- The ctx ladder below runs at q8_0.

## Gemma 12B MTP ctx ladder (graphs ON, q8_0 KV)

Standalone llama-server (pin) on 11438 ran the pair target + drafter with `--spec-draft-n-max 2` and `--jinja`.
Sampling used the full thinking-profile flags.
Each rung loaded once, then ran 6 generations on a fixed B-tree coding prompt with `max_tokens` 800.
VRAM is whole-GPU nvidia-smi including the ~2.1 GiB desktop baseline.

| rung | VRAM after load | decode tok/s (n=6) | draft acceptance |
|---|---|---|---|
| 32768 | 10398 | 84.6-97.8 | 0.61-0.68 |
| 65536 | 10917 | 92.9-96.9 | 0.62-0.67 |
| 98304 | 11336 | 94.1-101.2 | 0.63-0.73 |
| 131072 | 11501 | 91.0-97.5 | 0.61-0.68 |
| 163840 | 11634 | 83.7-98.0 | 0.65-0.69 |
| 200000 | 11678 | 57.0-60.9 | 0.59-0.70 |

- 36/36 generations completed: zero crashes, no decode-degradation precursor at any rung.
- **Ceiling: 200000** (the plan's rule: highest stable rung). The 12B MTP entry serves at 200k.
- The 2026-07-17 eval's gen-5 crash at 200k did not reproduce (n=6 here vs its n=5).
  - Changed since the eval: Gemma QAT snapshots re-pinned 2026-07-23, `--jinja` templating in use.
  - Still treated as a known intermittent exposure; the per-rebuild crash-matrix rule stands.
- 200k costs ~35-40% decode vs 160k (57.0-60.9 vs 83.7-98.0 tok/s) - a ctx-size cost, stable across all 6 gens.

## 26B-A4B MTP pair at the ceiling

Its profile ctx is 131072: docs/parameters.md caps 26B-A4B there, under the 12B's 200k.
The check therefore ran at 131072 on standalone llama-server with the same flags as the ladder.
`-ngl auto` (the b9860 default) handled the partial offload.

- Load OK; whole-GPU VRAM 11774 MiB.
- 6/6 generations stable: 39.1-41.7 tok/s, draft acceptance 0.62-0.74.
- No lower 26B-specific ceiling recorded: 131072 stands.

## Qwen-MTP graphs-on hammer (router child)

The `scripts/repro-mtp-graphs.sh` shape ran against the llamacpp router (launch.sh, port 11433).
30 bounded generations on `qwen3.5-9b-mtp-coding-ud-q4-k-xl`, using the 9b-coders long prompt at `max_tokens` 4096.
A crash counts as a non-200 response or a new `illegal memory access` / `CUDA error` line in the router log.

- **30/30 clean**, full 4096 tokens every run, 98-121 tok/s, zero crash lines.
- The llama-swap contingency trigger (any crash) did not fire.
- Context: the 2026-07-01 Ollama-lane characterization put the crash rate at ~12.5%/run.
  - That rate would produce 0/30 with ~2% probability.
  - This agrees with the eval's verdict that stock b9860 graphs-on is the stable lane.

## Decision: launcher pin abort removed (2026-08-03, user)

- launch.sh keeps `9860 (fdb1db877)` as a last-known-good record; the hard `--version` abort is removed.
  - The abort guarded an accident with no precedent.
    - The stale b9552 binaries sat in the repo root, never on the launch path.
    - The launcher always used the absolute `build/bin` path.
  - Solo-box operating model: deliberate rebuilds only, so departure from the pin is always a chosen event.
- Unchanged: the locked spec's rebuild rule - re-run the crash matrix, re-validate the froggeric pair.
  - Passing it is what moves the last-known-good record forward.

## Provenance and validity

- Single box, single model, one 16k chunk, n=1 per KL cell; the spec directs reading the tool's numbers as-is.
- VRAM method is whole-GPU totals, one sample per cell.
  - Allocator variance and desktop baseline shifts show across days, so only same-day deltas are treated as signal.
- 6 gens per ladder rung and 30 hammer runs are small-n for an intermittent crash.
  - The per-rebuild crash-matrix rule is the ongoing control, not these counts.
- The session scratchpad holds `kld-*.log`, `kv-*.log`, `ladder-*.log`, `26b-check.log`, and `router-hammer.log`.
  - The logits base sat on `/mnt/f/llamacpp-kld-tmp/` and is deleted once the KV decision closes.
