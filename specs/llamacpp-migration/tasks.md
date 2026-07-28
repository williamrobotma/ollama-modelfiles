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
  - 86G freed. The q4/q5 blobs were confirmed distinct before deletion.
  - All 22 kept `FROM`/`DRAFT` paths resolve (19 + 3, corrected from 20, re-verified 2026-07-28).

## Phase 0 - router protocol smokes

Completed 2026-07-28, all 11 smokes passed; evidence: `docs/history/2026-07-28-llamacpp-p0-smokes.md`.

- [x] `llamacpp/` skeleton: 3-model preset INI (incl. the guarded 9B non-MTP) + launcher on 11433
  - Verified: all 19 keys map to b9860 flags, every referenced path resolves, and the copy is sha256-identical.
  - The `[*]`-global and comment mechanics were source-checked in `common/preset.cpp`.
- [x] Launcher uses the absolute build/bin path and aborts unless `--version` reports 9860
  - Verified: the assert substring matches live `--version` output and `bash -n` passes.
  - The abort branch stays untested (accepted).
- [x] Router up: `/v1/models` lists only preset entries (no phantom `default`, no HF-cache auto-discovery)
  - One generation completed under the `LLAMA_CACHE` redirect.
- [x] `/v1/messages` smoke via router: basic, streaming, tool loop, cache hits (427 cached tokens on turn 2)
  - A streaming block-overlap quirk at the thinking->text boundary is logged for the P3 claude-local validation.
- [x] Multi-system immunity check on `/v1/messages` (per-build) - a two-block system request returns 200
- [x] `/v1/chat/completions` + froggeric on a guarded Qwen - a mid-conversation system message returns 200
  - The served template is byte-identical to the pinned copy.
- [x] `/v1/responses` Codex-shaped smoke with a function tool - the round-trip completes with no 500
- [x] Per-child `/props` matches docs/parameters.md profile - all 3 children match exactly
  - `/props` `n_predict -1` is a pin display artifact. The request default is the flag value (server-schema.cpp:503).
- [x] Sleep-idle unload/reload observed (sleeping, VRAM released, ~3 s wake); models-max behavior recorded
  - Two 9B children coexist at full speed (11.5/12.3 GiB) with no eviction.
- [x] Gemma thinking confirmed on the wire with no flags set; disable path and `-rea` mapping recorded
  - `enable_thinking:false` disables it per-request, and `-rea off` disables it at launch.
- [x] MTP x `--mmproj` behavior recorded - b9860 serves both from one entry with no conflict
  - The image round-trip works with drafting active at a ~35-40% decode penalty, so P2 splits entries for speed.
- [x] Gemma drafter auto-discovery from a local snapshot path tested - none exists
  - The child dies without `model-draft` (`failed to create MTP context`). Explicit wiring is mandatory.

## Phase 1 - stability envelopes

- [ ] Gemma KV probe: llama-perplexity KL (f16 vs q8_0, one ~16k segment) + VRAM delta; type fixed before the
      ladder; Qwen only if Gemma surprises
- [ ] Gemma 12B MTP ctx ladder (32k..200k, crash matrix per rung, graphs ON); pick ceiling
- [ ] 26B MTP pair checked at the chosen ceiling
- [ ] Qwen-MTP graphs-on hammer, 30 gens, 0 crashes (crash = contingency trigger)
- [ ] Results written to a dated docs/history log

## Phase 2 - full-fleet config home

- [ ] Preset INI: 17 configs + 6 aliases, full flags, mmproj, drafters, froggeric on the 3 guarded-GGUF entries
- [ ] Serving flags set (`-fa on`, KV type, `-np 1`, `--jinja`) and explicit `min_p` on every entry
- [ ] froggeric template pinned into `llamacpp/templates/`
- [ ] `llamacpp/README.md`: layout, alias policy, add-a-model procedure
- [ ] Name-parity check against `ollama list`; 3 spot-loads verified via `/props`

## Phase 3 - client cutovers

- [ ] claude-local rewired: base URL 11433, tier vars, `--disallowedTools WebSearch`, web-search MCP
- [ ] `OLLAMA_API_KEY` moved to a user-readable env file for the MCP
- [ ] claude-local validated: tool loop, live MCP search, body-log check, cache hits, WebFetch
- [ ] Open WebUI on OpenAI connection 11433; fleet in picker; search-enabled chat passes
- [ ] OpenCode provider block + context limits; search-tool behavior recorded
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
