# Tasks: llamacpp-migration

Planning done 2026-07-23 (spec vetted, plan.md filled). Details and verify steps per item live in `plan.md`.

GPU-loading items are heavy loads: get user confirmation before starting each.

## Pre-flight (2026-07-25)

- [x] Stale b9552 binaries deleted from the llama.cpp repo root; build/bin b9860 is the only one left
- [x] Router preset, alias, and child-env mechanics verified from source on the pin
- [x] Gemma thinking mechanism traced across Google, unsloth, the GGUF template, and llama.cpp source
- [x] Sampling and MTP claims verified against vendor cards; conflicts recorded in docs/parameters.md
- [x] Findings written to docs/history/2026-07-25-llamacpp-preflight.md

## Phase 0 - router protocol smokes

- [ ] `llamacpp/` skeleton: 2-model preset INI + launcher on 11433
- [ ] Launcher uses the absolute build/bin path and aborts unless `--version` reports 9860
- [ ] Router up, `/v1/models` clean (no phantom `default`)
- [ ] `/v1/messages` smoke via router: basic, streaming, tool loop, cache hits
- [ ] Multi-system immunity check on `/v1/messages` (per-build)
- [ ] `/v1/chat/completions` + froggeric on a guarded Qwen
- [ ] `/v1/responses` Codex-shaped smoke with a function tool
- [ ] Per-child `/props` matches docs/parameters.md profile
- [ ] Sleep-idle unload/reload observed; models-max behavior recorded
- [ ] Gemma thinking confirmed on the wire with no flags set; disable path and `-rea` mapping recorded
- [ ] MTP x `--mmproj` behavior recorded; two-entry split confirmed to load if they conflict
- [ ] Gemma drafter auto-discovery from a local snapshot path tested

## Phase 1 - stability envelopes

- [ ] KV cache f16 vs q8_0 probed on our own quants (quality + VRAM); type fixed before the ladder
- [ ] Gemma 12B MTP ctx ladder (32k..200k, crash matrix per rung, graphs ON); pick ceiling
- [ ] 26B MTP pair checked at the chosen ceiling
- [ ] Qwen-MTP graphs-on hammer, 30 gens, 0 crashes (crash = contingency trigger)
- [ ] Results written to a dated docs/history log

## Phase 2 - full-fleet config home

- [ ] Preset INI: 21 configs + 7 aliases, full flags, mmproj, drafters, froggeric where guarded
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
- [ ] Purge (user-confirmed): store + pruned snapshots deleted, modelfiles/ + create script retired, vhdx compacted
- [ ] Disk numbers and final state recorded in a dated docs/history log
