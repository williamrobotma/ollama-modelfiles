# Tasks: llama.cpp serving

Status legend: [ ] pending, [x] done. This file is the resume point for the feature; update as phases land.

2026-07-16 spec review: **Option C (evaluation first)** chosen; re-scoped per plan.md's C note (Phase 0-2, then stop at a written A-vs-B verdict). Recorded intent: the end goal is dropping Ollama entirely (Option B) once blockers clear, so the verdict is framed against that goal; keep watching #24795 and alternatives to it. Phase 3 machinery (llama-swap / native router) deferred at review - endpoint parity is research-only this round, flagged as a pre-B validation item. Full live GPU runs authorized.

## Phase 0 - decision + research

- [x] **User picks the option at spec review** (A hybrid / B full migration / C eval-first). Recorded: **C**, 2026-07-16; intent note in header.
- [x] Re-verify #24795 status via api.github.com. Verified 2026-07-17 (adversarial re-check): still open, no fix merged through b10036; fix candidate PR #24942 unmerged. On-box the failure turned out config-gated, not build-gated: under graphs-on defaults the 12B pair loads and drafts (acceptance 0.75-0.81) and the 26B pair loads (CPU test, acceptance 0.94), while `GGML_CUDA_DISABLE_GRAPHS=1` reproduces the exact #24795 load-failure signature at 200k ctx (crash matrix, report section 2b; supersedes the interim VRAM-pressure hypothesis). Classic-drafter alternative moot.
- [x] Verify llama-server omitted-param behavior on-box. Verified 2026-07-17: bare server injects temp 0.8 / top_k 40 / top_p 0.95 / min_p 0.05 (NOT the rumored top_p 0.9); launch flags reset the served defaults; effective values readable via GET /props default_generation_settings; source-confirmed (server-schema.cpp params_base fallback) incl. the gotcha that GGUF sampling metadata overrides compiled defaults unless the CLI flag is given.
- [x] Verify model-swap state. Verified 2026-07-17: b9860 has native router mode (--models-dir/--models-preset INI/--models-max 4, per-child draft flags, source-verified arg.cpp:3220-3248); llama-swap v240 (2026-07-15, 5k stars) is a pure passthrough proxy adding idle-TTL unload + single port. Router-mode TTL semantics still open (research agent pending at checkoff).
- [x] Confirm local llama.cpp build (b9860+) builds/runs on current CUDA. Verified 2026-07-17: b9860 (fdb1db877) serves GPU inference, 77-123 tok/s decode on the 9B/12B class.
- [x] Research Anthropic front doors. Verified 2026-07-17: stock b9860 llama-server NATIVELY serves /v1/messages + count_tokens (server.cpp:222,239; upstream PR #17570), incl. a Claude-Code-specific prefix-cache fix; on-box smokes pass (round trip, SSE event sequence, tool_use/tool_result, system block arrays). llama-swap needed only for swap/TTL, not protocol.

## Phase 1 - single-model lane

- [x] Launch one Qwen coding GGUF under llama-server from its HF-cache snapshot path. Done 2026-07-17: Qwen3.5-9B-UD-Q4_K_XL from the pinned snapshot, healthy in 4s, 9.4 GiB VRAM at full 131072 ctx (fa + q8_0 KV).
- [x] Encode its docs/parameters.md profile as launch flags; confirm served sampling matches. Done 2026-07-17: /props default_generation_settings == precise-coding profile (0.6/0.95/20/0.0/1.0/0.0).
- [x] Smoke test a coding prompt via `/v1/chat/completions`. Done 2026-07-17: 9b-coders medium prompt, coherent output, 77.0 tok/s decode / 781 tok/s prefill, timings object present.

## Phase 2 - throughput parity

- [x] Bench llama-server vs Ollama, same GGUF + prompt, decode tok/s. Done 2026-07-17: benchmark-results/20260717T{075828,171502,172619}Z; stock faster on every cell (qwen9b 1.06-1.14x, qwen9b-mtp 1.04-1.13x, gemma12b 1.16x); report section 6.
- [x] Include Qwen self-MTP both engines; note Gemma MTP. Done 2026-07-17: Qwen MTP 1.58-1.73x on both engines. Gemma MTP INVERTED the spec's premise - Ollama's DRAFT lane crashes on-box (9/10 requests, illegal memory access) while stock serves it at 1.83x under graphs-on; full crash matrix in report section 2b.
- [x] Stock speculative alternative benched. Done 2026-07-17: ngram-mod is a clear negative (14 vs 38 tok/s, zero accepted drafts) and moot - the real drafter loads on stock under graphs-on.
- [x] Wire into the existing benchmark harness shape. Done 2026-07-17: self-contained benchmarks/llamacpp-parity/ suite (dry-run default, --matrix/--runtime-matrix partial-rerun overrides, failed-run tolerance, own report.py); documented in docs/benchmarking.md.

## Phase 3 - multi-model (deferred at spec review)

- Deferred 2026-07-16: no new swap machinery under C. The llama-swap vs native-router choice is researched in Phase 0 and recorded in the eval report for the follow-on (B) spec to act on.

## Phase 4 - eval report + verdict (re-scoped from "document + decide")

- [x] Write the eval report (landed as docs/history/2026-07-17-llamacpp-eval.md; the work crossed midnight). Done 2026-07-17: throughput, endpoint parity (native /v1/messages, smoked on-box), client compat (template gate), VRAM/keep-alive, plus the Gemma-drafter crash matrix; every number primary-sourced with stated Ns.
- [x] Explicit A-vs-B verdict. Done 2026-07-17: B (full migration) indicated and can begin now; 6-item pre-B checklist; interim posture - move Gemma MTP to stock (graphs-on, capped ctx) immediately since Ollama's lane crashes on-box; watch #24795/#24443/#24942.
- [x] Document the new parity suite in docs/benchmarking.md. Done 2026-07-17: layout entry, port assignments (11435/11438), suite description, distilled findings. (docs/architecture.md "second lane" update deferred to the follow-on spec - under C the lane is an eval harness, not a supported serving path.)
