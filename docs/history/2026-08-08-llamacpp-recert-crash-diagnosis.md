# 2026-08-08: build 10326 re-cert failure, live crash-loop, partial crash diagnosis

Build 10326 (3653e6d6d) went through the migration spec's rebuild rule (crash matrix + froggeric pair), failed it, crash-looped in live use the same evening, and got the first half of a mechanism diagnosis before the GPU gate reclosed. Raw artifacts: session job scratch (`recert/`, `gpu-batch/`) and `~/.local/state/llama-router.log`; distilled results here. Box: RTX 4070, 12282 MiB.

## 1. Re-cert (morning): crash matrix + froggeric pair

- Gemma 12B MTP 6/6 @200k ctx, 99-110 tok/s (9860 ladder ref: 57-61); 26B MTP 6/6 @131072, 21.5-27.7 tok/s (ref 39-42).
- Per-build multi-system `/v1/messages` immunity probe: PASS.
- froggeric patched-pair probes (`/v1/chat/completions`, non-first system + tools): 200 + no guard 400 on both guarded GGUFs.
  - The 9B answered in content; Queen-27B spent its 32-token cap inside reasoning (status-level pass, no visible text).
- Qwen-9B-MTP hammer FAILED: 2/30 gens crashed the child; 9860 ran the identical shape 30/30 (P1 log, 2026-08-03).
  - Signature: `CUDA error: an illegal memory access` in `ggml_backend_cuda_synchronize` (ggml-cuda.cu:2499), mid-generation, no precursor.
- Verdict: 10326 NOT certified; launch.sh's last-known-good record stays 9860.

## 2. Upstream check: no fix exists

- llama.cpp #26609 (OPEN, unlabeled, 2026-08-05): exact signature and site (:2499), flash-attn path, reporter model Qwen3.6-35B MoE, cross-build (b10107/b10243); reporter's crash cleared 3/3 with `-fa off`.
- llama.cpp #26558 (OPEN, unlabeled): `--spec-type draft-mtp`, community CUDA-graphs cache-corruption theory; `GGML_CUDA_DISABLE_GRAPHS=1` soaked clean 1h47m.
- Master tip b10327: unrelated copy-kernel launch fix; nothing to gain. Issue states checked live via `gh` 2026-08-08.
- User decisions: downgrading is never an option (the current on-disk build is canonical); mitigation must be config-side or upstream-forward.

## 3. Live crash-loop (evening): claude-local on gemma4-12b-it-qat-mtp, user's 19:26 router

- 13 CUDA illegal-memory crashes across 15 child spawns in 35 minutes; same :2499 signature every time.
- Each respawn re-prefilled the ~88k-token session (48-54 s measured) and died mid-work; latterly about once a minute.
- Post-record: all 15 pre-kill spawns eventually crashed (14 illegal-memory + 1 misaligned address); a 16th survived to the router kill.
- The morning matrix (~1k-token prompts, 800-token gens) missed this exposure entirely: it is large-context-linked and near-deterministic.

## 4. Diagnosis (stages 1-2 of a 7-stage plan; gate reclosed on user stop-order mid-batch)

Repro asset: 340,916-byte synthetic prompt, server-tokenized to 81,163 tokens. Model under test: `gemma4-12b-it-qat-mtp` via the router.

- Stage 1, default config (fa on, q8_0 KV, ctx 200000):
  - gen1 (fresh prefill): CRASHED at n_decoded=1051, exact :2499 signature (`gpu-batch/r1.log:153-156`), child exit 1.
  - gen2 (fresh prefill after respawn): clean 2048 tokens; prefill 1704 tok/s, decode 74.1 tok/s.
  - gen3 reused the prefix cache (81158/81163 cached) - not a fresh-prefill trial. Fresh-trial crash rate: 1/2.
- Stage 2, overlay `--flash-attn off --cache-type-k f16 --cache-type-v f16 --ctx-size 131072`:
  - One fresh-prefill run: clean 2048 tokens, zero crash lines, running well past the gen1 crash point (wall 940.5 s).
  - Cost: prefill 1704 -> 344 tok/s (~5x slower); decode 74 -> 2.95 tok/s (~25x slower).
  - CUDA graphs stayed active under the overlay (`graphs reused = 758`), so the graphs mechanism was not perturbed.
  - Confound: the overlay changed FA + KV dtype + ctx together; offload state unverified (no layer lines at this verbosity).
- Verdict so far: consistent with #26609 (flash-attn path), NOT a confirmed isolation; #26558 (graphs) entirely untested.

## 5. Second batch (2026-08-09, post-rename)

**Correction (2026-08-09, same day): this section first claimed `GGML_CUDA_DISABLE_GRAPHS` had been removed upstream and
that the graphs discriminator needed a rebuild. Both claims were false. The text below is the corrected version; the
error and its cause are kept in section 6 because the failure mode is the reusable lesson.**

- `GGML_CUDA_DISABLE_GRAPHS` is alive at `ggml/src/ggml-cuda/common.cuh:1258`, in `ggml_cuda_graph::is_enabled()`.
  - It moved out of `ggml-cuda.cu` in `090b137e` ("ggml-cuda: refactor cuda graph usage", #18637, 2026-01-06).
  - It tests presence only (`getenv(...) != nullptr`), so `GGML_CUDA_DISABLE_GRAPHS=0` also disables graphs.
  - So the repo's graphs-off contingency and upstream #26558's workaround both remain available on this build.
- Whether the env took effect is **indeterminate** for this batch: the only proof is the `CUDA graph warmup ...`
  debug lines, which the router's default verbosity does not emit, and neither log carries them.
  - `graphs reused` (741/1526/2375 here) is llama's own graph-reuse counter (`llama-context.cpp:4139`), not CUDA graphs.
  - The stage therefore neither confirms nor refutes the graphs mechanism; it stands as one more clean fresh trial.
  - Default-config fresh-prefill record across both batches: 1 crash in 3 trials (this stage's status unresolved).
  - The mechanism question (#26558 graphs vs #26609 flash-attn) stays open, and the discriminator is cheap to re-run.
- Prefix-cache caveat: re-sending an identical prompt to the single-slot router serves from KV cache (`cache_n` ~= prompt).
  - Only `cache_n: 0` requests count as trials; use varied prompts or `cache_prompt: false` for repeat trials.
- 35B daily lane (`qwen3.6-35b-a3b-mtp-coding`, default config): 1 fresh 81,695-token prefill + 1 cached, 0 crashes.
  - Prefill 198.5 tok/s, decode 25.2 tok/s, draft acceptance 0.733, VRAM 11026 MiB. No exposure observed (n=1 fresh).
- 31B drafter load test (`gemma4-31b-it-qat-mtp`, no `spec-draft-ngl` pin): PASS - loaded and generated, VRAM 11186 MiB.
  - The 26B sibling's NaN-split loader crash did not reproduce here; n=1, so the pin question stays open on evidence.
- Instruct-entry gate probes after the rename: `qwen3.6-27b` and `qwen3.6-35b-a3b` both HTTP 200, no guard error text.
  - Both answered "OK." in one word, consistent with the mid-conversation system message surviving `merged_system`; n=1 each.
- Still owed: a verified graphs-off discriminator (env works on this binary; confirm via the `CUDA graph warmup` lines
  at raised verbosity), an unconfounded `-fa on`/`-fa off` pair at fixed ctx and KV type, a no-MTP control on the same
  prompt, and multi-trial repeats of every n=1 above.

## 6. Isolation batch (2026-08-09): MTP is the trigger; CUDA graphs are not

Design: identical model (`gemma4-12b-it-qat-mtp` unless noted), identical 81,163-token prompt, `max_tokens` 1600,
five fresh trials per arm, one variable changed per arm. Freshness enforced per trial (see the cache note below).

- Marker control first (this is what the previous batch lacked): with `GGML_CUDA_DISABLE_GRAPHS` unset the log carries
  `ggml_backend_cuda_graph_compute: CUDA graph warmup complete`; with it set, zero such lines. The env provably works.

| Arm | Crashes / fresh trials | Crash lines in log |
|---|---|---|
| Baseline (default config) | 4/5 | 10 |
| CUDA graphs off | 2/5 | 4 |
| **No MTP** (`gemma4-12b-it-qat`, same GGUF, no `spec-type`) | **0/5** | **0** |
| flash-attn on (ctx 131072, f16 KV) | 1/3 | 2 |
| flash-attn off (ctx 131072, f16 KV) | 0/2 | 0 |

- **Removing MTP stops it**: 4/5 -> 0/5 against the same-session baseline, Fisher exact two-tailed **p = 0.048**.
  - The no-MTP arm is the same GGUF served without `spec-type`/`model-draft` (it does carry `mmproj`, the one other diff).
  - This matches upstream #26782 (same model, same flag, HIP backend); ours is the CUDA-side confirmation that thread lacks.
- **CUDA graphs are not the mechanism here**: 4/5 -> 2/5 is not significant (Fisher exact two-tailed p = 0.50).
  - Both graphs-off crashes carried the identical signature, so graphs-off is at best a partial mitigant.
  - That is evidence against #26558's theory as applied to this crash, not against #26558 itself (different regime).
- flash-attn arms are too small to conclude, and fa-off runs ~17x slower, which itself lowers exposure to a timing race.
  - One fa-on crash reported `misaligned address` rather than `illegal memory access` at the same function - possibly a
    second fault mode, not distinguishable from this data.
- Crash timing widened: crashes landed at n_decoded 0 (prefill->decode boundary), ~403, ~609, and ~1517, not just the
  earlier 981-1391 window. Several landed exactly at the boundary.
- Baseline rate escalated to 80% here from the earlier 1/3. Unexplained; the agent's hypothesis is repeated
  load/unload cycling within one router session. It applies equally to every arm, so cross-arm comparison holds.
- Side benefit: the baseline and no-MTP arms are a clean MTP A/B (same GGUF, same 81k prompt, same everything else).
  - MTP 63.7-67.4 tok/s at draft acceptance 0.70; no-MTP 41.9 tok/s. **MTP is ~1.6x faster when it completes.**
  - But at 4/5 crashed vs 0/5, expected useful output inverts: ~0.2 x 67 vs 1.0 x 42, so no-MTP wins ~3x on this
    lane at this prompt size, before counting the 48-54 s reprefill each crash costs. MTP's speed is real; on the
    12B lane at ~81k its expected value is still negative.
- **Methodological finding**: `"cache_prompt": false` is silently ignored on `/v1/messages` at this build - a resent
  prompt still reported `cache_read_input_tokens` > 0 with `selected slot by LCP similarity, f_sim_best=1.000`.
  - Freshness had to be forced with `POST /models/unload` between trials, verified per trial in the log.
  - Any future trial counting must verify freshness from the log, never from the request flag.

## 7. The crash persists on 10335 (2026-08-09, after the user rebuilt)

- Build `74ce15741` (10335), 9 commits past 10326; only 2 touch CUDA and none touch MTP, speculative, or graphs.
- Same model, same 81,163-token prompt, byte-identical request body (`cmp` clean against the baseline request file).
- **5/5 fresh trials crashed**, same signature (`illegal memory access`, `ggml_backend_cuda_synchronize`, :2499).
  - Every trial provably cold (`selected slot by LRU, t_last = -1`, full reprocess); zero cache hits in the whole log.
  - vs 4/5 on 10326: Fisher exact p = 1.0. No detectable change - the rebuild neither fixed nor worsened it.
  - Failure-mode mix unchanged: 3 mid-decode, 2 at the prefill->decode transition.
- No trial completed, so this arm yields no decode figure; the 1.6x MTP A/B stands on the 10326 measurement.
- Per-build multi-system `/v1/messages` immunity probe on 10335: PASS (200, Anthropic-shaped).
- Standing conclusion: on the current canonical build, `gemma4-12b-it-qat-mtp` cannot serve ~81k-token prompts.
  - Untested and likely sharing the exposure: the 26B and 31B Gemma MTP pairs (same target+drafter mechanism).

### This is not a regression, and reverting has no supporting evidence

Re-read of the primary records, prompted by "are we even sure reverting would fix it?" (user, 2026-08-09):

- **b9860 crashed with this signature too.** 2026-07-17 eval, section 2b, Gemma 12B MTP at ctx 200000, graphs ON:
  "loads; 4 gens OK (~105 tok/s, acceptance 0.745), then `illegal memory access` on gen 5". The last-known-good
  build has a recorded instance of the same failure at large context.
- **Ollama's older vendored llama.cpp crashed too**: 2026-07-01, `ggml-cuda.cu:104 illegal memory access` on
  `qwen3.5-9b-mtp-coding`, rate ~12.5%/run. Same abort macro, different line number (version drift).
- Upstream #26609 likewise reports its crash as cross-build (b10107, b10243).
- So the failure spans Ollama-era llama.cpp, b9860, 10326, and 10335 - months of history, not a recent regression.

What actually changed this week was **workload, not build**: nothing had ever pushed ~81k-token prompts through an
MTP lane. The b9860 "30/30 clean" hammer used ~5k prompts, and the 36/36 ctx ladder used 800-token generations on a
small fixed prompt - neither touches the failure regime.

Recomputing the two comparisons that matter, pooled across builds:

| Comparison | Result | Fisher exact (two-tailed) |
|---|---|---|
| Qwen hammer, 9860 0/30 vs 10326 2/30 | apparent regression | **p = 0.49 - not significant** |
| Gemma 81k, MTP 9/10 vs no-MTP 0/5 | MTP as trigger | **p = 0.002** |

- The 10326 re-cert failure was a **policy** failure (the rule is "any crash = fail"), not a demonstrated regression
  against 9860. Both statements are true and should not be conflated.
- The only intervention with statistical support is removing MTP. Version is not the axis; MTP is.

### Uncontrolled variable found 2026-08-09: the GPU is shared with Windows

Observed by the owner with the router down, no llama-server alive, and no compute apps listed:
`nvidia-smi` reported **4731 MiB / 12282 MiB used**, "No running processes found", 6% utilization.
On WSL2 the guest cannot see host processes, so that memory is Windows-side.

**Scope correction, same day**: the 4731 MiB reading was taken *after* every trial in this document had finished, and
the owner confirms the expected steady-state host load is ~1.5 GB (measured 1569 MiB minutes later). Idle readings
taken around the trials themselves were 838-1442 MiB. So the spike was transient and the trials ran at the normal
operating point - **host contention does not explain the recorded crash rates**, and the earlier framing of a
"~3.9 GB swing during the session" overstated it.

What remains true and worth carrying:

- The card is shared with Windows and the guest's `nvidia-smi` cannot see host processes, so headroom is not ours alone.
- The crashing config reached whole-GPU totals of 11209-11491 MiB of 12282, i.e. **~800-1000 MiB of headroom** at the
  normal baseline. That is thin, and a transient host spike of the size actually observed (4731 MiB) would not fit.
- `-ngl` is unset, so layers are fitted to *available* VRAM at load time, and availability can move mid-run.
- Related documented mechanism on the 26B pair: a fully-used GPU reports free=0 -> NaN layer split -> loader throw
  (upstream #19973). Same family: VRAM contention.

Counter-evidence against contention as the crash mechanism, independent of the above:

- Removing MTP took 5/5 -> 0/5 while freeing only ~240 MiB (10967 vs 11209 MiB whole-GPU). A 240 MiB delta flipping
  the outcome that hard needs the config to sit exactly on a cliff.
- The flash-attn-off arm ran at a *higher* footprint (11884 MiB) and was clean 0/2.

**Standing consequence (reduced but real): free VRAM was still never recorded per trial**, only whole-GPU totals after
load, and host RAM was never recorded at all - which matters because partial-offload models read weights through it.

Fixed as protocol rather than intention: `docs/benchmarking.md` (Resource capture) now requires GPU and host-RAM
snapshots before load, after load, and at crash or completion, plus an explicit `-ngl` pin so two "identical" trials
really are identical. `AGENTS.md` carries the pointer. Everything in this document predates that rule.

### A second, unrelated llama.cpp bug found while running this

`POST /models/unload` arriving at an already-crashed, still-terminating instance orphans the model name in
`stopping_models`, and the **next** instance spawned under that name is force-killed after `stop_timeout` (10 s).

- `tools/server/server-models.cpp:1085` erases the name when the child exits; `:1141` re-inserts it if the unload
  lands after that erase; nothing removes it afterwards, so `is_stopping()` at `:1042` stays true.
- Symptom: `W srv operator(): force-killing model instance name=... after 10 seconds timeout`, with no CUDA error.
- Cost us one trial in each of two consecutive runs. Workaround: poll `/v1/models` and only unload if not already
  unloaded (a crash auto-unloads). Reportable upstream on its own merits.

## 8. Method failures worth keeping (both mine, both same-day)

- **A truncated grep cannot prove absence.** The "removed upstream" claim came from `grep -rn ... | head -8`, whose
  output filled with unrelated `USE_CUDA_GRAPH` hits before reaching the single real match in `common.cuh`.
  A follow-up grep narrowed to `ggml-cuda.cu` alone and appeared to confirm it. Never `head` a search meant to
  establish that something does not exist; count matches over the whole tree instead.
- **A similar-sounding counter is not the signal.** `graphs reused` was read as evidence about CUDA graphs; it is
  llama's own graph-reuse counter. When testing whether a switch turned something off, verify the absence of that
  thing's own marker, not a nearby metric that merely shares vocabulary.
- Upstream match claims need the same discipline: `ggml-cuda.cu:2499` is `cudaStreamSynchronize`, a generic detection
  point any async fault reaches, so "same site as #26609" is near-vacuous. Section 2's wording overstated it.

## 9. Attribution change 2026-08-09: the GPU faults on its own, with no LLM workload

Nothing above is retracted. The crash rates, the MTP gate, and the not-a-regression finding all stand as measured.
What changes is the **attribution**: there is a local cause that was never checked, and it has to be ruled out first.

### The card logs this document's fault signature while nothing of ours is running

Windows System log, provider `nvlddmkm`, Event ID 13 - the WSL analogue of Xid 13, Graphics Exception. `dmesg` inside
WSL shows none of it and sees only llama-server's own SIGABRT, because the kernel-mode driver lives Windows-side.

Read 2026-08-09 23:50 EDT over the whole log (oldest event 2026-06-17 22:31:38):

| Figure | Value |
| --- | --- |
| Id-13 events, all time | 1122 |
| of those, carrying an SM location | 680 |
| on **GPC 3**, any TPC | 660 (97%) |
| on **GPC 3, TPC 1** specifically | 566 (83%) |
| warp exceptions by month | 6 (Jun), 145 (Jul), 256 (Aug) |

The two fault names logged are `Out Of Range Address` and `Misaligned Address`. They map exactly onto the two CUDA
errors recorded here: `illegal memory access` (stages 1-3) and `misaligned address` (stage 4a).

**The control.** Three bursts on 2026-08-09 at 23:16:26, 23:25:19 and 23:26:44, every one
`Graphics SM Warp Exception on (GPC 3, TPC 1, SM 0/1): Out Of Range Address`, with:

- `curl 127.0.0.1:11433/v1/models` refused, no `llama-server` process, `nvidia-smi --query-compute-apps` empty
- no llama-server log written under `~/.local/state` or this repo since 18:00
- the GPU gate closed all evening, so no trial ran

Ordinary Windows desktop use reproduces this document's crash signature on this document's hardware. The desktop
survives it because the compositor resets per frame; a long-lived CUDA context cannot, so one fault rate reads as
"nothing wrong" on Windows and as a hard abort in llama.cpp.
**Rate claim corrected 2026-08-10 - see the correction two subsections below; read them together.**

### A core overclock is live

- `nvidia-smi --query-gpu=power.limit,power.default_limit` -> `220.00 W, 200.00 W`: a 110% limit is applied right now.
- In Afterburner's per-GPU profile file, every profile except `[Profile1]` carries `PowerLimit=110` and
  `CoreClkBoost=230000` (+230 MHz core). `[Profile1]` alone is stock. `MSIAfterburner.exe` runs at startup.
- So the core is +230 MHz whichever non-stock profile is active. Which one is active is UNVERIFIED from inside WSL and
  does not matter for the test below, since `[Profile1]` resets core, memory and power together.

A flat core offset shifts the whole V/F curve including its low-voltage points, which is where instability appears
first - consistent with faults firing under light desktop load.

### What this explains, and the one thing it does not

It explains, better than any software hypothesis has, that **no build ever fixed this**. 9860, 10326, 10335 and
Ollama's older engine all crash the same way (section 7). A defect in the machine predicts exactly that; an upstream
regression does not.

It does not explain the **MTP flag gate**: 9/10 with `--spec-type draft-mtp` against 0/5 without, same GGUF, same ctx,
same prompt (section 6). Marginal silicon is not normally gated on a software flag. The hypothesis worth holding is
exposure - the MTP path runs a denser kernel mix with rapid draft/verify transitions, so it trips a marginal SM where
the plain path does not. That is untested. If the MTP gating survives at stock clocks, both causes are real.

Evidence for neither side: the 6/145/256 monthly trend. GPU-hours rose over the same months as the benchmark program,
so the trend is confounded and is recorded as a bare observation.

### Correction 2026-08-10: the fault rate tracks LLM workload, not desktop use

"Ordinary Windows desktop use reproduces this document's crash signature" overstated the rate. Hourly Id-13 buckets
over the four days to 2026-08-10 02:52:

| Hour bucket | Events | What was running |
| --- | --- | --- |
| 2026-08-08 02-09 | 405 | the re-cert crash session |
| 2026-08-08 13-20 | 361 | the live crash-loop and the diagnosis batches |
| 2026-08-09 12 | 2 | - |
| 2026-08-09 23 | 12 | the zero-workload control above |
| 2026-08-10 00-02 | 0 | idle |

780 events in four days, and 766 of them fall inside documented GPU-LLM sessions. All of 2026-08-09 produced 14,
while the overclock was confirmed live at 23:50 that night. **Idle windows were already quiet at 220 W**, so a quiet
idle window at stock clocks discriminates nothing.

Two claims survive, narrowed:

- The 23:16-23:26 burst did occur with no `llama-server` process, no CUDA compute client, and no trial running. That
  rules out **llama.cpp**, not GPU compute in general - Firefox and dwm held GPU memory and were never checked for
  compute work (video decode, WebGL). "No LLM workload" is what was verified; "no GPU compute" was not.
- The spatial concentration - 97% of located events on GPC 3 - is untouched by any of this.

### The discriminator, superseded 2026-08-10

The passive idle watch below is retired: it cannot separate the hypotheses, for the reason in the correction above.
The stock-clock **crash matrix**, with an Id-13 delta bracketing every trial, replaces it. Pre-registered reading:

| Outcome | Reading |
| --- | --- |
| 0/10 crashes | against 9/10, Fisher p ~ 0.0001 - the overclock was the cause and there is nothing to file |
| crashes persist, Id-13 fires | marginal silicon independent of clocks; remediation changes, still nothing to file |
| crashes persist, **no** Id-13 delta | the software case gets much stronger - this is what unblocks the dossier |

The third row is why the Id-13 bracket matters more than the crash count.

### The original discriminator (retired, kept for the record)

Set Afterburner to `[Profile1]`, change nothing else, leave the desktop to idle and browse, then count Id-13 events
over a comparable window.

- Faults go to zero -> the overclock is the cause, and a crash-matrix re-run is confirmation.
- Faults persist -> the silicon is marginal independent of clocks, and remediation changes (underclock, or RMA).

A crash-matrix re-run means nothing until that is done. **No upstream report before it**: filing now would attribute
to llama.cpp a fault this machine produces unprompted.

### Reading this log correctly (a measurement trap)

`Get-WinEvent`'s `.Message` renders **empty** from WSL, because the provider's resource DLL is not loadable there. A
message-text filter therefore matches nothing and reads as "no such events". The text lives in the event XML:

```powershell
Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='nvlddmkm';Id=13} |
  ForEach-Object { ([xml]$_.ToXml()).Event.EventData.Data[1] }
```

Multi-line PowerShell does not survive `powershell.exe -Command -` over stdin either: it executes line by line and
silently drops block bodies, exiting 0. Use single-line pipelines.

### Cleared locally (verified at HEAD, for an eventual upstream report)

- Toolkit **13.3.73** (`nvcc --version`; CMakeCache `FIND_PACKAGE_MESSAGE_DETAILS_CUDAToolkit ... [v13.3.73()]`),
  driver 610.62. Not the 13.2 the repo warns about - and `docs/parameters.md:23` ("**CUDA 13.2 produces corrupted
  Gemma 4 output.** Use CUDA 13.1 or 13.3") is itself unsourced and speaks only to corrupted output, never crashes.
- Build config stock: `CMAKE_BUILD_TYPE=Release`, `CMAKE_CUDA_ARCHITECTURES=89` (correct for Ada), `CMAKE_CUDA_FLAGS`
  empty, `GGML_CUDA_GRAPHS=ON` as intended, `GGML_LTO=OFF`, no `GGML_CUDA_F16`, no fast-math.
- Agent-reported, not re-verified here: all 7 GGUF blobs sha256-match their HF OIDs; no `GGML_*`/`CUDA_*`/`LD_PRELOAD`
  in any shell init or the launcher; no GPU limits in `.wslconfig`; no remapped-row failures.

## Provenance and validity

- Small n throughout: 2 fresh-prefill control trials, 1 fa-off trial; the live loop (15 spawns) is the strongest sample.
- Stage 2's three-variable overlay caps the mechanism claim at "consistent with"; a single clean run is weak against a low per-run rate.
- One anomaly consumed a trial: a 240s client timeout orphaned a server-side fa-off generation (attempt A, discarded).
- Raw evidence: `recert/` (router.log + 42 response JSONs + version.txt), `gpu-batch/` (r1-gen1..3.json, r2-gen1.json, r1/r2/r2b.log), `~/.local/state/llama-router.log`. Job scratch is session-lifetime; this log is the durable record.
