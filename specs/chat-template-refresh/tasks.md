# Tasks: chat-template-refresh

Status legend: `[ ]` pending, `[x]` done. Research is done (spec.md); these are the execution steps.

- [ ] **Gemma re-pull.** Confirm the `26B-A4B`/`31B` 2026-07-17 commits carry the template update (HF commit metadata - before any download; 12B confirmed), then `hf download` the 3 QAT repos at those snapshots and edit each `FROM` (12B/26B-A4B/31B). -> verify: `FROM` points at the new snapshot dir; MTP drafter load check passes on stock (graphs-on).
- [ ] **Qwen OpenAI-lane fix.** Front each guarded model facing `/v1/chat/completions` clients with froggeric (set + validation recipe: spec "Actions (lane-aware)"). -> verify: `test_v21.py` + multi-system + tool-loop smoke pass once on the target build; each model then returns 200 on one multi-system request.
- [ ] **Gate rewrite + doc corrections.** Rewrite the AGENTS.md chat-template-gate section (currently :52/:54) in one pass: new vetting procedure (spec "Vetting gate") + the Corrections-table fixes; reference it from `specs/stack-upkeep`. Append a dated correction note to `llamacpp-eval` s5 (history is immutable - no inline edits). -> verify: gate section matches the spec's procedure + Corrections table; s5 note present.
- [ ] **(Optional) Qwen quality.** Evaluate froggeric on the Anthropic lane for Qwen coders not already fronted by it via the OpenAI-lane fix (i.e. the `merged_system` set). -> verify: A/B a tool-loop session vs the stock template; adopt only if it helps.
