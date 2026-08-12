# Bonsai-27B onboarding (llama.cpp serving stack; ternary first-class)

## Why

- **Target: ternary Bonsai-27B** - an extreme-quant rebuild of the Qwen3.6-27B base the fleet already serves.
  - Quality retained vs the full-precision base (vendor-claimed): 94.6%.
  - Size: fully resident on the 12 GB 4070; the fleet's 27B class partial-offloads today.
- **Ternary is first-class (decision 2026-08-03, user)**: onboarded directly, not via a 1-bit interim phase.
  - The stepping-stone rationale expired when #25707 (fast group-64 ternary CUDA) merged 2026-07-30.
  - Q1_0, the 1-bit variant, stays as a bench comparison only; it is runnable on stock llama.cpp
    (kernel support verified on-box at b9860).
  - Q1_0 shares ternary's file layout, drafter, and template family.
- llama.cpp-only, by necessity then and by default now.
  - Ollama could not load either variant (bundled ggml lacked type 41; verified on-box) - moot since its retirement.

## Known facts

See `research.md` in this bundle - verification status marked per claim. The hard ones:

- Q1_0 runs on stock llama.cpp b9860 with CUDA kernels (on-box verified).
- Ternary fast CUDA was blocked on ggml-org/llama.cpp [PR #25707](https://github.com/ggml-org/llama.cpp/pull/25707) (group-64).
  - Merged upstream 2026-07-30 (checked 2026-08-03) - the remaining prerequisite is an on-box rebuild past it.
  - The `Q2_g64` GGUF is the upstream-compatible file; the fork's g128 formats will never be upstream.
- DSpark is a classic separate drafter (`-md`, not `--spec-type draft-mtp`).
  - Community speedups range +33% to -37% by hardware - it must be A/B'd, not assumed.
- The vendor's quality-retained numbers put agentic tool use as the weakest domain.
  - Relevant because the daily drivers here are agentic coding.

## Prerequisites

1. Met: `specs/llamacpp-migration` built the serving stack; models are configured in `llamacpp/models.ini`.
   - This spec adds a model to that stack; it creates no new serving machinery.
2. Met at b10335 (2026-08-10): the on-disk build contains #25707 and passed certification.
   - Re-check the build record (`llamacpp/launch.sh`) at pickup; a moved record re-certifies (rebuild rule).
3. Watch only: [ollama#13668](https://github.com/ollama/ollama/issues/13668) would reopen an Ollama path someday.

## Decisions at spec review

1. **Ternary path - resolved 2026-08-03**: upstream via #25707 (merged 2026-07-30); `Q2_g64` is the compatible file.
   - The fork option and its llama-swap prerequisite are retired; the fork's g128 files diverge from upstream.
   - Router mode stays single-binary, which the upstream path satisfies.
2. **Sampling profile**: PrismML card 0.7/0.95/20 vs inheriting the qwen3.6 precise-coding 0.6 profile.
   - The vendor is the authority for its own requant.
   - `repeat_penalty` 1.0 stands either way (Qwen-lineage mandate, docs/parameters.md).
3. **Intended role**: resident benchmark/general model vs coding daily-driver candidate.
   - The weak agentic quality-retained numbers say candidate status must be earned by the Phase 2/3 bench, not assumed.

## Acceptance

- **Ternary (first-class)**: Ternary-Bonsai-27B serves on the llama.cpp stack's fast CUDA path, template-vetted.
  - Served from a pinned HF-cache snapshot; full profile flags verified via `/props`.
  - Benched against 1-bit and `qwen3.6-27b-coding` (same base) in the retired parity suite's shape (git history).
  - A written serving-role verdict exists.
  - Delivers the repo's first fully-resident 27B and the first published 4070 numbers.
- **1-bit (bench comparison)**: `Q1_0` served from a pinned snapshot and template-vetted far enough to bench.
  - No serving-role claim of its own.
- DSpark drafter A/B'd with recorded accept rates and tok/s delta; adopted only if it wins on this hardware.
- Chat-template gate passed: multi-system `/v1/chat/completions` probe recorded.
  - The guard fires where `system` messages pass through untouched: `/v1/chat/completions` is the probed
    endpoint, and `/v1/responses` shares the template path.
  - `/v1/messages` folds all system blocks into one leading message before the template runs, so it cannot trip.
- docs/parameters.md gains a Bonsai-27B profile section with source URLs.
  - Benchmarking notes and watch items (#25707, ollama#13668) recorded.
- Disk budgeted against `/mnt/f` (AGENTS.md rule: never the guest `df /`).
  - Downloads: ~10.2 GB for ternary, ~5.6 GB more for the 1-bit comparison (no second mmproj).
