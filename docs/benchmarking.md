# Benchmarking

Three dry-run-by-default Ollama benchmark suites live under `benchmarks/`.
They are frozen legacy harnesses targeting the retired Ollama serving lane, kept on disk for reference.
llamacpp-parity (below) stays current: it benches stock llama-server, the live serving lane.
Shared machinery and a report tool live alongside them.
Headline findings are distilled below with links into the immutable evidence logs in `history/`.

## Layout

```text
benchmarks/
  qwen/        run.sh  matrix.tsv  runtime.tsv  prompts/{medium,long}.txt
  gemma/       run.sh  matrix.tsv  runtime.tsv  prompts/{reasoning,analysis}.txt
  9b-coders/   run.sh  matrix.tsv  runtime.tsv  prompts/{medium,long}.txt
  llamacpp-parity/  run.sh  report.py  matrix.tsv  runtime.tsv  prompts/{medium,long}.txt
  common.sh    shared harness body sourced by each suite's run.sh
  report.py    post-run report: per-prompt throughput mean/stdev + sanity flags
  all.sh       runs qwen, gemma, 9b-coders sequentially
```

Each Ollama suite's `run.sh` sets its suite name and sources `common.sh`.
`matrix.tsv` lists the model IDs to compare.
`runtime.tsv` defines the runtime A/B profiles (graphs-off vs graphs-on).

**llamacpp-parity** is a self-contained cross-engine suite (it does not source `common.sh`).
It benches the same GGUF on an isolated Ollama serve (graphs-off profile) against stock llama-server.
Stock llama-server is now the live serving lane.
`LLAMA_SERVER_BIN` selects the binary (default `~/Developer/llama.cpp/build/bin/llama-server`).
Decode tok/s is read from each engine's own primary metrics.
The Ollama side reads `ollama run --verbose` eval rate; the llama-server side reads response `timings`.
Its matrix rows carry the GGUF snapshot path, ctx, sampling flags (mirroring docs/parameters.md).
They also carry spec-decode flags per model.
It has its own `report.py` (mean/stdev plus llamacpp-vs-ollama and mtp-vs-plain ratios).
Same dry-run-by-default CLI as the other suites.
Built for the specs/done/llamacpp-serving option-C eval.
See [history/2026-07-17-llamacpp-eval.md](history/2026-07-17-llamacpp-eval.md).

## Running

The commands below cover the frozen qwen/gemma/9b-coders suites.
They still run mechanically against the now-retired Ollama lane.

- Everything is dry-run by default: nothing runs without `--execute`.
- `benchmarks/qwen/run.sh` prints the plan and the exact `ollama run --verbose` commands it would run.
- `benchmarks/qwen/run.sh --list` lists the configured models and prompts.
- `benchmarks/qwen/run.sh --execute` actually runs the matrix. Nothing touches Ollama without `--execute`.
- `benchmarks/all.sh` runs all three suites sequentially (safe - see the port note).
- Executed runs write raw logs and timing under `benchmark-results/<timestamp>/` (gitignored).

Suite scope:

- **qwen**: canonical Qwen 3.6 coding variants.
- **gemma**: first-pass, text-only, two models (`gemma4-12b-it-qat`, `gemma4-26b-a4b-it-qat`).
- **9b-coders**: small coders that fit fully in 12 GB VRAM, benched against the `gemma4-12b-it-qat` baseline.
  - `qwen3.5-9b-coding-ud-q4-k-xl`
  - `qwen3.5-9b-mtp-coding` (self-draft variant)
  - `qwopus3.5-9b-coder` (community finetune)

## Isolated serves and ports

Runtime A/B compares CUDA graphs off vs on via temporary isolated `ollama serve` instances on alternate ports.
It never mutates systemd mid-run:

- `127.0.0.1:11434` - the Ollama systemd service's port (untouched by the harness).
  - Ollama is retired as the serving lane; stop/purge is tracked in specs/llamacpp-migration Phase 4.
- `127.0.0.1:11435` - graphs-off profile (`GGML_CUDA_DISABLE_GRAPHS=1`), the prod target under Ollama serving.
  - Also the llamacpp-parity suite's Ollama side.
- `127.0.0.1:11436` - graphs-on profile (`GGML_CUDA_DISABLE_GRAPHS` unset).
- `127.0.0.1:11437` - `scripts/repro-mtp-graphs.sh` only.
- `127.0.0.1:11438` - llamacpp-parity suite's llama-server side.

The suites share these ports, so **never run two suites concurrently** unless you change the host assignments.
`all.sh` is sequential and safe.
For the cleanest results, stop or idle the Ollama systemd service first.

The isolated serves run as the invoking user.
The harness sets `OLLAMA_MODELS=/usr/share/ollama/.ollama/models` (the systemd `ollama` user's store).
This lets it see the `ollama create`d models.
It requires the invoking user to be in the `ollama` group for read access.

## Report tool

```bash
python3 benchmarks/report.py benchmark-results/<timestamp> ...
```

Stdlib only (`pyproject.toml` pins `requires-python >= 3.10`).
Produces per-prompt throughput mean/stdev (graphs-off vs graphs-on) plus coarse output-sanity flags.

## Findings

Distilled from the evidence logs; follow the links for the primary-source detail.

### MTP speedups (decode throughput)

- Qwen 3.5 9B self-draft MTP: ~1.65x.
  - See [history/2026-06-23-qwen3.5-9b-mtp-bench.md](history/2026-06-23-qwen3.5-9b-mtp-bench.md).
- Gemma 4 MTP via Ollama `DRAFT`: 1.67x on the 12B pair, 1.54x on the 26B pair.
  - See [history/2026-07-10-migration-local-ggufs.md](history/2026-07-10-migration-local-ggufs.md).

### MTP x CUDA-graphs crash

- MTP models with CUDA graphs on crashed ~12.5% per run (illegal memory access) on the Ollama lane.
  - Reproduced with a 30-run hammer.
  - See [history/2026-07-01-mtp-graphs-crash.md](history/2026-07-01-mtp-graphs-crash.md).
- Ollama-era decision: keep `GGML_CUDA_DISABLE_GRAPHS=1` serve-wide.
  - Ollama had no per-model graphs toggle (issue #12083).
  - A ~12.5%/run hard crash on the MTP models served via claude-local outweighed the throughput trim.
  - The MTP self-draft speedup already dwarfed the recoverable graphs delta.
- Current stance (llama-server lane): CUDA graphs run ON fleet-wide, deliberately.
  - Validated in Phase 1 of specs/llamacpp-migration (2026-08-03).
  - The 12B MTP ctx ladder ran 36/36 clean generations through 200k ctx.
  - A 30-run graphs-on hammer on the router child came back 30/30 clean, zero crash lines.
  - The upstream MTP x graphs issue remains open but did not reproduce across the Phase 1 checks.
  - See [history/2026-08-03-llamacpp-p1-envelopes.md](history/2026-08-03-llamacpp-p1-envelopes.md).

### llama.cpp parity eval (2026-07-17)

- Stock llama-server b9860 beat the graphs-off Ollama prod target on every measured cell.
  - qwen9b +6-14%, gemma12b +16%, qwen9b-mtp +4-13%; stock-only gemma12b MTP ran 1.83x.
  - See [history/2026-07-17-llamacpp-eval.md](history/2026-07-17-llamacpp-eval.md).
- The Gemma MTP drafter is config-gated on stock: stable only with CUDA graphs ON at moderate ctx (7/7 gens at 16k).
  - Graphs-off fails the drafter load at 200k with the #24795 signature.
  - Graphs-off also crashes in-flight at 16k (misaligned address).
  - Ollama's `DRAFT` lane (graphs-off env) crashed 9/10 requests on-box.
  - Stock was the only working Gemma MTP path.
- Verdict recorded in the eval log: full migration (B) indicated.
  - Gemma MTP processes belong on stock with graphs ON and a capped ctx.
  - The crash matrix is the post-rebuild regression test.

### Graphs-off throughput cost

- Turning graphs off cost Gemma ~15-17% and non-MTP Qwen ~20-26% decode throughput on the Ollama lane.
  - Accepted then as the price of avoiding the crash.
  - See [history/2026-06-21-runtime-ab.md](history/2026-06-21-runtime-ab.md).

### Caveat on older numbers

- 2026-07: the 9b-coding model moved from Ollama-official Q4_K_M back to Unsloth UD-Q4_K_XL.
  - Graphs-off numbers measured before that change predate the quant and are not comparable.
  - See [history/2026-06-30-9b-coders-vram.md](history/2026-06-30-9b-coders-vram.md).
