# Specs

Spec-driven work bundles, executed end to end by the run-spec skill. Each `<feature>/` directory holds:

- `spec.md` - its Acceptance section defines done.
- `tasks.md` - the resume point.
- `plan.md` - present when the work needs one.
- `README.md` - the whole bundle when nothing is scoped yet, saying it is unplanned and what is known.
  - Write spec.md when planning actually runs, and tasks.md only once there is a spec to execute.
  - The three files above are structure standing in for work nobody has scoped until then.

The work order lives in `ROADMAP.md`, next to this file.

## Status is the folder

- `specs/<feature>/` - in flight.
- `specs/done/<feature>/` - Acceptance met; kept for the record. run-spec moves it here on completion.
- No status column, so status can't drift out of sync.

## Reference convention

- Refer to a spec by name; the name is its directory (`specs/<name>/`, or `specs/done/<name>/` once done).
- Inside a bundle, use plain-text or backtick paths, not `](relative)` links.
  - A bundle can then move to `done/` without rewriting links.

## Scaffold shape

Short `##` sections (goal / decisions / done-when), one idea per bullet, ~15-30 lines total.
