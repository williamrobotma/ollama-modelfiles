# Session summary — runtime A/B, CUDA-graphs diagnosis, analysis tooling (2026-06-21)

Branch: `refactor/benchmark-common-harness`. Captures a full graphs-off vs
graphs-on benchmark run, a CUDA-graphs failure diagnosis, the new
`benchmark-report.py` analysis tool, and the open questions to resume on.

## What was done

1. **Ran the full benchmark** (`./benchmark-all.sh --execute`) — both suites, both
   runtime profiles, ~8 h on the RTX 4070 (12 GB). 80 measured runs (Qwen 64 +
   Gemma 16) + 40 warmups, **all `exit_status=0`**. Results are local + gitignored:
   - Qwen:  `benchmark-results/20260621T090535Z/`
   - Gemma: `benchmark-results/20260621T122328Z/`
2. **Added `benchmark-report.py`** — post-processes a results dir into per-prompt
   throughput mean/stdev (graphs-off vs graphs-on) + coarse output-sanity flags.
   Stdlib only; `pyproject.toml` pins `requires-python >= 3.10`.
   Run: `python3 benchmark-report.py benchmark-results/<timestamp> ...`
3. **Researched Gemma quants + MTP**; updated CLAUDE.md (see Key findings).
4. **Diagnosed the claude-local + 27b-mtp CUDA-graphs crash** (fresh subagent +
   reading the prod systemd config).

## Key findings

### Runtime A/B (CUDA graphs off vs on), generation tok/s, per prompt
- **Gemma: clean, consistent win from graphs-on** — both models, both prompts,
  +14.8–17.7 %, tiny stdev:
  - `gemma4-12b-it-qat`     ~49.6 → ~58.1 tok/s  (+17 %)
  - `gemma4-26b-a4b-it-qat` ~23.6 → ~27.1 tok/s  (+15 %)
- **Qwen: mostly n=2 noise** — per-prompt deltas sign-flip between long/medium for
  most models, so the earlier cross-prompt "regressions" were averaging+variance
  artifacts. One consistent exception:
  - **`qwen3.6-27b-mtp-coding-ud-q4-k-xl`: negative on BOTH prompts (−21 % long,
    −11 % medium)** — the only Qwen case worth confirming at higher reps.
- Dense 27B coding is brutally slow (~2.3–2.8 tok/s — an 18 GB model does not fit
  12 GB VRAM); the MTP variants roughly double that.

### CUDA-graphs crash (claude-local + 27b-mtp)
> **CORRECTION 2026-07-01:** two claims in this section were later falsified -
> see `session_summary_mtp_graphs_crash.md`. (1) "serial single-slot graphs-on
> does NOT error" is WRONG: a 30-run hammer on graphs-on + qwen3.5-9b-mtp
> crashed ~1 in 8 (12.5%), same `ggml_backend_cuda_synchronize` illegal-memory
> signature - it is intermittent, so the earlier clean run was luck, not proof.
> (2) "prod runs GGML_CUDA_DISABLE_GRAPHS=1" is WRONG: the systemd override had
> that line commented out, so prod was running graphs-ON and exposed to the
> crash. The verdict below (keep graphs-off) is still right; its evidence and
> the assumed prod state were not.

- The benchmark proves serial, single-slot graphs-on runs of the *exact* 27b-mtp
  model do NOT error (`USE_GRAPHS=1`, thousands of graph reuses, exit 0).
- claude-local's traffic is the opposite: all-streaming, huge/growing context,
  **concurrent** requests (from its OTEL capture).
- Discriminator: concurrent requests only change GPU batch shape (breaking the
  static-shape assumption of a captured CUDA graph) if `OLLAMA_NUM_PARALLEL > 1`.
- **Prod config (read from systemd):** `GGML_CUDA_DISABLE_GRAPHS=1`,
  `OLLAMA_NUM_PARALLEL` *unset* (→ Ollama auto-default, ~1 on this box),
  KV `q8_0`, flash-attn on, ctx 131072. `journalctl` shows no current CUDA
  errors — expected, since prod runs graphs-off.
  > **CORRECTION 2026-07-01:** the disable line was actually commented out in
  > the override, so prod ran graphs-ON. `OLLAMA_NUM_PARALLEL=1` *is* set
  > explicitly. See `session_summary_mtp_graphs_crash.md` for the fix.
- **Verdict:** keep `GGML_CUDA_DISABLE_GRAPHS=1` (benchmark-proven safe here,
  community-standard fix; throughput cost negligible on this offloaded setup).
  If `NUM_PARALLEL` is ever >1, that both confirms the trigger and is
  independently ill-advised on a single 12 GB GPU.

### ⚠️ CUDA 13.2 lead (UNRESOLVED — top priority next)
- `nvidia-smi` reports **CUDA Version 13.2** (driver 596.36) — the version
  CLAUDE.md flags as corrupting Gemma 4 output. Caveat: that is the WSL2
  driver's *max-supported* version, NOT necessarily the runtime Ollama bundles.
  **Not yet confirmed what CUDA Ollama actually loads.** If Ollama is on 13.2 and
  it corrupts Gemma under graphs, it could undercut the Gemma graphs-on win.

### Gemma quants / MTP
- **QAT repos publish only `UD-Q4_K_XL`** (verified via HF tree API) — no
  IQ4/Q5/Q6/Q8. By design (QAT targets ~Q4). Nothing to sweep within QAT.
- A fuller ladder exists only in the **non-QAT** repos. The one motivated
  experiment: 26B-A4B at a sub-12 GB quant to test fit-vs-speed — agent-reported
  bracket, **VERIFY against the repo**: `UD-IQ3_S` ~11.3 GB / `UD-Q3_K_XL`
  ~12.9 GB / `UD-IQ4_XS` ~13.6 GB. Caveat: at ctx 131072 + `q8_0` KV the cache is
  multi-GB, so the model offloads regardless of quant unless ctx is also reduced.
- **Gemma MTP: Mac/MLX-only in Ollama** (PR #15980, May 2026; CUDA runner
  returns "requires macOS", issue #16019). Drafters ship in the QAT repos
  (`mtp-gemma-4-*.gguf`). Mechanism = target + separate drafter via the `DRAFT`
  Modelfile directive (unlike Qwen's single self-contained MTP GGUF). Revisit
  when the CUDA runner lands; recheck `ollama --version` / release notes.

## Next steps (priority order)
1. **Resolve CUDA 13.2 & validate the Gemma win.**
   - (free) grep `benchmark-results/*/graphs-on/ollama-serve.log` for the CUDA
     runtime Ollama actually loaded.
   - (small run, only if 13.2) deterministic `temperature=0` Gemma graphs-off vs
     graphs-on diff (2 models, 1 short prompt) to confirm graphs-on is not
     silently corrupting output (the real version of the correctness check).
2. **Confirm the one real Qwen regression** — rerun
   `qwen3.6-27b-mtp-coding-ud-q4-k-xl` (or all Qwen) at `--repetitions 5`.
3. **Per-model runtime policy** — if Gemma graphs-on is validated, serve Gemma
   with graphs on; keep claude-local + Qwen-MTP graphs-off / `NUM_PARALLEL=1`.
4. **(later)** 26B-A4B VRAM-fit quant sweep (verify the bracket above);
   Gemma MTP once Ollama's CUDA runner supports it.

## Repo changes in this branch
- `benchmark-all.sh` — unified runner (runs both suites sequentially).
- `benchmark-common.sh` — isolated serves set `OLLAMA_MODELS` to the systemd
  `ollama` store so `ollama create`d models are visible.
- `benchmark-report.py` + `pyproject.toml` — analysis tool + Python floor.
- `CLAUDE.md` — QAT-quant + Gemma-MTP conventions updated; isolated-serve dir
  and new files documented.
