# Tasks: Bonsai-27B onboarding

Status legend: [ ] pending, [x] done. This file is the resume point for the feature; update as phases complete.

DRAFT 2026-07-17, reworked 2026-08-03 (ternary first-class), pre-flight review 2026-08-12 - implementation not started.

Cleared to start (user, 2026-08-12): full send, in its own session. Does not wait on `specs/llamacpp-migration`.

GPU-loading items are heavy loads: get user confirmation before starting each.

Resume point: Phase 1, at the residency measurement, HELD on the GPU gate (user, 2026-08-12).
Everything in Phase 1 that does not touch the GPU is done: both downloads, and the template vet for both files.
Held work, in order, once the gate clears:

1. The residency ladder, both arms (with and without `--mmproj`), rungs 32768 / 65536 / 100000 / 131072 / 200000.
   - Run both arms back to back, or host drift lands inside the 0.586 GiB projector delta being measured.
   - Ceiling = the largest rung that keeps every layer on the card. One rung per server start:

   ```text
   llama-server -m <snapshot>/Ternary-Bonsai-27B-Q2_g64.gguf [--mmproj <snapshot>/Ternary-Bonsai-27B-mmproj-Q8_0.gguf]
       -ngl 99 -c <rung> -fa on -ctk q8_0 -ctv q8_0 -np 1 --jinja --no-warmup --port 11435
   ```

   - `-ngl` pinned, never unset: docs/benchmarking.md warns the split otherwise tracks host conditions.
   - `-fa on` with q8_0 KV mirrors the `[*]` block, and the pair is mandatory.
   - Capture `nvidia-smi` and `free -m` at all three points, per docs/benchmarking.md (Resource capture).
   - Bracket the whole ladder with the nvlddmkm Id-13 count.
   - Pass a rung only when the log's `offloaded N/M layers to GPU` line has `N == M`.
     - A bound server is not the criterion.
     - llama.cpp fits layers to free VRAM (`models.ini:16`), and nothing auto-shrinks on OOM (AGENTS.md).
     - So an over-budget rung can bind with layers quietly spilled, and report success.
   - Stop rule: climb until a rung fails.
     - A ladder whose top rung passes has measured a floor, not a ceiling.
     - 200000 is predicted at 13.70 GiB and is there to terminate the climb; extend upward if it passes.
   - The Id-13 bracket is a recorded pair, not a verdict.
     - Expect it blank under WSL, and never read a zero or empty delta as "no fault" (docs/benchmarking.md).

2. The three ternary preset entries, written from the measured ceiling.
3. Serve, `/props`, coding smoke, router one-gen smoke.
4. The 1-bit live probe (gate steps 3-4) at `-ngl 0`, cheap to fold in with the above.

Runner decisions taken at pickup (user, 2026-08-12), where the plan left the call open:

- `mmproj` is measured both ways before it is decided.
  - The projector costs 0.586 GiB against a headroom under 5 GiB, so the arithmetic alone does not settle it.
- The full ternary profile set lands up front: `bonsai-27b-ternary-coding`, `-reasoning`, and `bonsai-27b-ternary`.
- Ids stand as ruled: a blank variant token reads as the binary build.
  - So `bonsai-27b` is the 1-bit instruct entry, and `bonsai-27b-ternary` is the ternary instruct entry.
- Long context may spill into system RAM.
  - `ctx-size` is not capped at the measured ceiling; the entry states the spill.

## Phase 0 - prerequisites + decisions

- [x] #25707 (group-64 ternary CUDA) merged upstream 2026-07-30, and is in the served build's history.
- [x] Build prerequisite met: on-disk b10335 matches its `llamacpp/launch.sh` record.
  - [x] Pinning at b10335 confirmed defensible; b10375 changes nothing this spec depends on.
  - [x] At pickup 2026-08-12: record unmoved, so no rebuild.
    - `llama-server --version` gives `version: 10335 (74ce15741)`, matching the `llamacpp/launch.sh:10` record.
- [x] Spec review closed. Decisions and their evidence are in spec.md and research.md.
  - [x] DSpark dropped; follow-on bundle scaffolded as `specs/bonsai-dspark`.
  - [x] KV cache A/B moved out to `specs/kv-cache-ab`, fleet-wide, with Bonsai as one arm.
  - [x] Sampling: four arms - coding, reasoning, instruct, and the vendor card.
  - [x] Role and `ctx-size`: decided after measuring, in Phase 1.
  - [x] Bench tool: `llama-bench`; serve-path checks are the runner's call at Phase 2.
- [x] GPU core clock offset confirmed at or below +120 MHz (user, 2026-08-12). Re-confirm if the profile changes.
- [x] Served ids ruled (user, 2026-08-12): `bonsai-27b-ternary` and `bonsai-27b`, plus profile tokens.
  - [x] The id rule softened for disambiguation in `llamacpp/README.md`.

## Phase 1 - ternary lane

- [x] Download + pin `Q2_g64` and mmproj `Q8_0` (8.21 GB; check `/mnt/f` before and after).
  - Never `Q2_0` or `PQ2_0` - fork group-128 packing, and `PQ2_0` is vendor-marked unstable.
  - Done 2026-08-12, snapshot `abbae723028d71be674e71e1a71201a6f43fab22`.
  - Sizes byte-exact against research.md: `Q2_g64` 7,585,330,240 B, mmproj `Q8_0` 629,246,880 B.
  - `df -h /mnt/f` read 277G both before and after, so the delta check was inconclusive.
    - The vhdx reused internal free space rather than growing. The byte-exact sizes are what verify the download.
- [x] Template vet per the AGENTS.md gate, with a positive control; result recorded in `llamacpp/README.md`.
  - The guard is known present, so a zero hit means the grep window was too small.
  - Done 2026-08-12, on-box, all four steps at `-ngl 0` on port 11435.
  - Verdict: guarded, no `merged_system`, so both entries serve under froggeric's template.
    - That is what research.md predicted from the HF side, now confirmed on the downloaded file.
  - Step 1: 1 hit. Verbatim: `{{- raise_exception('System message must be at the beginning.') }}`.
  - Step 2: 0 hits for `merged_system`.
  - Positive control: 8 distinct `raise_exception(...)` sites read inside the same 30 MB window.
    - So the window reached the whole template body, and the step-2 zero is a real absence, not truncation.
  - Step 3, embedded template (control): HTTP 500, `Jinja Exception: System message must be at the beginning.`
    - Matched on the message text. A leading-`system` request to the same server returned 200.
  - Step 3, froggeric override: HTTP 200. The override does the work on this GGUF at b10335.
  - Step 4, `/v1/messages` multi-block `system`: HTTP 200 on both arms, immune as documented.
- [x] Measure the residency ceiling with `nvidia-smi` at all three capture points.
  - q8_0-conditional: f16 KV roughly halves it, so `specs/kv-cache-ab` can void this result.
  - Measure the entry's real shape (projector resident if the entry carries one); `ctx-size` pads up to 256.
  - **Measured ceiling: 100000.** Done 2026-08-13, quiesced box, ladder run twice (with and without `mmproj`).
  - Confirmed two independent ways, which agree.
    - Memory: the drift-corrected footprint tracks predicted growth exactly to 100000, then stops.
    - Throughput: decode holds at ~54 tok/s to 100000, then collapses.

  | ctx | footprint, no mmproj | growth | predicted | decode tok/s | prompt tok/s |
  |---|---|---|---|---|---|
  | 32768 | 8537 MiB | - | - | 54.10 | 101.95 |
  | 65536 | 9785 MiB | +1248 | +1248 | not run | not run |
  | 100000 | 11101 MiB | +1316 | +1316 | 54.21 | 107.07 |
  | 131072 | 11581 MiB | +480 | +1179 | 16.37 | 35.32 |
  | 200000 | 11619 MiB | +38 | +2632 | not run | not run |
  | 262144 | 11581 MiB | 0 | +2365 | 9.47 | 28.32 |

  - Load success is not a ceiling test on this box, which is why the first ladder read every rung as passing.
    - Every rung to 262144 loaded and reported `offloaded 65/65 layers to GPU`.
    - At 262144 llama.cpp's own buffers claim 17,096 MiB on a 12,282 MiB card, and `nvidia-smi` shows 11,581.
    - WSL2's WDDM driver backs the excess with shared host memory instead of failing the allocation.
    - So the ceiling had to be found by where the footprint stops tracking, and confirmed by throughput.
  - research.md's arithmetic is confirmed exactly, read off llama.cpp's own buffer accounting.
    - `CUDA0 KV buffer size` at 32768 is 1088.00 MiB, which is 32768 x 34.0 KiB to the byte.
    - `CUDA0 RS buffer size` is 149.62 MiB and constant at every rung, against a predicted ~150 MiB.
    - The KV log shows `layer 0: filtered` and `layer 3: dev = CUDA0`, so 16 of 64 layers hold KV.
  - The projector costs about 516-602 MiB of real VRAM, and its cost is invisible in the LLM's own accounting.
    - It reports `CUDA0 model buffer size = 0.00 MiB`, and the vendor card calls the tower "usually offloaded".
    - The two arms differ by 602 MiB at 32768 and 516 MiB at 100000, which is the `nvidia-smi` truth.
    - At 100000 with the projector the footprint is 11,617 MiB, leaving 665 MiB for Windows.
  - The measurement is only valid quiesced. The Windows baseline drifted 1397 -> 226 MiB during the first ladder.
    - That drift exceeds the projector delta, so absolute readings are useless and only per-rung deltas count.
  - Id-13 nvlddmkm count was 1146 before and 1146 after both ladders, so no GPU hardware fault. A zero delta
    still proves nothing on its own.
- [ ] Decide role and `ctx-size` from that measurement; write the preset entry.
- [ ] llama-server launch from the pinned path; `/props` matches the profile; coding smoke.
- [ ] Served through the router preset (one-gen smoke).
- [ ] Record any repetition loops or malformed tool calls.

## Phase 2 - bench (ternary)

- [ ] `llama-bench`: ternary vs `qwen3.6-27b-coding` across a ctx ladder, warmup plus repetitions.
- [ ] Serve-path checks scoped at pickup; the four sampling arms are part of them, not of `llama-bench`.
- [ ] Sampling arms compared on quality: coding, reasoning, instruct, vendor card.
- [ ] (optional) mmproj vision smoke.

## Phase 3 - 1-bit comparison

- [x] Download + pin `Q1_0` (3.80 GB; no second mmproj).
  - Done 2026-08-12, snapshot `f10afb355f104535e3e3e98cf7ab7795c72bd292`.
  - 3,803,452,480 B, byte-exact against research.md.
- [x] Template vet steps 1-2 (the grep half; no GPU).
  - Same verdict as ternary: guarded, no `merged_system`, same 8 `raise_exception` sites as the control.
  - Both GGUFs embed a byte-identical chat template: 7,764 chars, sha256 `e84f32a23fdda27689f868aa...`.
    - Read from the `tokenizer.chat_template` header field with llama.cpp's `gguf-py`, not inferred from greps.
    - Architecture reads `qwen35` on both, matching the `src/models/qwen35.cpp` code research.md cites.
  - Steps 3-4 (the live probe) are held with the rest of the GPU work.
    - The identical template plus the passing (froggeric, b10335) pair make the outcome near-certain.
- [ ] Confirm it generates correct output, not just that it loads - greedy diff against a known-good reference.
  - Reference settled at pickup: the same GGUF on the CPU path (`-ngl 0`), greedy, against the CUDA/MMQ path.
    - Upstream's Q1_0 CPU kernels merged 2026-04-06 (PR #21273) and are separately verified, so CPU is the
      trustworthy side of the comparison.
    - Pass criterion is coherence and semantic agreement over 100-200 greedy tokens, not a byte diff.
      CUDA and CPU diverge on reduction order, so byte-identity would fail for the wrong reason.
    - The ternary CPU probe already produced coherent output, so the reference format is known good.
  - The vendor's own two sources disagree on whether this needs their fork, which is the open question here.
    - The 1-bit card says to clone the fork: `# Clone the PrismML fork of llama.cpp`.
    - The formats docs say the opposite: "Because Q1_0 is upstream, any llama.cpp-based tool built from a
      recent enough version runs 1-bit Bonsai."
- [ ] Template vet + `/props`; bench rows alongside ternary.
- [ ] Three-way comparison + serving-role verdict; the winner added as a preset entry.

## Phase 4 - document

- [ ] docs/parameters.md Bonsai-27B profile section.
- [ ] docs/benchmarking.md findings, the measured ceiling, and the first published 4070 numbers.
- [ ] research.md resolution notes appended.
- [x] Watch item recorded: #26337 (DSpark). `specs/bonsai-dspark/tasks.md` already watches it, which is its
      home now that DSpark is its own bundle.
  - [x] ollama#13668 struck as moot 2026-08-12 (user), and removed from spec.md's Acceptance.
    - Ollama was retired 2026-08-07, so an issue about what Ollama cannot load no longer gates anything here.
    - It was not moved to `specs/stack-upkeep`, whose scope line states that Ollama left when it was retired.
