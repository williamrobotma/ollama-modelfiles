# Bonsai-27B onboarding (llama.cpp serving stack; ternary first-class)

## Why

- Target: ternary Bonsai-27B, an extreme-quant rebuild of the Qwen3.6-27B base the fleet already serves.
  - Quality retained vs the full-precision base (vendor-claimed): 94.6%.
  - The weights alone fit the 12 GB 4070. Whether it stays resident depends on `ctx-size`, measured in Phase 1.
- Ternary is first-class (decision 2026-08-03, user): onboarded directly, not via a 1-bit interim phase.
  - `Q1_0`, the 1-bit variant, stays a bench comparison only.
- llama.cpp-only.

## Known facts

Evidence and sources: `research.md`, section "Pre-flight re-verification 2026-08-12". The load-bearing ones:

- The build prerequisite is met at b10335, and no rebuild is needed.
- Upstream `Q2_0` is group-64. Download `Q2_g64`; `Q2_0` and `PQ2_0` are the fork's group-128 packing.
- Flash attention, quantized KV, and ternary weights cannot interact.
- The 4070 runs both quant types through MMQ.
- The GGUF template carries the guard and no `merged_system`, so both entries serve under froggeric's template.
- DSpark does not load on stock llama.cpp. Dropped here; the follow-on bundle is `specs/bonsai-dspark`.
- No 4070 throughput number is published anywhere, so this spec produces the first.
- The vendor's numbers make agentic tool use the weakest domain; an independent bench disagrees on which
  domain degrades worst. Both stay hypotheses until Phase 2/3.

## Prerequisites

1. Met: `specs/llamacpp-migration` built the serving stack. This spec adds a model, not machinery.
2. Met: the on-disk build is b10335 and contains #25707.
   - Re-check `llamacpp/launch.sh` at pickup; a moved record re-certifies (rebuild rule).
   - Pinning is deliberate: nothing between b10335 and b10375 touches these quant types or the router.
3. Owner-only, blocking: confirm the GPU core clock offset is at or below +120 MHz.
   - AGENTS.md records that WSL cannot read it.

## Decisions at spec review (2026-08-12)

1. Ternary path: upstream via #25707, file `Q2_g64`. The fork option is retired.
2. DSpark dropped from Acceptance and every phase.
3. Sampling: four arms trialled - the repo's coding, reasoning, and instruct profiles, plus the vendor card
   (temp 0.7 / top_p 0.95 / top_k 20).
   - The card is a thinking-mode profile by its own statement, so it is not the repo's Instruct profile.
   - `repeat_penalty` stays exactly 1.0 (mandate). Community practice leans 1.1-1.15 and is declined.
   - DRY sampling is a separate mechanism the mandate does not cover, so it stays available.
4. Role and `ctx-size`: decided after measuring, in Phase 1.
5. Bench tool: `llama-bench` for throughput. Serve-path checks are the runner's call at Phase 2 pickup.
6. KV cache type is out of scope. The fleet-wide q8_0 vs f16 A/B is `specs/kv-cache-ab`; Bonsai is one arm.

## Open decision, to rule at Phase 1

- Served ids. The grammar says an id names the entry, never the quant (`llamacpp/README.md:19`), which rules out
  the draft's `bonsai27b-q2g64` and `bonsai27b-q1`.
  - Recommendation: PrismML's own repo names, `ternary-bonsai-27b` and `bonsai-27b`, plus profile tokens.

## Acceptance

- Ternary serves on the fast CUDA path, template-vetted, from a pinned HF-cache snapshot.
  - Full profile flags verified via `/props`.
  - Benched against 1-bit and `qwen3.6-27b-coding` on `llama-bench`.
  - A written serving-role verdict exists, with the measured ctx ceiling behind it.
  - Delivers the first published 4070 numbers for this model.
- Residency is measured, not assumed. `ctx-size` sits at or below the measured ceiling, or the entry states
  that it partial-offloads.
- 1-bit serves from a pinned snapshot, template-vetted, and confirmed to generate correct output.
  - No serving-role claim of its own.
- Chat-template gate passed, with a positive control so a zero hit means the guard is absent, not unread.
- docs/parameters.md gains a Bonsai-27B profile section with source URLs.
- Watch items recorded: #26337 (DSpark), ollama#13668.
- Disk budgeted against `/mnt/f`. Downloads: 8.21 GB ternary, 3.80 GB 1-bit.
