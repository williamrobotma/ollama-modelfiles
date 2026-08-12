# Plan: llama.cpp migration

Written 2026-07-23 from the vetted spec; evidence in `docs/history/2026-07-23-llamacpp-migration-planning.md`.

Every GPU-loading step is a heavy load: announce and get user confirmation before starting it.

Two markers run through this file:

- `verify:` - the check that closes the step it sits under.
- `Amended YYYY-MM-DD:` - a later change to the item it sits under.

## Phase 0 - router protocol smokes (GPU, light)

- Skeleton first: `llamacpp/` preset INI with three models: `qwen3.5-9b-mtp-coding-ud-q4-k-xl`,
  `gemma4-12b-it-qat-mtp` + drafter, and `qwen3.5-9b-coding-ud-q4-k-xl`.
  - The third is the guarded Qwen that smoke 4 needs; both originally-named models are guard-free
    (AGENTS.md scan: MTP GGUF 0 hits, non-MTP 9B 1 hit).
- Launcher script runs `llama-server --models-preset ... --sleep-idle-seconds 86400` on `127.0.0.1:11433`.
  - Absolute path to `~/Developer/llama.cpp/build/bin/llama-server`, and abort unless `--version` reports 9860.
  - `LLAMA_CACHE` pointed at an empty directory so the preset is the whole served fleet (spec execution revisions).
- Preset mechanics are confirmed from source on the pin, so Phase 2 can rely on them.
  - Evidence: `docs/history/2026-07-25-llamacpp-preflight.md`.
  - Sections take dash-stripped CLI flag names; `[*]` is the global section.
  - `--alias` carries the 6 alias names as a comma-separated value.
  - `default` is NOT a global: only `*` short-circuits to the global preset in `common_preset_context::load_from_ini`.
  - A `[default]` section is served as a model entry: a served model named `default` that no one configured.

1. Router starts; `/v1/models` lists exactly the preset entries.
   - verify: curl output shows the three names, no `default` entry, and no auto-discovered HF-cache entries.
   - verify: one generation against a preset entry succeeds under the `LLAMA_CACHE` redirect.
2. `/v1/messages` through the router (routed by the body's `model` field): basic, streaming, one tool loop.
   - verify: Anthropic-shaped response from the correct child; `cache_read_input_tokens` grows on turn 2.
3. Multi-system immunity check on `/v1/messages` (chat-template-refresh procedure, once per build).
   - verify: a two-block system request does not 400.
4. `/v1/chat/completions` on a guarded Qwen under froggeric.
   - verify: a multi-system request answers, no 400.
   - Amended 2026-08-10 (applies to items 3-4): "no 400" was build-true then; the guard's HTTP status varies by
     build (500 at b10335), so vet on the guard message text, never the status code (AGENTS.md gate step 3).
5. `/v1/responses` minimal Codex-shaped request including one function tool.
   - verify: the tool call round-trips, no 500.
6. Per-child `/props` (`?model=` selects the child) reflects the preset's sampling flags, not the GGUF metadata values.
   - verify: values match the docs/parameters.md profile exactly.
7. Sleep-idle: relaunch with a short timer (e.g. 30s) for this check, wait past it, then send a request.
   - verify: unload observed, reload succeeds, response OK.
8. models-max: request the second model while the first is loaded (stock `--models-max 4`, per spec revisions).
   - verify: behavior recorded (evict or coexist) for `llamacpp/README.md`.
   - On 12 GB two ~9 GiB children cannot coexist: label an eviction as VRAM-forced, not router policy.
9. Gemma thinking in a live response: one request to the Gemma child with no thinking flags set.
   - verify: a thought channel appears, confirming llama.cpp's `enable_thinking` default reaches the template.
   - verify: `--chat-template-kwargs '{"enable_thinking":false}'` suppresses it, and record what `-rea off` does.
10. MTP x `--mmproj`: launch one entry carrying both against `qwen3.5-9b-mtp-coding`.
    - verify: record whether it refuses, ignores the projector, or serves both.
    - If it conflicts, split that GGUF into two entries (one drafter, one `--mmproj`) and confirm both load.
11. Gemma drafter discovery: launch the Gemma pair without an explicit drafter flag.
    - verify: whether auto-discovery works from a local snapshot path or explicit wiring is required.

Contingency: any protocol smoke fails -> llama-swap (port the preset to YAML, re-run this phase through it).

## Phase 1 - stability envelopes (GPU, heavy)

0. KV cache type probe, before the ladder (Gemma-only KL, per spec execution revisions).
   - Build `llama-perplexity` first; sha256 `llama-server` before and after to prove the pin untouched.
   - One ~16k-token wikitext segment on the 12B QAT canonical: f16-cache baseline run (~8.6 GB base file, deleted
     after), q8_0 comparison run with `--kl-divergence`; read the tool's numbers as-is.
   - verify: KL numbers plus the f16-vs-q8_0 VRAM delta at fixed ctx, both recorded in the history log.
   - Decision rule: q8_0 KL small -> q8_0 fleet-wide; a ~0.1 signal -> Gemma serves f16 and the ladder runs at f16.
   - Qwen is probed only if the Gemma result is outside the decision rule.
   - The chosen type is fixed for the ladder below, since KV type changes the VRAM the ladder is measuring.
1. Gemma MTP ctx probe on the 12B pair, graphs on: ladder 32k -> 64k -> 96k -> 128k -> 160k -> 200k.
   - At each rung run the crash-matrix protocol (eval log section 2b: repeated gens, N stated).
   - Stop at the first unstable rung; serve at the highest stable rung.
   - verify: dated history log holds the full crash matrix.
2. Re-check the chosen ceiling once on the 26B pair (partial offload).
   - verify: stable N gens, or a lower 26B-specific ceiling recorded.
3. Qwen-MTP graphs-on hammer: 30 gens on `qwen3.5-9b-mtp` (repro-mtp-graphs.sh shape, against a router child).
   - verify: 0 crashes. Any crash = contingency trigger (that model to a graphs-off standalone script, or llama-swap).

## Phase 2 - full-fleet config home

1. Fill the preset INI: 17 configs and 6 alias names (2026-07-27 fleet reduction).
   - Amended 2026-08-08: the q6 trio replaced the 35B q5 trio -> 17 configs + 8 alias names.
   - Amended 2026-08-08 (reshape): blank-instruct ids, 27B instruct entry, Queen i1 tags -> 18 configs + 8 aliases.
   - Amended 2026-08-09: quants removed from served ids; the alias layer collapses -> 18 configs + 1 alias name.
   - Amended 2026-08-11 (user): 27B gains a reasoning mode (`qwen3.6-27b-mtp-reasoning`), mirroring the
     35B-A3B instruct/coding/reasoning trio, and Queen-27B gains an instruct entry (`qwen3.5-queen-27b`)
     -> 20 configs + 1 alias name; froggeric now covers 4 entries. Record: tasks.md.
   - Every key sits under a `[section]` header.
   - A top-level key silently becomes a served model named `default` that no one configured.
   - The upstream example's top-level `version = 1` does exactly this - do not copy it.
   - Full sampling flags per docs/parameters.md (GGUF metadata overrides any flag not set - eval log section 3).
   - Serving flags per docs/parameters.md (Serving flags): `-fa on`, `-ctk`/`-ctv` (Phase 1's choice), `-np 1`, `--jinja`.
   - Explicit `min_p` on every entry, Gemma included, or llama-server injects `0.05`.
   - `--chat-template-kwargs '{"enable_thinking":false}'` on the instruct-mode entry; Gemma needs no thinking flag.
   - `--mmproj` for vision canonicals; drafter + `--spec-type draft-mtp --spec-draft-n-max 2` for MTP lanes.
     - `--spec-draft-n-max` defaults to 3 on the pin, not 2 - it must be explicit on every MTP entry.
     - Where an entry wants both, split it per the Phase 0 probe: one MTP entry plus one `--mmproj` entry.
   - froggeric `--chat-template-file` on the 3 guarded-GGUF entries (9B non-MTP; Queen-27B coding + reasoning);
     per-model ctx (Gemma from Phase 1).
   - `35b-a3b-coding` alias -> the MTP-q5 coding entry (already repointed on disk at the fleet reduction).
2. Copy froggeric v21.3 `chat_template.jinja` into `llamacpp/templates/` with its `23a40b0b` provenance noted.
3. Write `llamacpp/README.md`: layout, alias policy, add-a-model procedure (bonsai's entry point).
   - verify: name parity - every kept `ollama list` name resolves to a router entry id or an `aliases[]` member
     (aliases are not top-level ids in `/v1/models`; pickers built from `.data[].id` will not show them).
4. Spot-load 3 representative entries (one per family).
   - verify: `/props` matches the profile; one generation each.

## Phase 3 - client cutovers (order: claude-local, Open WebUI, OpenCode, Codex, Pi)

1. claude-local rewire (`~/.bashrc` fn + `~/.config/claude-local.env` - user files, edit with consent):
   - `ANTHROPIC_BASE_URL=http://127.0.0.1:11433`, dummy auth token, tier vars -> `qwen3.6-35b-a3b-mtp-coding`.
   - Drop `ollama launch`; exec `claude --disallowedTools WebSearch` (scoped deny - cloud sessions keep WebSearch).
   - Wire the Ollama web-search MCP (stdio, `OLLAMA_API_KEY` from `~/.config`, never the repo); Brave MCP is the fallback.
   - Move `OLLAMA_API_KEY` into a user-readable env file (it currently sits only in the systemd override).
   - verify: real session - tool loop completes, MCP search returns live results, WebFetch fetch + summary works.
   - verify: body log shows no `web_search_20250305` sub-request; `cache_read_input_tokens` > 0 on later turns.
   - verify: a tool loop containing thinking blocks completes (llama-server returns them with `signature: ""`;
     a client that validates signatures would reject them).
2. Open WebUI: add the OpenAI connection `http://127.0.0.1:11433/v1` in the Admin UI; disable the Ollama connection.
   - Raise `AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST` only if the picker times out against a cold router.
   - The picker will show the 17 canonical ids only - aliases are not top-level ids in `/v1/models`.
   - verify: picker lists the fleet; one chat per family; one search-enabled (Brave) chat end-to-end.
3. OpenCode: `opencode.jsonc` provider (`@ai-sdk/openai-compatible`, `:11433/v1`) + per-model context/output limits.
   - verify: session with tool calls; record which search tool (if any) fires - see the evidence log's discrepancy note.
4. Codex: `~/.codex/config.toml` custom provider (`base_url` `:11433/v1`, wire_api responses, fresh threads only).
   - Known upstream risk: tool calls vs llama-server Responses (codex #26977 open, #10635 closed-unknown).
   - verify: tool loop test.
   - If upstream-broken: document it and keep Codex on Ollama; Ollama stays running until this is resolved.
5. Pi (best-effort): `~/.pi/agent/models.json`, `openai-completions` at `:11433/v1`.
   - verify: one session, or explicitly defer.

## Phase 4 - staged retirement

1. Prerequisites: claude-local + Open WebUI + OpenCode validated; Codex validated or documented-blocked.
2. `sudo systemctl stop ollama && sudo systemctl disable ollama` (user runs; binary + store kept for rollback).
3. Docs rewrite for the new serving stack:
   - architecture.md (new stack diagram), AGENTS.md (serving + build sections), README, CLAUDE.md claude-local note.
   - benchmarking.md drops the pending graphs-off systemd action (no longer applies - Ollama no longer serves).
   - verify: rumdl clean; no doc claims Ollama serves anything.
4. Validation window: ~2 weeks of daily use; rollback is `systemctl start ollama` (nothing deleted yet).
5. Purge (started only after the validation window closes; confirm with user - destructive):
   - `ollama rm` all, uninstall Ollama, delete the `/usr/share/ollama` store (232G).
   - (Pruned HF snapshots already deleted at the 2026-07-27 fleet reduction - nothing HF-side left to purge.)
   - Retire `modelfiles/` + `scripts/ollama-create.sh` (git rm; history preserves them).
   - User runs `wsl --shutdown` + `Optimize-VHD` host-side; budget against `df /mnt/f` before and after.
   - verify: disk numbers in a dated history log; every client unaffected in its next session.

## Deferred / follow-ups

- Benchmark `presence_penalty` 1.5 vs 0.0 on `qwen3.6-35b-a3b-mtp-reasoning` (diverges from its card).
  - Preflight log has the divergence; held out of the migration to keep the cutover sampling-neutral.
- Benchmark `--spec-draft-n-max` 4 vs 2 on the Gemma MTP lanes; unsloth's Gemma card recommends 4, the fleet runs 2.
- systemd unit for the router (after the validation window).
- `specs/copilot-byok` (scaffolded; VS Code Copilot Custom Endpoint).
- bonsai-27b decision 1 (wait for #25707 vs build the PrismML fork) blocks llama-swap adoption; it sits early in that spec.
- stack-upkeep: add the router INI schema and the froggeric pair to the per-rebuild re-vet checklist.
