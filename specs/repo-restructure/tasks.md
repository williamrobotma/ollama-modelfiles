# Tasks: repo restructure and documentation overhaul

Status legend: [ ] pending, [x] done. This file is the resume point for the restructure; update as phases land.

## Phase 0 - scout

- [x] Reference map: every tracked file + who references it (Haiku) ->
      .migration-artifacts/reference_map.txt (392 lines)

## Phase 1 - skeleton + moves (pure git mv commit)

Commit 79d429e: 56 renames, all 100% similarity, zero content changes.

- [x] modelfiles/<family>/<stem>/Modelfile for all 28
- [x] benchmarks/{qwen,gemma,9b-coders}/{run.sh,matrix.tsv,runtime.tsv,prompts/}
- [x] benchmarks/{common.sh,report.py,all.sh}
- [x] scripts/{ollama-create.sh,repro-mtp-graphs.sh}
- [x] docs/history/YYYY-MM-DD-<slug>.md x7 (dates from first commit)
- [x] ARCHITECTURE.md -> docs/architecture.md

## Phase 2 - script surgery

Commit 9d13c59: 10 files; parity verified (dry-runs identical, real alias
rebuild left `ollama list` IDs unchanged); stale history path in runtime.tsv
x3 fixed. Leftover for Phase 3/5: pyproject.toml comment still says
"benchmark-report.py".

- [x] ollama-create.sh: dir-based names, alias resolution, no magic values
- [x] benchmarks/common.sh + run.sh x3: new paths, named constants
- [x] repro-mtp-graphs.sh: same treatment
- [x] Dry-run parity verified for each (before/after diff)

## Phase 3 - documentation rewrite

Also fixed the leftover pyproject.toml comment (benchmark-report.py ->
benchmarks/report.py) and retired .task_plan.md (below).

- [x] docs/parameters.md
- [x] docs/architecture.md (path updates)
- [x] docs/openwebui.md
- [x] docs/benchmarking.md
- [x] docs/history/index.md
- [x] README.md rewrite (quickstart + catalog)
- [x] AGENTS.md (tooling-agnostic)
- [x] CLAUDE.md thinned to shim
- [x] Opus coverage report: no load-bearing fact lost

## Phase 4 - specs for next work

- [x] specs/llamacpp-serving/{spec,plan,tasks}.md (options analysis; user picks at review)
- [x] specs/openwebui-wrapup/{spec,tasks}.md
- [x] Retire .task_plan.md (done in Phase 3; live content -> history log + docs topics)

## Phase 5 - lint + link + validate

- [ ] rumdl check clean
- [ ] ASCII sweep clean
- [ ] Link check clean
- [ ] ollama-create dry parity; benchmark dry parity; ollama list unchanged
- [ ] Commit series + push
