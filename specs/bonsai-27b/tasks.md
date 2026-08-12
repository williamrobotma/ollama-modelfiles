# Tasks: Bonsai-27B onboarding

Status legend: [ ] pending, [x] done. This file is the resume point for the feature; update as phases complete.

DRAFT 2026-07-17, reworked 2026-08-03 (ternary first-class) - not started.

Runs after `specs/llamacpp-migration` closes; the serving stack and config home already exist.

Spec review pending: the two remaining decisions in spec.md (sampling profile, intended role).

## Phase 0 - prerequisites + decisions

- [x] #25707 (fast group-64 ternary CUDA) merged upstream 2026-07-30; checked 2026-08-03, fork contingency retired.
- [x] Build prerequisite met: on-disk b10335 contains #25707 and passed certification 2026-08-10.
  - [ ] At pickup: confirm the build record (`llamacpp/launch.sh`) has not moved; if it has, the migration
    spec's rebuild rule applies.
- [ ] Spec review: sampling-profile and role decisions recorded here.

## Phase 1 - ternary lane

- [ ] Download + pin `Q2_g64`, DSpark Q4_1, mmproj Q8_0 (~10.2 GB; check `/mnt/f` before/after).
- [ ] Template vet per the AGENTS.md gate; result recorded in `llamacpp/README.md`.
- [ ] llama-server launch from the pinned path; `/props` matches the profile; coding smoke.
- [ ] Served through the router preset (first ternary-family GGUF through the router; one-gen smoke).

## Phase 2 - bench (ternary)

- [ ] A/B rows `bonsai27b-q2g64` / `bonsai27b-q2g64-dspark` vs `qwen3.6-27b-coding` (retired parity suite's shape).
- [ ] DSpark A/B (tok/s delta + acceptance rate); adopt only on a win.
- [ ] VRAM/ctx envelope + long-context ceiling on the 4070.
- [ ] (optional) mmproj vision smoke.

## Phase 3 - 1-bit comparison

- [ ] Download + pin `Q1_0` + DSpark Q4_1 (~5.6 GB; no second mmproj).
- [ ] Served far enough to bench: template vet + `/props`; A/B rows `bonsai27b-q1` / `bonsai27b-q1-dspark`.
- [ ] Three-way comparison + serving-role verdict; the winner added as a preset entry.

## Phase 4 - document

- [ ] docs/parameters.md Bonsai-27B profile section.
- [ ] docs/benchmarking.md findings + watch items (#25707 resolved, ollama#13668 watched).
- [ ] research.md resolution notes appended.
