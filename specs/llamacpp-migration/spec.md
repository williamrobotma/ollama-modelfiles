# llama.cpp migration (option B)

Vetted 2026-07-23; evidence log: `docs/history/2026-07-23-llamacpp-migration-planning.md`.
Executes the 2026-07-17 eval verdict (`docs/history/2026-07-17-llamacpp-eval.md`): retire Ollama, serve from stock llama-server.

## Decisions (locked at planning review, 2026-07-23)

- **Switching: native router mode** (`--models-preset` INI, `--sleep-idle-seconds`); standalone scripts are the escape hatch.
  - llama-swap is the named contingency (~half a day to port the config).
  - Triggers here: a Phase-0 protocol smoke fails, or the Qwen-MTP graphs-on hammer fails.
  - Third trigger is bonsai decision 1: "build the PrismML fork" means adopting llama-swap before ternary onboards.
    - Router children spawn only from the router's own binary (`server-models.cpp`, b9860); a fork build cannot be a child.
    - "Wait for #25707" (the other option) keeps router mode sufficient - ternary would be a normal GGUF entry.
    - The gate lives early in `specs/bonsai-27b` deliberately - ternary is one of the reasons for this migration.
- **Posture**: launcher script first, no daemon; a systemd unit is a post-validation follow-up.
  - Router port `127.0.0.1:11433` (8080 = Open WebUI, 11434 = Ollama until retired, 11435-11438 = benchmarks).
- **Config home**: new top-level `llamacpp/` dir - preset INI, launcher, template files, notes.
  - Git-tracked, peer of `modelfiles/`; bonsai-27b lands here. No secrets in the repo.
- **Web-search parity**: deny `WebSearch` in claude-local; serve search via Ollama's web-search MCP (Brave MCP fallback).
  - Verified: Claude Code fulfills WebSearch by a sub-request to the model server carrying `web_search_20250305`.
  - Ollama's daemon executes that tool mid-generation; stock llama-server turns it into a hollow function tool.
  - Left enabled it would fabricate results silently, hence the deny. The MCP needs only `OLLAMA_API_KEY`, no daemon.
  - Open WebUI's Brave search is client-side and unaffected; Codex, Copilot, and Pi need nothing.
- **Ollama: staged retirement.**
  - Stop + disable after blocking clients validate; keep binary + store as rollback for a ~2-week validation window.
  - Purge is the gated final task: uninstall, delete the 232G store, retire `modelfiles/` + create script, compact vhdx.
  - Everything Ollama-side stays frozen (not edited, not deleted) until that purge.
  - The pending graphs-off systemd fix (docs/benchmarking.md) is cancelled as moot.
- **Prune** (skip migration; delete at purge; ~60G HF-cache reclaim):
  - `models--noctrex--Qwopus3.5-9B-Coder-MTP` (15G): orphaned, no Modelfile ever referenced it.
  - `35b-a3b-mtp-ud-q4-k-xl` + `35b-a3b-mtp-coding-ud-q4-k-xl`: superseded by the q5 pair (~23G blob).
  - Non-MTP `35b-a3b-coding-ud-q4-k-xl` lane (22G repo): unused by any integration.
  - The `35b-a3b-coding` alias repoints to the MTP-q5 coding config; 21 configs + 7 alias names remain.
- **Build pin**: stay on b9860 (fdb1db877).
  - Re-verified 2026-07-23: no tracked-bug fix merged through b10094; new crash reports exist on newer builds.
- **Acceptance clients**: Claude Code, Codex CLI, OpenCode blocking; Pi best-effort.
  - VS Code Copilot is out of scope here -> `specs/copilot-byok` (scaffolded this session).

## Pre-flight additions (2026-07-25)

Evidence log: `docs/history/2026-07-25-llamacpp-preflight.md`. These refine the locked decisions; none reverse one.

- **Pin enforcement is mechanical, not documentary.** The launcher uses the absolute `build/bin/llama-server` path and
  asserts `--version` reports 9860 before starting.
  - Amended 2026-08-08: the version assert was removed 2026-08-03 (tasks.md deviation, user).
    - Per `specs/stack-upkeep`, the pin is a last-known-good record that moves forward when the named check passes.
  - Stale b9552 binaries at the llama.cpp repo root were deleted this session; router children spawn from the router's
    own executable, so launching the wrong one would silently run the whole fleet off-pin.
- **Router mode cannot do per-model env.** Children inherit the router's environment verbatim, so CUDA graphs is a
  router-wide setting.
  - This is why a Qwen-MTP graphs-on failure is a contingency trigger rather than a per-model tuning fix.
  - The escape hatch is a standalone process outside the router; `llamacpp/` must define where those scripts live.
- **Gemma thinking moves from a `SYSTEM` directive to a template kwarg**, which llama.cpp defaults on. The six
  `SYSTEM <|think|>` directives do not migrate, and Phase 0 confirms the behavior on the wire before Phase 2 relies on
  it.
- **Sampling stays neutral across the cutover** so any behavior change is attributable to the engine.
  - Gemma entries pin `min_p 0.0` against llama-server's `0.05` injection.
  - Qwen thinking-general keeps `presence_penalty 0.0` despite the 35B-A3B card's `1.5`; the A/B is a follow-up.
  - MTP lanes keep `--spec-draft-n-max 2` despite Gemma's card recommending 4; the comparison is a follow-up.
- **KV cache type is an open question, probed before Phase 1.** Third-party KL data suggests q8_0 hurts Gemma and not
  Qwen; the ctx ladder must run at whichever type the probe selects.
- **`--mmproj` and MTP are documented incompatible.** Affected GGUFs get two router entries - one MTP, one vision -
  rather than dropping a capability, if the probe confirms the conflict.

## Execution revisions (2026-07-27)

Decided at the first execution session's review; these supersede the specific locked or pre-flight items they name.

- **The preset INI is the entire served fleet.** Router mode also auto-serves every GGUF in the HF cache
  (`load_from_cache()` unconditional at `server-models.cpp:342-345`; still unconditional on master `0e4a03622`;
  opt-out request llama.cpp#18609 closed not-planned).
  - Unsuppressed, every kept model is servable twice - preset name (pinned flags) vs cache name (bare defaults,
    embedded template) - and pruning by omission would not unserve anything.
  - Fix: `launch.sh` sets `LLAMA_CACHE` to an empty directory (first in the cache resolution order,
    `common/hf-cache.cpp:43`). Preset entries are absolute paths and never resolve through the cache.
  - Phase 0 verifies a preset entry loads and generates under the redirect, not just that `/v1/models` is clean.
- **Keep-set narrowed; deletion pulled forward** (supersedes "delete at purge" for these items): OBLITERATUS
  (3 configs + 1 alias), Qwopus (config + Jackrong repo), noctrex repo, 35B q4 MTP pair, and the non-MTP 35B lane
  are deleted now - Modelfiles, Ollama models, and HF cache (~89G) together. Queen-27B and the heretic pair stay.
  - Fleet becomes **17 configs + 6 alias names** (was 21 + 7).
    - Amended 2026-08-08: the q6 trio replaced the 35B q5 trio -> 17 configs + 8 alias names.
  - `35b-a3b-coding` alias repoints to `qwen3.6-35b-a3b-mtp-coding-ud-q5-k-xl` and is rebuilt under Ollama.
  - Guarded fleet drops to 2 GGUFs (unsloth 9B non-MTP, Queen-27B); froggeric applies to the 3 entries they back
    (Queen-27B backs both `queen-27b-*` configs - corrected 2026-07-28, was "two entries").
  - Phase 4 purge shrinks to: Ollama uninstall + 232G store, `modelfiles/` + create-script retirement, vhdx compact.
- **KV probe replaced** (supersedes the same-prompt comparison): Gemma-only `llama-perplexity` KL run, one
  ~16k-token wikitext segment, f16-cache baseline vs q8_0; read the tool's numbers as-is, no pooling.
  - Also record the f16-vs-q8_0 VRAM delta at fixed ctx - the input the ctx ladder actually needs.
  - q8_0 KL small -> keep q8_0 fleet-wide; a ~0.1 signal -> Gemma entries serve f16 and the ladder runs at f16.
  - Qwen is probed only if Gemma surprises. No f8 cache type exists on b9860; bf16 is 16-bit (no VRAM win).
  - `llama-perplexity` must be built first; sha256 `llama-server` before and after to prove the pin untouched.
- **`--models-max` stays stock (4) for now**; the Phase 0 smoke records actual second-model behavior on 12 GB.

## Execution decisions (2026-07-28, round 2 session)

User-confirmed at the Phase 0 pre-implementation review; recorded here per the keep-docs-updated rule.

- **Phase 0 serves `gemma4-12b-it-qat-mtp` at the profile's 200000 ctx**, not the known-stable 16k.
  - The 2026-07-17 eval recorded a gen-5 crash at 200k graphs-on: a ctx-instability crash during the smokes is
    documented behavior, NOT a "protocol smoke fails" contingency trigger. The Phase 1 ladder still bounds the ceiling.
- **froggeric scope corrected**: the 2 guarded GGUFs back 3 preset entries; all 3 get `--chat-template-file`.
- **froggeric template copied at Phase 0** (Phase 2 item pulled forward); byte-identical, sha256 + provenance in
  `llamacpp/templates/README.md`.
- **Stale counts fixed in place**: spec Steps "21 configs" -> 17 + 6; plan preamble "7 alias names" -> 6; tasks.md
  fleet-reduction "20 FROM paths" -> 22 FROM/DRAFT paths (19 FROM + 3 DRAFT, re-verified resolving 2026-07-28).

## Steps (plan.md holds the task breakdown)

1. Phase 0 - router smokes on 11433 with a 3-model preset: all three endpoints, per-child `/props`, sleep-idle, models-max.
2. Phase 1 - Gemma MTP ctx probe (ladder above known-stable 16k, crash matrix, graphs ON); Qwen-MTP graphs-on hammer.
3. Phase 2 - full-fleet preset: 17 configs + 6 aliases (now 17 + 8), full flags, mmproj, drafters, froggeric on guarded.
4. Phase 3 - client cutovers: claude-local, Open WebUI, OpenCode, Codex, Pi (best-effort).
5. Phase 4 - staged retirement: stop + disable, docs rewrite, validation window, gated purge + prune.

## Rules

- Stay on b9860. Any rebuild: re-run the crash matrix (eval log 2b) and re-validate the froggeric (template, build) pair.
- Guarded Qwen GGUFs face OpenAI clients only under the froggeric template (v21.3, snapshot `23a40b0b`, `--jinja`).
- Never scrape `GET /metrics` on the router - it autoloads models and blocks idle sleep (llama.cpp #23096).
- Codex threads start fresh per provider - replayed `web_search_call` history 400s on local backends (codex #24612).

## Watch

- <https://github.com/ggml-org/llama.cpp/pull/24942> - Gemma MTP fix candidate; open, unreviewed (2026-07-23).
- <https://github.com/ggml-org/llama.cpp/issues/24795> - open, no fix merged (re-verified 2026-07-23).
- <https://github.com/ggml-org/llama.cpp/issues/24443> - sibling load-failure issue; open, no fix merged.
- <https://github.com/ggml-org/llama.cpp/issues/25873> - closed `not_planned` but re-confirmed 2026-07-22; treat as live.
- <https://github.com/ggml-org/llama.cpp/issues/25986> - gemma4 parser vs long tool-call args; stalled on a repro.
- New this review:
  - <https://github.com/ggml-org/llama.cpp/issues/26017> - Gemma E4B MTP CUDA crash on b10090.
  - <https://github.com/ggml-org/llama.cpp/issues/25618> - draft-MTP greedy divergence on quantized targets (correctness).
  - <https://github.com/ggml-org/llama.cpp/issues/25828> - closed, same crash family, resolution unknown.
- <https://github.com/ggml-org/llama.cpp/pull/25707> - ternary gate (bonsai); open, blocked, needs rebase (2026-07-23).
- <https://github.com/mostlygeek/llama-swap/issues/946> - TTL race deadlock; matters only if a contingency trigger fires.

## Done when

- Every non-pruned model serves from router mode via `llamacpp/`, launched by one script.
- Blocking clients validated on the lane:
  - claude-local: real session with tool loops, prefix-cache hits, MCP web search working, WebSearch denied.
  - Codex: tool loop tested; if upstream-broken, documented and the Ollama gate holds until resolved.
  - OpenCode: sessions work with per-model context limits set.
  - Open WebUI: search-enabled chat smoke passes on the OpenAI connection.
- Gemma MTP serves at the probed ctx ceiling, graphs ON; results recorded in a dated history log.
- ollama.service stopped + disabled; purge executed after the validation window.
- `llamacpp/` documents where per-model serving config lives; architecture.md, AGENTS.md, README rewritten.
- tasks.md items all checked or explicitly deferred with reasons.
