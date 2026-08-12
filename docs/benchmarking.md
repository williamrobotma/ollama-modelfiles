# Benchmarking

Three dry-run-by-default Ollama benchmark suites live under `benchmarks/`.
They are frozen legacy harnesses targeting the retired Ollama stack, kept on disk for reference.
llamacpp-parity (below) stays current: it benches stock llama-server, the live serving stack.
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
`matrix.tsv` lists the ids to compare.
`runtime.tsv` defines the runtime arms to compare, graphs-off vs graphs-on (its column for an arm is `profile`).

**llamacpp-parity** is a self-contained cross-engine suite (it does not source `common.sh`):

- It benches the same GGUF on an isolated Ollama serve (graphs-off arm) against stock llama-server,
  now the live serving stack.
- `LLAMA_SERVER_BIN` selects the binary (default `~/Developer/llama.cpp/build/bin/llama-server`).
- Decode tok/s is read per engine: `ollama run --verbose` eval rate (Ollama), response `timings` (llama-server).
- `matrix.tsv` rows carry the GGUF snapshot path, ctx, sampling flags (per docs/parameters.md), and spec-decode flags.
- It has its own `report.py` (mean/stdev plus llamacpp-vs-ollama and mtp-vs-plain ratios).
- Same dry-run-by-default CLI as the other suites.
- Built for the specs/done/llamacpp-serving option-C eval: [history/2026-07-17-llamacpp-eval.md](history/2026-07-17-llamacpp-eval.md).

## Running

Everything is dry-run by default - nothing runs without `--execute`:

```bash
benchmarks/<suite>/run.sh            # print the plan and exact commands
benchmarks/<suite>/run.sh --list     # configured models and prompts
benchmarks/<suite>/run.sh --execute  # run the full matrix.tsv
benchmarks/all.sh                    # qwen, gemma, 9b-coders sequentially
```

Executed runs write raw logs and timing under `benchmark-results/<timestamp>/` (gitignored).
The three Ollama suites are frozen against the retired Ollama stack.
Some of their `matrix.tsv` rows reference models deleted at the 2026-07-27 fleet reduction and no longer resolve.
Each suite's `matrix.tsv` is authoritative.

## Isolated serves and ports

Runtime A/B compares CUDA graphs off vs on via temporary isolated `ollama serve` instances on alternate ports.
It never mutates systemd mid-run.

Port assignments, all on 127.0.0.1:

- `11434` - the Ollama systemd service's port, untouched by the harness.
  - Ollama is retired as the serving stack; stop/purge is tracked in specs/llamacpp-migration Phase 4.
- `11435` - graphs-off arm (`GGML_CUDA_DISABLE_GRAPHS=1`), the prod target under Ollama serving.
  - Also the llamacpp-parity suite's Ollama side.
- `11436` - graphs-on arm (`GGML_CUDA_DISABLE_GRAPHS` unset).
- `11437` - `scripts/repro-mtp-graphs.sh` only.
- `11438` - llamacpp-parity suite's llama-server side.

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
Why this is a rule: the 2026-08-09 crash trials recorded only whole-GPU totals after load, so no crash rate in
`history/2026-08-08-llamacpp-recert-crash-diagnosis.md` is controlled for free VRAM or host RAM.

Run the commands below at three points in every trial:

1. Before load.
2. After load.
3. At crash or completion.

```bash
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu,temperature.gpu,clocks_throttle_reasons.active \
    --format=csv,noheader    # GPU; the guest cannot see Windows-side use
free -m | sed -n '2p;3p'     # host RAM and swap (WSL2 shares them)

# GPU hardware faults (Windows-side): bracket every trial; record the delta.
/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command \
    "(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='nvlddmkm';Id=13} -EA 0).Count"
```

Before the trial starts:

- Pin `-ngl` explicitly. Unset means layers fit to whatever is free at load time, so the split silently
  depends on host conditions and two "identical" trials are not identical.
- Note whether the host was quiescent. A steady-state baseline here is ~1.5 GB GPU; transient host spikes to ~4.7 GB
  have been observed, which is more than the headroom a 12B at large ctx leaves (~800-1000 MiB).

Reading the numbers:

- The Id-13 delta is one-directional: a nonzero delta confirms a hardware fault, a zero delta proves nothing.
  - The counter is specific but insensitive, and coarser than a trial. Never read zero as "software bug".
  - Nearly all recorded events sat inside GPU-LLM sessions (766 of the 780 recorded in the four-day window);
    the one verified no-LLM burst rules out llama.cpp specifically, not GPU compute.
  - `dmesg` cannot see these: the kernel-mode driver is Windows-side, so WSL only shows llama-server's own SIGABRT.
  - `.Message` renders empty under WSL, so a message-text filter silently matches nothing. Read the event XML.
  - Location breakdown one-liner and the full finding:
    [history/2026-08-08-llamacpp-recert-crash-diagnosis.md](history/2026-08-08-llamacpp-recert-crash-diagnosis.md).
- Whether CUDA graphs took effect is visible only in the `CUDA graph warmup ...` debug lines.
  - `graphs reused` in the timings is llama's own graph-reuse counter (`llama-context.cpp:4139`), unrelated to
    CUDA graphs.
- Swap pressure matters as much as VRAM: partial-offload models read weights through host RAM, so a host under
  memory pressure changes timings and can starve a run that looked fine on VRAM alone.

## Report tool

```bash
python3 benchmarks/report.py benchmark-results/<timestamp> ...
```

Stdlib only (`pyproject.toml` pins `requires-python >= 3.10`).
Produces per-prompt throughput mean/stdev (graphs-off vs graphs-on) plus coarse output-sanity flags.

## Findings

Distilled from the evidence logs; follow the links for the primary-source detail.

### MTP speedups (decode throughput)

- Qwen 3.5 9B self-draft MTP: ~1.65x; 98-121 tok/s on the router child (Phase 1 hammer test, 2026-08-03).
  - See [history/2026-06-23-qwen3.5-9b-mtp-bench.md](history/2026-06-23-qwen3.5-9b-mtp-bench.md).
- Gemma 4 MTP via Ollama `DRAFT`: 1.67x on the 12B pair, 1.54x on the 26B pair.
  - See [history/2026-07-10-migration-local-ggufs.md](history/2026-07-10-migration-local-ggufs.md).

### MTP crash investigation (resolved: GPU core overclock)

- **Resolved 2026-08-10: the large-ctx MTP crashes were this box's GPU core clock offset, not llama.cpp.**
  - **Standing rule: keep the GPU core offset at or below +120 MHz**, certified by a 25-trial clean soak.
    +135 and up are unproven or failed.
  - The memory offset and the power limit are not implicated.
  - Nothing was filed upstream, and no configuration or build change was needed.
  - The mechanism is voltage-for-frequency, not peak clock: the overclock was validated under full load
    (~1100 mV), and LLM decode runs below that band, where it was never validated.
- Current stance: CUDA graphs are on fleet-wide, deliberately.
  - Validated in Phase 1.
  - Graphs were disproven as the trigger during the investigation.
  - The Ollama-era serve kept graphs off to avoid what was then read as an MTP x graphs crash
    ([history/2026-07-01-mtp-graphs-crash.md](history/2026-07-01-mtp-graphs-crash.md)).
- Full arc - re-cert failure, live crash-loop, isolation batch, decomposition, offset ladder:
  [history/2026-08-08-llamacpp-recert-crash-diagnosis.md](history/2026-08-08-llamacpp-recert-crash-diagnosis.md)
  sections 1-12, plus [history/2026-08-09-mtp-crash-report-dossier.md](history/2026-08-09-mtp-crash-report-dossier.md).

### llama.cpp parity eval (2026-07-17)

- Stock llama-server build b9860 beat the graphs-off Ollama prod target on every measured cell.
  - qwen9b +6-14%, gemma12b +16%, qwen9b-mtp +4-13%; stock-only gemma12b MTP ran 1.83x.
  - See [history/2026-07-17-llamacpp-eval.md](history/2026-07-17-llamacpp-eval.md).
- On stock, the Gemma MTP drafter's stability is set by configuration, not by the build.
  - It is stable only with CUDA graphs on at moderate ctx (7/7 generations at 16k).
  - Graphs-off fails the drafter load at 200k with the #24795 signature.
  - Graphs-off also crashes in-flight at 16k (misaligned address).
  - Ollama's `DRAFT` path (graphs-off env) crashed 9/10 requests on-box.
  - Stock was the only working Gemma MTP path.
- Verdict recorded in the eval log: full migration (B) indicated.
  - Gemma MTP processes belong on stock with graphs on and a capped ctx.
  - The crash matrix is the post-rebuild regression test.

### Graphs-off throughput cost

- Turning graphs off cost Gemma ~15-17% and non-MTP Qwen ~20-26% decode throughput on the Ollama stack.
  - Accepted then as the price of avoiding the crash.
  - See [history/2026-06-21-runtime-ab.md](history/2026-06-21-runtime-ab.md).

### Caveat on older numbers

- 2026-07: the 9b-coding model moved from Ollama-official Q4_K_M back to Unsloth UD-Q4_K_XL.
  - Graphs-off numbers measured before that change predate the quant and are not comparable.
  - See [history/2026-06-30-9b-coders-vram.md](history/2026-06-30-9b-coders-vram.md).
