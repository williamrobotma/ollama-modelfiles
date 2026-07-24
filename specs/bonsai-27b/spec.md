# Bonsai-27B onboarding (llama.cpp lane; ternary end state)

## Why

- **Ternary Bonsai-27B is the target**: the highest-retention extreme quant (94.6% vendor-claimed) of the repo's existing Qwen3.6-27B base, small enough to run fully resident on the 12 GB 4070 - the 27B class currently partial-offloads (docs/history/2026-07-17-llamacpp-eval.md section 7).
- **1-bit Q1_0 is the stepping stone**: runnable today on the stock b9860 lane; same file layout, drafter, and template as ternary, so onboarding it builds every mechanism ternary needs while ternary's fast CUDA path is blocked upstream.
- Ollama cannot load either variant (bundled ggml lacks type 41; verified on-box), so this feature lives entirely on the llama.cpp serving lane built in `specs/llamacpp-migration`. No Modelfile, no keep-set entry.

## Known facts

See [research.md](research.md) in this bundle - verification status marked per claim. The hard ones:

- Q1_0 runs on stock llama.cpp b9860 with CUDA kernels (on-box verified).
- Ternary fast CUDA is gated on ggml-org/llama.cpp [PR #25707](https://github.com/ggml-org/llama.cpp/pull/25707) (group-64; the `Q2_g64` GGUF is the upstream-compatible file); the fork's g128 formats will never be upstream.
- DSpark is a classic separate drafter (`-md`, not `--spec-type draft-mtp`); community speedups range +33% to -37% by hardware - it must be A/B'd, not assumed.
- Vendor retention numbers put agentic tool use as the weakest domain - relevant because the daily drivers here are agentic coding.

## Dependencies / gates

1. `specs/llamacpp-migration` builds the serving lane and fixes where non-Ollama models are configured (`specs/done/llamacpp-serving` already landed its Phase 2 parity + Phase 4 verdict). This spec adds a model to that lane; it creates no new serving machinery.
2. Ternary end state: PR #25707 merged + on-box rebuild, OR the fork decision below.
3. Watch only (not gates): [ollama#13668](https://github.com/ollama/ollama/issues/13668) would reopen a Modelfile path someday.

## Decisions at spec review

1. **Ternary path**: wait for #25707 (recommended - no second engine to maintain; `Q2_g64` is the compatible file) vs build the PrismML fork now (unblocks ternary immediately; adds fork maintenance; its g128 files diverge from upstream).
   - Serving-layer gate (added 2026-07-23): router mode is single-binary (b9860 `tools/server/server-models.cpp`).
   - So "build the PrismML fork" requires adopting llama-swap (or a second port) BEFORE ternary onboards.
   - Decide early in Phase 0 - the migration's router INI ports to llama-swap YAML in ~half a day.
2. **Sampling profile**: PrismML card 0.7/0.95/20 (vendor is the authority for its own requant) vs inheriting the qwen3.6 precise-coding 0.6 profile. `repeat_penalty` 1.0 stands either way (Qwen-lineage mandate, docs/parameters.md).
3. **Intended role**: resident benchmark/general model vs coding daily-driver candidate - the vendor's agentic-retention numbers say candidate status must be earned by the Phase 2/3 bench, not assumed.

## Acceptance

- **Ternary (end state)**: Ternary-Bonsai-27B serves on the llama.cpp lane's fast CUDA path from a pinned HF-cache snapshot, full profile flags verified via `/props`, template-vetted; benched against 1-bit and against `qwen3.6-27b-coding-ud-q4-k-xl` (same-base comparison) in the parity suite's shape; a written serving-role verdict.
- **1-bit (interim, achievable now)**: same criteria on `Q1_0`; delivers the repo's first fully-resident 27B and the first published 4070 numbers.
- DSpark drafter A/B'd with recorded accept rates and tok/s delta; adopted only if it wins on this hardware.
- Chat-template gate passed: multi-system `/v1/chat/completions` probe recorded (Anthropic path is structurally immune; the OpenAI path is the risk).
- docs/parameters.md gains a Bonsai-27B profile section with source URLs; benchmarking notes and watch items (#25707, #13668) recorded.
- Ollama untouched: no Modelfiles, keep-set policy intact, disk budgeted against `/mnt/f` (downloads ~6.2 GB for 1-bit lane, ~9.5 GB more for ternary).
