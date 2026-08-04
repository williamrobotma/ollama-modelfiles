# 2026-08-03: llamacpp-migration Phase 1 stability envelopes

Executes Phase 1 of `specs/llamacpp-migration`. Sections are appended as stages complete.

- Environment: WSL2 + RTX 4070 (12282 MiB), stock llama.cpp b9860 (fdb1db877); pin sha256-verified unchanged.
- `llama-perplexity` was already built at the pin (`version: 9860`), so no rebuild happened.

## KV cache probe (Gemma-only KL, per spec execution revisions)

Method: `llama-perplexity --kl-divergence` on the 12B QAT canonical (`gemma-4-12B-it-qat-UD-Q4_K_XL.gguf`),
one 16384-token wikitext-2-raw chunk (`-c 16384 --chunks 1 -fa on -ngl 99`), f16-cache base logits saved once and
reused for both comparison runs. f16/q8_0 cells ran 2026-07-29; bf16 cells ran 2026-08-03 (same base file).

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
- Growth is sub-linear in ctx: most Gemma-4 layers are sliding-window and llama-server allocates the SWA-sized
  cache by default (`--swa-full` is the opt-out). Plain 12B fits at 200k under every type.
- MTP changes the budget: the P0 log measured the 12B pair at 200k/q8_0 = 11014 MiB (drafter adds ~1.2 GiB).
  - By arithmetic (not measured), an f16 pair is ~12.6-12.8 GiB at any rung - over the 12282 MiB card.
  - So MTP entries require q8_0 regardless of the fleet-wide decision.
- Absolute totals are not comparable across days (desktop baseline moved ~1.1 GiB); read the deltas.

### Decision

- Decided 2026-08-03 (user): **q8_0 fleet-wide**.
  - bf16's equal divergence shows ~0.07 KLD is dtype-change noise, not quantization damage - the f16 quality case
    is retired and no f16 A/B follow-up is filed.
  - Also cache-neutral vs what Ollama served (`KV_CACHE_TYPE=q8_0`), and the only type that fits the MTP pair.
- The ctx ladder below runs at q8_0.

## Provenance and validity

- Single box, single model, one 16k chunk, n=1 per KL cell; the spec directs reading the tool's numbers as-is.
- VRAM method is whole-GPU totals, one sample per cell; allocator variance and desktop baseline shifts are
  visible across days, so only same-day deltas are treated as signal.
- Raw logs in the session scratchpad (`kld-*.log`, `kv-*.log`); logits base on `/mnt/f/llamacpp-kld-tmp/`,
  deleted once the KV decision closes.
