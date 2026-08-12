# KV cache type A/B, fleet-wide

SCAFFOLD - plan in a fresh session.

Decided 2026-08-12 (user, at the bonsai-27b pre-flight review): re-test q8_0 vs f16 KV across every model
family, not just the one that raised it.

## Goal

- A per-family verdict on the fleet's q8_0 K and V cache, replacing a single-family result generalised in 2026-08.
- Both a numeric arm and a behavioural arm, since the reported failure is behavioural.

## Why now

- The fleet-wide q8_0 decision (2026-08-03) rests on one Gemma probe: KLD 0.072 against bf16's 0.070. The Qwen
  probe was skipped because Gemma stayed inside the decision rule.
- Community reports tie quantized KV to repetition loops and broken tool calls on Bonsai-27B at 12 GB
  (`specs/bonsai-27b/research.md`). A KL probe would not have caught either symptom.
- `[*]` in `llamacpp/models.ini` applies q8_0 to every entry, so a wrong default is fleet-wide.

## Decisions for planning

- Families to cover: Gemma 4, Qwen 3.5, Qwen 3.6, Queen-27B, and Bonsai-27B as one arm.
- Numeric arm: reuse the 2026-08-03 llama-perplexity KL method so results stay comparable to the Gemma number.
- Behavioural arm: needs a repetition check and a tool-call round-trip. Design is open.
- `-fa on` and quantized KV stay paired, so an f16 arm is the only alternative under test.
- Cost is the constraint: every arm is a GPU load, and both budgets are shared with Windows.
- Ordering against `specs/bonsai-27b`: its Phase 1 ceiling is measured at q8_0, and f16 costs 64 KiB/token
  against q8_0's 34.0. Running the Bonsai arm first avoids a ceiling, role, and entry that expire; running it
  second means re-deriving all three.

## Done when

- Each family has a recorded q8_0 vs f16 result on both arms, with resource capture per trial.
- `docs/parameters.md` states the per-family verdict, and `models.ini` matches it.
- Any family that must deviate from the `[*]` default carries the reason on its entry.
