# Session Summary: 9B-Coders VRAM-Fit Research (12 GB RTX 4070)

Reconstructed after a `/clear` wiped the original research context. All sizes
and claims re-verified against the HuggingFace API and the model cards.

## Validation verdict (prior Sonnet research, recovered from transcript)
The Feb-2026 Sonnet session did the original research; its `please validate`
subagent failed ("Prompt is too long") so the check never ran. Validated here:

**Sound (confirmed):** 12 GB fit/offload line; Qwen3.6 has no small dense tier;
Qwen3.5 dense ladder (0.8/2/4/9/27B); 9B fits ~6 GB; KV-at-131072 forces offload
so capping `num_ctx` is the real lever; UD-Q4_K_XL is the quant sweet spot;
correctly refused to invent "Qwopus 3.6" until given the real Jackrong HF repo.

**Quality numbers are untrustworthy — not a clean re-ranking:** Sonnet's scores
came from SEO aggregators, not model cards. A primary-source spot-check of the
one staged model disagrees by ~10 pts: Sonnet cited **Qwen3.5-9B LiveCodeBench
= 55.8**; the official card claims **65.6** (itself a vendor self-report — trust
it no more than Qwopus's card). That gap means the *rankings can't be trusted as
derived*. But it does **not** re-rank anything: 65.6 (LCB) vs the unstaged 14B's
89% (HumanEval, saturated/2024) are different benchmarks, and Sonnet itself
wrote *"I could not cleanly rank these on quality."* **14B-vs-9B stays
unresolved.** The only thing that settles it is an on-box benchmark — which is
exactly what the `benchmark-9b-coders` matrix/harness is for.

**Staged ≠ recommended:** Sonnet's verdict was primary=Qwen2.5-Coder-14B,
fallback=Qwen3.5-9B, heavy=Qwen3-Coder-30B-A3B. On disk: only Qwen3.5-9B +
Qwopus3.5-9B-Coder (the user steered to the 9B/Qwopus line). The 14B/30B were
never staged.

**Qwopus edge is unproven:** its card beats base 9B only on *bespoke* tests
(HermesAgent-20 85 vs 71, BugFind-15 79) plus a self-reported SWE-bench 53.89%
(implausibly high for a 9B; "experimental", warns of capability decay); no
LiveCodeBench/HumanEval/MBPP. → keep ONLY as an experimental A/B vs base.

**Config notes on the staged files:** `num_ctx` is held at **131072 (128K) by
user preference** — at full context the 9Bs may partially offload (Sonnet's math
puts the clean-resident point ~64K), so the benchmark *measures* the 128K
offload cost rather than capping to avoid it. And neither Sonnet nor the files
use **Qwen3.5-9B-MTP** (fits + speculative-decoding speed on CUDA) — left as a
recommendation, not staged.

## Why this exists
Every installed coding model **offloads** on the 12 GB card:
- `qwen3.6-27b-coding` ~18 GB, `qwen3.6-35b-a3b-*` ~19–23 GB → partial CPU
  offload → dense 27B runs ~2.3–2.8 tok/s (`session_summary_runtime_ab.md`).
- Only `gemma4-12b-it-qat` (6.9 GB) is fully GPU-resident, but it is a thinking
  model, not coding-specialized.

Goal: a **coding** model that fits resident and runs fast.

## The constraint that forces Qwen 3.5
Qwen **3.6**'s smallest GGUF is **27B** (offloads). Qwen **3.5** is the nearest
line with small dense variants — 9B / 4B / 2B / 0.8B (each also `-MTP`). So
`Qwen3.5-9B` is the largest Qwen dense that fits 12 GB. Unsloth ships **no**
Qwen3.5 Coder/Instruct GGUF → hence the community **Qwopus** coder finetune.

## Why a 9B holds 128K on 12 GB: Gated-DeltaNet hybrid
Qwen3.5 arch = 32 layers, **24 linear-attention (Gated DeltaNet) + 8 full-
attention** (3:1 pattern, per `Qwen/Qwen3.5-9B` config.json). KV cache grows
only on the 8 full-attn layers → ~¼ of a full-attention 9B.
- KV @ 131072, q8_0, n_kv_heads=4, head_dim=256, 8 layers ≈ **~2.1 GB**.
- A full-attention 9B would be ~8.4 GB KV → offload. The hybrid is the enabler.
- Server runs `flash_attention=1`, `kv_cache_type=q8_0` (halves KV vs f16).

## Fit table (UD-Q4_K_XL unless noted; usable ≈ 10–11 GB on WSL2)
| Model | Quant | Weights | KV@128K | ~Total@128K | Fit |
|---|---|---|---|---|---|
| Qwen3.5-9B-MTP | UD-Q4_K_XL | 6.14 GB | ~2.1 | ~9.5 GB | resident (tight) + MTP speedup |
| Qwen3.5-9B | UD-Q4_K_XL | 5.97 GB | ~2.1 | ~9.4 GB | resident (tight) |
| Qwopus3.5-9B-Coder | Q4_K_M | 5.63 GB | ~2.1 | ~9.0 GB | resident (tight); coder finetune |
| Qwen3.5-4B | UD-Q4_K_XL | 2.71 GB | ~1.0 | ~4.5 GB | resident, large headroom |
| gemma4-12b-it-qat | UD-Q4_K_XL | 6.9 GB | larger (full-attn) | offloads @200K | resident only ≤~32K |

KV figures are estimates. @128K the 9Bs sit near the edge and may partially
offload; `num_ctx` is held at 128K by preference, so `ollama ps` shows the
actual GPU/CPU split the benchmark measures.

## Recommendation
- **Primary: `Qwen3.5-9B-MTP`** — 9B quality + speculative-decoding throughput,
  fits. **Runs on this CUDA box:** Qwen MTP is a single self-contained GGUF, so
  it avoids the separate-drafter path CLAUDE.md flags as macOS/MLX-only (that
  caveat is Gemma-specific) — confirmed by the installed `qwen3.6-27b-mtp-*`
  models (~2× throughput, runtime A/B). *Not yet staged — worth adding.*
- **Staged:** `Qwen3.5-9B` (base reference) and `Qwopus3.5-9B-Coder` — bench the
  finetune head-to-head vs base to test whether the Claude-Opus distill actually
  helps (its benchmarks are self-reported only).
- **Fallback / speed:** `Qwen3.5-4B` (or `-MTP`) — fits trivially at full ctx.
- **Baseline:** `gemma4-12b-it-qat` — keep; fits only at reduced ctx.
  **Caveat:** this host runs CUDA **13.2**, which CLAUDE.md flags as corrupting
  Gemma 4 output — verify the baseline emits clean output (or move to CUDA
  13.1/13.3) before trusting any head-to-head against it.

## Verified facts
- HF `/tree/main` sizes (bytes): 9B `5,966,095,584`; 9B-MTP `6,135,034,208`;
  Qwopus Q4_K_M `5,629,104,928`; 4B `2,912,109,728`.
- `Qwen3.5-9B`: model_type `qwen3_5`, native context **262144 (256K)**, max
  ~1.01M with YaRN; precise-coding params temp 0.6 / top_p 0.95 / top_k 20 /
  min_p 0 / presence 0 / repeat 1.0 (unsloth card). Official card (vendor
  self-reported): **LiveCodeBench v6 65.6**, GPQA-Diamond 81.7; a unified vision-
  language general model (not coder-tuned), so a coder finetune like Qwopus is a
  reasonable thing to test.
- `Qwopus3.5-9B-Coder`: finetune of `Qwen/Qwen3.5-9B`; Claude-Opus 4.x trace-
  inversion + GLM-5.1 agent traces; emits `<think>`; self-reported benchmarks;
  ships `mmproj-F32.gguf` (vision) but `:Q4_K_M` pulls the text GGUF only.
- Host: RTX 4070 12 GB, WSL2, CUDA **13.2** (see Gemma baseline caveat above).
