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
- [x] Name-parity check against `ollama list`; 3 spot-loads verified via `/props`
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
- [ ] Open WebUI on OpenAI connection 11433; fleet in picker; search-enabled chat passes
  - Prep 2026-08-04: backup `~/.open-webui/webui.db.bak-pre-0.11.0` taken, then the pending 0.11.0 first start ran
    - 9 alembic migrations + 13 seeded config defaults; documented settings and the Brave key intact; serve up on 8080
    - Remaining (user, browser): enable the OpenAI toggle (still false in the DB), add 11433/v1, picker + chat checks
    - During the first chat: check the outgoing body for client-injected temperature/top_p (OpenAI-connection unknown)
- [x] OpenCode provider block + context limits; search-tool behavior recorded
  - Applied 2026-08-04 (user consent, "no model left behind"): 12-model provider block with per-model limits
  - Validated: real tool-loop session fixed a file on disk; requests hit 11433 (no #5674 symptom); picker lists all 12
  - Search recorded: no websearch tool exists in opencode 1.16.2 - webfetch only; the "search via Ollama" belief closed
  - Seam clean (no P0-style block overlap); upstream client bug found: `opencode run` drops final text from stdout
    - 4/4 sessions, stored text intact via `opencode export`; TUI untested; non-blocking for the cutover
  - Decode 23.2-34.0 tok/s, acceptance 0.71-0.99; zero E/W or CUDA lines across the session's 192 router-log lines
- [ ] Codex custom provider (Responses, fresh threads); tool loop tested or upstream-blocked documented
- [ ] Pi best-effort config tried or explicitly deferred

## Phase 4 - staged retirement

- [ ] Gate met (claude-local, Open WebUI, OpenCode validated; Codex validated or documented-blocked)
- [ ] ollama.service stopped + disabled (user runs sudo)
- [ ] Docs rewritten: architecture.md, AGENTS.md, README, CLAUDE.md note, benchmarking.md pending-action dropped
- [ ] Validation window (~2 weeks daily use) completed without rollback
- [ ] Purge (user-confirmed): store deleted, modelfiles/ + create script retired, vhdx compacted (pruned HF
      snapshots already gone at the fleet reduction)
- [ ] Disk numbers and final state recorded in a dated docs/history log
