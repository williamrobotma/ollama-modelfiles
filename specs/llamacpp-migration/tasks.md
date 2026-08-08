# Tasks: llamacpp-migration

Planning done 2026-07-23 (spec vetted, plan.md filled). Details and verify steps per item live in `plan.md`.

GPU-loading items are heavy loads: get user confirmation before starting each.

`spec.md` and `plan.md` locked 2026-07-28 (user directive): no further edits for the remainder of the task.
Execution deviations and per-item verification notes are recorded here only.

## Pre-flight (2026-07-25)

- [x] Stale b9552 binaries deleted from the llama.cpp repo root; build/bin b9860 is the only one left
- [x] Router preset, alias, and child-env mechanics verified from source on the pin
- [x] Gemma thinking mechanism traced across Google, unsloth, the GGUF template, and llama.cpp source
- [x] Sampling and MTP claims verified against vendor cards; conflicts recorded in docs/parameters.md
- [x] Findings written to docs/history/2026-07-25-llamacpp-preflight.md

## Fleet reduction (2026-07-27)

Keep-set narrowed at the execution review; deletion pulled forward from the Phase 4 purge (spec execution
revisions). Fleet: 17 configs + 6 aliases.

- [x] 8 Modelfiles deleted: 3 OBLITERATUS configs + `27b-obliterated-coding` alias, `qwopus3.5/` family,
      35B q4 MTP pair, non-MTP 35B lane - verified 23 Modelfiles remain (17 + 6)
- [x] `35b-a3b-coding` alias repointed to the MTP-q5 coding config; rebuilt under Ollama - verified 28 GB (q5
      class; the old q4 build was 23 GB)
- [x] 9 Ollama models removed - verified `ollama list` = 23, matching the Modelfile count
- [x] HF cache: OBLITERATUS x2, noctrex, Jackrong Qwopus, non-MTP 35B repo, 35B q4 blob deleted - hub 285G -> 199G
  - 86G freed; q4/q5 blobs confirmed distinct before deletion
  - All 22 kept `FROM`/`DRAFT` paths resolve (19 + 3; count corrected from 20, re-verified 2026-07-28)

## Phase 0 - router protocol smokes

Completed 2026-07-28, all 11 smokes passed; evidence: `docs/history/2026-07-28-llamacpp-p0-smokes.md`.

- [x] `llamacpp/` skeleton: 3-model preset INI (incl. the guarded 9B non-MTP) + launcher on 11433
  - Verified: 19 keys map to b9860 flags, all paths resolve, `[*]` mechanics source-checked, copy sha256-identical
- [x] Launcher uses the absolute build/bin path and aborts unless `--version` reports 9860
  - Verified: assert substring matches live `--version` output; `bash -n` clean; abort branch untested (accepted)
  - Deviation 2026-08-03 (user): abort removed after P1; launch.sh keeps the pin as a last-known-good record
    - The spec's rebuild rule moves that record forward (decision record in the P1 log)
- [x] Router up: `/v1/models` lists only preset entries (no phantom `default`, no HF-cache auto-discovery)
  - One generation OK under the `LLAMA_CACHE` redirect
- [x] `/v1/messages` smoke via router: basic, streaming, tool loop, cache hits (427 cached tokens on turn 2)
  - Streaming block-overlap quirk at the thinking->text boundary logged for the P3 claude-local validation
- [x] Multi-system immunity check on `/v1/messages` (per-build) - two-block system 200
- [x] `/v1/chat/completions` + froggeric on a guarded Qwen - mid-conversation system 200, template byte-identical
- [x] `/v1/responses` Codex-shaped smoke with a function tool - round-trip completed, no 500
- [x] Per-child `/props` matches docs/parameters.md profile - all 3 children exact
  - `/props` `n_predict -1` is a pin display artifact; the request default is the flag value (server-schema.cpp:503)
- [x] Sleep-idle unload/reload observed (sleeping, VRAM released, ~3 s wake); models-max behavior recorded
  - Two 9B children coexist full-speed at 11.5/12.3 GiB, no eviction
- [x] Gemma thinking confirmed on the wire with no flags set; disable path and `-rea` mapping recorded
  - `enable_thinking:false` disables per-request; `-rea off` disables at launch
- [x] MTP x `--mmproj` behavior recorded - b9860 serves both from one entry, no conflict, loads fine unsplit
  - Image round-trip OK with drafting active, at a ~35-40% decode penalty; P2 splits for speed
- [x] Gemma drafter auto-discovery from a local snapshot path tested - none; explicit `model-draft` mandatory
  - Child dies without it: `failed to create MTP context`

## Phase 1 - stability envelopes

- [x] Gemma KV probe: llama-perplexity KL (f16 vs q8_0, one ~16k segment) + VRAM delta; type fixed before the
      ladder; Qwen only if Gemma surprises
  - q8_0 fleet-wide (user, 2026-08-03): q8_0 KLD 0.072 == bf16's 0.070 vs the f16 base, so the tail is dtype noise
    - Gemma did not surprise, so no Qwen probe ran; evidence in `docs/history/2026-08-03-llamacpp-p1-envelopes.md`
- [x] Gemma 12B MTP ctx ladder (32k..200k, crash matrix per rung, graphs ON); pick ceiling
  - 36/36 gens stable across all 6 rungs; ceiling 200000; the eval's 200k crash did not reproduce (n=6)
- [x] 26B MTP pair checked at the chosen ceiling
  - 6/6 gens stable at 131072 (its profile ctx), 39.1-41.7 tok/s, acceptance 0.62-0.74, `-ngl auto` partial offload
- [x] Qwen-MTP graphs-on hammer, 30 gens, 0 crashes (crash = contingency trigger)
  - 30/30 clean against the router child, full 4096 tokens each, 98-121 tok/s; contingency not triggered
- [x] Results written to a dated docs/history log
  - `docs/history/2026-08-03-llamacpp-p1-envelopes.md` + index row

## Phase 2 - full-fleet config home

- [x] Preset INI: 17 configs + 6 aliases, full flags, mmproj, drafters, froggeric on the 3 guarded-GGUF entries
  - Verified: 17 sections + 6 alias names, all 29 file paths resolve, `alias`/`reasoning` are b9860 flags
    - Review sweep 2026-08-03: `enable_thinking` via kwargs is deprecated on the pin -> `reasoning = off`
  - MTP x vision split applied: MTP entries carry no mmproj; policy recorded in docs/parameters.md
    - The 35B instruct canonical serves plain (no spec-type) with mmproj as that family's vision lane
- [x] Serving flags set (`-fa on`, KV type, `-np 1`, `--jinja`) and explicit `min_p` on every entry
  - Verified: `[*]` carries all four, plus the fleet-constant sampling keys hoisted at the review sweep
    - min-p/n-predict/repeat-penalty/top-p/presence-penalty live in `[*]`; per-entry values only where they differ
- [x] froggeric template pinned into `llamacpp/templates/`
  - Done at P0; sha256 `d203f334...` re-verified at P2
- [x] `llamacpp/README.md`: layout, alias policy, add-a-model procedure
- [x] Name-parity check against `ollama list`; spot-loads verified via `/props` (4 ran)
  - Parity EXACT 2026-08-03: 17 ids + 6 aliases == the 23 `ollama list` names
  - Heretic templates extracted offline 2026-08-03 (review-sweep M8): zero `raise_exception` in either GGUF
  - Spot-loads 2026-08-04: 4/4 PASS (31b-mtp, queen-27b-coding, 35b-a3b-mtp-coding, 26b-heretic carrying the probe)
    - `/props` sampling exact per profile on all 4; ctx-size pads to a 256 boundary (200000 -> 200192)
    - Display-only `/props` artifacts: `n_predict -1` (known P0) and `speculative.types "none"` while drafting runs
    - Queen's served template byte-identical to froggeric; acceptance 0.83 (31B pair) / 0.88 (35B); no CUDA lines
    - Heretic probe HTTP 200 via the "outdated gemma4 chat template" compat rewrite (3 warnings; unsloth sibling 0)
      - The multi-system pass depends on that upstream workaround staying present
    - 31B `-ngl auto` fitting could not measure the drafter ("failed to measure draft model memory"); worked anyway
  - Finding 2026-08-04: the 31B MTP entry serves ctx 200000 but its drafter is trained at 131072
    - Source: drafter GGUF `gemma4-assistant.context_length = 131072`; load warns "possible training context overflow"
    - 12B's drafter is trained at 262144 (fine at 200000); the 26B pair serves exactly its drafter's 131072
    - Speculation is output-invariant: the exposure is acceptance/speed past ~131k positions, not correctness
    - Decided 2026-08-04 (user): keep 200000; noted on the models.ini entry

## Phase 3 - client cutovers

- [x] claude-local rewired: base URL 11433, tier vars, `--disallowedTools WebSearch`, web-search MCP
  - Applied 2026-08-04 with user consent: `~/.bashrc` fn + `~/.config/claude-local.env` rewrite + new mcp.json
  - Deviation (measured): `--disallowedTools=WebSearch` = form; the plan's space form swallows `"$@"` into deny rules
  - MCP scope: per-invocation `--mcp-config` only; nothing registered globally (`~/.claude.json` has no mcpServers)
  - MCP runtime: pipx (user: pipx first; uv absent) runs the official script vendored at `llamacpp/mcp/`
    - Local pin `mcp>=1.9,<2` (2026-08-04): mcp 2.0.0 removed FastMCP and Server.tool(); upstream script unfixed
    - Stdio handshake + live web_search 200 verified end-to-end on the pinned content
    - Provenance record: `llamacpp/mcp/README.md`
- [x] `OLLAMA_API_KEY` moved to a user-readable env file for the MCP
  - Copied (not moved) 2026-08-04: the spec freezes the systemd override until the P4 purge; env file is mode 600
- [x] claude-local validated: tool loop, live MCP search, body-log check, cache hits, WebFetch
  - 2026-08-04: 9/9 checks PASS against the live router (evidence: session scratchpad p25/; P3 history log at phase end)
  - Blocker found: tier vars don't override settings.json's literal model - `claude-fable-5` hit the wire, router 400
    - Fixed: the function now exports `ANTHROPIC_MODEL=$_cl_model`
    - Re-smoked with no passthrough: alias on the wire, 200
  - Cache hits ~25.9k `cache_read_input_tokens` on later turns; thinking blocks round-trip with `signature: ""`
  - Alias resolves server-side (alias request -> canonical child); decode 26.8-36.0 tok/s, acceptance 0.66-0.97
  - WebSearch absent from the tools array; `web_search_20250305` count 0 across all 21 body-log files
  - MTP x graphs-on side result: 10 requests to 26.2k ctx, graphs reused to 1030, zero crashes
    - n=1; the tracked issue stays open
- [x] Open WebUI on OpenAI connection 11433; fleet in picker; search-enabled chat passes
  - Prep 2026-08-04: backup `~/.open-webui/webui.db.bak-pre-0.11.0` taken, then the pending 0.11.0 first start ran
    - 9 alembic migrations + 13 seeded config defaults; documented settings and the Brave key intact; serve up on 8080
  - Browser pass 2026-08-07 (user): OpenAI connection saved (external/bearer, no model filter, no passthrough params)
    - Picker shows the 17 canonical ids (plus Open WebUI's own "Arena Model"); Ollama connection disabled
    - Gemma family chat served via the router with thinking rendering (user screenshot)
  - Sampling neutrality closed at source: `open_webui/utils/payload.py:70` applies only non-None params
    - Unset chat params never enter the body, so the router's launch-time profiles govern (0.11.0 installed package)
  - Search chat 2026-08-07 (user): tool-mode search ran on the 12B child - "Explored search_web", 5 cited sources
    - Web search is Open WebUI's platform toggle, not a model tool
    - Two earlier turns denied having search; the successful turn's reasoning trace calls those refusals incorrect
    - DB cross-matches the router log verbatim (predicted_per_second 96.66... on the search turn in both)
  - Connection research 2026-08-07 (source-grounded, 0.11.0 installed package): keep external + chat-completions
    - external vs local is a label: the sole behavioral read picks the external vs local task model (utils/task.py:20)
    - Recommend Provider=llama.cpp: prior-turn reasoning goes back as reasoning_content; unset DROPS it
      - Sites: middleware.py:2059-2073 -> misc.py:437-439; also unlocks the Loaded badge + Eject (/models/unload)
      - Our router serves per-model status in /v1/models, so the badge reads true residency (fallback caveat moot)
    - Responses api_type would lose tok/s (stream_options popped at openai.py:1113; Responses stream has no timings)
      - And filter-injected web_search/namespace tools would pass into llama-server's silent drop; keep chat-completions
    - tok/s already works: timings merge into message.usage (middleware.py:4378-4382); the info icon shows the dict
    - froggeric renders <think> only after the last user query (jinja:226); cross-turn stripping is template-enforced
  - Finding 2026-08-07: 26b-a4b-mtp child died loading its drafter via the router - vector::_M_range_check
    - First-ever router-context load: P1's 6/6 was standalone with a free GPU; three residents held ~10.7/12.3 GiB here
    - Router evicts LRU at stock models-max 4 (observed live: 12b-mtp died for 31b, 9b for 26b)
    - Root cause (source-traced): full GPU reports free=0 -> NaN split -> devices.at(1) on size-1 (llama-model.cpp:1291)
    - The drafter bypasses fitting and demands full offload (server-context.cpp:1205); any pressured load can hit it
    - Upstream: #19973 derived the mechanism (closed unfixed); a #24443 comment reproduces it verbatim; no fix on master
    - Deterministic fix candidate: spec-draft-ngl = 0 on the 26b entry (241 MiB drafter to CPU); awaiting user go
    - Applied 2026-08-07 (user: "yes to both"): spec-draft-ngl = 0 in models.ini; launch.sh gains --models-max
      - models-max default 1 per user (over the proposed 2): one-model-at-a-time usage; effective at next restart
  - Family-chat check 2026-08-07: zero qwen3.5/qwen3.6 chats exist in webui.db (11 chats total, all scanned)
    - Today's 15:55 qwen child spawns came from a non-Open-WebUI client (agentic task-id pattern, 97-127 tok/s)
  - Finding 2026-08-07: 31b-mtp decoded at 1.82 tok/s under 4-resident pressure (vs 38-120 tok/s elsewhere today)
    - The two follow-up 31b generations were cancelled ~1 s after launch each; reads as giving up on a hang
    - Same pathology on the 35b instruct as a 5th model: 2.94 tok/s on its first turn (chat f49e10a3)
  - qwen3.6 family chat verified in DB 2026-08-07: chat f49e10a3 turn 1 done=true, 35b instruct via Open WebUI
    - Turn 2 completed with platform search on the same model - 2x search_web, 10 sources (user screenshot)
  - Observation 2026-08-07: 35b instruct fell into a "/" repetition loop after 7 searches (~11.6k ctx, 30 sources)
    - Log clean (truncated = 0, no context shift): sampling degeneracy, not corruption; profiles carry no repeat penalty
    - Same model completed the 2-search turn fine; user cancelled the looping task (1313); regenerate is the escape
  - qwen3.5 family chat verified in DB 2026-08-07 post-restart: chat 68d974be, queen-27b-reasoning, 3 done turns
    - usage.predicted_per_second joins each DB turn to its router-log task exactly (22.896.../1.947.../1.930...)
  - Post-restart verification 2026-08-07 (models-max 1 live): 26b-mtp loads clean, --n-gpu-layers-draft 0 in args
    - 5 completed gens at 22.9-31.2 tok/s, acceptance 0.638-0.841; zero _M_range_check or draft-load failures
  - Correction to the pressure finding: dense 16-18 GB offloaders sit at ~2-3 tok/s even solo (offload-bound)
    - queen-27b 1.93-2.30 and 31b 2.77 as lone residents; pressure mainly hurt MoE (35b back to 25-30 solo)
  - models-max 1 trade-off observed live: switching models force-kills an in-flight generation after 10 s
  - The 31b "n_ctx_train 131072" overflow W is the drafter's trained ctx (P2 finding); the target trains 262144
- [x] OpenCode provider block + context limits; search-tool behavior recorded
  - Applied 2026-08-04 (user consent, "no model left behind"): 12-model provider block with per-model limits
  - Validated: real tool-loop session fixed a file on disk; requests hit 11433 (no #5674 symptom); picker lists all 12
  - Search recorded: no websearch tool exists in opencode 1.16.2 - webfetch only; the "search via Ollama" belief closed
  - Seam clean (no P0-style block overlap); upstream client bug found: `opencode run` drops final text from stdout
    - 4/4 sessions, stored text intact via `opencode export`; TUI untested; non-blocking for the cutover
  - Decode 23.2-34.0 tok/s, acceptance 0.71-0.99; zero E/W or CUDA lines across the session's 192 router-log lines
- [x] Codex custom provider (Responses, fresh threads); tool loop tested or upstream-blocked documented
  - Applied 2026-08-04 (user consent): provider table + overlay + 12-model catalog; cloud default untouched
  - Validated: tool loop fixed a file via exec_command x3; /v1/responses -> canonical child proven
    - #10635 affirmatively dead on the pin (zero 4xx across both runs)
  - Auth qualifier: 0.145.0 accepts the authless provider but attached the ambient ChatGPT credential
    - The router ignores the header; authless-without-login and the env_key fallback stay unvalidated
  - Finding: llama-server silently skips Responses tools typed `namespace` (Codex MCP) and `web_search`, returning 200
    - Codex-side MCP fails invisibly on this lane (W lines in the router log only); plain function tools unaffected
    - #26977's zero hits = path never exercised, not fixed; carry to the P4 docs rewrite
  - Codex phones home under the local profile (chatgpt.com analytics + OTLP); recorded, out of scope here
  - Cleanup: removed the trust entry Codex self-wrote for the ephemeral validation sandbox; marketplace drift left as-is
  - Decode 28.9-37.4 tok/s, acceptance 0.72-0.95; the ~10k-token Codex preamble costs ~42 s cold prefill per session
- [x] Pi best-effort config tried or explicitly deferred
  - Explicitly deferred 2026-08-07 (user: "defer pi for now"); Pi is not installed here, so nothing was rewired
  - No Pi config landed in the repo; wire it from `llamacpp/models.ini` at pickup - does not gate P4

## Phase 4 - staged retirement

- [x] Gate met (claude-local, Open WebUI, OpenCode validated; Codex validated or documented-blocked)
  - Met 2026-08-07: all four cutovers validated (claude-local/OpenCode/Codex 2026-08-04, Open WebUI 2026-08-07)
- [x] ollama.service stopped + disabled (user runs sudo)
  - Done 2026-08-07 (user ran sudo; stop and disable verified live: is-active inactive, is-enabled disabled)
  - Port 11434 closed; store/binaries/override stay frozen on disk until the purge
  - Validation window starts 2026-08-07; purge eligible ~2026-08-21 on explicit user go
- [x] Docs rewritten: architecture.md, AGENTS.md, README, CLAUDE.md note, benchmarking.md pending-action dropped
  - 2026-08-07: six files (those plus openwebui.md and parameters.md touch-ups); all rumdl-clean
  - architecture.md redrawn for the router: runbook, frozen-legacy framing, fresh du figures (HF 199G, store 186G)
  - The silent Responses tool-drop folded into architecture.md + openwebui.md; openwebui.md guidance inverted
  - benchmarking.md pending action replaced by the graphs-ON stance with P1 evidence
  - launch.sh pin documented as record-not-assertion (reconciles the spec's pin-enforcement wording)
- [x] PR #15 review response (2026-08-08): merge-gating comments addressed
  - Applied: README catalog tables deleted (root-cause de-drift); live counts corrected to 20 configs + 9 aliases
  - Spec-class lock lifted by user: spec.md/plan.md carry dated amendments (counts; pin-assert superseded note)
  - q6 aliases reshaped per user: self-identical names dropped; reasoning gains qwen3.6-35b-a3b-reasoning-ud-q6-k
  - launch.sh: --cors-origins localhost added (user picked B4a); overlay/bind comments; build record updated
    - Finding: POST /models executes regardless of CORS or --api-key at 10326 (path-only public-endpoint exemption)
    - Full closure = upstream fix or local patch; neither taken; upstream report not filed (not authorized)
  - Build record: on-disk moved to 10326 (3653e6d6d, 2026-08-07); re-cert pending (crash matrix + froggeric pair)
    - GPU-gated; present-tense prose made version-free so it cannot restale
    - Re-cert RAN 2026-08-08: 10326 FAILS the Qwen-MTP hammer - 2/30 gens crashed the child
      (CUDA illegal memory access, ggml_backend_cuda_synchronize, ggml-cuda.cu:2499; 9860 was 30/30)
    - Passed on 10326: Gemma 12B matrix 6/6 @200k, 26B 6/6 @131072, /v1/messages immunity,
      froggeric patched-pair probes on both guarded GGUFs (no guard 400, tools block rendered)
    - Throughput notes: 12B 99-110 tok/s (9860: 57-61); 26B 21.5-27.7 (9860: 39-42); hammer 108-123
    - launch.sh record stays 9860 last-known-good (pins move on pass); disposition pending user decision
    - Raw evidence: job scratch recert/ (router.log, 42 response JSONs); history log to follow disposition
    - Decided 2026-08-08 (user): disposition = upstream check, rebuild newer, re-run hammer + per-build probes only
      - Upstream check done 2026-08-08: NO fix exists upstream; rebuild-to-fix is off the table (re-decision open)
      - #26609 (OPEN, unlabeled): exact signature - synchronize site :2499, fa path, Qwen3.6-35B MoE; -fa off clears it
      - #26558 (OPEN, unlabeled): draft-mtp, CUDA-graphs cache-corruption theory; GGML_CUDA_DISABLE_GRAPHS=1 soaks clean
      - Tip b10327 = unrelated cpy launch fix; constraints: graphs-off breaks Gemma MTP, fa-off breaks q8_0 V-cache
      - 9860-revert caveat (search agent): 30/30 clean is ~11% by luck at a true 7%/run; blamed design predates 9860
  - Decided 2026-08-08 (user): fleet reshape package, gated on the new-GGUF chat-template gate + the build fix
    - 35B instruct: repoint to unsloth/Qwen3.6-35B-A3B-GGUF (UD-Q6_K + mmproj); rename qwen3.6-35b-a3b-ud-q6-k
      - No compat alias (old-name requests fail visibly); OpenCode/Codex ids swap in the same batch
    - Naming axes: profile token (blank = instruct); -mtp- explicit on every MTP-serving name
      - Vision is the plain lane's mmproj property, not a name token; blank entries are not defaults (no bare alias)
    - qwen3.6-27b gains a blank instruct entry qwen3.6-27b-ud-q4-k-xl (Instruct profile, non-MTP GGUF + mmproj, q4)
      - Fleet becomes 18 configs + 8 alias names at the reshape (ctx mirrors the plain 27B entry, 131072)
    - Queen-27B ids gain quant-tag fidelity -i1-q4-k-m (upstream i1-Q4_K_M, Heretic precedent); no compat alias
    - No alias moves at 27B: qwen3.6-27b-coding stays on the plain coding entry (mtp-explicit rule)
    - Executed 2026-08-08 (GPU-gate closed, config-side): models.ini 18 + 8, OpenCode/Codex swapped, doc counts moved
      - Download complete (29.3G blob, snapshot a483e9e6); stale 16.9G .incomplete removed
      - New-GGUF gate greps: guard 0, merged_system 7 - joins the carriers (now 5 GGUFs / 7 entries)
  - GPU-window queue (gate closed 2026-08-08): diagnosis hammers (graphs-off; fa-off; optional 35B lane hammer)
    - Plus: 31B drafter load test; live probes (gate step 3) for both new instruct entries before first real use
    - Plus: per-build multi-system /v1/messages probe whenever the build moves
  - Resolved 2026-08-08 (user): merged_system exposure accepted + documented (5 GGUFs / 7 entries post-reshape)
    - Those entries would silently drop mid-conversation system messages on /v1/chat/completions (no error surfaces)
    - No live exposure: the one multi-system client rides /v1/messages; OpenAI-endpoint clients send leading-only
    - The gate's merged_system step flags future carriers at vetting; froggeric extension rejected as overengineering
  - claude-local subagent pinning documented in CLAUDE.md (B6a); wrapper change not taken
  - Held by user: OTEL body-log cleanup (B8)
  - Fixed 2026-08-08 (user "1"): the 9-tag whitespace patch is applied to the vendored template; render verified
    - Provenance + new sha recorded in templates/README.md; upstream report (option 2) not taken
    - Gate re-validation of the patched (template, 10326) pair queued with the build re-cert (GPU-gated)
    - Online investigation 2026-08-08 (all 66 repo discussions grepped byte-exact): the bug is unreported - novel
    - It is a v21.3 regression: the vulnerable split landed in the repo's last commit (2026-07-02); v21.2 was immune
    - Qwen/unsloth official templates are immune by construction (single string literal); froggeric-only exposure
    - Undiagnosed symptom threads #55/#56/#64 (broken tool calls "with v21.3") are consistent with this root cause
    - Author pattern: bursty batch fixes, 5-week lull ongoing; best traction = detailed repro report (#43 precedent)
  - Decided 2026-08-08 (user): the #32 window clock does NOT restart at the 10326 re-cert; opened 2026-08-07 stands
  - Decided 2026-08-08 (user, "Q6 quants for 35B are now standard. no more others"): unsuffixed 35B aliases
    repointed q5 -> q6 in models.ini (claude-local follows automatically via its alias)
    - Resolved 2026-08-08 (user): the 35B q5 trio deleted from models.ini - fleet is 17 configs + 9 alias names
    - OpenCode + Codex swapped to the q6 ids (catalog, provider list, and the Codex coding default)
      - ctx limits carry over unchanged (coding 200000; reasoning/instruct 262144)
      - Deleted 2026-08-08 (user go): the 35B UD-Q5_K_XL GGUF blob (26G measured) removed from the HF cache
        - Guest / usage 484G -> 459G; q6 + mmproj blobs untouched; host vhdx reclaim folds into the purge step
        - The frozen q5 canonical Modelfile keeps its dead FROM path (build-time only; store copy serves rollback)
- [ ] Validation window (~2 weeks daily use) completed without rollback
- [ ] Purge (user-confirmed): store deleted, modelfiles/ + create script retired, vhdx compacted (pruned HF
      snapshots already gone at the fleet reduction)
- [ ] Disk numbers and final state recorded in a dated docs/history log
