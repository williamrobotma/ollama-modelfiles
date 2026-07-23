# Repo restructure and documentation overhaul

## Why

The repo grew organically (flat root, 28 `Modelfile.*` files, 20+ benchmark files, 7 session logs, a monolithic CLAUDE.md). A first-time cloner cannot browse it with low friction, agent instructions are Claude-specific, and the layout does not anticipate the next feature (llama.cpp serving alongside Ollama).

## What (requirements)

1. **Directory structure** (interview decision 2026-07-10):

   ```text
   .
   |- README.md            entry point: what/why, quickstart, catalog pointer
   |- AGENTS.md            canonical, tooling-agnostic agent instructions
   |- CLAUDE.md            thin shim: references AGENTS.md + Claude-specific notes only
   |- modelfiles/<family>/<stem>/Modelfile
   |                       model name = "<family>-<stem>" (computed by build script)
   |                       families: gemma4, qwen3.5, qwen3.6, qwopus3.5
   |- benchmarks/
   |  |- qwen/ gemma/ 9b-coders/   suite dirs: run.sh + matrix.tsv + runtime.tsv + prompts/
   |  |- common.sh  report.py  all.sh
   |- scripts/
   |  |- ollama-create.sh  repro-mtp-graphs.sh
   |- docs/
   |  |- architecture.md  parameters.md  openwebui.md  benchmarking.md
   |  |- history/          dated, immutable session logs + index.md
   |- specs/<feature>/spec.md + plan.md + tasks.md
   ```

2. **Naming**: kebab-case filenames everywhere; session logs renamed to `YYYY-MM-DD-<slug>.md` by first-commit date; no `Modelfile.` prefix files remain.
3. **Entrypoints**: clean break - no root shims; README and AGENTS.md document `scripts/` and `benchmarks/` paths. All internal path references updated.
4. **Docs content** (distill + archive): still-load-bearing facts from session logs move into `docs/` topic files; originals move verbatim to `docs/history/` (immutable, linked from an index). No information is dropped - only relocated or distilled.
5. **AGENTS.md**: tooling-agnostic (any coding agent can follow it); contains conventions (GGUF sourcing, Modelfile layering, parameter verification sources, Claude-Code template gate, keep-set policy, disk budget rule), build/validate commands, and pointers into docs/. CLAUDE.md keeps only: reference to AGENTS.md plus anything genuinely Claude-Code-specific.
6. **Markdown style**: rumdl clean (`rumdl check` passes; MD013 disabled per user config); soft-wrap, one logical line per bullet; ASCII only; simple visual structure editable on an ANSI keyboard (no box-drawing characters, no HTML).
7. **Scripts**: paths follow the new tree; magic numbers/values hoisted to named variables with a comment stating provenance (ports 11435/11436, models dir, HF cache root, rep counts, num_predict caps); `ollama-create.sh` computes model names from `<family>/<stem>` dirs and still resolves alias dependencies.
8. **Spec-driven development**: this spec + `specs/llamacpp-serving/` (next task, option analysis included - user chose "you propose it") + `specs/openwebui-wrapup/` (side task). `.task_plan.md` retires; its resume-point role moves to the active feature's `tasks.md`.

## Acceptance

- `git ls-files` shows the tree above; no orphaned references: `grep -rn "Modelfile\.\|benchmark-.*\.tsv\|session_summary" --include="*.sh" --include="*.py" --include="*.md"` finds only history/ and intentional mentions.
- `scripts/ollama-create.sh modelfiles/gemma4/12b-it-qat` (and no-arg all-mode) builds models with unchanged names; `ollama list` set is unchanged before/after.
- `benchmarks/*/run.sh` dry-run output identical in substance to pre-move output.
- `rumdl check .` exits 0.
- A first-time reader can go README -> catalog -> docs topic -> spec without dead links (verified by a link-check pass).
- Existing Ollama models keep working untouched (restructure changes files, not the model store).
