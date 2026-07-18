# 2026-07-17: llama.cpp serving eval (specs/llamacpp-serving, option C)

Spec review 2026-07-16 picked **option C (evaluation first)** with the recorded intent that the end goal is dropping Ollama entirely (option B) once blockers clear. This log is the eval evidence and the A-vs-B verdict, framed against that goal. Environment: WSL2, RTX 4070 (12282 MiB), stock llama.cpp **b9860 (fdb1db877)** at `~/Developer/llama.cpp` (checkout == binary, tree clean, source-verified), Ollama **0.31.2** systemd (vendored llama.cpp ~b9840; note AGENTS.md still records 0.31.1). Web/GitHub facts were gathered 2026-07-16/17 by a research fan-out with an independent adversarial re-verification pass; on-box numbers are from this session's smokes, a crash matrix, and the new `benchmarks/llamacpp-parity` suite.

## Headline findings

1. **#24795 is config-gated, not build-gated, on this box.** The Gemma MTP drafter load failure reproduces on b9860 ONLY with `GGML_CUDA_DISABLE_GRAPHS=1`: at 200k ctx the drafter fails to load with the issue's exact signature (`Gemma4Assistant requires ctx_other` -> `vector::_M_range_check`); at 16k it loads but dies 817 tokens into the first generation (`CUDA error: misaligned address`). With CUDA graphs ON at moderate ctx, stock serves Gemma MTP stably at ~1.8x. This reconciles the 2026-07-10 on-box repro (graphs-off migration env) with this session's initial non-repro (graphs-on defaults).
2. **Ollama's Gemma MTP `DRAFT` lane is broken on-box on 0.31.2**: `CUDA error: an illegal memory access` in `common_speculative_impl_draft_mtp::process` on 9 of 10 requests (6/6 at the Modelfile's 200k ctx, 3/4 at a 16k override; all graphs-off, the suite/prod-target env). The spec's founding premise - "Ollama is the only working CUDA path for Gemma MTP" - is inverted: today stock has the only working Gemma MTP configuration.
3. **Stock llama-server natively serves the Anthropic API.** `/v1/messages` + `/v1/messages/count_tokens` are in b9860, including tools, streaming, system block arrays, thinking mapping, and a Claude-Code-specific prefix-cache fix. On-box smokes all pass.
4. **Throughput parity: stock beat Ollama on every measured cell** (each engine in the config it would actually run: Ollama graphs-off prod target, stock defaults): gemma12b +16%, qwen9b +6-14%, qwen9b-mtp +4-13%, and stock-only gemma12b-mtp at 1.83x.
5. **Chat-template gate:** the unsloth Qwen3.5-9B (non-MTP) GGUF embeds a `System message must be at the beginning` Jinja guard; llama-server's OpenAI endpoint 400s multi-system requests against it. The Anthropic path is structurally immune. No other fleet GGUF has the guard.
6. **The spec's UNVERIFIED sampling rumor is resolved:** bare llama-server injects temp 0.8 / top_k 40 / top_p 0.95 / min_p 0.05 (not top_p 0.9) into requests that omit them; launch flags reset the served defaults; `GET /props` exposes the effective values.

## 1. #24795 re-verification

Upstream (all claims adversarially re-verified against api.github.com):

- Issue open, `bug-unconfirmed`, unassigned; created 2026-06-19, last updated 2026-06-30. Title claims regression window b9553 -> b9702/b9717, not bisected.
- No fix merged anywhere through **b10064** (latest at check, 2026-07-17): zero commit-search hits for 24795/24443, `src/models/gemma4-assistant.cpp` touched only by the two original support PRs (#23398, #24282), and none of the range's 204 commits touch gemma4 files (version-delta pass, specs/stack-upkeep/spec.md appendix).
- The live fix candidate is **PR #24942** (server: disable embeddings/pooling on the speculative draft/MTP context; llama-cli unaffected). Open, unmerged, merge-dirty, gated by the new-contributor bot. Sibling issue #24443 also open.
- Upstream reports are contradictory (works for some setups, not others; one contributor blames VRAM exhaustion). The on-box crash matrix below explains our instance: the trigger here is the CUDA-graphs-off env combined with ctx size, on an otherwise idle GPU - not VRAM pressure.

Consequence for B: do not gate the migration on #24795 closing. On this box the drafter loads and runs under graphs-on; the pre-B rule is to keep Gemma MTP processes on graphs-on at a capped ctx (see crash matrix), re-check after every llama.cpp rebuild, and watch #24942/#24795/#24443 for the real fix.

## 2. MTP speculative decoding on stock (smokes)

Single-request smokes, stock defaults (CUDA graphs ON), 16k ctx unless noted:

| config | decode tok/s | acceptance |
|---|---|---|
| Qwen3.5-9B non-MTP (131k ctx, phase-1 smoke) | 77.0 | - |
| Qwen3.5-9B-MTP `--spec-type draft-mtp` | 123.2 | 0.81, mean len 2.62 |
| Gemma4-12B plain | 60.5 | - |
| Gemma4-12B + mtp drafter | 115.8-119.8 (3 runs) | 0.75-0.81, mean len ~2.6 |
| Gemma4-12B plain, 200k ctx | 38.1 | - |
| Gemma4-12B `--spec-type ngram-mod`, 200k ctx | 14.0 | no accepted drafts |
| Gemma4-26B-A4B + mtp drafter, CPU-only load test | loads, generates | 0.94 (16 drafts) |

- Drafter-free `ngram-mod` is a clear negative on this workload (14 vs 38.1 tok/s): pure overhead, zero accepted drafts. Moot anyway - the real drafter loads (under graphs-on).
- A negative control (drafter without `--spec-type draft-mtp`) also loads and runs: the spec-type flag was not the gating variable; the graphs env was (section 2b).
- Flag mapping: Ollama `draft_num_predict 2` == `--spec-draft-n-max 2`. b9860 hard-errors on the removed `--draft-max`/`--draft-min`; `-md`/`--model-draft` still alias `--spec-draft-model`. Per-request speculative adjustment is compiled out (server-schema.cpp:193-222) - draft config is per-process.

## 2b. Gemma drafter crash matrix (the load-bearing result)

Gemma4-12B target + `mtp-gemma-4-12B-it.gguf` drafter, fa + q8_0 KV throughout. "Stable" means every attempted generation completed; Ns are small and stated.

Stock llama-server b9860:

| ctx | CUDA graphs ON (default) | CUDA graphs OFF (`GGML_CUDA_DISABLE_GRAPHS=1`) |
|---|---|---|
| 16384 | **stable**: 7/7 gens across smokes + matrix, 106-120 tok/s | loads; `CUDA error: misaligned address` 817 tokens into gen 1 |
| 200000 | loads; 4 gens OK (~105 tok/s, acceptance 0.745), then `illegal memory access` on gen 5, preceded by decode degradation to <10 tok/s | **drafter load fails with the exact #24795 signature** (`Gemma4Assistant requires ctx_other` -> `vector::_M_range_check`) |

Ollama 0.31.2, isolated serve with the suite/prod-target env (graphs-off):

| ctx | result |
|---|---|
| 200000 (Modelfile num_ctx) | 6/6 requests: `illegal memory access` in `common_speculative_impl_draft_mtp::process`, 18-40 s into generation; serve log also shows `[spec] failed to measure draft model memory` |
| 16384 (`/api/generate` num_ctx override) | gen 1 OK (92.9 tok/s), gens 2-4: same illegal memory access |

- Ollama under graphs-ON was not re-tested this session; the 2026-07-08/10 measurement (1.67x on the 12B pair) ran on graphs-on prod, consistent with graphs-on being the stable side of this bug - but Ollama has no per-model graphs toggle (issue #12083), and graphs-on carries the known Qwen-MTP ~12.5%/run crash (docs/history/2026-07-01-mtp-graphs-crash.md). On Ollama the two crash bugs pincer each other; on stock, graphs is a per-process env var, so each model's launch script can pick its safe side.
- Also new this session: one Ollama runner crash on **plain gemma12b** (no MTP), graphs-off, during the first bench attempt (1 in ~17 generations; `illegal memory access`). Recorded in `benchmark-results/20260717T075828Z/failed-runs.txt`.
- Stock qwen9b-mtp under graphs-on completed 6/6 bench gens plus smokes without a crash - promising but not conclusive against a ~12.5%/run rate (P(no crash in 6) ~ 0.46 if the Ollama rate applied).

## 3. Sampling defaults (spec item resolved)

- Bare llama-server `/props` `default_generation_settings`: temperature 0.8, top_k 40, top_p 0.95, min_p 0.05, repeat_penalty 1.0, presence 0.0. The spec's "reportedly 0.8/0.9" was wrong on top_p and missed the min_p 0.05 injection (which violates the Qwen profile's mandated `min_p 0.0`).
- A `/v1/chat/completions` request that omits a field inherits the server default: task params are copied from `params_base.sampling` before request JSON is evaluated (tools/server/server-schema.cpp:497-506), and a field only overrides when the key is present (field_num::eval, :567-586).
- Launch flags (`--temp --top-p --top-k --min-p --repeat-penalty --presence-penalty`) set exactly those served defaults - verified live: `/props` == the precise-coding profile after relaunch with flags.
- Gotcha (source-verified, common/common.cpp:1121-1179): GGUF sampling metadata silently overrides compiled defaults at load for any parameter NOT explicitly set on the CLI. So per-model launch scripts must pass the full profile (as the parity suite does) and `/props` should be read per model rather than assumed.

## 4. Anthropic endpoint and client compat

Native support in b9860 (source- and smoke-verified):

- Routes registered: `POST /v1/messages`, `POST /v1/messages/count_tokens` (tools/server/server.cpp:222,239; landed upstream as PR #17570). Conversion layer (server-chat.cpp:325-548) covers system as string or block array, tool_use/tool_result, tools + tool_choice (auto/any/tool), stop_sequences, max_tokens (default 4096), temperature/top_p/top_k/stream/chat_template_kwargs passthrough, and Anthropic `thinking` -> `thinking_budget_tokens` (default 10000).
- Claude-Code-specific: `normalize_anthropic_billing_header` (server-chat.cpp:289-323) rewrites the rotating `cch=` stamp in Claude Code's system prompt to a constant so prompt-prefix caching works across turns.
- On-box smokes (Qwen3.5-9B lane): basic round trip returns proper Anthropic shape (thinking + text blocks, `stop_reason: end_turn`, usage incl. `cache_read_input_tokens`); streaming emits the correct SSE sequence (message_start, content_block_start/delta/stop, message_delta, message_stop); tools work end-to-end (`stop_reason: tool_use`, correct input, then tool_result continuation to a grounded answer); system as an array of two blocks accepted; count_tokens returns a count.
- Upstream since b9860 (version-delta pass): one narrow Anthropic fix (image blocks in tool_result, PR #22536) - a future-rebuild carrot for Claude Code tool loops.

Chat-template gate (the AGENTS.md concern, now llama-server-specific):

- The unsloth **Qwen3.5-9B non-MTP** GGUF (the `9b-coding` daily driver's source) embeds `raise_exception('System message must be at the beginning.')`. On llama-server's OpenAI endpoint, a request with a mid-conversation system message 400s (verified live). This never fired under Ollama because Ollama does not execute the GGUF's Jinja template.
- Guard scan across the fleet's cached GGUFs (strings on the header region): ONLY that one GGUF has the guard - the Qwen3.5-9B-MTP sibling, Gemma 12B/26B, Qwen3.6-27B (plain+MTP), and Qwen3.6-35B-A3B are all clean.
- The Anthropic path is structurally immune: Anthropic requests carry system as a top-level param (string or block array) which converts to a single leading system message; `messages[]` cannot contain system roles. So this bites OpenAI-protocol multi-system clients only.
- Vetting rule for the llama.cpp lane: `ollama show --template` does not apply; probe with a multi-system `/v1/chat/completions` request (or dump the GGUF `chat_template` metadata) before trusting a community GGUF with OpenAI-protocol clients.

Residual pre-B validation (deliberately out of this eval's scope, Phase 3 deferred): an actual claude-local session driven end-to-end against llama-server `/v1/messages` (tool loops at scale, caching behavior over long sessions), and Open WebUI rewired to an OpenAI `/v1` connection with per-model launch-flag profiles.

## 5. Model swap / keep-alive (research only; Phase 3 deferred)

- b9860 has native router mode (source-verified, common/arg.cpp:3220-3248): `--models-dir`, `--models-preset` (INI, per-model presets incl. per-child draft flags), `--models-max` (default 4), `--models-autoload`; each model runs as a child llama-server subprocess; router CLI args overlay every preset. The router's own `/props` returns dummies; query the child (`?model=`) for real settings.
- llama-swap v240 (2026-07-15; 5010 stars; commit 1 day old at check) is a pure byte-level passthrough proxy - zero Anthropic protocol code (routing reads only the top-level `model`/`stream` fields) - adding: one stable port, config mapping model id -> arbitrary llama-server command line (absolute path fine), idle-based TTL unload (`ttl` seconds per model; global default never-unload; genuinely idle-based), `/health`-gated readiness queueing, per-model env. Its Anthropic metrics parsing was fixed 2026-05 (#742). Evidence of Claude Code usage exists (#483) but no confirmed end-to-end success/failure report.
- Keep-alive parity with Ollama's 24h `OLLAMA_KEEP_ALIVE`: llama-swap `ttl` is the direct equivalent. Whether native router mode has a TTL-unload equivalent was left unresolved (the research agent covering it hung and was stopped; resolve during Phase 3 of the follow-on spec).
- Per-model env is a stock-side advantage relevant to the crash matrix: graphs on/off can be chosen per model process (impossible on Ollama, issue #12083).

## 6. Throughput parity (benchmarks/llamacpp-parity)

Matrix: qwen9b / qwen9b-mtp (131k ctx) and gemma12b / gemma12b-mtp (200k ctx), 9b-coders medium+long coding prompts, warmup + 2 measured reps per cell, full docs/parameters.md profiles as launch flags. Ollama: isolated serve, prod-target env (graphs-off, FA + q8_0 KV, 11435). Stock: b9860 defaults (graphs on) + FA + q8_0 KV, `-np 1`, 11438. Decode tok/s from each engine's own metrics (`ollama run --verbose` eval rate; llama-server `timings.predicted_per_second`). Raw data: `benchmark-results/20260717T075828Z` (ollama qwen + partial gemma), `20260717T171502Z` (ollama gemma resume), `20260717T172619Z` (llamacpp full).

| model | prompt | ollama tok/s (n=2) | llamacpp tok/s (n=2) | llamacpp/ollama |
|---|---|---|---|---|
| qwen9b | long | 63.7 (sd 5.2) | 67.6 (sd 0.03) | 1.06x |
| qwen9b | medium | 66.5 (sd 0.4) | 75.9 (sd 0.3) | 1.14x |
| qwen9b-mtp | long | 101.3 (sd 0.6) | 114.6 (sd 9.9) | 1.13x |
| qwen9b-mtp | medium | 115.1 (sd 1.9) | 120.0 (sd 1.4) | 1.04x |
| gemma12b | long | 49.8 (sd 0.1) | 57.9 (sd 0.3) | 1.16x |
| gemma12b | medium | 50.3 (sd 0.1) | 58.1 (sd 0.2) | 1.16x |
| gemma12b-mtp | long | crashed 0/3 | 105.9 (sd 1.0), accept 0.745 | stock only |
| gemma12b-mtp | medium | crashed 0/3 | warmup 104.5, then crash (see 2b) | - |

- MTP-vs-plain within engine: Ollama qwen 1.59x/1.73x (long/medium); stock qwen 1.70x/1.58x; stock gemma 1.83x (long).
- Read the cross-engine ratios as "each engine in its would-run config", not isolated-variable A/B: Ollama runs graphs-off by policy (crash avoidance) which history shows costs ~15-26% decode; stock runs its stable default. That IS the migration-relevant comparison.
- qwen9b-mtp long runs hit the 65536 `num_predict` cap on both engines (thinking-heavy prompt); rates are still per-token and comparable.
- Failed runs recorded by the harness: the 6 Ollama gemma12b-mtp crashes, 2 stock gemma12b-mtp medium failures (server crash + dead port), and 1 Ollama plain-gemma12b crash on the first attempt (all in the dirs' `failed-runs.txt`).

## 7. VRAM observations

- Qwen3.5-9B at full 131k ctx (fa + q8_0 KV): 9.4 GiB total GPU use - fits the 4070 with headroom.
- Gemma4-12B at its Modelfile 200k ctx fits but decode drops ~35% vs 16k (38.1 vs 60.5 tok/s smoke, plain); the 12B MTP pair at 16k used 8.6 GiB incl. drafter.
- The 26B/27B/31B/35B classes partial-offload on 12 GB and are out of this eval's clean-parity scope. The 26B-A4B MTP pair does load on stock (CPU-only load test).

## Verdict: A vs B, against the drop-Ollama end goal

**B (full migration off Ollama) is the indicated end state, and the migration can begin now - nothing that works today on Ollama would be lost by moving.** The eval found stock faster on every measured cell, the Anthropic front door native to stock, and the one capability that justified keeping Ollama - Gemma MTP - actually broken on Ollama on-box while stock has the only working configuration (graphs-on, moderate ctx). Option A's "hybrid" is the transition state, not the destination.

Pre-B checklist (ordered; items 1-3 are the real work):

1. **Gemma MTP lane hygiene on stock**: run it graphs-ON per-process and find the stable ctx ceiling between 16k (stable) and 200k (unstable both engines) before daily-driving; extend the qwen-mtp graphs-on N too. The crash matrix (2b) is the regression test - re-run it after any llama.cpp rebuild.
2. **claude-local end-to-end** against llama-server `/v1/messages`: real Claude Code session, tool loops, streaming, prefix-cache behavior (b9860 already carries the cch-stamp normalization).
3. **Open WebUI rewiring** to OpenAI `/v1` with per-model launch profiles; handle the unsloth Qwen3.5-9B template guard (patch GGUF metadata, swap the source GGUF, or keep that model off multi-system OpenAI clients).
4. Swap/keep-alive orchestration (Phase 3, deferred): native router mode vs llama-swap; resolve router TTL semantics then.
5. Pin + watch: stay on b9860 (no upstream fix through b10064; upgrading buys nothing for the tracked bugs and the CLI rewrite is a compat risk); watch #24942/#24795/#24443 and re-verify on any rebuild.
6. Only after 2-3 pass: retire the Ollama daemon, reclaim the blob-store disk (host-side vhdx compact per AGENTS.md).

Interim posture, effective immediately: the Gemma MTP models should be served from stock llama-server (graphs-on, capped ctx) rather than Ollama's currently-crashing DRAFT lane; Ollama keeps claude-local and Open WebUI only until checklist items 2-3 validate.

Watch items: ggml-org/llama.cpp#24795, #24443, PR #24942 (fix candidate), llama-swap releases, Ollama releases that bump the vendored engine (0.32.x does not).

## Provenance and validity

- On-box numbers: this session's smoke/crash-matrix scripts and raw JSON/log outputs (session scratchpad), plus the three `benchmark-results/` dirs listed in section 6 (gitignored raw logs; suite: `benchmarks/llamacpp-parity/`). Single box (WSL2 + RTX 4070), single quant per model (UD-Q4_K_XL), two coding prompts; n=2 per bench cell, crash-matrix Ns as stated - treat rates like "9 of 10" and "1 in 5" as small-sample observations, directionally strong only where the pattern is stark (the 2x2 matrix) or consistent with prior history (graphs cost, MTP ratios).
- Upstream facts: api.github.com and repo sources fetched 2026-07-16/17 by a research fan-out; three of four researchers returned and every load-bearing claim was independently re-verified by an adversarial verifier (all confirmed; one immaterial parenthetical refuted); the fourth (alternatives) hung and was stopped - its questions were answered on-box or by the other agents, except router-TTL semantics (flagged in section 5). File:line citations refer to llama.cpp @ fdb1db877 and llama-swap @ 6b5320de. Version deltas: specs/stack-upkeep/spec.md appendix.
- The graphs-off gating of #24795 on this box is established by the 2x2 matrix (load failure and misaligned-address crash appear only in graphs-off cells); WHY graphs-off destabilizes the drafter path is not diagnosed here, and upstream's mixed reports may have different triggers on other hardware.
