# Tasks: Bonsai-27B onboarding

Status legend: [ ] pending, [x] done. This file is the resume point for the feature; update as phases land.

DRAFT 2026-07-17 - not started. Blocked on `specs/llamacpp-serving` (Phase 2 parity + Phase 4 verdict + follow-on serving decision). Ternary is the end state; 1-bit is the interim lane. Spec review pending: the three decisions in spec.md.

## Phase 0 - gate check + re-verify

- [ ] llamacpp-serving verdict landed; serving-config home known.
- [ ] #25707 status re-checked (api.github.com); rebuild plan if merged (incl. Gemma MTP load re-check).
- [ ] Spec review: ternary-path / sampling-profile / role decisions recorded here.

## Phase 1 - 1-bit lane

- [ ] Download + pin `Q1_0`, dspark Q4_1, mmproj Q8_0 (~6.2 GB; check `/mnt/f` before/after).
- [ ] Template vet: multi-system `/v1/chat/completions` probe recorded.
- [ ] llama-server launch from pinned path; `/props` matches profile; coding smoke.

## Phase 2 - bench (1-bit)

- [ ] Parity rows `bonsai27b-q1` / `bonsai27b-q1-dspark` vs `qwen3.6-27b-coding-ud-q4-k-xl`.
- [ ] DSpark A/B (tok/s delta + acceptance); adopt only on a win.
- [ ] VRAM/ctx envelope on the 4070.
- [ ] (optional) mmproj vision smoke.

## Phase 3 - ternary (end state)

- [ ] Ternary gate cleared (upstream merge + rebuild, or fork decision executed).
- [ ] Phases 1-2 repeated on `Q2_g64` (or fork format).
- [ ] Three-way comparison + long-context ceiling + serving-role verdict.

## Phase 4 - document

- [ ] docs/parameters.md Bonsai-27B profile section.
- [ ] docs/benchmarking.md findings + watch items (#25707, #13668).
- [ ] research.md resolution notes appended.
