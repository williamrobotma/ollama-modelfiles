# GPU stability test

Package the ad-hoc crash matrix into one command that certifies this box's GPU is stable enough to serve.
Derives from specs/llamacpp-migration, which already names the crash matrix as its post-rebuild regression test.

## Goal

One command answers two questions: is the GPU stable at the current clocks, and does this build still serve cleanly.

## Decisions

- The suite is defined in `benchmarks/gpu-stability/`, so it inherits the dry-run-by-default CLI and the ports table.
  - It reports a pass/fail verdict rather than throughput numbers - the one way it differs from the other suites.
- The ~81k-token prompt is generated from a short seed to a target token count, never committed.
  - Record the sha256 of the generated body so comparability with the 2026-08-10 decomposition arms stays checkable.
- Default entry is `gemma4-12b-it-qat-mtp` at ~81k ctx: the most crash-sensitive configuration found.
- Verdict is `PASS N/N` or `FAIL at trial N`. One crash disqualifies; there is no partial pass.
- Soak mode repeats rounds until a crash or a stop file, reporting cumulative clean trials.

## Must carry (each earned by a failure on 2026-08-10)

- Live-probe 11433 and abort on a live router.
- Capture own PID at launch; never `pgrep`/`pkill`.
- Bracket every trial with `nvlddmkm` Id-13, `nvidia-smi`, and `free -m`.
  - The Id-13 delta is one-directional: nonzero confirms a hardware fault; zero proves nothing (insensitive,
    coarser than a trial).
- Unload between trials only when `.status.value` says so, logging the result - `.status` is an object, not a string.
- Freshness assertion: `cache_read_input_tokens = 0` or the trial is void and says so.
- Log the value a condition branches on, not just the branch taken.

## Done when

- `benchmarks/gpu-stability/run.sh --execute` returns `PASS 25/25` at the recorded safe core offset.
- Dry-run by default; `--list` and `--execute` behave as in the other suites.
- Its README states the standing core-offset rule and links the 2026-08-10 core-offset ladder.
- `docs/benchmarking.md` and the AGENTS.md doc map point at it.
