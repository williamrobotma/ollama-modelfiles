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

## Steps (plan.md holds the task breakdown)

1. Phase 0 - router smokes on 11433 with a 2-model preset: all three endpoints, per-child `/props`, sleep-idle, models-max.
2. Phase 1 - Gemma MTP ctx probe (ladder above known-stable 16k, crash matrix, graphs ON); Qwen-MTP graphs-on hammer.
3. Phase 2 - full-fleet preset in `llamacpp/`: 21 configs, full sampling flags, `--mmproj`, drafters, froggeric where guarded.
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
