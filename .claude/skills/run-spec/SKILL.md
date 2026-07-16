---
name: run-spec
description: Execute a specs/<feature>/ bundle end to end - branch, implement, verify, commit, PR. Use when the user asks to run, finish, implement, or resume work on a specs/<feature>/ directory, or names a feature whose spec lives there.
---

# Run a spec

1. Read every file in `specs/<feature>/`. `spec.md`'s Acceptance section defines done; `tasks.md` holds the remaining work.
2. Branch off `main`, named for the spec directory.
3. Mirror the unchecked `tasks.md` items into the session todo list. Keep both updated as items complete, noting in `tasks.md` how each was verified.
4. Implement per the plan, following AGENTS.md conventions.
5. Run the Acceptance checks as written.
6. Commit implementation and `tasks.md` together; open a PR, flagging deviations from the spec.
