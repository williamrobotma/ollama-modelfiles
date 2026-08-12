# Tasks: Bonsai-27B onboarding

Status legend: [ ] pending, [x] done. This file is the resume point for the feature; update as phases complete.

DRAFT 2026-07-17, reworked 2026-08-03 (ternary first-class), pre-flight review 2026-08-12 - implementation not started.

Cleared to start (user, 2026-08-12): full send, in its own session. Does not wait on `specs/llamacpp-migration`.

Resume point: Phase 0. Everything below Phase 0 is untouched.

## Phase 0 - prerequisites + decisions

- [x] #25707 (group-64 ternary CUDA) merged upstream 2026-07-30, and is in the served build's history.
- [x] Build prerequisite met: on-disk b10335 matches its `llamacpp/launch.sh` record.
  - [x] Pinning at b10335 confirmed defensible; b10375 changes nothing this spec depends on.
  - [ ] At pickup: re-confirm the record has not moved; else the rebuild rule applies.
- [x] Spec review closed. Decisions and their evidence are in spec.md and research.md.
  - [x] DSpark dropped; follow-on bundle scaffolded as `specs/bonsai-dspark`.
  - [x] KV cache A/B moved out to `specs/kv-cache-ab`, fleet-wide, with Bonsai as one arm.
  - [x] Sampling: four arms - coding, reasoning, instruct, and the vendor card.
  - [x] Role and `ctx-size`: decided after measuring, in Phase 1.
  - [x] Bench tool: `llama-bench`; serve-path checks are the runner's call at Phase 2.
- [ ] Owner confirms the GPU core clock offset is at or below +120 MHz. Blocking; not readable from WSL.
- [ ] Rule on the served ids (spec.md's open decision).

## Phase 1 - ternary lane

- [ ] Download + pin `Q2_g64` and mmproj `Q8_0` (8.21 GB; check `/mnt/f` before and after).
  - Never `Q2_0` or `PQ2_0` - fork group-128 packing, and `PQ2_0` is vendor-marked unstable.
- [ ] Template vet per the AGENTS.md gate, with a positive control; result recorded in `llamacpp/README.md`.
  - The guard is known present, so a zero hit means the grep window was too small.
- [ ] Measure the residency ceiling with `nvidia-smi` at all three capture points.
- [ ] Decide role and `ctx-size` from that measurement; write the preset entry.
- [ ] llama-server launch from the pinned path; `/props` matches the profile; coding smoke.
- [ ] Served through the router preset (one-gen smoke).
- [ ] Record any repetition loops or malformed tool calls.

## Phase 2 - bench (ternary)

- [ ] `llama-bench`: ternary vs `qwen3.6-27b-coding` across a ctx ladder, warmup plus repetitions.
- [ ] Sampling arms: coding, reasoning, instruct, vendor card.
- [ ] Serve-path checks scoped at pickup.
- [ ] (optional) mmproj vision smoke.

## Phase 3 - 1-bit comparison

- [ ] Download + pin `Q1_0` (3.80 GB; no second mmproj).
- [ ] Confirm it generates correct output, not just that it loads - greedy diff against a known-good reference.
- [ ] Template vet + `/props`; bench rows alongside ternary.
- [ ] Three-way comparison + serving-role verdict; the winner added as a preset entry.

## Phase 4 - document

- [ ] docs/parameters.md Bonsai-27B profile section.
- [ ] docs/benchmarking.md findings, the measured ceiling, and the first published 4070 numbers.
- [ ] research.md resolution notes appended.
- [ ] Watch items recorded: #26337 (DSpark), ollama#13668.
