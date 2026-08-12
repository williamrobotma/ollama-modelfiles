# Benchmarking

The benchmark suites were removed at the 2026-08-12 repo purge: all of them needed the retired Ollama stack to run.
Two things stay live here: the resource-capture procedure (mandatory for GPU runs) and the distilled findings.

## Retired suites

Git history preserves them; `benchmark-results/` (gitignored) keeps their raw outputs.

- `benchmarks/{qwen,gemma,9b-coders}` - Ollama runtime A/B: CUDA graphs off vs on, shared `common.sh` harness.
- `benchmarks/llamacpp-parity` - the same GGUF on Ollama vs stock llama-server (the 2026-07-17 eval below).
- `benchmarks/report.py` + `all.sh`, `scripts/repro-mtp-graphs.sh` - report tool, sequential runner, crash repro.
- All were dry-run by default (`--execute` to run) and shared ports 11435-11438, now free.

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
