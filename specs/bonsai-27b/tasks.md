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
- [ ] Measure the residency ceiling with `nvidia-smi` at all three capture points.
  - q8_0-conditional: f16 KV roughly halves it, so `specs/kv-cache-ab` can void this result.
  - Measure the entry's real shape (projector resident if the entry carries one); `ctx-size` pads up to 256.
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
- [ ] Template vet + `/props`; bench rows alongside ternary.
- [ ] Three-way comparison + serving-role verdict; the winner added as a preset entry.

## Phase 4 - document

- [ ] docs/parameters.md Bonsai-27B profile section.
- [ ] docs/benchmarking.md findings, the measured ceiling, and the first published 4070 numbers.
- [ ] research.md resolution notes appended.
- [ ] Watch items recorded: #26337 (DSpark), ollama#13668.
