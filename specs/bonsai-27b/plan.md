# Plan: Bonsai-27B onboarding

Blocked until `specs/llamacpp-migration` builds the serving lane (`specs/done/llamacpp-serving` landed its verdict).

Ternary is first-class (decision 2026-08-03); 1-bit is a bench comparison. Re-verify research.md facts at run time.

## Phase 0 - gate check + rebuild

- Confirm the serving-config home from `specs/llamacpp-migration` exists and is documented.
- Rebuild llama.cpp past the #25707 merge (2026-07-30); this is the remaining ternary gate.
  - The rebuild triggers the migration spec's rebuild rule: crash matrix re-run, froggeric pair re-validation.
  - Include the Gemma MTP load re-check (docs/history/2026-07-17-llamacpp-eval.md, verdict item 5).
  - Passing the rule moves the last-known-good pin forward (stack-upkeep policy).
  - Amended 2026-08-08: gate condition met build-wise - on-disk build 10326 includes #25707 (merged 2026-07-30).
  - 10326 is uncertified: it failed the 2026-08-08 re-cert. Re-evaluate this gate at pickup.
- Spec review: record the two remaining decisions (sampling profile, intended role) in tasks.md.
  - Ternary path is already resolved upstream (spec.md decision 1).

## Phase 1 - ternary lane

- `hf download prism-ml/Ternary-Bonsai-27B-gguf`: `Q2_g64` (7.59 GB), dspark Q4_1 (1.95 GB), mmproj Q8_0 (0.63 GB).
  - Pin the snapshot path per the AGENTS.md sourcing convention.
  - Verify: `df -h /mnt/f` before/after, ~10.2 GB delta.
- Template vet: multi-system `/v1/chat/completions` probe against a running instance.
  - Verify: no 400; record pass/fail next to the fleet's guard-scan note.
- Launch under llama-server from the pinned path with the full decided profile as flags.
  - Verify: `/props default_generation_settings` matches the profile; coding smoke coherent with timings.
- Serve through the router preset (first ternary-family GGUF through the router).
  - Verify: one-gen smoke under the preset name.

## Phase 2 - bench (ternary)

- Parity rows `bonsai27b-q2g64` / `bonsai27b-q2g64-dspark` vs `qwen3.6-27b-coding` (same base).
  - Verify: report.py output with warmup + reps, not smoke N=1.
- DSpark A/B: `-md` + `--spec-draft-n-*` flags on vs off.
  - Verify: decode tok/s delta and acceptance recorded; adopt only on a win.
- VRAM/ctx envelope on the 4070: resident footprint at the Modelfile-class contexts.
  - Verify: `nvidia-smi` figures in the results dir.
- Long-context ceiling: community figures put ternary at 13.7 GiB at 100K ctx.
  - Establish the actual resident ceiling with the lane's KV quantization before claiming long-ctx support.
- Optional: mmproj load + one vision smoke (first `--mmproj` use on this lane).

## Phase 3 - 1-bit comparison

- `hf download prism-ml/Bonsai-27B-gguf`: `Q1_0` (3.8 GB), dspark Q4_1 (1.79 GB); ~5.6 GB, no second mmproj.
  - Pin the snapshot path; verify the `/mnt/f` delta.
- Serve far enough to bench: template vet + `/props` check on the decided profile.
- Parity rows `bonsai27b-q1` / `bonsai27b-q1-dspark`.
- Three-way comparison: ternary vs 1-bit vs `qwen3.6-27b-coding` on throughput, VRAM, and spot quality.
  - The vendor retention deltas (94.6% vs 89.5%) are the hypothesis under test.
- Write the serving-role verdict; wire the winner into the serving config chosen by the llamacpp follow-on.

## Phase 4 - document

- docs/parameters.md: Bonsai-27B profile section (values + source URLs + the repeat_penalty stance).
- docs/benchmarking.md: the new rows and distilled findings; watch items alongside the llamacpp watch list.
  - #25707 resolved (merged 2026-07-30); #13668 still watched.
- research.md: append a dated resolution note per gated fact (merged / still open / superseded).

## Risks / notes

- Vendor quality and speed numbers are unbenched marketing until Phase 2/3 - do not promote the model on them.
- DSpark can be a net slowdown on some hardware (-37% on DGX Spark); treat the drafter as an experiment, not a default.
- (Retired 2026-08-03) Fork lane: #25707 merged, so upstream is the only lane; no second engine to maintain.
- VRAM contention while benchmarking: same posture as the parity suite (idle the systemd Ollama during runs).
