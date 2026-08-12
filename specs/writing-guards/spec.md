# Writing guards

SCAFFOLD - plan in a fresh session.

Two writing checks the linter cannot do today, held for later (user, 2026-08-12: "hold off for now, but
bare scaffold a spec").
The work happens in the synced `~/.claude` folder (its hooks and skills), not in this repo.
Pushing `~/.claude` goes through its usual review gate.

## Goal

Catch the two writing mistakes that keep slipping through:

1. Comments wider than 80 columns in shell, Python, INI, and TOML files.
2. Markdown lines wrapped mid-sentence instead of shortened.

For what a script cannot judge - overall clarity - add a review pass on PRs that change a lot of doc text.

## Decide at planning

- Where the checks live: extend `~/.claude/hooks/rumdl-md-check.py`, or a new hook beside it.
- How to spot a mid-sentence wrap.
  - Candidate rule: a line with no ending punctuation whose next line starts lowercase.
  - Measure its false positives first; that measurement decides warn vs block.
- The reviewer: likely a `~/.claude` skill that reads a PR and reports, never edits.
  - Its checklist: language a newcomer can follow, lists instead of prose, pointers that say what they
    point to, corrections rewritten into the text rather than stacked on top.
  - How many changed doc lines should trigger it.

## Done when

- Both checks flag a deliberately bad test file and stay quiet on this repo as it is today.
- The reviewer skill exists and has run on one real PR.
