# Writing guards (global ~/.claude scope)

SCAFFOLD - plan in a fresh session.

Held 2026-08-12 (PR #15 mitigation items 3-4, user: "hold off for now, but bare scaffold a spec").
Scope: the synced global `~/.claude` folder (hooks, skills) - not this repo's files; sync-push gates the publish.

## Goal

Mechanize the two writing mistakes no linter sees, and gate doc-heavy PRs with fresh eyes.

## Decisions for planning

- Hook extension (`~/.claude/hooks/rumdl-md-check.py` or a sibling):
  - Flag comment lines over 80 cols in `.sh` / `.py` / `.ini` / `.toml`.
  - Flag probable mid-idea wraps in md (a line without sentence-final punctuation, next line starting lowercase).
  - Measure the false-positive rate first; it decides warn vs block.
- Standing style reviewer: a report-only pass on doc-heavy PRs.
  - Rubric = cold-reader clarity, lists over prose, hints at pointers, no sediment.
  - Probably a `~/.claude` skill; the doc-line trigger threshold is a planning decision.

## Done when

- Both checks fire on a synthetic bad file and stay quiet on this repo at head.
- The reviewer skill exists with its rubric and has run on one PR end to end.
