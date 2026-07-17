# Tasks: chat-template-refresh

Status legend: `[ ]` pending, `[x]` done. Research is done (spec.md); these are the execution steps.

- [x] Research pass: live-HF templates/commits + read-only on-box gate scan; findings in spec.md. Done 2026-07-17.
- [ ] **Gemma re-pull.** `hf download` the 3 QAT repos at their 2026-07-17 snapshots; edit each `FROM` (12B/26B-A4B/31B). -> verify: `FROM` points at the new snapshot dir; `26B-A4B`/`31B` commit == template update; MTP drafter load check passes on stock (graphs-on).
- [ ] **Qwen OpenAI-lane fix.** For guarded models (unsloth Qwen3.5-9B non-MTP, OBLITERATUS-27B, Queen-27B) that face `/v1/chat/completions` clients: launch with `--jinja --chat-template-file froggeric`. -> verify: `test_v21.py` passes on the target build; a multi-system + tool-loop smoke returns 200 (not 400) on that build.
- [ ] **Vetting gate swap.** Replace `ollama show --template` with GGUF `chat_template` dump + dual-path (`/v1/messages` and `/v1/chat/completions`) multi-system smoke against a resident model. -> verify: procedure written and referenced from `specs/stack-upkeep`.
- [ ] **Doc corrections.** Fix AGENTS.md:52 (guard is official default; Ollama does not execute GGUF Jinja) and :54 (drop `ollama show --template` as the gate); narrow `llamacpp-eval` s5 guard-scan scope inline. -> verify: each edited line matches spec.md's Corrections table.
- [ ] **(Optional) Qwen quality.** Evaluate froggeric on the Anthropic lane for agentic/KV-cache wins on Qwen coders. -> verify: A/B a tool-loop session vs the stock template; adopt only if it helps.
