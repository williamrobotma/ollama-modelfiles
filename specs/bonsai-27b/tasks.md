# Tasks: Bonsai-27B onboarding

Status legend: [ ] pending, [x] done. This file is the resume point for the feature; update as phases complete.

DRAFT 2026-07-17, reworked 2026-08-03 (ternary first-class), pre-flight review 2026-08-12.
Phases 0 and 1 are complete as of 2026-08-16, and the ternary lane serves.

Cleared to start (user, 2026-08-12): full send, in its own session. Does not wait on `specs/llamacpp-migration`.

GPU-loading items are heavy loads: get user confirmation before starting each.
CPU inference loads are gated the same way (user, 2026-08-16), so an `-ngl 0` run needs its own confirmation too.
Only numbers taken under a cleared GPU gate are valid on this box, since a cleared gate is what guarantees
nothing else is loading the card. The desktop baseline is the tell: valid runs sat at 226-465 MiB.

Resume point: Phase 2, which is GPU-gated end to end.
Phase 3's execution steps are scoped below and each carries its gate, so only gated work is left in it.
Phase 4 waits on Phase 2 and 3 numbers, except its `docs/parameters.md` section, which is written.

Runner decisions (user), where the plan left the call open:

- The full ternary profile set landed up front: `bonsai-27b-ternary-coding`, `-reasoning`, `bonsai-27b-ternary`.
- Ids stand as ruled: a blank variant token reads as the binary build.
  - So `bonsai-27b` is the 1-bit instruct entry, and `bonsai-27b-ternary` is the ternary instruct entry.
- `mmproj` rides all three ternary entries.
- `ctx-size` is 100096 on all three, which is the measured residency ceiling (2026-08-16).
  - This replaced an earlier call to keep the fleet's convention ctx and accept the spill.
  - Oversizing buys nothing: the KV cache is allocated in full at load, not as context fills.

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
  - **Measured ceiling: 100096.** Done 2026-08-13, quiesced box, ladder run twice (with and without `mmproj`).
  - Confirmed two independent ways, which agree.
    - Memory: the drift-corrected footprint tracks predicted growth exactly to the ceiling, then stops.
    - Throughput: decode holds at ~54 tok/s to the ceiling, then collapses.

  | ctx requested | served n_ctx | footprint, no mmproj | growth | predicted | decode tok/s |
  |---|---|---|---|---|---|
  | 32768 | 32768 | 8537 MiB | - | - | 54.10 |
  | 65536 | 65536 | 9785 MiB | +1248 | +1248 | not run |
  | 100000 | 100096 | 11101 MiB | +1316 | +1316 | 54.21 |
  | 131072 | 131072 | 11581 MiB | +480 | +1179 | 16.37 |
  | 200000 | 200192 | 11619 MiB | +38 | +2632 | not run |
  | 262144 | 262144 | 11581 MiB | 0 | +2365 | 9.47 |

  - The served column is why the entries read 100096: llama.cpp pads ctx up to a 256 boundary at load, so the
    rung requested as 100000 is the same configuration as an entry written 100096.
  - Prefill was not measured at depth. The only prompt-rate figures taken here came from a ~20-token prompt,
    which says nothing about prefill at the ceiling, so they are left out. `llama-bench` in Phase 2 is that job.

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
- [x] Decide role and `ctx-size` from that measurement; write the preset entry.
  - Three entries written 2026-08-13: `bonsai-27b-ternary-coding`, `-reasoning`, and `bonsai-27b-ternary`.
  - Written first at the fleet convention, 200000 and 262144, then reset to the ceiling on 2026-08-16 below.
  - All three carry `mmproj`, since the fleet's no-projector rule exists only for the MTP speed split.
- [x] llama-server launch from the pinned path; `/props` matches the profile; coding smoke.
  - `/props` verified per entry 2026-08-13. The field is `temperature`, not `temp`.
  - Coding: temperature 0.6, top_k 20, top_p 0.95, min_p 0.0, repeat_penalty 1.0, presence_penalty 0.0.
  - Instruct: top_p 0.80 and presence_penalty 1.5, both as the profile requires.
  - `ctx-size` padding confirmed as plan.md predicted: 200000 is served as `n_ctx` 200192.
  - `reasoning = off` works: only the instruct entry returned visible text on a 32-token budget.
    - The coding and reasoning entries spent the whole budget thinking and returned empty content.
    - That is the same behaviour templates/README.md records for Queen-27B, and it is a pass.
- [x] Served through the router preset (one-gen smoke).
  - All three ids appear in `/v1/models` and each generated through the router.
- [x] `ctx-size` set to 100096 on all three entries (user, 2026-08-16), replacing the convention values.
  - 100096 is the measured resident rung written literally. llama.cpp pads ctx up to a 256 boundary, so the
    ladder's "100000" rung in fact ran at 100096, and the padded value is the one with a measurement behind it.
  - This follows the documented practice, which the research pass confirmed against the pinned build.
    - The KV cache is allocated in full at load, never lazily (`src/llama-kv-cache.cpp:286`).
    - `--fit` stops auto-sizing the moment `ctx-size` is set (`common/fit.cpp:369`), so every entry here opts out.
    - No paged or lazy KV exists in mainline; ggml-org discussion #21961 is open design work, unshipped.
    - So an oversized ctx is a misconfiguration rather than a strategy, and on WSL2 it fails silently: the WDDM
      driver backs the overflow with host memory instead of refusing the allocation as Linux would.
  - Only numbers taken under a cleared GPU gate are valid on this box, since a cleared gate is what guarantees
    nothing else is loading the card. The desktop baseline is the tell: valid runs sat at 226-465 MiB.
- [ ] Record any repetition loops or malformed tool calls.
  - Nothing to report yet, and nothing that counts as evidence either: the only generations so far were
    short smokes with no tools in play. The community reports this on 12 GB cards, so it needs a real
    agentic session before it can be called absent.

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
  - Step 3 (the live probe) is held under the CPU gate; step 4 is per build, and b10335 already passed it.
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
  - Runbook scoped 2026-08-16, unrun. Two llama-server launches on port 11435, one shared request body.
    - It only produces the two outputs; the pass criterion that judges them is the one recorded above, unchanged.
    - Server binary is `/home/wma/Developer/llama.cpp/build/bin/llama-server` (`llamacpp/launch.sh:16`), b10335.
      - Launch it directly. Never `launch.sh`, which owns the router's port 11433 and the whole preset.
    - The pinned path was checked on disk 2026-08-16: `stat -L` reads 3,803,452,480 B, matching the size above.
    - Both arms carry identical flags, so `-ngl` is the only variable under test.

      ```bash
      # CPU gate. Reference arm: the same GGUF on the CPU path.
      /home/wma/Developer/llama.cpp/build/bin/llama-server \
        --model /home/wma/.cache/huggingface/hub/models--prism-ml--Bonsai-27B-gguf/snapshots/f10afb355f104535e3e3e98cf7ab7795c72bd292/Bonsai-27B-Q1_0.gguf \
        --host 127.0.0.1 --port 11435 --ctx-size 4096 --parallel 1 \
        --jinja \
        --chat-template-file /home/wma/Developer/ollama-modelfiles/llamacpp/templates/chat_template.jinja \
        --reasoning off -fa on --cache-type-k q8_0 --cache-type-v q8_0 \
        -ngl 0

      # GPU gate. CUDA arm: the identical command with the -ngl 0 line dropped, so the build default offloads.
      ```

    - `--ctx-size 4096` is deliberate, and not the entry's 100096: this tests kernel correctness, not residency,
      and a small ctx keeps the CPU arm's host KV cheap. It is identical on both arms, so it is not a variable.
    - `--reasoning off` is there because both arms have to be prompt-identical to the entry that will serve, and
      the draft entry carries `reasoning = off`. It reaches the model as a template kwarg
      (`common/arg.cpp:3579`, `params.default_template_kwargs["enable_thinking"] = "false"`), so it shapes the
      rendered prompt in front of the kernel and has to be the same on both sides.
    - `-fa on` with q8_0 KV is the fleet pairing and is safe on both backends. The CPU kernel takes K through
      `vec_dot_type` and V through `to_float`, so quantized KV is supported there
      (`ggml/src/ggml-cpu/ops.cpp:8542-8548`).
    - One request body, sent to whichever arm is up.

      ```bash
      curl -s http://127.0.0.1:11435/v1/chat/completions \
        -H 'Content-Type: application/json' \
        -d '{"model":"bonsai-27b","messages":[{"role":"user","content":"Write a Python function that returns the nth Fibonacci number iteratively, then explain in two sentences why the iterative version is preferred over the naive recursive one."}],"temperature":0,"top_k":1,"max_tokens":200}'
      ```

    - Before the CUDA arm, run the router pre-flight (AGENTS.md Serving): `curl -s 127.0.0.1:11433/v1/models`.
      - An answer may be a router this session did not start - report and ask, never work around it.
      - A resident router child holds the card for 24 h (`plan.md:82-84`), so the CUDA arm needs 11433 quiet.
      - Confirm 11435 is free as well, then launch.
    - Store the reference arm's full output verbatim under this item when it runs, so a later CUDA session can
      diff against it without re-running the CPU arm.
      - In-flight findings live in the feature bundle until the work wraps (`docs/history/index.md:3`), and
        Phase 1's evidence is already inline here.
      - Record both arms' output if one session clears both gates.
    - Coherence only: this step quotes no number, so incidental timings from it are not results.
- [ ] Template vet + `/props`; bench rows alongside ternary.
  - Only vet step 3 is left. Steps 1-2 are done above, and step 4 is per build rather than per GGUF: b10335
    passed it during the ternary vet - `Step 4, /v1/messages multi-block system: HTTP 200 on both arms`.
  - Step 3 (CPU gate): three requests across two servers, both at `-ngl 0` on port 11435, from one probe body.
    - The control/override split is a launch difference, not a body difference, so it is two sequential launches.
    - Control server: the launch above with only the `--chat-template-file` line dropped, so the embedded
      template runs. `--jinja` has to stay, or no embedded Jinja runs at all and the guard cannot fire.
    - Override server: the launch above unchanged.

      ```bash
      # Probe body: the system message is NOT first. Sent to both servers.
      curl -s -w '\n%{http_code}\n' http://127.0.0.1:11435/v1/chat/completions \
        -H 'Content-Type: application/json' \
        -d '{"model":"bonsai-27b","messages":[{"role":"user","content":"hi"},{"role":"assistant","content":"hello"},{"role":"system","content":"Be terse."},{"role":"user","content":"say ok"}],"max_tokens":32}'

      # Liveness check, control server only: the system message IS first.
      curl -s -w '\n%{http_code}\n' http://127.0.0.1:11435/v1/chat/completions \
        -H 'Content-Type: application/json' \
        -d '{"model":"bonsai-27b","messages":[{"role":"system","content":"Be terse."},{"role":"user","content":"say ok"}],"max_tokens":32}'
      ```

    - Expected, matched on the guard's message text and never the HTTP status (AGENTS.md gate, step 3):
      - Control, non-first `system`: the guard fires - `Jinja Exception: System message must be at the beginning.`
      - Control, leading `system`: success, which is what proves that control server was alive.
      - Override, non-first `system`: success. That is the pair the ternary arm already produced at b10335.
  - `/props` splits across the two gates, because the sampler fields do not depend on offload.
    - Read it per the Phase 1 precedent above: the field is `temperature`, not `temp`.
    - Sampler fields (CPU gate): they read the same off a direct `-ngl 0` launch carrying the draft entry's
      keys, so they do not wait on the entry landing at the verdict.
      - `temperature` 0.7, `top_p` 0.80, `top_k` 20, `presence_penalty` 1.5, `repeat_penalty` 1.0, `min_p` 0.0.
    - `n_ctx` 100096 (GPU gate): only the real entry proves this one. At `-ngl 0` it would allocate the whole
      KV in host RAM, which tests nothing about residency.
  - Bench rows: blocked on the Phase 2 `llama-bench` ladder, which is not scoped here (user declined it 2026-08-16).
- [ ] Three-way comparison + serving-role verdict; the winner added as a preset entry.
  - Blocked on the same Phase 2 `llama-bench` ladder: the ternary and `qwen3.6-27b-coding` rows are two of the
    three, so this cannot be scoped without scoping Phase 2.
  - DRAFT `[bonsai-27b]`, held here until the verdict. It is not in `llamacpp/models.ini`, and lands only then.
    - A delta from `[bonsai-27b-ternary]` (`llamacpp/models.ini:92-101`): two keys change and nothing else.
    - `model =` swaps to the pinned Q1_0 path.

      ```ini
      model = /home/wma/.cache/huggingface/hub/models--prism-ml--Bonsai-27B-gguf/snapshots/f10afb355f104535e3e3e98cf7ab7795c72bd292/Bonsai-27B-Q1_0.gguf
      ```

    - `mmproj =` is dropped: there is no second mmproj, per the download step above.
    - Every other key is copied verbatim: `chat-template-file`, `reasoning = off`, `ctx-size = 100096`,
      `temp = 0.7`, `top-p = 0.80`, `top-k = 20`, `presence-penalty = 1.5`.
    - `ctx-size = 100096` carries over without a new ladder, by strict dominance over the measured ternary entry.
      - Same architecture (`qwen35` on both, read from the headers above) and the same KV arithmetic
        (research.md, "Residency arithmetic"), so KV per token, the recurrent state, and the ctx-scaled compute
        buffer are all identical at a given ctx.
      - The weights are smaller by 3,781,877,760 B: 7,585,330,240 B ternary against 3,803,452,480 B here.
        That is 3,607 MiB, which is arithmetic on the two recorded sizes rather than a reading.
      - The projector comes off too, and the ternary carried it resident through the ladder.
      - The ternary is measured resident at 100096, so this entry sits strictly under a footprint that fit.
      - Its own ceiling is higher and unmeasured. Measuring it is optional gated work, not a prerequisite here,
        because the entry is bench-only - `spec.md:53`, "The 1-bit is bench-only".
    - Writing it moves the `llamacpp/models.ini:1` header total from 23 configs to 24.

## Phase 4 - document

- [x] docs/parameters.md Bonsai-27B profile section. Written 2026-08-12, `docs/parameters.md:114`.
  - Carries the vendor triple with source URLs, the thinking-mode scoping, and the repeat_penalty stance.
  - Also records that an unset sampling flag falls through to the GGUF rather than the build default, which
    is fleet-wide rather than Bonsai-specific.
  - Its "which profile Bonsai serves" line stays open until the Phase 2 arm comparison.
- [ ] docs/benchmarking.md findings, the measured ceiling, and the first published 4070 numbers.
  - Blocked on Phase 2 and 3; the ceiling and the resident decode rate are ready to go in with them.
  - Worth carrying: on this box an over-budget entry does not partial-offload the way AGENTS.md describes.
    All layers report resident and WDDM backs the overflow with host memory, so any ceiling test that asks
    only "did it load" gets a wrong answer here.
- [ ] research.md resolution notes appended.
- [x] Watch item recorded: #26337 (DSpark). `specs/bonsai-dspark/tasks.md` already watches it, which is its
      home now that DSpark is its own bundle.
  - [x] ollama#13668 struck as moot 2026-08-12 (user), and removed from spec.md's Acceptance.
    - Ollama was retired 2026-08-07, so an issue about what Ollama cannot load no longer gates anything here.
    - It was not moved to `specs/stack-upkeep`, whose scope line states that Ollama left when it was retired.
