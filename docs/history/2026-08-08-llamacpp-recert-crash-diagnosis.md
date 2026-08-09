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

## 6. Method failures worth keeping (both mine, both same-day)

- **A truncated grep cannot prove absence.** The "removed upstream" claim came from `grep -rn ... | head -8`, whose
  output filled with unrelated `USE_CUDA_GRAPH` hits before reaching the single real match in `common.cuh`.
  A follow-up grep narrowed to `ggml-cuda.cu` alone and appeared to confirm it. Never `head` a search meant to
  establish that something does not exist; count matches over the whole tree instead.
- **A similar-sounding counter is not the signal.** `graphs reused` was read as evidence about CUDA graphs; it is
  llama's own graph-reuse counter. When testing whether a switch turned something off, verify the absence of that
  thing's own marker, not a nearby metric that merely shares vocabulary.
- Upstream match claims need the same discipline: `ggml-cuda.cu:2499` is `cudaStreamSynchronize`, a generic detection
  point any async fault reaches, so "same site as #26609" is near-vacuous. Section 2's wording overstated it.

## Provenance and validity

- Small n throughout: 2 fresh-prefill control trials, 1 fa-off trial; the live loop (15 spawns) is the strongest sample.
- Stage 2's three-variable overlay caps the mechanism claim at "consistent with"; a single clean run is weak against a low per-run rate.
- One anomaly consumed a trial: a 240s client timeout orphaned a server-side fa-off generation (attempt A, discarded).
- Raw evidence: `recert/` (router.log + 42 response JSONs + version.txt), `gpu-batch/` (r1-gen1..3.json, r2-gen1.json, r1/r2/r2b.log), `~/.local/state/llama-router.log`. Job scratch is session-lifetime; this log is the durable record.
