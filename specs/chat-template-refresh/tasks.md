# Tasks: chat-template-refresh

Status legend: `[ ]` pending, `[x]` done. Research is done (spec.md); these are the execution steps. Tasks touching `AGENTS.md`'s gate claims, `docs/history/2026-07-17-llamacpp-eval.md`, or `specs/stack-upkeep` assume PR #9 has merged (spec.md "Depends on").

- [x] Research pass: live-HF templates/commits + read-only on-box gate scan; findings in spec.md. Done 2026-07-17.
- [ ] **Gemma re-pull.** Confirm each QAT repo's 2026-07-17 HF commit is the template update *before* downloading, then `hf download` + edit each `FROM` (12B/26B-A4B/31B). -> verify: `FROM` points at the confirmed snapshot; MTP drafter load check passes.
- [ ] **Qwen OpenAI-lane rule.** Apply spec.md's family-wide rule to the guarded models (fleet table): serve them under `--jinja --chat-template-file froggeric`. Validate froggeric once per (template, build) - `test_v21.py` + a multi-system + tool-loop smoke - then per-model is launch + one smoke. -> verify: a multi-system `/v1/chat/completions` returns 200 (not 400) for each.
- [ ] **Vetting gate.** Replace `ollama show --template` with the gate in spec.md ("Vetting gate"): guard `grep` + OpenAI-lane smoke per GGUF, Anthropic smoke once per build. -> verify: procedure referenced from `specs/stack-upkeep`.
- [ ] **Doc fixes (post-#9).** Rewrite the AGENTS.md gate section (:48-54) per spec.md's Corrections table (also the CLAUDE.md claude-local vetting line), and append a dated correction note to `2026-07-17-llamacpp-eval.md` s4 narrowing the guard-scan scope. -> verify: edits match the Corrections table; the eval log's original text stays intact (note appended, not inline-edited).
- [ ] **(Optional) Qwen quality A/B.** Only for the `merged_system` (non-guarded) models - the guarded ones already run froggeric on both lanes. A/B froggeric vs `merged_system` on a tool-loop session; adopt if it helps. -> verify: decision recorded.
