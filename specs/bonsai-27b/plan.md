# Plan: Bonsai-27B onboarding

Not started. Pre-flight review 2026-08-12; its decisions are in spec.md, its evidence in research.md.
`Verify:` marks the check that closes the step above it.

Terms:

- `Q2_g64` (ternary) and `Q1_0` (1-bit) - the two Bonsai GGUF variants under test.
- Residency ceiling - the largest `ctx-size` at which the model stays on the card without offloading.

## Phase 0 - prerequisites

- Confirm the build record still matches the on-disk binary.
  - Verify: `llamacpp/launch.sh` header against `llama-server --version`. A moved record triggers the rebuild rule.
- Confirm the GPU core clock offset is at or below +120 MHz.
  - Verify: owner statement. WSL cannot read it, and every quoted number depends on it.
- Rule on the served ids (spec.md).

## Phase 1 - ternary lane

- Download `Q2_g64` (7,585,330,240 B) and mmproj `Q8_0` (629,246,880 B); pin the snapshot paths.
  - `Q2_g64` only: `Q2_0` fails on stock with `invalid ggml type 142`, and `PQ2_0` is vendor-marked "do not use yet".
  - Verify: `df -h /mnt/f` before and after, 8.21 GB delta.
- Template vet per the AGENTS.md gate, with a positive control added to step 1.
  - The guard is known present, so a zero hit means the 30 MB window was too small, not that it is unguarded.
  - Verify: matched by the guard's message text, never the HTTP status; recorded in `llamacpp/README.md`.
- Measure the residency ceiling before writing the entry.
  - Predicted near 100K; 200000 and 262144 are over the card (arithmetic in research.md).
  - Amended 2026-08-12: that prediction is optimistic, because research.md's totals exclude compute buffers.
    - Corrected 2026-08-13 after measuring: the compute buffer is not the fixed ~1.3 GB the vendor card implies.
    - It scales with ctx, from 240 MiB at 32768 to 1360 MiB at 262144, roughly 5.2 MiB per 1000 tokens.
    - The conclusion held anyway: the measured ceiling is 100000, below the plan's predicted "near 100K" once
      the entry's real headroom against the Windows desktop is counted.
    - Measured results and method are in tasks.md; the ladder ran to 262144.
  - Measure the entry's actual shape: if it will carry `mmproj`, the projector is resident for the measurement.
    It costs 0.586 GiB, against a margin of roughly 1 GiB at 100K.
  - `ctx-size` pads up to a 256 boundary on load (200000 -> 200192), so set the entry below the ceiling, not at it.
  - **The ceiling is q8_0-conditional.** f16 KV costs 64 KiB/token against q8_0's 34.0, so it roughly halves the
    ceiling. If `specs/kv-cache-ab` moves this family to f16, the ceiling, the role, and the entry are re-derived.
  - Verify: `nvidia-smi` at all three capture points (docs/benchmarking.md).
- Decide role and `ctx-size` from that measurement, then write the preset entry.
  - Verify: `/props` matches the profile; one coding smoke returns coherent output with timings.
- Serve through the router preset.
  - Verify: one-gen smoke under the preset name.
- Record any repetition loops or malformed tool calls.
  - DRY sampling is the mitigation; `repeat_penalty` stays 1.0.

## Phase 2 - bench (ternary)

- `llama-bench`: ternary vs `qwen3.6-27b-coding` (same base model) across a ctx ladder.
  - Verify: warmup plus repetitions recorded, not a single-run smoke.
- Serve-path checks are the runner's call: `llama-bench` exercises neither the router nor the chat template.
- Sampling arms - coding, reasoning, instruct, and the vendor card - belong to those serve-path checks, not to
  `llama-bench`, which measures throughput and would return four near-identical figures.
  - They are a quality comparison. The method is set at pickup, and it is what decides the served profile.
- Optional: mmproj load plus one vision smoke.

## Phase 3 - 1-bit comparison

- Download `Q1_0` (3,803,452,480 B); pin the path. No second mmproj.
  - Verify: `/mnt/f` delta 3.80 GB.
- Confirm the 1-bit path generates correct output, not just that it loads.
  - The vendor card still says to clone the fork, and no upstream report settles this either way.
  - Verify: greedy output diffed against a known-good reference.
- Template vet plus a `/props` check on the decided profile.
- Three-way comparison: ternary vs 1-bit vs `qwen3.6-27b-coding` - throughput, VRAM, spot quality.
  - The vendor quality-retained deltas (94.6% vs 89.5%) are the hypothesis under test.
- Write the serving-role verdict; add the winner as a `llamacpp/models.ini` entry.

## Phase 4 - document

- docs/parameters.md: Bonsai-27B profile section (values, source URLs, the repeat_penalty stance).
- docs/benchmarking.md: findings, the measured ceiling, the first 4070 numbers.
- research.md: append a dated resolution note per blocked fact.

## Risks / notes

- Vendor quality and speed numbers stay unbenched marketing until Phase 2/3.
- An oversized `ctx-size` fails silently: nothing auto-shrinks on OOM, so the entry partial-offloads instead.
- A resident router child holds the card for 24 h (`--models-max 1`, `--sleep-idle-seconds 86400`), and idling it
  does not release the memory.
  - Either stop the router for bench runs, or accept `POST /models/unload` and its known orphan race.
- The card and host RAM are shared with Windows, so resource capture applies to every quoted run.
- Worth one smoke test: long context plus request cancellation. The vendor fork has an open CUDA-fault report on
  the same MMQ path these quant types use; unconfirmed on stock.
