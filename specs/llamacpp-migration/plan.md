# Plan: llama.cpp migration

Written 2026-07-23 from the vetted spec; evidence in `docs/history/2026-07-23-llamacpp-migration-planning.md`.

Every GPU-loading step is a heavy load: announce and get user confirmation before starting it.

## Phase 0 - router protocol smokes (GPU, light)

- Skeleton first: `llamacpp/` preset INI with two models (`qwen3.5-9b-mtp-coding`, `gemma4-12b-it-qat-mtp` + drafter).
- Launcher script runs `llama-server --models-preset ... --sleep-idle-seconds 86400` on `127.0.0.1:11433`.

1. Router starts; `/v1/models` lists both entries.
   - verify: curl output shows both names and no phantom `default` entry.
2. `/v1/messages` through the router (routed by the body's `model` field): basic, streaming, one tool loop.
   - verify: Anthropic-shaped response from the correct child; `cache_read_input_tokens` grows on turn 2.
3. Multi-system immunity check on `/v1/messages` (chat-template-refresh procedure, once per build).
   - verify: a two-block system request does not 400.
4. `/v1/chat/completions` on a guarded Qwen under froggeric.
   - verify: a multi-system request answers, no 400.
5. `/v1/responses` minimal Codex-shaped request including one function tool.
   - verify: the tool call round-trips, no 500.
6. Per-child `/props` (`?model=` selects the child) reflects the preset's sampling flags (GGUF metadata must not leak through).
   - verify: values match the docs/parameters.md profile exactly.
7. Sleep-idle: relaunch with a short timer (e.g. 30s) for this check, wait past it, then send a request.
   - verify: unload observed, reload succeeds, response OK.
8. models-max: request the second model while the first is loaded.
   - verify: behavior recorded (evict or coexist) for the config-home README.

Contingency: any protocol smoke fails -> llama-swap (port the preset to YAML, re-run this phase through it).

## Phase 1 - stability envelopes (GPU, heavy)

1. Gemma MTP ctx probe on the 12B pair, graphs ON: ladder 32k -> 64k -> 96k -> 128k -> 160k -> 200k.
   - At each rung run the crash-matrix protocol (eval log section 2b: repeated gens, N stated).
   - Stop at the first unstable rung; serve at the highest stable rung.
   - verify: dated history log holds the full matrix.
2. Re-check the chosen ceiling once on the 26B pair (partial offload).
   - verify: stable N gens, or a lower 26B-specific ceiling recorded.
3. Qwen-MTP graphs-on hammer: 30 gens on `qwen3.5-9b-mtp` (repro-mtp-graphs.sh shape, against a router child).
   - verify: 0 crashes. Any crash = contingency trigger (that model to a graphs-off standalone script, or llama-swap).

## Phase 2 - full-fleet config home

1. Fill the preset INI: 21 configs (18 canonical + 6 layered - 3 pruned) and 7 alias names.
   - Full sampling flags per docs/parameters.md (GGUF metadata overrides any flag not set - eval log section 3).
   - `--mmproj` for vision canonicals; drafter + `--spec-type draft-mtp --spec-draft-n-max 2` for MTP lanes.
   - froggeric `--chat-template-file` on every guarded Qwen entry; per-model ctx (Gemma from Phase 1).
   - `35b-a3b-coding` alias -> the MTP-q5 coding config; pruned models get no entry.
2. Copy froggeric v21.3 `chat_template.jinja` into `llamacpp/templates/` with its `23a40b0b` provenance noted.
3. Write `llamacpp/README.md`: layout, alias policy, add-a-model procedure (bonsai's entry point).
   - verify: name parity - every non-pruned `ollama list` name resolves to a router entry or alias.
4. Spot-load 3 representative configs (one per family).
   - verify: `/props` matches the profile; one generation each.

## Phase 3 - client cutovers (order: claude-local, Open WebUI, OpenCode, Codex, Pi)

1. claude-local rewire (`~/.bashrc` fn + `~/.config/claude-local.env` - user files, edit with consent):
   - `ANTHROPIC_BASE_URL=http://127.0.0.1:11433`, dummy auth token, tier vars -> `qwen3.6-35b-a3b-mtp-coding`.
   - Drop `ollama launch`; exec `claude --disallowedTools WebSearch` (scoped deny - cloud sessions keep WebSearch).
   - Wire the Ollama web-search MCP (stdio, `OLLAMA_API_KEY` from `~/.config`, never the repo); Brave MCP is the fallback.
   - Move `OLLAMA_API_KEY` into a user-readable env file (it currently sits only in the systemd override).
   - verify: real session - tool loop completes, MCP search returns live results, WebFetch fetch + summary works.
   - verify: body log shows no `web_search_20250305` sub-request; `cache_read_input_tokens` > 0 on later turns.
2. Open WebUI: add the OpenAI connection `http://127.0.0.1:11433/v1` in the Admin UI; disable the Ollama connection.
   - Raise `AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST` only if the picker times out against a cold router.
   - verify: picker lists the fleet; one chat per family; one search-enabled (Brave) chat end-to-end.
3. OpenCode: `opencode.jsonc` provider (`@ai-sdk/openai-compatible`, `:11433/v1`) + per-model context/output limits.
   - verify: session with tool calls; record which search tool (if any) fires - see the evidence log's discrepancy note.
4. Codex: `~/.codex/config.toml` custom provider (`base_url` `:11433/v1`, wire_api responses, fresh threads only).
   - Known upstream risk: tool calls vs llama-server Responses (codex #26977 open, #10635 closed-unknown).
   - verify: tool loop test. If upstream-broken: document it, keep Codex on Ollama, the retirement gate holds.
5. Pi (best-effort): `~/.pi/agent/models.json`, `openai-completions` at `:11433/v1`.
   - verify: one session, or explicitly defer.

## Phase 4 - staged retirement

1. Gate: claude-local + Open WebUI + OpenCode validated; Codex validated or documented-blocked.
2. `sudo systemctl stop ollama && sudo systemctl disable ollama` (user runs; binary + store kept for rollback).
3. Docs rewrite for the new lane:
   - architecture.md (new stack diagram), AGENTS.md (serving + build sections), README, CLAUDE.md claude-local note.
   - benchmarking.md drops the pending graphs-off systemd action (moot).
   - verify: rumdl clean; no doc claims Ollama serves anything.
4. Validation window: ~2 weeks of daily use; rollback is `systemctl start ollama` (nothing deleted yet).
5. Purge (gated on the window; confirm with user - destructive):
   - `ollama rm` all, uninstall Ollama, delete the `/usr/share/ollama` store (232G).
   - Delete pruned HF snapshots (~60G): noctrex repo, 35B q4 MTP blob, non-MTP 35B repo.
   - Retire `modelfiles/` + `scripts/ollama-create.sh` (git rm; history preserves them).
   - User runs `wsl --shutdown` + `Optimize-VHD` host-side; budget against `df /mnt/f` before and after.
   - verify: disk numbers in a dated history log; every client unaffected in its next session.

## Deferred / follow-ups

- systemd unit for the router (after the validation window).
- `specs/copilot-byok` (scaffolded; VS Code Copilot Custom Endpoint).
- bonsai-27b decision 1 (wait for #25707 vs build the PrismML fork) gates llama-swap adoption; early gate in that spec.
- stack-upkeep: add the router INI schema and the froggeric pair to the per-rebuild re-vet checklist.
