# Plan: llama.cpp serving (recommended option A - hybrid)

This plans the recommended option (A: llama-server alongside Ollama). If the user picks B or C at spec review, adapt: B = do Phase 0-1 then follow spec.md's "If B" acceptance (Gemma MTP stays on Ollama until #24795 closes); C = do Phase 0-2 and stop at a written A-vs-B verdict. The research phase is mandatory under any option - today's facts (below) are re-verified at implementation time, not trusted to hold.

## Phase 0 - research (re-verify, do not trust this doc's facts)

The spec's Known facts were verified 2026-07-10; recheck before building:

- #24795 status via api.github.com (still open? fix PR merged? which build?). If fixed, Gemma MTP on stock llama.cpp becomes testable and B's main blocker clears.
- llama-server omitted-parameter behavior: does `/v1/chat/completions` inject temp/top_p defaults, and what values? Confirm the per-process launch-flag override works (start with `--temp`/`--top-p`/`--top-k`, send a request omitting them, read what the server used). Primary source: on-box run, not a blog.
- Model-swap state: native router mode (`--models-dir`/`--models-preset`/`--models-max`) vs llama-swap - current maturity, which the hybrid lane should use for multi-model. Verify the local build supports the router flags.
- Confirm the local llama.cpp build (b9860 or newer) still builds/runs on the current CUDA.

## Phase 1 - single-model llama-server lane

- Pick one benchmark model with a self-contained GGUF (a Qwen coding variant) and launch it under llama-server from its HF-cache snapshot path.
- Encode the model's docs/parameters.md profile as launch flags; confirm the served sampling matches (from Phase 0's injection finding).
- Smoke test: a coding prompt via `/v1/chat/completions`, output sane.

## Phase 2 - throughput parity vs Ollama

- Same GGUF, same prompt, llama-server vs Ollama; record decode tok/s.
- Include Qwen self-MTP (loads on both engines). Note Gemma MTP as Ollama-only unless Phase 0 found #24795 fixed.
- Fold this into the existing benchmark harness shape (dry-run default) rather than a one-off script.

## Phase 3 - multi-model convenience (optional, if the lane earns it)

- Stand up model-swap for the llama.cpp lane using whichever Phase 0 favored (llama-swap or native router). Keep it experiment-scoped; Ollama remains the integration daemon.
- Per-model `ttl`/keep-alive so idle models release VRAM.

## Phase 4 - document and decide

- Update docs/architecture.md: the second serving lane and when to reach for which.
- Add a short llama.cpp usage note (how to launch a model, where params live).
- Record the parity numbers; state whether they justify opening a full-migration (B) spec, gated on #24795.

## Risks / notes

- VRAM contention if Ollama and llama-server both hold weights - idle/stop one lane when benchmarking the other (mirror the existing harness's advice to idle systemd Ollama).
- Parameter drift: profiles now live in two places (Modelfiles + launch flags). Keep docs/parameters.md the single source; generate both from it if it grows painful.
- Do not migrate Gemma MTP off Ollama in any phase while #24795 is open.
