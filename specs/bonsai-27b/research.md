# Bonsai-27B research findings (2026-07-17)

RECORD - written 2026-07/08 and kept as written; re-verify its claims at pickup (plan.md).
Ollama-era references are historical.

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

Consequence: Bonsai-27B cannot be a Modelfile or join the keep-set today - it lives entirely on the llama.cpp lane built in `specs/llamacpp-migration`.

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

## Pre-flight re-verification 2026-08-12

Re-check before pickup. llama.cpp paths read at the served commit `74ce15741`.

### Build and kernels

- Served build is `version: 10335 (74ce15741)` - `llama-server --version`.
- #25707 is in that history: `9b2a08881 CUDA: add Q2_0 support (#25707)` - `git log 74ce15741 --grep=25707`.
- Merged 2026-07-30T09:33:25Z - llama.cpp PR #25707.
- Ternary CUDA kernel: `ggml/src/ggml-cuda/template-instances/mmq-instance-q2_0.cu`.
- 1-bit CUDA kernel: `mmq-instance-q1_0.cu`, same directory.
- Type enums are `GGML_TYPE_Q1_0 = 41` and `GGML_TYPE_Q2_0 = 42` - `ggml/include/ggml.h:431-432`.
- b10335 -> b10375 is 40 commits, none touching ternary, Q1_0, or router code -
  `gh api .../compare/74ce15741...b10375`.
  - One fleet-relevant fix sits there: #26793, merged 2026-08-11. The `<function` trigger constrained valid text
    such as `#include <functional>` whenever tools were supplied. Affects the Qwen entries, not Bonsai.

### File selection

Upstream's `q2_0` is the group-64 layout, so the file to download is `Q2_g64`.

- `Q2_g64` = upstream `Q2_0` (type 42): `QK2_0 64`, 2 B scale + 16 B, 2.25 bpw -> 7.59 GB predicted,
  7,585,330,240 B actual.
- Fork `Q2_0` and `PQ2_0`: group-128, 2 B + 32 B, 2.125 bpw -> 7.17 GB predicted, 7,165,121,600 B actual.
- `Q1_0` (type 41): `QK1_0 128`, 2 B + 16 B, 1.125 bpw -> 3.80 GB predicted, 3,803,452,480 B actual.
- Block definitions, each with a `static_assert` on its size: `ggml/src/ggml-common.h:180-192`.
- The fork file fails loudly, not silently: `tensor 'output.weight' has invalid ggml type 142. should be in
  [0, 42)` - llama.cpp issue #26073.
- `PQ2_0` is unstable: "Do not use yet... no guarantee they stay the same" - Bonsai-demo README.
- The 27B file is `Ternary-Bonsai-27B-Q2_g64.gguf`; smaller Bonsai repos use `-Q2_0_g64`, so their download
  pattern 404s here.
- Group-64 was settled 2026-04-21: "A group size of 64 would cost less than 6% extra memory and will be more
  practical" - ggerganov, llama.cpp discussion #22019.

### Residency arithmetic

Qwen3.6-27B is hybrid SSM/attention: most layers hold a constant-size state, not a growing KV cache.

- 16 of 64 layers are full attention - `full_attention_interval = 4`, and `src/models/qwen35.cpp:25` marks layer
  `i` recurrent when `(i + 1) % 4 != 0`.
- KV per token at q8_0 is 34.0 KiB - `16 x 4 x (256 + 256)` elements at 34 B per 32 - `ggml-common.h:251-256`.
- Recurrent state is ~150 MiB and constant - `n_embd_r` 30,720 + `n_embd_s` 786,432 per layer, f32, x48 -
  `llama-hparams.cpp:204,222`.
- KV quant reaches attention layers only; `recurrent_type_k/v` are hard-coded `GGML_TYPE_F32` -
  `src/llama-model.cpp:2295-2296`.

Totals below are weights 7.07 GiB + recurrent 0.15 GiB + KV, excluding compute buffers:

- 32K -> 8.28 GiB. 64K -> 9.35. 100K -> 10.46. 131072 -> 11.47. 200000 -> 13.70. 262144 -> 15.72.
- Usable is ~11.2-11.6 GiB, since Windows shares the card, so 200000 and 262144 are over.
- The vendor's FP16-KV figures (8.4 GB at 4K, 14.7 GB at 100K) imply 64 KiB/token, exactly double the q8_0 figure.
- The community's "13.7 GiB @ 100K" is that same FP16 measurement expressed in GiB.

### Chat template

- The guard is present verbatim: `raise_exception('System message must be at the beginning.')` - read from the
  GGUF header field `gguf.chat_template`.
- `merged_system` is absent, so mid-conversation system messages hard-fail rather than being dropped.
- Both entries therefore serve under froggeric's `chat_template.jinja`.
- Gate gap: step 1's 30 MB grep cannot separate "no guard" from "not read far enough". Add a positive control.

### DSpark: dropped

- Does not load on stock: `gguf_init_from_reader: tensor 'dspark.fc.weight' has offset 337718592, expected
  357584192` - llama.cpp issue #26337, OPEN, filed 2026-07-30.
- Reproduced on master - GTaf, 2026-08-01: "I was able to reproduce the problem on my setup with the latest
  master branch."
- Vendor confirms fork-only - khosravipasha, 2026-08-10: "the dspark version only work with our fork at the
  moment... Might take some time before we finalize this."
- Not fixed in our build: no offset fix among the 138 commits b10197 -> b10335.
- Not a classic `-md` drafter: needs `--spec-type draft-dspark`, and plain `--model-draft` gives
  `unknown model architecture: 'dspark'`.
- No fallback drafter exists: Bonsai 1.7B/8B carry vocab 151,669 against the 27B's 248,320, versus
  `SPEC_VOCAB_MAX_SIZE_DIFFERENCE 128` - `common/speculative.cpp:28`.
- The #26337 config nearly matches this box: q8_0 KV, flash attention, `models-max 1`, `parallel 1`,
  `spec-draft-n-max 2`, the same three files.
- Rejected: a comment there blames a 17 B `Q2_0` block. It is 18 B (`ggml-common.h:192`), which reproduces the
  file's exact byte size.

### Cleared risks

- Flash attention, quantized KV, and ternary weights cannot interact - `ggml_cuda_get_best_fattn_kernel()`
  dispatches on the Q/K/V/mask types only - `ggml/src/ggml-cuda/fattn.cu:358`.
- MMQ covers both types on this GPU - Ada (sm_89) takes the Ampere path (`mmq.cuh:244`), and
  `mmq-config-ampere.cuh` carries explicit `Q2_0` and `Q1_0` cases.
- Router CLI flags do reach children - `tools/server/server-models.cpp:548-552` merges the base preset into
  every entry.
- A failed load does not take down the router - PR #25707's log shows the child exiting and the router logging
  `instance name=... exited with status 1`, then continuing.
- No speculative-decoding flag renames are pending: `--spec-draft-model`/`-md`, `-n-max`/`-n-min`, and
  `--spec-draft-ngl` are unchanged since b9641.
- No base-model churn: Qwen3.7 is API-only and closed, with no open-weight successor to Qwen3.6-27B.
- No quant-format churn: no PR renumbers types 41/42, and new ternary work appends at index 43+.

### Community evidence (N=1 each, informal)

- No RTX 4070 throughput number is published anywhere.
- Nearest 12 GB-class is an RTX 3060 at 18-27 tok/s ternary, "121k to 64k taking 10.7gb vram" - ternary repo
  discussion #16. A 4090 reports ~89 tok/s - discussion #40.
- Looping and broken tool calls on 12 GB-class cards - lobstertot, RTX 4070 Ti: "its loopy (on reasoning, tool
  calling), hallucinates and got tool calling problems" - discussion #41.
  - Resolved only after moving to a 20 GB card at f16 KV, never re-confirmed at 12 GB.
- q8_0 KV is untested by anyone: aaron-newsome ran q4_0, and PrismML's own dev replied "maybe can try Q8_0
  kv-cache?" - discussion #36.
- One mitigation: CypherPK fixed it under q4 KV using froggeric's template plus DRY sampling - discussion #41.
- Several users run `repeat_penalty` 1.1-1.15; one at 1.15 still got "syntax hallucinations while coding" -
  discussions #19 and #36.
- An independent bench (ArmanJR, 98 questions, thinking off) inverts the vendor's emphasis: coding held best at
  94.0% ternary and 97.6% 1-bit, while math collapsed to 69.0% and 64.3%.

### Unresolved, carried into the plan

- Whether `Bonsai-27B-Q1_0.gguf` generates correct output on stock. Kernels exist and `QK1_0 128` matches the
  file's packing, but the vendor card still says "Clone the PrismML fork" and no upstream report settles it.
- The q8_0 residency ceiling, unpublished; Phase 1 measures it.
- Fork issue #102: CUDA illegal memory access at 81920 ctx after task cancellation, on the same MMQ path.
  Unconfirmed on stock; worth one smoke test.

