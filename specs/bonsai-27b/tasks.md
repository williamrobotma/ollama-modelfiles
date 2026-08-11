# Tasks: Bonsai-27B onboarding

Status legend: [ ] pending, [x] done. This file is the resume point for the feature; update as phases land.

DRAFT 2026-07-17, reworked 2026-08-03 (ternary first-class) - not started.

Blocked on `specs/llamacpp-migration` (the serving stack + config home; llamacpp-serving verdict landed).

Spec review pending: the two remaining decisions in spec.md (sampling profile, intended role).

## Phase 0 - prerequisite check + rebuild

- [ ] Serving-config home known (from `specs/llamacpp-migration`). llamacpp-serving verdict has landed (B).
- [x] #25707 status re-checked: merged 2026-07-30 (checked 2026-08-03; fork + llama-swap contingency retired).
- [ ] Rebuild past the merge; migration-spec rebuild rule passed (crash matrix, froggeric, Gemma MTP re-check).
  - Amended 2026-08-08: the prerequisite is met build-wise (build b10326 includes #25707).
  - Amended 2026-08-08: b10326 is uncertified - the re-cert failed.
  - Re-evaluate at pickup.
- [ ] Spec review: sampling-profile and role decisions recorded here.

## Phase 1 - ternary lane

- [ ] Download + pin `Q2_g64`, dspark Q4_1, mmproj Q8_0 (~10.2 GB; check `/mnt/f` before/after).
- [ ] Template vet: multi-system `/v1/chat/completions` probe recorded.
- [ ] llama-server launch from pinned path; `/props` matches profile; coding smoke.
- [ ] Served through the router preset (first ternary-family GGUF through the router; one-gen smoke).

## Phase 2 - bench (ternary)

- [ ] Parity rows `bonsai27b-q2g64` / `bonsai27b-q2g64-dspark` vs `qwen3.6-27b-coding`.
- [ ] DSpark A/B (tok/s delta + acceptance); adopt only on a win.
- [ ] VRAM/ctx envelope + long-context ceiling on the 4070.
- [ ] (optional) mmproj vision smoke.

## Phase 3 - 1-bit comparison

- [ ] Download + pin `Q1_0` + dspark Q4_1 (~5.6 GB; no second mmproj).
- [ ] Served far enough to bench: template vet + `/props`; parity rows `bonsai27b-q1` / `bonsai27b-q1-dspark`.
- [ ] Three-way comparison + serving-role verdict; winner wired into the serving config.

## Phase 4 - document

- [ ] docs/parameters.md Bonsai-27B profile section.
- [ ] docs/benchmarking.md findings + watch items (#25707 resolved, #13668 watched).
- [ ] research.md resolution notes appended.
