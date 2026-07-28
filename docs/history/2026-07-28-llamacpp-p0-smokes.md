# 2026-07-28: llamacpp-migration Phase 0 router smokes

Executes Phase 0 of `specs/llamacpp-migration` (round 2 session). All 11 smokes passed.

- Environment: WSL2 + RTX 4070 (12282 MiB), stock llama-server b9860 (fdb1db877), router mode on `127.0.0.1:11433`.
- Config: `llamacpp/launch.sh` + `llamacpp/models.ini` @ commit b70b827, 3 entries.
  - `qwen3.5-9b-mtp-coding-ud-q4-k-xl` and `gemma4-12b-it-qat-mtp` (ctx 200000 per the 2026-07-28 spec decision).
  - The guarded `qwen3.5-9b-coding-ud-q4-k-xl` serves under froggeric.
- n=1 per cell unless stated. tok/s values come from llama-server `timings.predicted_per_second`.

## Router and fleet suppression

- `/v1/models` lists exactly the 3 preset entries (`source: preset`).
  - No phantom `default` appeared and no HF-cache entries were auto-discovered.
- One generation completed under the `LLAMA_CACHE` redirect.
- The `[*]` globals reached every child: `--jinja`, `-fa on`, q8_0 KV, and `-np 1` appear in each child's args.
- The router propagates its CLI `--sleep-idle-seconds` into child presets and injects `--alias <name>` per child.
- The launcher's pin assert ran on all 5 relaunches. The wrong-binary abort branch was not exercised.

## Anthropic endpoint (/v1/messages)

- Basic: correct message shape with thinking + text blocks and `stop_reason: end_turn`.
- Streaming emits valid Anthropic event types, with one ordering quirk at the thinking->text boundary.
  - `content_block_start[1]` and the first `text_delta` arrive before block 0's empty `signature_delta` and the stops.
  - Single-block responses close correctly. The quirk feeds the P3 claude-local validation (plan flags `signature: ""`).
- Tool loop: `stop_reason: tool_use` with correct input, and the `tool_result` continuation returns a grounded answer.
- The prefix cache works: turn-2 `cache_read_input_tokens` = 427.
- Multi-system immunity (per-build): a two-block system array returns 200 and both blocks are honored.

## OpenAI and Responses endpoints

- A mid-conversation `system` on `/v1/chat/completions` returns 200 from the guarded 9B under froggeric (77.0 tok/s).
  - The served `chat_template` sha256 equals the pinned `llamacpp/templates/chat_template.jinja` (`d203f334...`).
  - The MTP sibling keeps its embedded `merged_system` template, since that entry sets no `chat-template-file`.
- `/v1/responses` (Codex shape) returns `reasoning` + `function_call` items with correct arguments and no 500.
  - The `function_call_output` continuation completes with grounded text.

## /props vs profile

- All three children match the docs/parameters.md profile exactly, including `min_p 0.0` (no 0.05 injection).
- Gemma `n_ctx` reports 200192, which is 200000 rounded up to block granularity.
- `/props` shows `n_predict -1` regardless of `--n-predict`. This is a pin display artifact, not a config failure.
  - `get_props` copies only `params.sampling` into a fresh `task_params` (`tools/server/server-context.cpp:4554`).
  - Request defaults DO copy `params_base.n_predict` = 65536 (`tools/server/server-schema.cpp:503`).
  - Do not re-flag this at the Phase 2 spot-loads.

## Swap behavior (models-max stock 4, sleep-idle)

- Both 9B children coexisted loaded (11.5/12.3 GiB) with no eviction at `--models-max` 4.
  - Both ran full-speed: the guarded child at 77.0 tok/s, the MTP child at 116.7 tok/s with draft acceptance 0.815.
- Sleep-idle (relaunched with `SLEEP_IDLE_SECONDS=30`): the child went `loaded` -> `sleeping` after the idle window.
  - Sleep released VRAM (10.2 -> 1.2 GiB). Wake-on-request took ~3 s and generated healthily (134.8 tok/s).

## Gemma probes (12B MTP pair, ctx 200000, graphs ON)

- The pair loads at 200k in 11.0 GiB and decodes at 112.4 tok/s with 26/32 drafts accepted.
- 4 short gens ran without a crash. The eval's gen-5 crash did not re-trigger, and the P1 ladder still owns the ceiling.
- Thinking appears on the wire with NO flags set, so the `enable_thinking` default reaches the template.
  - The six `SYSTEM <|think|>` Modelfile directives need no migration.
- The per-request `chat_template_kwargs {"enable_thinking": false}` suppresses the channel.
- The launch flag `--reasoning off` (`-rea off`) also suppresses it. That is the recorded flag->kwarg mapping.

## MTP x --mmproj probe (9B MTP entry, temporary INI edit)

- b9860 SERVES BOTH from one entry: the child load ran stages `text_model` + `spec_model` + `mmproj_model`.
- The entry advertised image modality, and a 1x1 red PNG round-trip answered "Red" with drafting active (draft_n 74).
- This contradicts the vendor card's "not yet supported with MTP" on this build.
  - The card's claim also covers `-np > 1`, which was not tested here. The fleet runs `-np 1`.
- The resident projector costs the MTP lane ~35-40%: 69.9-80.6 tok/s across 3 gens vs 116.7-134.8 without it.
  - P2 consequence: split MTP and vision entries for speed, not necessity. Re-measure before leaning on the numbers.

## Gemma drafter auto-discovery (temporary INI edit)

- With `spec-type draft-mtp` and no `model-draft`, the child dies at the `spec_model` stage and the router returns 500.
  - The error is `context type MTP requested but model doesn't contain MTP layers` -> `failed to create MTP context`.
- No auto-discovery exists for local snapshot paths on b9860. Explicit `model-draft` wiring is mandatory.
- unsloth's auto-discovery claim is `-hf`-loading-only, as the 2026-07-25 preflight assumed.

## Provenance and validity

- Single box, single session, small n (1-4 gens per cell). Throughput numbers are indicative only.
- Protocol pass/fail cells are deterministic parse-time behavior, so n=1 is conclusive for them.
- `GET /metrics` was never scraped (spec rule: it autoloads models and blocks idle sleep).
- Raw router logs and probe scripts lived in the session scratchpad and are not retained in the repo.
- The mmproj coexistence and decode-penalty findings contradict or extend prior docs. Both are n<=3 on one GGUF.
