# 2026-08-09: evidence dossier for an upstream llama.cpp report (MTP CUDA crash)

Raw material for a human-written upstream report. llama.cpp forbids AI-written posts
([CONTRIBUTING.md](https://github.com/ggml-org/llama.cpp/blob/master/CONTRIBUTING.md) item 5), so nothing here is a
draft to paste - it is the verified facts, with a source link for each, to write from.

## Upstream issues

| Issue | State | Relevance |
|---|---|---|
| [#26782](https://github.com/ggml-org/llama.cpp/issues/26782) - Eval bug: Running gemma 4 12b with draft-mtp causes memory access fault (opened 2026-08-09) | OPEN | **Best match.** Same model + `--spec-type draft-mtp`; reporter says the crash vanishes when draft-mtp is removed. Theirs is HIP/RX 6700 XT and crashes during prefill; ours is CUDA and crashes at/after the prefill->decode boundary. |
| [#26558](https://github.com/ggml-org/llama.cpp/issues/26558) - Eval bug: llama-server hard crash (cublasSgemm INVALID_VALUE) with --spec-type draft-mtp under KV-cache saturation (opened 2026-08-04) | OPEN | Same flag, different error and regime (`-np 4`, KV saturation, 0.8B). Its CUDA-graph theory is not supported by our data. |
| [#26609](https://github.com/ggml-org/llama.cpp/issues/26609) - CUDA illegal memory access in cudaStreamSynchronize (flash-attn path) with Qwen3.6-35B MoE + partial expert offload (opened 2026-08-05) | OPEN | Shares only the abort line. No MTP on their side. Probably not ours. |
| [#26738](https://github.com/ggml-org/llama.cpp/issues/26738) - Page fault at depth with -fa 0 and MoE expert offload on HIP / [PR #26771](https://github.com/ggml-org/llama.cpp/pull/26771) - CUDA: Recapture graph after memory pool flush (2026-08-07/08) | OPEN | Excluded for us: that fix path is in `ggml_cuda_pool_leg`, and this box reports `VMM: yes` so it uses `ggml_cuda_pool_vmm`. |

## Environment

- Build [`3653e6d6d`](https://github.com/ggml-org/llama.cpp/commit/3653e6d6d547ec763317d9ecd0ace334a7e21359) = b10326,
  2026-08-07 ("tts: account for the vocoder pass in the timings line (#26733)"). `llama-server --version` prints
  `version: 10326 (3653e6d6d)`. Built with `GGML_CUDA_GRAPHS:BOOL=ON`, `GGML_CUDA_NO_VMM:BOOL=OFF`, Release.
- NVIDIA GeForce RTX 4070, 12282 MiB, driver 610.62, compute capability 8.9, `VMM: yes`.
- Ubuntu 26.04 LTS on WSL2, kernel 6.18.33.2-microsoft-standard-WSL2.
- Model: [unsloth/gemma-4-12B-it-qat-GGUF](https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF), snapshot
  `980b060c40a8539ac159e0501a3e0f66a6365af3`: `gemma-4-12B-it-qat-UD-Q4_K_XL.gguf` + drafter `mtp-gemma-4-12B-it.gguf`.

Serving config (router mode; the crashing entry):

```ini
[*]
jinja = true
flash-attn = on
cache-type-k = q8_0
cache-type-v = q8_0
parallel = 1
min-p = 0.0
n-predict = 65536
repeat-penalty = 1.0
top-p = 0.95
presence-penalty = 0.0

[gemma4-12b-it-qat-mtp]
model = .../gemma-4-12B-it-qat-UD-Q4_K_XL.gguf
model-draft = .../mtp-gemma-4-12B-it.gguf
spec-type = draft-mtp
spec-draft-n-max = 2
ctx-size = 200000
temp = 1.0
top-k = 64
```

Launcher adds `--models-preset`, `--models-max 1`, `--sleep-idle-seconds 86400`, `--cors-origins localhost`,
`--host 127.0.0.1 --port 11433`. `-ngl` unset (build default, auto).

## Crash signature (verbatim, `iso/r1.log:169-173`)

```text
/home/wma/Developer/llama.cpp/ggml/src/ggml-cuda/ggml-cuda.cu:106: CUDA error
CUDA error: an illegal memory access was encountered
  current device: 0, in function ggml_backend_cuda_synchronize at ggml-cuda.cu:2499
  cudaStreamSynchronize(cuda_ctx->stream())
```

- `ggml-cuda.cu:106` is `GGML_ABORT(GGML_CUDA_NAME " error")` inside the `CUDA_CHECK` macro.
- `ggml-cuda.cu:2499` is the `CUDA_CHECK(cudaStreamSynchronize(cuda_ctx->stream()))` in
  `ggml_backend_cuda_synchronize`. **This is a detection point, not a bug site**: any async fault from any earlier
  kernel surfaces here. No kernel is named yet - that needs a `compute-sanitizer` run.
- One variant: `CUDA error: misaligned address` at the same function (`iso/r4on.log:150-151`), seen only in the
  flash-attn-on arm at ctx 131072 with f16 KV. Possibly a second fault mode.

## The isolation result

Identical model, identical 81,163-token prompt, `max_tokens` 1600, five fresh trials per arm, one variable per arm.
Freshness forced per trial (see the cache caveat below) and confirmed from the server log.

| Arm | Crashes / fresh trials | Crash lines in log |
|---|---|---|
| Baseline (config above) | 4/5 | 10 |
| `GGML_CUDA_DISABLE_GRAPHS=1` | 2/5 | 4 |
| **No MTP** - same GGUF, no `spec-type`/`model-draft` | **0/5** | **0** |
| flash-attn on, ctx 131072, f16 KV | 1/3 | 2 |
| flash-attn off, ctx 131072, f16 KV | 0/2 | 0 |

- Removing MTP: 4/5 -> 0/5, Fisher exact two-tailed **p = 0.048**. The no-MTP entry differs only by the absence of
  `spec-type`/`model-draft` and the presence of `mmproj` (state that difference honestly).
- CUDA graphs off: 4/5 -> 2/5, **p = 0.50** - not significant. Both crashes carried the identical signature.
- The graphs env was proven effective first: `CUDA graph warmup complete` appears in the log with the var unset and
  is absent with it set. The var lives at `ggml/src/ggml-cuda/common.cuh:1258` and tests presence only, so
  `GGML_CUDA_DISABLE_GRAPHS=0` also disables graphs. It moved there in
  [`090b137e`](https://github.com/ggml-org/llama.cpp/commit/090b137e56a80b189dbced7d31e637951f3e123f) (#18637).

Earlier observations on the same build, same model:

- Real interactive use at ~88k context: 13 crashes across 15 child spawns in 35 minutes, each after a 48-54 s reprefill.
- A separate model, [unsloth/Qwen3.5-9B-MTP-GGUF](https://huggingface.co/unsloth/Qwen3.5-9B-MTP-GGUF) (self-contained
  MTP, no separate drafter), crashed 2/30 bounded generations with the same signature - so the exposure spans both MTP
  mechanisms and two model families.
- Crash points ranged from n_decoded 0 (at the prefill->decode boundary) through ~403, ~609, ~1517.

## Caveats that belong in any report

- No kernel is named and no `compute-sanitizer` trace exists yet. `compute-sanitizer` 2026.2.1.0 is available locally
  (`~/miniforge3/envs/llamacpp/bin/compute-sanitizer`) but is slow at this context size.
- The baseline rate here (4/5) is far above an earlier same-build measurement (1/3) on the same config. Unexplained;
  possibly related to repeated load/unload cycling within one router session. It applies to every arm equally.
- The flash-attn arms are underpowered (3 and 2 trials) and fa-off runs ~17x slower, which itself lowers exposure.
- No first-bad-commit. The previous last-known-good (b9860) is not being re-tested - the current on-disk build is
  canonical here by owner policy, so no downgrade comparison will be produced.
- **`"cache_prompt": false` is silently ignored on `/v1/messages`** at this build: a resent prompt still reported
  `cache_read_input_tokens` > 0 with `selected slot by LCP similarity, f_sim_best = 1.000`. Freshness had to be forced
  with `POST /models/unload` between trials. Worth reporting separately if reproducible from a clean checkout.

## Artifacts

Session scratch (not durable): `~/.claude/jobs/face4be1/tmp/iso/` - `r0on/r0off/r1/r2/r3/r4on/r4off.log`, per-trial
response JSONs, `TALLY.md`. Earlier batches in `../gpu-batch/` and `../gpu-batch2/`; the live-use crash loop is in
`~/.local/state/llama-router.log`.
