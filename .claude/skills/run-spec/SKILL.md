---
name: run-spec
description: Execute a specs/<feature>/ bundle end to end - fresh or partially done - branch, implement, verify, commit, PR. Use when the user asks to run, finish, implement, or resume work on a specs/<feature>/ directory, or names a feature that AGENTS.md's doc map places under specs/.
---

# Run a spec

Read the whole `specs/<feature>/` bundle first (not every bundle has all files): `spec.md`'s Acceptance section is the definition of done; `tasks.md`, if present, is the checkbox resume point.

1. **Branch** off `main`, named for the spec directory.
2. **Implement** per the plan; take `tasks.md`'s explicit values as written but verify them against their live source. Follow AGENTS.md's conventions for the file types touched.
3. **Verify** exactly what Acceptance lists - no assumed checklist. Repo facts: markdown lint is `~/.local/bin/rumdl check` (not on PATH); Modelfiles build via `scripts/ollama-create.sh <dir>` (no dry-run exists - a real build is the desired outcome).
4. **Checkbox `tasks.md` as items complete**, each with a one-line note of how it was verified.
5. **One commit** (implementation + `tasks.md` together), then `gh pr create`, flagging any deviation from the spec or judgment call made where it was silent.

Where the docs are silent, proceed on judgment; stop and ask only for irreversible decisions or when the documents contradict each other or live state.
