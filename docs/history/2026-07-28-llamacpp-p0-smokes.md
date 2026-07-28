# 2026-07-28: llamacpp-migration Phase 0 router smokes

Executes Phase 0 of `specs/llamacpp-migration` (round 2 session). All 11 smokes passed.

- Environment: WSL2 + RTX 4070 (12282 MiB), stock llama-server b9860 (fdb1db877), router mode on `127.0.0.1:11433`.
- Config: `llamacpp/launch.sh` + `llamacpp/models.ini` @ commit b70b827, 3 entries.
  - `qwen3.5-9b-mtp-coding-ud-q4-k-xl` and `gemma4-12b-it-qat-mtp` (ctx 200000 per the 2026-07-28 spec decision).
  - Guarded `qwen3.5-9b-coding-ud-q4-k-xl` under froggeric.
- n=1 per cell unless stated; tok/s from llama-server `timings.predicted_per_second`.

## Router and fleet suppression

- `/v1/models`: exactly the 3 preset entries, `source: preset`, no phantom `default`, no HF-cache auto-discovery.
- One generation OK under the `LLAMA_CACHE` redirect.
- `[*]` globals merged into every child: `--jinja`, `-fa on`, q8_0 KV, and `-np 1` present in each child's args.
- Router CLI `--sleep-idle-seconds` propagated into child presets; the router injects `--alias <name>` per child.
- Launcher pin assert exercised on all 5 relaunches; the wrong-binary abort branch was not exercised.

## Anthropic endpoint (/v1/messages)

- Basic: correct message shape, thinking + text blocks, `stop_reason: end_turn`.
- Streaming: valid Anthropic event types; one ordering quirk at the thinking->text boundary.
  - `content_block_start[1]` + first `text_delta` arrive before block 0's `signature_delta` (empty) and both stops.
  - Single-block responses close correctly; feeds the P3 claude-local validation (plan flags `signature: ""` there).
- Tool loop: `stop_reason: tool_use` with correct input; `tool_result` continuation returns a grounded answer.
- Prefix cache: turn-2 `cache_read_input_tokens` = 427.
- Multi-system immunity (per-build): two-block system array -> 200, both blocks honored.

## OpenAI and Responses endpoints

- Guarded 9B under froggeric: mid-conversation `system` on `/v1/chat/completions` -> 200 at 77.0 tok/s.
  - Served `chat_template` sha256 == the pinned `llamacpp/templates/chat_template.jinja` (`d203f334...`).
  - The MTP sibling keeps its embedded `merged_system` template (no `chat-template-file` on that entry).
- `/v1/responses` (Codex shape): `reasoning` + `function_call` items with correct arguments, no 500.
  - `function_call_output` continuation -> `completed` with grounded text.

## /props vs profile

- All three children match the docs/parameters.md profile exactly, including `min_p 0.0` (no 0.05 injection).
- Gemma `n_ctx` reports 200192: 200000 rounded up to block granularity.
- `/props` shows `n_predict -1` regardless of `--n-predict`: a pin display artifact, not a config failure.
  - `get_props` copies only `params.sampling` into a fresh `task_params` (`tools/server/server-context.cpp:4554`).
  - Request defaults DO copy `params_base.n_predict` = 65536 (`tools/server/server-schema.cpp:503`).
  - Do not re-flag at the Phase 2 spot-loads.

## Swap behavior (models-max stock 4, sleep-idle)

- Coexist: both 9B children loaded at once (11.5/12.3 GiB), no eviction observed at `--models-max` 4.
  - Both full-speed: guarded 77.0 tok/s; MTP 116.7 tok/s at draft acceptance 0.815.
- Sleep-idle (relaunch with `SLEEP_IDLE_SECONDS=30`): `loaded` -> `sleeping` after the idle window.
  - VRAM 10.2 -> 1.2 GiB on sleep; wake-on-request ~3 s; generation healthy (134.8 tok/s).

## Gemma probes (12B MTP pair, ctx 200000, graphs ON)

- Pair loads at 200k in 11.0 GiB; 112.4 tok/s, draft 26/32 accepted.
- 4 short gens total, no crash; the eval's gen-5 crash did not re-trigger and the P1 ladder still owns the ceiling.
- Thinking on the wire with NO flags: `reasoning_content` present - the `enable_thinking` default reaches the template.
  - The six `SYSTEM <|think|>` Modelfile directives need no migration.
- Per-request `chat_template_kwargs {"enable_thinking": false}` suppresses the channel.
- Launch flag `--reasoning off` (`-rea off`) also suppresses it - recorded as the flag->kwarg mapping.

## MTP x --mmproj probe (9B MTP entry, temporary INI edit)

- b9860 SERVES BOTH from one entry: load stages `text_model` + `spec_model` + `mmproj_model`, image modality listed.
- A 1x1 red PNG round-trip answered "Red" with drafting active (draft_n 74).
- Contradicts the vendor card's "not yet supported with MTP" on this build.
  - The card's claim also covers `-np > 1`, untested here; the fleet runs `-np 1`.
- Cost: 69.9-80.6 tok/s across 3 gens with the projector resident vs 116.7-134.8 without - a ~35-40% MTP penalty.
  - P2 consequence: split MTP and vision entries for speed, not necessity; re-measure before leaning on the numbers.

## Gemma drafter auto-discovery (temporary INI edit)

- `spec-type draft-mtp` with no `model-draft`: the child dies at the `spec_model` stage and the router returns 500.
  - Error: `context type MTP requested but model doesn't contain MTP layers` -> `failed to create MTP context`.
- No auto-discovery from local snapshot paths on b9860; explicit `model-draft` wiring is mandatory.
- unsloth's auto-discovery claim is `-hf`-loading-only, as the 2026-07-25 preflight assumed.

## Provenance and validity

- Single box, single session, small n (1-4 gens per cell); throughput numbers are indicative only.
- Protocol pass/fail cells are deterministic parse-time behavior where n=1 is conclusive.
- `GET /metrics` never scraped (spec rule: it autoloads models and blocks idle sleep).
- Raw router logs and probe scripts lived in the session scratchpad; not retained in the repo.
- The mmproj coexistence + decode-penalty findings contradict or extend prior docs; both are n<=3 on one GGUF.
