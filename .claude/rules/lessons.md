# Lessons

## Docs and scaffolds

- Spec scaffolds and similar docs: minimal AND structured - short `##` sections (goal / decisions / done-when), one idea per bullet, ~15-30 lines total; never appendix-style citation dumps, never structure-free paragraphs. Why: a 62-line scaffold was rejected as bloated ("I ain't reading all that"), and the slimmed redo was rejected again for dropping md structure ("minimal does not mean don't bother formatting"). Both fail the same reader; density and structure are one requirement, not a tradeoff.

- Name an enumerable set; never write its size in prose or comments ("the 26B entries", not "both"). (2026-08-11)
  - The one sanctioned count is a file's own header total (models.ini:1), checked against the file at review.
  - Why: a written count is a cached computation the next fleet edit silently invalidates; all six PR #15 review
    sweeps caught a count-drift bug (fleet 17+6 -> 18+1 over four moves, alias 9-vs-8, client-id 12-vs-13,
    "both" vs three 26B entries) - the class regenerated after every instance-level fix.

## Router operations

- Live-probe 11433 before any router start, stop, or parse-check: `curl -s 127.0.0.1:11433/v1/models`, every time. (2026-08-08)
  - Something answers -> a router you did not start is up: do not launch over it, do not pkill; report and ask.
  - Trust a check's readout only after confirming your own instance bound (its log says so), not just that the port answered.
  - Why: a parse-check trusted an hours-stale "router down" note; the new instance failed to bind, the curl silently
    read the user's live router (old preset), and the cleanup pkill killed it mid-use.
- Kill only a PID you captured from your own launch (`nohup ... & MYPID=$!`), never one found by pgrep/pkill. (2026-08-09)
  - A probe that refuses to launch must abort the whole script - check the refusal before curl or kill, not after.
  - Why: the launcher's preflight correctly refused over a live router, the script ignored the refusal, curled that
    router (stale ids surfaced it), then killed it by pgrep first-match. Same loss as before, new path in.
