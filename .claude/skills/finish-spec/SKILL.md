---
name: finish-spec
description: Execute an in-flight specs/<feature>/ bundle end to end (branch, implement, verify, commit, PR). Use when the user asks to finish, implement, follow, or resume work in a specs/<feature>/ directory, or names a feature that AGENTS.md's doc map says lives under specs/.
---

# Finish a spec

Read the whole `specs/<feature>/` bundle in full - the live files, not memory of a prior session - before touching anything. Not every bundle has all three files; `spec.md`'s Acceptance section is the definition of done, `tasks.md` is the checkbox resume point.

1. **Branch** off `main`, named for the spec directory. `git status` first; stash or ask if unrelated work is sitting there.
2. **Implement** per the plan, using `tasks.md`'s explicit values as written - but verify each against the live source it was derived from. Follow AGENTS.md's conventions for whatever file type the spec touches.
3. **Verify** exactly what the Acceptance section lists for *this* spec - don't assume a fixed checklist. Two repo facts: markdown lint is `~/.local/bin/rumdl check` (not on PATH), and Modelfiles build via `scripts/ollama-create.sh <dir>` (AGENTS.md "Build commands"; no dry-run exists - a real build is the desired outcome under the keep-set policy).
4. **Checkbox `tasks.md` as each item completes** - it's the resume point, keep it truthful throughout - with a one-line note of how the item was verified.
5. **Commit and PR**: one commit (implementation + `tasks.md` together), then `gh pr create`; flag in the PR body any deviation from the spec's literal values or judgment call made where it was silent.

Where the docs are silent, use ordinary judgment and proceed. Stop and ask only when a decision is irreversible, or the documents contradict each other or what you find live.
