# Session summary - Qwen3.5-9B-MTP bench, MTP+graphs incompat (2026-06-30)

Branch: `refactor/benchmark-common-harness`.  Captures (a) the migration of
the canonical 9B-coding Modelfile off the broken Unsloth HF OCI bridge,
(b) the staging of Qwen3.5-9B-MTP as a speed variant for the 9B-coders
suite, and (c) the first benchmark run which produced both the MTP
speedup measurement and a hard CUDA crash for MTP + graphs-on.

## What was done

1. **Migrated `Modelfile.qwen3.5-9b-coding` source** from
   `hf.co/unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL` (HF OCI config-blob endpoint
   hangs indefinitely, verified repo-wide, every tag, 7+ days) to Ollama
   official `qwen3.5:9b` (Q4_K_M, 6.6 GB).  Trade: ~1-2% quality
   (UD-Dynamic 2.0 -> standard Q4_K_M) for durable re-pullability.
   Renamed Modelfile to `-q4-k-m` suffix.  See memory
   `unsloth_qwen3.5_oci_bridge_broken.md`.
2. **Staged Qwen3.5-9B-MTP** as a new variant alongside the base 9B.
   Source: `hf.co/unsloth/Qwen3.5-9B-MTP-GGUF:UD-Q4_K_XL`, OCI bridge
   verified (config blob fetches in ~130 ms, 3/3) - **different repo
   from the broken sibling**.  Single self-contained MTP GGUF
   (Qwen-style, not Gemma-style separate-drafter), `draft_num_predict 2`
   per Unsloth.  Built clean, ~7.1 GB.
3. **Ran `./benchmark-9b-coders.sh --execute`** end-to-end.  Completed
   21/32 measured runs (all 16 graphs-off + 5 graphs-on before crash).

## Key findings

### Throughput (mean+/-sd tok/s, n=2 reps per cell)
```
model                              prompt   graphs-off       graphs-on    delta%
qwen3.5-9b-mtp-coding-ud-q4-k-xl   long      98.18+/-6.77    CRASH         -
qwen3.5-9b-mtp-coding-ud-q4-k-xl   medium   103.79+/-4.19    CRASH         -
qwen3.5-9b-coding-q4-k-m           long      57.81+/-0.11    72.79+/-6.66  +25.9%
qwen3.5-9b-coding-q4-k-m           medium    63.37+/-0.33    76.86+/-0.59  +21.3%
qwopus3.5-9b-coder-q4-k-m          long      59.63+/-3.72    -             -
qwopus3.5-9b-coder-q4-k-m          medium    60.09+/-3.85    -             -
gemma4-12b-it-qat                  long      45.66+/-0.14    -             -
gemma4-12b-it-qat                  medium    45.97+/-0.20    -             -
```

- **MTP self-draft delivers ~1.65x speedup** at graphs-off (98-104 vs
  58-63 tok/s on the same Qwen3.5-9B base, same precise-coding profile).
  In Unsloth's claimed 1.5-2x range.
- **Qwopus shows no speed edge** over the base 9B (~60 vs ~60); a
  finetune doesn't change the underlying decode budget.  Its coding-
  quality claim remains untested - the throughput run doesn't address it.
- **CUDA graphs on the non-MTP 9B**: +21-26% on top of graphs-off, with
  one noisy cell (long, sd 6.66) suggesting some run-to-run variance.
- Gemma 12B baseline at ~46 tok/s is the slowest of the resident set, as
  expected (dense 12B vs dense/hybrid 9B).

### MTP + CUDA graphs = hard crash
The graphs-on run died on `qwen3.5-9b-mtp-coding-ud-q4-k-xl/long/run-1`
with:

```
ggml-cuda.cu:104: CUDA error
CUDA error: an illegal memory access was encountered
  current device: 0, in function ggml_backend_cuda_synchronize
  cudaStreamSynchronize(cuda_ctx->stream())
... llama-server terminated, signal: aborted
```

Decode rate just before the crash was ~107 tok/s for 1289 tokens, so the
combination *worked* for a while.  The crash was not OOM (the 7.1 GB MTP
GGUF fits resident at 128K with KV q8_0 on the 12 GB card).  This is the
same family of CUDA-graphs failure documented in
`session_summary_runtime_ab.md` for Qwen3.6-27B-MTP: speculative decoding
appears to fight CUDA graph capture/replay, and MTP makes it worse
because every drafted token can change the graph shape vs the captured
one.  **Production stays on graphs-off** (`GGML_CUDA_DISABLE_GRAPHS=1`
in systemd), so this does not affect real use of the MTP model.

Did not invest time re-running graphs-on - the production setup never
turns graphs on, and the crash reproduces the documented incompatibility
rather than revealing something new.

## Operational notes
- The 9B-coders suite now has three variants: non-MTP base
  (`qwen3.5-9b-coding`), MTP self-draft (`qwen3.5-9b-mtp-coding`), and
  the Qwopus finetune.  All three fit fully GPU-resident at 128K ctx
  with KV q8_0.
- The MTP self-draft (~1.65x) is the cheapest available decode speedup
  for the 12 GB card; no extra hardware, no quality loss vs the base,
  same precise-coding profile.  Default coding driver should be
  `qwen3.5-9b-mtp-coding` when MTP-ready Ollama is in use.
- Most runs hit `num_predict=65536` (output cap), so eval_count is
  truncation-bound rather than EOS-bound; throughput numbers are
  unaffected (rate, not length), but quality comparison would need EOS-
  bound or token-bounded prompts.

## Open
- Qwopus vs base 9B on **quality** (the original open question) remains
  unsettled by this run, which only measured decode rate.  Throughput is
  equal; coding-quality A/B needs the rubric, not the timer.
- The Qwen3.5-9B MTP draft acceptance rate is implicit in the ~1.65x
  vs the theoretical 2x ceiling (two-token draft) - around 60-70%
  acceptance, healthy but worth confirming via server-side counters if
  they become available.
