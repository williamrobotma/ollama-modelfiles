# Session summary - MTP x CUDA-graphs crash, reproduced + characterized (2026-07-01)

Branch: `refactor/benchmark-common-harness`. Settles whether Qwen MTP +
CUDA graphs is actually broken on this box, after a chain of over-confident
claims (mine) that rested on unverified secondhand summaries and N=1.

## The question
The 2026-06-30 9B-coders benchmark crashed once on graphs-on +
`qwen3.5-9b-mtp-coding` (`ggml-cuda.cu:104 illegal memory access`, ~1289
tokens in). Is that a real MTP x graphs incompatibility, or a fluke?

## What was verified (all primary-source, on-box)

Stack: Ollama **0.30.11**, vendored llama.cpp **b9781** (2026-06-24, read from
`LLAMA_CPP_VERSION` at the v0.30.11 tag), CUDA driver **13.3**, `cuda_v13`
runtime, RTX 4070 12 GB, WSL2.

1. **Not deterministic.** A 3-cell isolation re-run had MTP@graphs-on go 4/4
   clean (two full 65536-token, ~10 min each). So "always crashes" is false.
2. **But real and intermittent.** A 30-run hammer on one warm serve (model
   100% GPU, no offload; each run bounded to `num_predict=4096`, 3x past the
   1289-token crash point): **7 clean runs, crash on run 8** at n_decoded
   ~1639. Same signature: `ggml_backend_cuda_synchronize` ->
   `cudaStreamSynchronize`, `ggml-cuda.cu:3249` / `:104`, illegal memory
   access. **Rate ~= 1/8 (12.5%) per bounded run.**
   - The hammer stops at the first crash by design (the runner dies; measuring
     further would be a poisoned rate). So 12.5% is a first-crash estimate,
     not a converged rate - the real point is "not rare."
3. **Mechanism is consistent with the diagnosis.** MTP draft acceptance = 0.771
   (2484/3222, mean accepted length 2.54) - i.e. a variable number of accepted
   tokens per step, hence variable graph shape per step. CUDA graph capture
   assumes static shape; speculative decoding violates it. `graphs reused =
   11243` before the crash shows capture is active and mostly working, until it
   isn't. This is the same failure family reported across engines (llama.cpp,
   vLLM, sglang) for spec-decoding + CUDA graphs; it is a known-hard
   interaction, not a config error.
   - NOTE: the earlier-cited llama.cpp fix (PR #21611, LRU graph-cache
     eviction, in b9781) addresses a *memory-leak-over-time* symptom, NOT this
     crash. Reading the 19-line diff confirms it cannot prevent an illegal
     memory access. Do not conflate the two.

## Decision
**Keep `GGML_CUDA_DISABLE_GRAPHS=1`** on the systemd Ollama instance.
- graphs-off ran 16/16 clean in the 2026-06-30 benchmark; the 30-run hammer
  crash only appears with graphs ON.
- Cost: Gemma loses ~15-17%, non-MTP Qwen ~20-26% decode throughput. Accepted:
  a ~12.5%-per-run hard crash on the MTP models actually served via
  claude-local is far worse than a 15% throughput trim. The MTP self-draft
  (~1.65x) already dwarfs the recoverable graphs delta on the primary coder.
- No per-model graphs toggle exists in Ollama (issue #12083 open since
  Aug 2025); the choice is serve-wide. Two-serve split (Gemma graphs-on,
  MTP/claude-local graphs-off) is possible but not worth the VRAM-doubling +
  orchestration on a 12 GB card for a +15% on a non-primary model.

## Corrected prior errors
`session_summary_runtime_ab.md` claimed (a) serial single-slot graphs-on does
NOT error and (b) prod runs graphs-off. Both false: (a) it crashes ~12.5%,
(b) the systemd override had the disable line commented out, so prod was
graphs-ON and exposed. Correction blocks added there. The three
`benchmark-*.runtime.tsv` "graphs-off" descriptions (which claimed to match a
graphs-off prod that didn't exist) were reworded to name the prod target and
this file.

## Action still required (needs sudo; not applied by the agent)
Uncomment the disable line in `/etc/systemd/system/ollama.service.d/override.conf`
and reload+restart (interrupts the warm 35b and any live claude-local session):
```
sudo sed -i 's/^# Environment="GGML_CUDA_DISABLE_GRAPHS=1"/Environment="GGML_CUDA_DISABLE_GRAPHS=1"/' \
    /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
# verify:
systemctl show ollama --property=Environment | tr ' ' '\n' | grep GRAPHS
```

## Repro tool
`repro-mtp-graphs.sh` (committed): dry-run-by-default, `--execute` runs the
30-rep hammer on an isolated alternate-port serve (never mutates systemd).
Kills its serve by PID on an EXIT trap (an earlier PGID kill also killed the
wrapper - the reason the first 3-cell version stopped after one cell).

## Method note (why this took several tries)
Two forks returned confident summaries; I repeated them as findings without
opening the primary sources (issue was fixed not stale; the "fix" was
unrelated; prod state was misread). The lesson is now in `~/.claude/CLAUDE.md`:
a summary/subagent-report/doc-claim/N=1 is a lead, not a finding - verify each
load-bearing fact directly (read the diff, hit the API, cat the config,
reproduce) before recommending.
