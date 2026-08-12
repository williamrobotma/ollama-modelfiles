# Plan: Bonsai-27B onboarding

Not started; runs after `specs/llamacpp-migration` closes (the serving stack it joins already exists).
Ternary is first-class (decision 2026-08-03); 1-bit is a bench comparison only.
Re-verify research.md facts at pickup; they were recorded 2026-07/08.
`Verify:` marks the check that closes the step above it.

Terms:

- #25707 - llama.cpp PR adding fast CUDA kernels for group-64 ternary quants; merged upstream 2026-07-30.
- b10326, b10335, ... - llama.cpp build numbers; the served build record lives in `llamacpp/launch.sh`.
- DSpark - PrismML's separate speculative-decoding drafter GGUF (a classic `-md` drafter, not embedded MTP).
- `Q2_g64` (ternary) and `Q1_0` (1-bit) - the two Bonsai GGUF variants under test.

## Phase 0 - prerequisites + decisions

- Confirm the build record is at or past b10335.
  - Verify: `llamacpp/launch.sh` header; b10335 contains #25707 and passed certification 2026-08-10.
  - If the record moved since: the migration spec's rebuild rule applies (crash matrix, froggeric pair,
    Gemma MTP load re-check).
- Record the two open decisions in tasks.md: sampling profile (vendor card vs the qwen3.6 coding profile)
  and intended role.

## Phase 1 - ternary lane

- `hf download prism-ml/Ternary-Bonsai-27B-gguf`: `Q2_g64` (7.59 GB), DSpark Q4_1 (1.95 GB), mmproj Q8_0 (0.63 GB).
  - Pin the snapshot path per AGENTS.md sourcing.
  - Verify: `df -h /mnt/f` before/after, ~10.2 GB delta.
- Template vet per the AGENTS.md chat-template gate.
  - Verify: probe result matched by the guard's message text (never HTTP status); recorded in `llamacpp/README.md`.
- Launch under llama-server from the pinned path with the decided profile as flags.
  - Verify: `/props` matches the profile; one coding smoke returns coherent output with timings.
- Serve through the router preset (the first ternary-family GGUF through the router).
  - Verify: one-gen smoke under the preset name.

## Phase 2 - bench (ternary)

- A/B rows: `bonsai27b-q2g64` and `bonsai27b-q2g64-dspark` vs `qwen3.6-27b-coding` (same base model).
  - The retired parity suite (git history) is the shape to follow; harness details are the runner's call.
  - Verify: warmup + repetitions recorded, not a single-run smoke.
- DSpark A/B: `-md` on vs off.
  - Verify: decode tok/s delta and acceptance rate recorded; adopt only on a win.
- VRAM/ctx envelope on the 4070: resident long-ctx ceiling under the fleet's q8_0 KV cache.
  - Community figure to test: 13.7 GiB resident at 100K ctx.
  - Verify: `nvidia-smi` figures per the benchmarking.md resource-capture procedure.
- Optional: mmproj load + one vision smoke.

## Phase 3 - 1-bit comparison

- `hf download prism-ml/Bonsai-27B-gguf`: `Q1_0` (3.8 GB), DSpark Q4_1 (1.79 GB); ~5.6 GB, no second mmproj.
  - Pin the snapshot path; verify the `/mnt/f` delta.
- Serve far enough to bench: template vet + `/props` check on the decided profile.
- A/B rows: `bonsai27b-q1` and `bonsai27b-q1-dspark`.
- Three-way comparison: ternary vs 1-bit vs `qwen3.6-27b-coding` - throughput, VRAM, spot quality.
  - The vendor quality-retained deltas (94.6% vs 89.5%) are the hypothesis under test.
- Write the serving-role verdict; add the winner as a `llamacpp/models.ini` entry.

## Phase 4 - document

- docs/parameters.md: Bonsai-27B profile section (values, source URLs, the repeat_penalty stance).
- docs/benchmarking.md: distilled findings; watch items (#25707 resolved, ollama#13668 watched).
- research.md: append a dated resolution note per blocked fact.

## Risks / notes

- Vendor quality and speed numbers are unbenched marketing until Phase 2/3; do not promote the model on them.
- DSpark can be a net slowdown (-37% on a DGX Spark community bench); treat it as an experiment, not a default.
- VRAM contention while benchmarking: keep the router's resident child idle; nothing else competes for the card.
