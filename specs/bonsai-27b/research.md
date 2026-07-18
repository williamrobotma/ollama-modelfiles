# Bonsai-27B research findings (2026-07-17)

Research record for this spec bundle. Sources: HF repo file trees, PrismML docs/announcement, ggml-org/llama.cpp PRs and discussions, community benchmarks, plus on-box checks (WSL2, RTX 4070 12 GB, stock llama.cpp b9860 at `~/Developer/llama.cpp`, Ollama 0.31.2 systemd). Verification status is marked per section; a partial adversarial-verification pass confirmed the file inventories 3-0, all other web claims are single-source quotes. Vendor performance numbers are unbenched on this box.

## Family

- PrismML Bonsai-27B, released 2026-07-14, Apache 2.0: extreme-quantization rebuild of **Qwen3.6-27B** - the same base model as `modelfiles/qwen3.6/27b-*`.
- Multimodal (separate mmproj GGUF), 262K context, thinking on by default, per-request `thinking_budget_tokens` (0 disables, -1 unlimited).
- Ships a **DSpark** speculative-decoding drafter as a separate GGUF: classic target+drafter shape (like Gemma MTP), not Qwen-style embedded MTP tensors.

File inventories (verified 3-0 against the HF file trees, 2026-07-17):

| Repo | Main GGUFs | DSpark drafter | mmproj |
|---|---|---|---|
| [prism-ml/Bonsai-27B-gguf](https://huggingface.co/prism-ml/Bonsai-27B-gguf) | `Bonsai-27B-Q1_0.gguf` 3.8 GB (1-bit, ~1.125 bpw); F16 53.8 GB | Q4_1 1.79 GB; bf16 7.29 GB | BF16 931 MB; Q8_0 629 MB |
| [prism-ml/Ternary-Bonsai-27B-gguf](https://huggingface.co/prism-ml/Ternary-Bonsai-27B-gguf) | `Q2_0` + `PQ2_0` 7.17 GB (group-128); `Q2_g64` 7.59 GB (group-64); F16 53.8 GB | Q4_1 1.95 GB; bf16 7.29 GB | BF16 931 MB; Q8_0 629 MB |

## Runtime support

The load-bearing facts; the first column is what gates this spec.

| Runtime | 1-bit `Q1_0` | Ternary |
|---|---|---|
| Stock llama.cpp b9860 (on-box) | **Runs.** Verified on-box: `GGML_TYPE_Q1_0` (type 41) in `ggml.h` with full CUDA kernel coverage incl. a dedicated MMQ instance (`mmq-instance-q1_0.cu`). Community confirms mainline CUDA runs it (b10013). | `Q2_g64` loads on mainline CUDA but on a **slow fallback path** (community test, rev 12127de). Fast CUDA kernels: [PR #25707](https://github.com/ggml-org/llama.cpp/pull/25707), **open** as of 2026-07-17 (group-64 only). `Q2_0`/`PQ2_0` (g128) are fork-only. |
| PrismML fork (`PrismML-Eng/llama.cpp`, `prism` branch) | Works; fork delta is fused "hybrid-attention" kernels (upstream-vs-fork perf delta unmeasured). | Fast path for the g128 formats. Second engine build to maintain. |
| Ollama 0.31.2 (on-box) | **Cannot load.** Verified: `strings` on the installed `libggml-base.so.0.15.3` shows only legacy `tq1_0`/`tq2_0`; the type enum ends before 41. Tracking: [ollama#13668](https://github.com/ollama/ollama/issues/13668). `ollama create --quantize` also caps at Q8_0-class types. | Cannot load. |

- Upstream Q1_0 history: CPU merged ~2026-04-06 ([PR #21273](https://github.com/ggml-org/llama.cpp/pull/21273)), x86 kernels 2026-04-20, CUDA follow-up #21629 - all pre-b9860, consistent with the on-box check.
- Upstream ternary history: CPU PR #24448 and Metal PR #25419 merged; format fixed at group-64 after maintainer review ([discussion #22019](https://github.com/ggml-org/llama.cpp/discussions/22019)) - so `Q2_g64` is the upstream-compatible file, and the fork's g128 files never will be.
- The model card's "requires PrismML fork" claim is stale for Q1_0; PrismML's own [formats page](https://docs.prismml.com/download/formats) says Q1_0 works out of the box upstream (CPU/Metal/CUDA/Vulkan).

Consequence: Bonsai-27B cannot be a Modelfile or join the keep-set today - it lives entirely on the llama.cpp lane from `specs/llamacpp-serving`.

## Quality retention (vendor-reported, UNVERIFIED)

PrismML's 15-benchmark thinking-mode table ([announcement](https://prismml.com/news/bonsai-27b)); the verification pass for these claims did not complete:

| Domain | FP16 Qwen3.6-27B | Ternary | 1-bit |
|---|---|---|---|
| Average | 85.07 | 80.49 (94.6%) | 76.11 (89.5%) |
| Math | 95.33 | 93.40 | 91.66 |
| Coding | 88.74 | 85.96 | 81.88 |
| Agentic tool use | 80.00 | 74.01 | 66.0 |
| Vision | 72.61 | 65.19 | - |

- Retention is uneven: coding holds, **agentic tool use falls hardest** - directly relevant because this box's daily drivers are agentic coding (claude-local).
- Independent community bench (98 questions, thinking off, N=1): 86.2% (ternary) / 82.9% (1-bit) relative to Qwen3.6-27B-Q4_K_M - same ordering, slightly below vendor claims.

## VRAM and throughput

- The 27B class currently partial-offloads on the 12 GB 4070 (docs/history/2026-07-17-llamacpp-eval.md section 7). Bonsai changes that:
  - 1-bit: 4.8 GiB @ 4K ctx, 5.2 @ 10K, 10.8 @ 100K (community); vendor claims ~9.4 GB at full 262K with 4-bit KV.
  - Ternary: 7.8 GiB @ 4K, 13.7 @ 100K - **exceeds 12 GB at long context** without KV quantization.
- No published RTX 4070 throughput anywhere (2026-07-17). Nearest: ~20 tok/s on an 8 GB RTX 40 laptop (N=1, ~40K ctx); RTX 5090 163/134 tok/s (1-bit/ternary, vendor); Jetson Orin 14.7/13.7 tok/s.
- On the PrismML fork, CPU ternary ran ~8-10x slower than 1-bit in one community report - kernel maturity varies by path; bench, don't assume.

## DSpark drafter

- Wiring: separate drafter GGUF -> llama-server `-md`/`--model-draft` + `--spec-draft-n-*` (classic drafter; NOT `--spec-type draft-mtp`). PrismML's demo wraps it as `BONSAI_SPECULATIVE=1`.
- Measured speedups are hardware-dependent and not always positive: vendor 1.34-1.37x on H100 (mean accepted length ~3.6 at k=4); community +33% on RTX PRO 6000 but **-37% on DGX Spark**. No 12 GB-class numbers. A/B it.

## Open items this research could not settle

- Chat template multi-system tolerance: no source documents it -> on-box probe required (multi-system `/v1/chat/completions`; the Anthropic `/v1/messages` path is structurally immune per the llamacpp eval).
- Sampling: card says temp 0.7 / top_p 0.95 / top_k 20, silent on `repeat_penalty`/`min_p`. Qwen-lineage mandate (`repeat_penalty` 1.0) presumed to apply; profile decision at spec review.
- Fork-vs-upstream perf delta for Q1_0; real 4070 throughput; whether #25707 merges soon.

## Sources

[HF 1-bit repo](https://huggingface.co/prism-ml/Bonsai-27B-gguf) - [HF ternary repo](https://huggingface.co/prism-ml/Ternary-Bonsai-27B-gguf) - [PrismML announcement](https://prismml.com/news/bonsai-27b) - [formats page](https://docs.prismml.com/download/formats) - [model docs](https://docs.prismml.com/models/bonsai-27b) - [llama.cpp PR #21273](https://github.com/ggml-org/llama.cpp/pull/21273) - [PR #25707](https://github.com/ggml-org/llama.cpp/pull/25707) - [discussion #22019](https://github.com/ggml-org/llama.cpp/discussions/22019) - [ollama#13668](https://github.com/ollama/ollama/issues/13668) - [Bonsai-demo](https://github.com/PrismML-Eng/Bonsai-demo/) - [kubesimplify bench](https://blog.kubesimplify.com/bonsai-27b-rtx-pro-6000-dgx-spark) - [HN thread](https://news.ycombinator.com/item?id=48910545)
