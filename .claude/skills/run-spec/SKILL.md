---
name: run-spec
description: Execute a specs/<feature>/ bundle end to end - branch, implement, verify, commit, PR. Use when the user asks to run, finish, implement, or resume work on a specs/<feature>/ directory, or names a feature whose spec lives there.
---

# Run a spec

1. Read every file in `specs/<feature>/`. Acceptance in `spec.md` defines done; `tasks.md` is the resume point. Files may be missing.
2. Branch off `main`, named for the spec directory.
3. Make a todo list from the unchecked `tasks.md` items (or from the plan).
4. Implement per the plan.
   - Use explicit values from `tasks.md` as written; verify each against its live source.
   - Follow AGENTS.md conventions for the file types touched.
5. Run the Acceptance checks as written.
   - Markdown lint: `~/.local/bin/rumdl check` (not on PATH).
   - Modelfile build: `scripts/ollama-create.sh <dir>` (no dry-run; a real build is the goal).
6. Check off `tasks.md` items as they complete, each with a one-line verification note.
7. Commit implementation and `tasks.md` together; `gh pr create`, flagging deviations from the spec.

Stop and ask only for irreversible decisions or contradictions between docs and live state; otherwise proceed on judgment.
