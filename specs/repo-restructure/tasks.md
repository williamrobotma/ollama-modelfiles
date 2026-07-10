# Tasks: repo restructure and documentation overhaul

Status legend: [ ] pending, [x] done. This file is the resume point for the restructure; update as phases land.

## Phase 0 - scout

- [ ] Reference map: every tracked file + who references it (Haiku)

## Phase 1 - skeleton + moves (pure git mv commit)

- [ ] modelfiles/<family>/<stem>/Modelfile for all 28
- [ ] benchmarks/{qwen,gemma,9b-coders}/{run.sh,matrix.tsv,runtime.tsv,prompts/}
- [ ] benchmarks/{common.sh,report.py,all.sh}
- [ ] scripts/{ollama-create.sh,repro-mtp-graphs.sh}
- [ ] docs/history/YYYY-MM-DD-<slug>.md x7 (dates from first commit)
- [ ] ARCHITECTURE.md -> docs/architecture.md

## Phase 2 - script surgery

- [ ] ollama-create.sh: dir-based names, alias resolution, no magic values
- [ ] benchmarks/common.sh + run.sh x3: new paths, named constants
- [ ] repro-mtp-graphs.sh: same treatment
- [ ] Dry-run parity verified for each (before/after diff)

## Phase 3 - documentation rewrite

- [ ] docs/parameters.md
- [ ] docs/architecture.md (path updates)
- [ ] docs/openwebui.md
- [ ] docs/benchmarking.md
- [ ] docs/history/index.md
- [ ] README.md rewrite (quickstart + catalog)
- [ ] AGENTS.md (tooling-agnostic)
- [ ] CLAUDE.md thinned to shim
- [ ] Opus coverage report: no load-bearing fact lost

## Phase 4 - specs for next work

- [ ] specs/llamacpp-serving/{spec,plan,tasks}.md (options analysis; user picks at review)
- [ ] specs/openwebui-wrapup/{spec,tasks}.md
- [ ] Retire .task_plan.md

## Phase 5 - lint + link + validate

- [ ] rumdl check clean
- [ ] ASCII sweep clean
- [ ] Link check clean
- [ ] ollama-create dry parity; benchmark dry parity; ollama list unchanged
- [ ] Commit series + push
