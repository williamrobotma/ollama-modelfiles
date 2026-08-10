# Tasks - gpu-stability-test

Resume point. Source harness to port: the 2026-08-10 session scratch (`stock-matrix.sh` + `soak-120.sh`), whose
behaviour is described in spec.md's "Must carry". The ladder that produced it: docs/history 2026-08-08 log, section 12.

- [ ] `benchmarks/gpu-stability/run.sh` - dry-run by default, `--list`, `--execute`, `TRIALS` and soak mode
- [ ] Prompt generator: seed -> target token count, prints the body sha256; no blob committed
- [ ] Per-trial capture: Id-13 bracket, `nvidia-smi`, `free -m`, plus the under-load clock sample
- [ ] Safety: live-probe 11433 and abort; own-PID capture; unload guarded on `.status.value`
- [ ] Freshness assertion and `INVALID-CACHED` / `CRASH` labelling distinct from each other
- [ ] Verdict line: `PASS N/N` or `FAIL at trial N`, plus cumulative clean trials in soak mode
- [ ] `benchmarks/gpu-stability/README.md` - usage, the standing core-offset rule, link to the ladder
- [ ] Pointers added: docs/benchmarking.md and the AGENTS.md doc map
- [ ] Acceptance run: `PASS 25/25` at the recorded safe offset, output pasted into the README

## Open

- Whether the generated prompt should reproduce the 2026-08-10 body byte-for-byte (it need not, if the sha is recorded).
