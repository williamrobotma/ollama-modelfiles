# 2026-08-07: llamacpp-migration Phase 3 client cutovers

Executes Phase 3 of `specs/llamacpp-migration`: every client moved off Ollama onto the llama-server router (11433).

- Environment: WSL2 + RTX 4070 (12282 MiB), stock llama.cpp b9860 (fdb1db877), router mode on `llamacpp/models.ini`.
- Provenance caveat: the raw P3 validation evidence (scratchpad request/body logs) was lost at the 2026-08-06 reboot.
  - `specs/llamacpp-migration/tasks.md` dated notes are the surviving record for the 2026-08-04 validations.
  - The 2026-08-07 evidence (webui.db reads, router-log slices) was collected live and cross-validated.

## claude-local (2026-08-04)

Rewired: `~/.bashrc` fn exports `ANTHROPIC_BASE_URL=http://127.0.0.1:11433`, a dummy auth token, `ANTHROPIC_MODEL`
plus the three tier vars and `CLAUDE_CODE_SUBAGENT_MODEL` (all -> the 35B coding alias), then sources a mode-600 env
file and execs `claude --disallowedTools=WebSearch --mcp-config=...` (`=` form required; space form eats `"$@"`).

- Validated 9/9: tool loop, live MCP search, body-log audit, cache hits (~25.9k `cache_read_input_tokens`), WebFetch.
- Blocker found and fixed: tier vars do not override a literal `model` in settings.json; `ANTHROPIC_MODEL` pins it.
- Thinking blocks round-trip with `signature: ""`; decode 26.8-36.0 tok/s, MTP acceptance 0.66-0.97.
- Web search: WebSearch denied client-side; the official Ollama web-search MCP vendored at `llamacpp/mcp/` with a
  local `mcp>=1.9,<2` pin (mcp 2.0.0 removed both API paths the script uses); `OLLAMA_API_KEY` copied to the env file.

## OpenCode 1.16.2 (2026-08-04)

- 12-model `@ai-sdk/openai-compatible` provider with per-model context/output limits; all 12 in the picker.
- Validated with a real tool-loop session on 11433; decode 23.2-34.0 tok/s, acceptance 0.71-0.99.
- No websearch tool exists in this build (webfetch only) - the "search via Ollama" belief closed as false.
- Upstream client bug found: `opencode run` drops final message text from stdout (stored text intact via export).

## Codex 0.145.0 (2026-08-04)

- Custom provider (`wire_api = "responses"`) + profile overlay + 12-model catalog; cloud default untouched.
- Tool loop validated via exec_command x3; issue #10635 affirmatively dead on the pin.
- Finding: llama-server silently skips Responses tools typed `namespace` (Codex MCP) and `web_search` with HTTP 200.
  - Codex-side MCP fails invisibly on this lane; plain `function` tools unaffected.
- Caveats: the ambient ChatGPT credential rides along (authless-without-login unproven); phones home under the
  local profile; the ~10k-token preamble costs ~42 s cold prefill per session.

## Open WebUI 0.11.0 (prepped 2026-08-04, cut over 2026-08-07)

- 0.11.0 first start ran 9 alembic migrations clean over a pre-upgrade backup; Brave key and settings intact.
- Connection: OpenAI type -> `http://127.0.0.1:11433/v1`, external/bearer, no model filter; Ollama connection
  disabled. Picker shows the 17 canonical ids (plus Open WebUI's own Arena Model pseudo-entry).
- Sampling neutrality closed at source: `utils/payload.py:70` applies only non-None params, so unset chat params
  never reach the wire and the router launch profiles govern.
- Chats verified in webui.db (cross-matched to router-log `predicted_per_second` verbatim): Gemma 12B MTP family
  chat with thinking rendering, two platform-search chats (12B: 5 sources; 35B instruct: 10 sources), qwen3.6
  family chat.
- qwen3.5 family chat: see the post-restart verification section below.
- Connection research (source-grounded): external-vs-local is a label (only read: task-model selection);
  Provider=llama.cpp enables reasoning round-trip as `reasoning_content` plus the Loaded/Eject UI; the Responses
  api_type would lose tok/s display and expose the silent tool-drop - keep chat-completions.
- Reasoning-in-context practice: templates enforce the standard (keep current-turn, strip history) - the pinned
  froggeric template renders `<think>` only after the last user query, so sending reasoning back is safe.
- tok/s display works out of the box: llama.cpp `timings` merge into `message.usage`; the info icon shows the dict.

## Router findings under multi-resident pressure (2026-08-07)

The first day of real mixed use loaded 4+ children on 12 GiB and exposed a failure class P1's solo checks could not:

- The router evicts LRU at stock `--models-max 4`, blind to VRAM; pressure starved the MoE decodes (35B: 2.94 tok/s).
- The 26B-A4B MTP child crashed loading its drafter: a full GPU reports free=0, the layer-split math produces NaN,
  and `devices.at(1)` throws on a 1-device vector (`llama-model.cpp:1291`). Upstream: #19973 derived the mechanism
  (closed unfixed), a #24443 comment reproduces it verbatim; no fix on master - a rebuild would not help.
  - Drafter loads bypass memory fitting and demand full offload, so any pressured load can hit this.
- Fixes applied (user go): `spec-draft-ngl = 0` on the 26B entry (241 MiB drafter to CPU, crash unreachable by
  construction) and `launch.sh` now defaults `--models-max 1` (user decision over the proposed 2: one-at-a-time
  usage, full-GPU residency; `MODELS_MAX` env overrides).
- Sampling-degeneracy observation: the 35B instruct fell into a `/` repetition loop on a 7-search, ~11.6k-token
  chat (log clean - no truncation or shift). Neutral profiles carry no repeat penalty by design; regenerate
  escapes, and a per-chat `repeat_penalty` is the documented escape hatch.

## Post-restart verification (2026-08-07, models-max 1 + CPU drafter live)

- The 26B pair loads clean with `--n-gpu-layers-draft 0` in its spawn args: zero range_check or draft-load errors.
  - 5 completed generations at 22.9-31.2 tok/s, draft acceptance 0.638-0.841 - the CPU drafter speculates normally.
- The qwen3.5 family chat landed through Open WebUI (queen-27b-reasoning, 3 completed turns), closing the last
  Phase 3 check.
  - DB `usage.predicted_per_second` joins each turn to its router-log task exactly (float-identical).
- Attribution correction: dense 16-18 GB offloaders decode at ~2-3 tok/s even as the lone resident.
  - queen-27b 1.93-2.30 and 31B 2.77 solo, vs 26-33 for the MoE models; dense offload dominates, not residency.
  - Multi-resident pressure was still real for MoE: the 35B family recovered from ~2.8-2.9 to 25-30 tok/s solo.
- models-max 1 trade-off observed: switching models force-kills an in-flight generation after a 10 s timeout.
- The 31B "n_ctx_train 131072" overflow warning is the drafter's trained ctx (a known P2 finding); the target
  trains at 262144.

## Pi

Explicitly deferred (user, 2026-08-07). Pi is not installed here; nothing was rewired and no config landed.
Wire it from `llamacpp/models.ini` at pickup - it does not gate Phase 4.
