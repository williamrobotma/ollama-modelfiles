# Plan: repo restructure and documentation overhaul

Orchestration: Opus for judgment (content decisions, distillation), Sonnet for mechanical work (moves, path rewrites, lint fixes), Haiku as scout (inventories, link checks). Recursive where subagents spawn their own helpers.

## Phase 0 - scout (Haiku)

- Inventory every tracked file with its referencing files (who mentions whom): scripts referencing TSVs/prompts, docs referencing filenames, CLAUDE.md sections and their consumers.
- Output: machine-readable reference map for the movers.

## Phase 1 - skeleton + moves (Sonnet, mechanical)

- `git mv` everything per spec layout. Modelfiles: `Modelfile.gemma4-12b-it-qat` -> `modelfiles/gemma4/12b-it-qat/Modelfile` (split on first `-` after family match against {gemma4, qwen3.5, qwen3.6, qwopus3.5}).
- Session logs -> `docs/history/YYYY-MM-DD-<slug>.md` using first-commit dates:
  - 2026-06-19 diffusiongemma, 2026-06-21 runtime-ab, 2026-06-23 9b-coders-vram, 2026-06-23 qwen3.5-9b-mtp-bench (00:39 vs 19:21 uncensored-models), 2026-07-01 mtp-graphs-crash, 2026-07-10 migration-local-ggufs.
- Benchmarks: `benchmark-qwen.*` -> `benchmarks/qwen/{run.sh,matrix.tsv,runtime.tsv,prompts/*.txt}`; `benchmark-common.sh` -> `benchmarks/common.sh`; `benchmark-report.py` -> `benchmarks/report.py`; `benchmark-all.sh` -> `benchmarks/all.sh`.
- One commit: pure renames (no content edits) so git tracks history across moves.

## Phase 2 - script surgery (Sonnet, verified by dry-runs)

- `scripts/ollama-create.sh`: iterate `modelfiles/*/*/Modelfile`, model name = `<family>-<stem>`; keep alias dependency resolution (FROM naming a sibling model name).
- `benchmarks/common.sh` + suite `run.sh`s: new relative paths; hoist magic values to named top-of-file variables (ports, models dir, HF cache root, timeouts, rep counts) each with a one-line provenance comment.
- `repro-mtp-graphs.sh` -> `scripts/`, same treatment.
- Verify each: dry-run before/after diff; `ollama-create.sh` no-arg dry (echo mode or single cheap alias rebuild).

## Phase 3 - documentation rewrite (Opus judgment, Sonnet drafting)

- `docs/parameters.md`: parameter reference tables + verification sources (from CLAUDE.md).
- `docs/architecture.md`: ARCHITECTURE.md content, paths updated.
- `docs/openwebui.md`: setup, launcher, config-in-DB semantics, Brave, endpoint choice rationale.
- `docs/benchmarking.md`: how suites work, ports, isolated serve, prior findings distilled with links into history/.
- `docs/history/index.md`: dated index with one-line abstracts.
- `README.md`: rewrite - what/why, quickstart (clone -> hf download -> create -> run), model catalog table generated from the tree, pointers.
- `AGENTS.md`: tooling-agnostic conventions + commands (from CLAUDE.md + memory-worthy rules: GGUF sourcing, mmproj/vision, MTP mechanisms, template gate, keep-set, disk budget, FA+q8_0 pairing).
- `CLAUDE.md`: thin - "read AGENTS.md" + Claude-Code-specific notes only.
- Distill-check (Opus): every load-bearing fact in old CLAUDE.md/session logs is either in a docs/ topic file or explicitly superseded; produce a coverage report before deleting anything from CLAUDE.md.

## Phase 4 - specs for next work (Opus)

- `specs/llamacpp-serving/spec.md`: options analysis (hybrid vs full migration vs eval-first) with tradeoffs, recommendation, acceptance criteria; plan.md + tasks.md skeletons. User decides the option at spec review.
- `specs/openwebui-wrapup/`: small spec - in-browser verification pass (chat, web search, native tool calling per model), template gate on queen-27b + 31b-heretic, model visibility defaults; tasks checklist.
- Retire `.task_plan.md` (content already distilled into history + specs).

## Phase 5 - lint + link + validate (Haiku scout, Sonnet fix)

- `rumdl check` -> fix all; ASCII sweep (em-dashes, arrows, box chars) per writing rules.
- Link check: every relative link in md files resolves; every path mentioned in docs exists.
- Acceptance run: spec.md checklist, including ollama-create dry-run parity and benchmark dry-run parity.
- Final commit series + push.

## Risks / notes

- Family split ambiguity (qwen3.5 vs qwen3.6 prefixes share "qwen3."): match longest family first.
- `benchmark-results/` stays gitignored; nothing moves it.
- `.migration-artifacts/` stays gitignored at root (scripts inside reference repo-root-relative paths - update if touched).
- Ollama model names must NOT change (Open WebUI DB + claude-local reference them).
