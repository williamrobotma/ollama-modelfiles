# Tasks: Open WebUI wrap-up

Status legend: [ ] pending, [x] done. Resume point for this side task.

## In-browser checks

- [x] Chat and search-enabled chats - covered by the 2026-08-07 cutover validation (migration P3 log).
- [ ] Native tool calling with `qwen3.6-27b-coding`.
- [ ] Vision: image drop on `gemma4-12b-it-qat`.
- [ ] Any failure written up in docs/openwebui.md or a history log.

## Chat-template gate

- [x] `qwen3.5-queen-27b-coding`: probed 2026-07-23 - guarded; froggeric-validated.
- [x] `gemma4-31b-it-heretic` template extracted 2026-08-03: no guard string.
  - 26B sibling live-probed clean, via the upstream compat rewrite (see spec.md's caveat).
- [ ] Residue: one live multi-system probe against the 31B entry; verdict recorded in docs/openwebui.md.

## Model visibility

- [ ] Decide the user-facing default model set.
- [ ] Set it in Admin Panel > Settings > Models; record the intended set in docs/openwebui.md.
