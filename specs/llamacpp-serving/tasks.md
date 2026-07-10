# Tasks: llama.cpp serving

Status legend: [ ] pending, [x] done. This file is the resume point for the feature; update as phases land. Tasks below are for the recommended option (A); if the user picks B or C, re-scope per plan.md.

## Phase 0 - decision + research

- [ ] **User picks the option at spec review** (A hybrid / B full migration / C eval-first). Record the choice and date here.
- [ ] Re-verify #24795 status via api.github.com (open? fixed? which build?).
- [ ] Verify llama-server omitted-param behavior on-box (does `/v1` inject temp/top_p defaults; do launch flags override).
- [ ] Verify model-swap state: native router mode vs llama-swap; which the lane uses.
- [ ] Confirm local llama.cpp build (b9860+) builds/runs on current CUDA.

## Phase 1 - single-model lane

- [ ] Launch one Qwen coding GGUF under llama-server from its HF-cache snapshot path.
- [ ] Encode its docs/parameters.md profile as launch flags; confirm served sampling matches.
- [ ] Smoke test a coding prompt via `/v1/chat/completions`.

## Phase 2 - throughput parity

- [ ] Bench llama-server vs Ollama, same GGUF + prompt, decode tok/s.
- [ ] Include Qwen self-MTP both engines; note Gemma MTP Ollama-only unless #24795 fixed.
- [ ] Wire into the existing benchmark harness (dry-run default).

## Phase 3 - multi-model (optional)

- [ ] Stand up model-swap (llama-swap or native router) for the llama.cpp lane.
- [ ] Per-model ttl/keep-alive verified.

## Phase 4 - document + decide

- [ ] docs/architecture.md: second serving lane + when to use which.
- [ ] llama.cpp usage note (launch + params location).
- [ ] Record parity numbers; decide whether to open a full-migration (B) spec gated on #24795.
