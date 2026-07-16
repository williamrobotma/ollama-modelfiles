---
name: finish-spec
description: Execute an in-flight specs/<feature>/ bundle in this repo end to end - branch, implement per plan.md, verify against spec.md's Acceptance section, checkbox tasks.md, commit, and open a PR. Use whenever the user asks to finish, implement, follow, or resume work in a specs/<feature>/ directory (e.g. "finish specs/gemma4-mtp", "follow the plan in specs/x", "pick up where tasks.md left off"), or names a feature that AGENTS.md's doc map says lives under specs/.
---

# Finish a spec

`specs/<feature>/` is this repo's resume-point convention (see AGENTS.md's doc
map): `spec.md` is why/what/constraints/acceptance, `plan.md` is the approach
and ordered steps, `tasks.md` is the checkbox-level resume point. This skill
runs that bundle to completion the same way a human would: read everything
before touching anything, verify against what the spec actually says (not a
fixed checklist), and leave `tasks.md` accurate at every step so a future
session (or a fresh Claude instance) can resume cold from it alone.

## Sequence

1. **Branch.** Don't implement on `main` - `git checkout -b` a feature branch
   named for the spec directory. Check `git status` first; if there's
   unrelated uncommitted work sitting there, stash or ask before switching.

2. **Read all three files in full** before writing anything - `spec.md`,
   `plan.md`, `tasks.md`. `spec.md`'s Acceptance section is the actual
   definition of done for this task; `plan.md` is the approach; `tasks.md` is
   the current progress. Don't start from memory or a summary of a prior
   session - read the live files.

3. **Implement per `plan.md`'s steps**, using `tasks.md`'s per-task detail
   (exact paths, parameter values, FROM/DRAFT targets) as the literal spec
   for each file. When `tasks.md` gives an explicit value, use it as written
   rather than re-deriving it - but verify it against the live parent file
   it's supposedly copied from (doc-state can drift from live-state). If this
   repo's layered-Modelfile pattern applies (see AGENTS.md's "Modelfile
   layering and naming"), prefer `FROM <local-model-name>` over manually
   retyping the parent's parameter block - inheritance beats copy-paste.

4. **Verify against `spec.md`'s Acceptance section literally** - read what it
   actually lists for *this* spec, don't assume it's always the same two
   checks. The two checks that recur across specs in this repo so far:
   - `~/.local/bin/rumdl check` (the binary isn't on PATH by default - check
     `~/.local/bin` and `pipx list` before assuming it's missing).
   - `ollama create <name> -f <Modelfile>` as the Modelfile parse/build
     check. There's no `--dry-run` flag - parsing a Modelfile *is* building
     it. That's not a workaround: this repo's keep-set policy (AGENTS.md)
     already expects every repo Modelfile to correspond to a real installed
     model, so building for real is the correct outcome, not a side effect
     to avoid or clean up afterward.
   If a spec's Acceptance section lists something else (a different command,
   a doc-link check, a benchmark run), verify that instead.

5. **Checkbox `tasks.md` as each item completes**, not only at the end - it's
   the resume point, so keep it truthful throughout in case the session ends
   partway through. Add a short note under a task if verification surfaced
   something worth recording (e.g. "verified via X: <finding>").

6. **Commit once verification passes.** One commit for the spec's changes
   (implementation + `tasks.md` updates together), following this repo's
   normal commit-message conventions (see the top-level git guidance already
   in scope for this session/CLAUDE.md - imperative summary, why over what).

7. **Review the diff and open a PR** (`gh pr create`) once the commit is in
   place. Use `git diff main...HEAD` (or the branch's actual base) to write
   the PR description; don't just restate the commit message verbatim - call
   out anything a reviewer would want flagged (e.g. a deviation from
   `tasks.md`'s literal values, or a judgment call made where the spec was
   silent).

## Judgment calls

`spec.md`/`plan.md`/`tasks.md` won't cover everything. Where they're
genuinely silent, use ordinary judgment and proceed - this skill does not by
default stop to interview the user on every design decision that surfaces.
(If a specific session asks for that behavior, it's a one-off instruction for
that session, not a standing property of this skill.) Do stop and ask when a
decision is irreversible, contradicts something the spec/plan/tasks actually
says, or the three documents disagree with each other - that's a real
ambiguity, not a style choice.

## Worked example

`specs/gemma4-mtp/` (2026-07): `spec.md` asked for two Modelfiles pairing
stock QAT gemma4 models with their Unsloth MTP drafters; `tasks.md` gave
literal FROM/DRAFT paths and a parameter-inheritance list. The build used
`FROM gemma4-12b-it-qat` / `FROM gemma4-31b-it-qat` (the layered pattern from
the existing `26b-a4b-it-qat-mtp` Modelfile) rather than retyping the seven
inherited parameters, then confirmed the inheritance actually took with
`ollama show <name> --parameters` before checking the task off. Verification
was `rumdl check` (clean) + `ollama create` (both parsed and built). Both
tasks got checked off with a one-line note on how inheritance was verified,
then one commit, then a PR.
