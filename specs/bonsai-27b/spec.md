# Bonsai-27B onboarding (llama.cpp lane; ternary first-class)

## Why

- **Ternary Bonsai-27B is the target**: the highest-retention extreme quant of the repo's existing Qwen3.6-27B base.
  - Vendor-claimed retention 94.6%.
  - Small enough to run fully resident on the 12 GB 4070; the 27B class currently partial-offloads.
    - Source: docs/history/2026-07-17-llamacpp-eval.md section 7.
- **Ternary is first-class (decision 2026-08-03, user)**: onboarded directly, not via a 1-bit interim lane.
  - The stepping-stone rationale expired when #25707 merged (2026-07-30); the upstream block is gone.
  - Q1_0 stays as a bench comparison, not an onboarding phase. It remains runnable on stock b9860.
  - Q1_0 shares ternary's file layout, drafter, and template family.
- Ollama cannot load either variant (bundled ggml lacks type 41; verified on-box).
  - So this feature lives entirely on the llama.cpp serving lane built in `specs/llamacpp-migration`.
  - No Modelfile, no keep-set entry.

## Known facts

See [research.md](research.md) in this bundle - verification status marked per claim. The hard ones:

- Q1_0 runs on stock llama.cpp b9860 with CUDA kernels (on-box verified).
- Ternary fast CUDA was gated on ggml-org/llama.cpp [PR #25707](https://github.com/ggml-org/llama.cpp/pull/25707) (group-64).
  - Merged upstream 2026-07-30 (checked 2026-08-03) - the remaining gate is an on-box rebuild past it.
  - The `Q2_g64` GGUF is the upstream-compatible file; the fork's g128 formats will never be upstream.
- DSpark is a classic separate drafter (`-md`, not `--spec-type draft-mtp`).
  - Community speedups range +33% to -37% by hardware - it must be A/B'd, not assumed.
- Vendor retention numbers put agentic tool use as the weakest domain.
  - Relevant because the daily drivers here are agentic coding.

## Dependencies / gates

1. `specs/llamacpp-migration` builds the serving lane and fixes where non-Ollama models are configured.
   - `specs/done/llamacpp-serving` already landed its Phase 2 parity + Phase 4 verdict.
   - This spec adds a model to that lane; it creates no new serving machinery.
2. Ternary: PR #25707 merged 2026-07-30; the remaining gate is the on-box rebuild (migration spec rebuild rule).
3. Watch only (not gates): [ollama#13668](https://github.com/ollama/ollama/issues/13668) would reopen a Modelfile path someday.

## Decisions at spec review

1. **Ternary path - resolved 2026-08-03**: upstream via #25707 (merged 2026-07-30); `Q2_g64` is the compatible file.
   - The fork option and its llama-swap prerequisite are retired; the fork's g128 files diverge from upstream.
   - Router mode stays single-binary, which the upstream path satisfies.
2. **Sampling profile**: PrismML card 0.7/0.95/20 vs inheriting the qwen3.6 precise-coding 0.6 profile.
   - The vendor is the authority for its own requant.
   - `repeat_penalty` 1.0 stands either way (Qwen-lineage mandate, docs/parameters.md).
3. **Intended role**: resident benchmark/general model vs coding daily-driver candidate.
   - The vendor's agentic-retention numbers say candidate status must be earned by the Phase 2/3 bench, not assumed.

## Acceptance

- **Ternary (first-class)**: Ternary-Bonsai-27B serves on the llama.cpp lane's fast CUDA path, template-vetted.
  - Served from a pinned HF-cache snapshot; full profile flags verified via `/props`.
  - Benched against 1-bit and `qwen3.6-27b-coding-ud-q4-k-xl` (same base) in the parity suite's shape.
  - A written serving-role verdict exists.
  - Delivers the repo's first fully-resident 27B and the first published 4070 numbers.
- **1-bit (bench comparison)**: `Q1_0` served from a pinned snapshot and template-vetted far enough to bench.
  - No serving-role claim of its own.
- DSpark drafter A/B'd with recorded accept rates and tok/s delta; adopted only if it wins on this hardware.
- Chat-template gate passed: multi-system `/v1/chat/completions` probe recorded.
  - The Anthropic path is structurally immune; the OpenAI path is the risk.
- docs/parameters.md gains a Bonsai-27B profile section with source URLs.
  - Benchmarking notes and watch items (#25707, #13668) recorded.
- Ollama untouched: no Modelfiles, keep-set policy intact, disk budgeted against `/mnt/f`.
  - Downloads: ~10.2 GB for the ternary lane, ~5.6 GB more for the 1-bit comparison (no second mmproj).
