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
Decode tok/s is read per engine: `ollama run --verbose` eval rate (Ollama), response `timings` (llama-server).
Its matrix rows carry the GGUF snapshot path, ctx, sampling flags (per docs/parameters.md), and spec-decode flags.
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
  - The 35B-A3B `q4-k-xl` pair (matrix rows 4-5) left the fleet in the 2026-07-27 reduction.
    - These frozen rows no longer resolve.
- **gemma**: first-pass, text-only, two models (`gemma4-12b-it-qat`, `gemma4-26b-a4b-it-qat`).
- **9b-coders**: small coders that fit fully in 12 GB VRAM, benched against the `gemma4-12b-it-qat` baseline.
  - `qwen3.5-9b-coding-ud-q4-k-xl`
  - `qwen3.5-9b-mtp-coding` (self-draft variant)
  - `qwopus3.5-9b-coder` (community finetune)
    - Left the fleet in the 2026-07-27 reduction; this frozen row no longer resolves.

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

## Resource capture (mandatory for crash trials and any GPU run whose numbers get quoted)

The box shares one 12 GB card with Windows and shares host RAM through WSL2, so both budgets move without warning
and neither is visible from a result file. Capture them per trial, or the trial is uninterpretable later.

Record at three points - before load, after load, and at crash or completion:

```bash
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu,temperature.gpu,clocks_throttle_reasons.active \
    --format=csv,noheader                      # GPU; the guest cannot see Windows-side consumers
free -m | sed -n '2p;3p'                       # host RAM and swap (WSL2 shares them)

# GPU hardware faults, Windows-side. Bracket every trial with this and record the delta.
/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command \
    "(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='nvlddmkm';Id=13} -EA 0).Count"
```

- The Id-13 delta is what separates a hardware fault from a software bug. This card logs SM warp exceptions on GPC 3
  with no LLM workload at all, so a crash trial without the delta cannot tell you which one you measured.
  - `dmesg` cannot see these: the kernel-mode driver is Windows-side, so WSL only shows llama-server's own SIGABRT.
  - `.Message` renders empty under WSL, so a message-text filter silently matches nothing. Read the event XML.
  - Location breakdown one-liner and the full finding:
    [history/2026-08-08-llamacpp-recert-crash-diagnosis.md](history/2026-08-08-llamacpp-recert-crash-diagnosis.md).
- Pin `-ngl` explicitly for trials. Unset means layers fit to whatever is free at load time, so the split silently
  depends on host conditions and two "identical" trials are not identical.
- Note whether the host was quiescent. A steady-state baseline here is ~1.5 GB GPU; transient host spikes to ~4.7 GB
  have been observed, which is more than the headroom a 12B at large ctx leaves (~800-1000 MiB).
- Swap pressure matters as much as VRAM: partial-offload models read weights through host RAM, so a host under
  memory pressure changes timings and can starve a run that looked fine on VRAM alone.
- Why this is a rule: the 2026-08-09 crash trials recorded only whole-GPU totals after load, so no crash rate in
  `history/2026-08-08-llamacpp-recert-crash-diagnosis.md` is controlled for free VRAM or host RAM.

## Report tool

```bash
python3 benchmarks/report.py benchmark-results/<timestamp> ...
```

Stdlib only (`pyproject.toml` pins `requires-python >= 3.10`).
Produces per-prompt throughput mean/stdev (graphs-off vs graphs-on) plus coarse output-sanity flags.

## Findings

Distilled from the evidence logs; follow the links for the primary-source detail.

### MTP speedups (decode throughput)

- Qwen 3.5 9B self-draft MTP: ~1.65x; 98-121 tok/s on the router child (P1 hammer, 2026-08-03).
  - See [history/2026-06-23-qwen3.5-9b-mtp-bench.md](history/2026-06-23-qwen3.5-9b-mtp-bench.md).
- Gemma 4 MTP via Ollama `DRAFT`: 1.67x on the 12B pair, 1.54x on the 26B pair.
  - See [history/2026-07-10-migration-local-ggufs.md](history/2026-07-10-migration-local-ggufs.md).

### MTP x CUDA-graphs crash

- MTP models with CUDA graphs on crashed ~12.5% per run (illegal memory access) on the Ollama lane.
  - Reproduced with a 30-run hammer.
  - See [history/2026-07-01-mtp-graphs-crash.md](history/2026-07-01-mtp-graphs-crash.md).
- Ollama-era decision (retired): kept `GGML_CUDA_DISABLE_GRAPHS=1` serve-wide to dodge the MTP crash above.
  - See [history/2026-07-01-mtp-graphs-crash.md](history/2026-07-01-mtp-graphs-crash.md).
- Current stance (llama-server lane): CUDA graphs run ON fleet-wide, deliberately.
  - Validated in Phase 1 of specs/llamacpp-migration (2026-08-03).
  - The 12B MTP ctx ladder ran 36/36 clean generations through 200k ctx.
  - A 30-run graphs-on hammer on the router child came back 30/30 clean, zero crash lines.
  - The upstream MTP x graphs issue remains open but did not reproduce across the Phase 1 checks.
  - See [history/2026-08-03-llamacpp-p1-envelopes.md](history/2026-08-03-llamacpp-p1-envelopes.md).
  - Amended 2026-08-08: build 10326 failed re-cert (Qwen hammer 2/30).
  - It also crash-looped live at ~88k ctx on the Gemma 12B MTP lane.
  - Isolated 2026-08-09: MTP is the trigger (p = 0.002). CUDA graphs were tested and are not (p = 0.50).
  - **Resolved 2026-08-10: the cause was this box's +230 MHz GPU core clock offset, not llama.cpp.**
    - Decomposed over 4 arms, same build and byte-identical prompt: core offset on 11/11 crashed, off 0/15,
      Fisher p = 1.3e-07. Memory offset (+1500) and a 110% power limit have no effect (p = 1.0 each).
    - **Standing rule: keep the GPU core offset at or below +120 MHz.** Certified by a 25-trial clean soak;
      +135 and up are unproven or failed. Memory offset (+1500) and the 110% power limit need no change.
    - Mechanism is voltage-for-frequency, not peak clock: peak reads 2805 MHz in crashing and clean arms alike.
      The offsets were validated under full load, where the BIOS pins ~1100 mV; LLM decode runs far below that,
      in a band the overclock was never validated in.
    - Offset ladder and the per-rung rates: the 2026-08-10 diagnosis log, section 12.
    - Nothing was filed upstream; no config or version change was needed.
  - See [history/2026-08-08-llamacpp-recert-crash-diagnosis.md](history/2026-08-08-llamacpp-recert-crash-diagnosis.md).

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
