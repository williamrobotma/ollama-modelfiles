# DSpark drafter for Bonsai-27B

SCAFFOLD - blocked upstream; plan in a fresh session once it unblocks.

Decided 2026-08-12 (bonsai-27b pre-flight review): DSpark is cut from `specs/bonsai-27b` and parked here.
Evidence is in `specs/bonsai-27b/research.md`, section "Pre-flight re-verification 2026-08-12".

## Goal

- Speculative decoding for Bonsai-27B on stock llama.cpp, adopted only if it wins on this hardware.
- Pure speed work. Nothing about serving Bonsai depends on it.

## Why it is blocked

- PrismML's shipped drafter does not load on stock llama.cpp - `gguf_init_from_reader: tensor
  'dspark.fc.weight' has offset 337718592, expected 357584192` (llama.cpp issue #26337, OPEN).
- The vendor confirms fork-only, with no ETA - khosravipasha, 2026-08-10.
- Mainline already has the mechanism (`--spec-type draft-dspark`, #25173); the drafter file is what mismatches.

## Decisions for planning

- Trigger: #26337 closing, or PrismML shipping a mainline-compatible drafter. Watch both.
- Re-conversion is an alternative, not a plan: b10335 carries a converter option (#26452) that could rebuild a
  drafter from `dspark-bf16` (7.29 GB). Cost and success are both unknown.
- Adoption is conditional on measurement, not on the vendor's H100 numbers. Community results on 12-16 GB cards
  range from failure to a 15x slowdown.
- VRAM is the real constraint: ~1.8 GiB of drafter competes directly with context on a 12 GB card, and a known
  bug has the drafter inherit the target's full `ctx-size`.

## Done when

- DSpark loads on stock llama.cpp, A/B'd against no-drafter with tok/s delta and acceptance rate recorded.
- Adopted as a `llamacpp/models.ini` entry only on a win, at a context size that leaves the pair resident.
- Or: closed as not-worth-it, with the measurement that says so.
