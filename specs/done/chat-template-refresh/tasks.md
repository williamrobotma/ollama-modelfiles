# Tasks: chat-template-refresh

Status: `[ ]` pending, `[x]` done. Research 2026-07-17 (see spec.md); executed 2026-07-23.

- [x] Research: read the live templates and commit history from Hugging Face, and scan every installed model's template on-box (read-only). Findings are in spec.md. Done 2026-07-17.
- [x] Re-pull the Gemma templates. First read each QAT repo's 2026-07-17 commit and confirm it is the template update (free, no download). Then `hf download` each and edit its `FROM` line, for 12B, 26B-A4B, and 31B. Done when: each `FROM` points at the confirmed snapshot, and the Gemma MTP drafter still loads.
  - Done 2026-07-23. Evidence: `docs/history/2026-07-23-chat-template-refresh.md`.
  - Deviation: Ollama Gemma models not rebuilt - the template is invisible to Ollama, and the lane is being retired.
- [x] Apply the Qwen rule on the OpenAI endpoint. For each guarded model in spec.md's list (unsloth Qwen3.5-9B non-MTP, OBLITERATUS-27B, Queen-27B), serve it with `--jinja --chat-template-file` pointing at froggeric's template. Validate froggeric once for the (template, build) pair - run `test_v21.py` and one request that has more than one system message and a tool loop - then each further model is just launch and one request. This is the same work as step 3 of `specs/llamacpp-migration`, widened to the full guarded set. Done when: a request with more than one system message returns 200 (not 400) for each model on `/v1/chat/completions`.
  - Done 2026-07-23. Evidence: `docs/history/2026-07-23-chat-template-refresh.md`.
  - Deviation: set extended to Qwopus3.5-9B-coder (guarded; the spec had it clean).
- [x] Replace the vetting check. Swap `ollama show --template` for spec.md's procedure: grep the GGUF template for the guard, send one multi-system request to `/v1/chat/completions` per GGUF, and one to `/v1/messages` once per build. Done when: the procedure is written down and referenced from `specs/stack-upkeep`.
  - Done 2026-07-23: procedure in the AGENTS.md gate section; referenced from `specs/stack-upkeep/spec.md`.
- [x] Fix the docs. Rewrite the `AGENTS.md` gate section (lines 48-54) to match spec.md's corrections (and fix the matching CLAUDE.md claude-local note), and append a dated correction note to section 4 of `docs/history/2026-07-17-llamacpp-eval.md` narrowing its scan-scope claim. Done when: the edits match the corrections, and the eval log's original text is untouched (the note is appended, not edited in place).
  - Done 2026-07-23: AGENTS.md gate + CLAUDE.md note rewritten; eval-log correction appended (original intact).
- [x] (Optional) Compare froggeric against `merged_system` for quality. Only worth doing for the `merged_system` models (the guarded ones already run froggeric on both endpoints). Compare a tool-loop session with each; adopt froggeric if it is better. Done when: the decision is recorded.
  - Decision 2026-07-23 (user): defer to `specs/openwebui-wrapup`, once the OpenAI lane is the daily driver.
  - When doing it, check froggeric's open tool-call regression reports (repo discussions #55/#56/#64; #56 is on b9860).
  - The Moore2877 fork of v21.3 is the actively-maintained fallback.
