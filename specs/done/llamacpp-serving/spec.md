# llama.cpp serving alongside / instead of Ollama

## Why

The stated next task is "incorporating/migrating for llama.cpp". The user chose "you propose it", so this spec is an options analysis with a recommendation; the option is decided at spec review, not here.

The pull toward llama.cpp:

- Direct control over the runner: `--model-draft` / `--spec-type` and other speculative-decoding knobs, sampler flags, cache-type flags - set per process on the launch command line, no Modelfile re-serialization step.
- Newer engine features land in stock llama.cpp first; Ollama tracks a vendored snapshot (currently b9840).
- The HF-cache GGUFs already serve llama.cpp directly (`--model` / `--model-draft`), same pinned snapshot paths the Modelfiles use - so there is no new provisioning to do.

The pull to keep Ollama, today:

- Gemma MTP on CUDA works only on Ollama's vendored engine (stock llama.cpp cannot load the gemma4-assistant drafters - #24795, open). See Known facts.
- claude-local drives Ollama's Anthropic `/v1/messages` endpoint; stock llama-server has no Anthropic endpoint.
- Open WebUI is wired to Ollama's native connection specifically to avoid `/v1` sampling injection (see docs/openwebui.md).

## Known facts to bake in

Verified this month; sources are docs/history/2026-07-10-migration-local-ggufs.md unless noted.

- Local stock llama.cpp build b9860 (CUDA arch 89) works on-box for normal (non-MTP) inference.
- Stock llama.cpp cannot load gemma4-assistant MTP drafters: issue #24795, **open** (verified via api.github.com 2026-07-10: created 2026-06-19, updated 2026-06-30, 4 comments, no fix PR). Repro'd on-box on both b9553 and b9860 (`Gemma4Assistant requires ctx_other` -> `vector::_M_range_check`); the issue's "b9553 works" claim did not hold here. Ollama's vendored engine carries a fix stock lacks.
- Gemma MTP via Ollama `DRAFT` measured 1.67x (12B pair) and 1.54x (26B pair) decode throughput. These are load-bearing: the reasoning/agentic daily driver is a Gemma MoE.
- Qwen MTP is self-contained GGUFs (embedded MTP tensors, no separate drafter). Stock llama.cpp loads these fine via its own speculative path - only the Gemma target+drafter shape hits #24795.
- The same HF-cache snapshot paths feed both runners; no conversion, no second copy needed for llama.cpp.
- llama-server applies its own sampling defaults when the client omits them (reportedly temperature 0.8 / top_p 0.9 - exact values UNVERIFIED, confirm at implementation time). It is NOT a pass-through. Unlike Ollama's `/v1`, llama-server exposes those defaults as per-process launch flags (`--temp`, `--top-p`, `--top-k`, ...), so the launch script becomes the parameter block. Do not assume behavior; verify (research phase).
- llama-swap (mostlygeek/llama-swap): mature Go proxy in front of llama-server, one OpenAI- and Anthropic-compatible front door. Exposes `/v1/messages` + `/v1/messages/count_tokens` (Anthropic) and the OpenAI `/v1/*` set; per-model `ttl` keep-alive; starts/swaps the right upstream by the request's `model` field. Active (v201, 2026-04; ~3k stars). Web research 2026-07-10: <https://github.com/mostlygeek/llama-swap>. This is the finding that most changes the analysis below - it supplies both the missing Anthropic endpoint and the model-swap orchestration in one component.
- llama-server has a native router/multi-model mode (`--models-dir`, `--models-preset`, `--models-max N` default 4, `--no-models-autoload`); each model runs in its own process (crash isolation). Introduced ~2025-12 (ggml-org blog 2025-12-11: <https://huggingface.co/blog/ggml-org/model-management-in-llamacpp>). Newer than llama-swap; maturity vs the proxy is unverified - a research item, not an assumption.

## Options

### Option A - Hybrid: llama-server alongside Ollama

- What it means: add per-model llama-server launch scripts (or a small llama-swap config) for benchmarks and experiments. Ollama stays the daemon for claude-local, Open WebUI, and Gemma MTP. llama.cpp becomes the direct-control lane; Ollama the integration lane.
- Pros:
  - Lowest cost and fully reversible: the GGUFs already serve llama.cpp, so this is launch scripts, not a migration.
  - Keeps every working integration intact (Gemma MTP, claude-local, Open WebUI) while unlocking direct `--spec-type`/sampler control and newer-engine testing.
  - Produces exactly the head-to-head evidence a later full migration would need (throughput parity, endpoint parity) as a side effect - so A subsumes the useful part of C.
- Cons:
  - Two serving stacks to keep straight (which model is served where, VRAM contention if both hold weights).
  - Parameter profiles are maintained twice until/unless one lane wins (Modelfile params vs launch-flag params).
- Prerequisites:
  - The b9860 (or newer) CUDA build already present in ~/Developer/llama.cpp.
  - Decide launch-flag param blocks mirroring docs/parameters.md per model; confirm llama-server's omitted-param defaults (research).

### Option B - Full migration: llama-server (fronted by llama-swap) is the only serving layer

- What it means: retire the Ollama daemon; serve every model from llama-server, orchestrated by llama-swap (or native router mode) for model-swap + keep-alive + the OpenAI and Anthropic front doors.
- Pros:
  - Single engine, always current; one place for sampler/spec-decode control; no Modelfile re-serialization and no Ollama blob-store second copy (frees disk - see the disk story in the history log).
  - llama-swap's `/v1/messages` gives claude-local an Anthropic endpoint without Ollama; its OpenAI `/v1` gives Open WebUI a connection.
- Cons / honest blockers:
  - Gemma MTP is a hard blocker: #24795 is open with no fix PR, so full migration loses the 1.67x/1.54x Gemma drafter speedups until upstream fixes it. Track #24795; do not migrate the Gemma MTP models off Ollama before it closes and is verified on-box.
  - Anthropic endpoint parity is now solvable (llama-swap) but unproven here: claude-local sends multiple mid-conversation system messages (the template gate, see AGENTS.md) and expects Anthropic streaming/tool-call semantics - must be validated end-to-end against llama-swap, not assumed.
  - Open WebUI rewiring: it currently uses Ollama's native connection to dodge `/v1` sampling injection. llama-server ALSO injects its own defaults when params are omitted (see Known facts). Mitigation is per-process launch flags, but the exact `/v1` behavior must be re-verified before trusting the Modelfile-equivalent profiles - do NOT assume it passes params through.
  - Model swap/keep-alive orchestration is new machinery: llama-swap (mature) or native router mode (newer, maturity unverified) or systemd templates. One-model-per-process either way; VRAM bounds concurrency.
- Prerequisites:
  - #24795 fixed upstream and verified on-box (else Gemma MTP stays on Ollama and this is not a full migration).
  - llama-swap installed and its Anthropic + OpenAI front doors validated for claude-local and Open WebUI.
  - Per-model launch configs with verified sampler flags; sampling-injection behavior confirmed.

### Option C - Evaluation first

- What it means: run a structured eval before choosing A vs B - throughput (incl. MTP where loadable), endpoint parity (Anthropic via llama-swap, OpenAI for Open WebUI), client compatibility (claude-local template gate, tool calling), VRAM/keep-alive behavior - and let the numbers pick.
- Pros:
  - Decides on evidence, not assumption; directly reuses the existing benchmark harness shape.
- Cons:
  - Most of the eval requires standing up the llama-server lane anyway - which is Option A. As a standalone phase it mostly duplicates A's early work without shipping the hybrid lane.
- Prerequisites:
  - Same as A (a working llama-server lane to measure).

## Recommendation

**Option A (Hybrid), with B tracked as a follow-on gated on #24795.**

Reasoning:

- Simplicity-first: A is the minimum that satisfies "incorporating llama.cpp" - launch scripts over already-cached GGUFs - without ripping out three working integrations. B is speculative complexity until its blockers clear.
- The one hard blocker (#24795, Gemma MTP) is outside our control and currently open; A needs it for nothing, B cannot complete without it. Building A now loses no option: it is the substrate B and C both require.
- The research changed B's odds but not the verdict: llama-swap removes the "no Anthropic endpoint" blocker, so B is now a real future target - but "real future" still waits on #24795 and on-box endpoint validation. A is what de-risks that future by generating the parity evidence (folding in C).
- Matches the repo's ethos: keep working things working (Gemma MTP, claude-local, Open WebUI), add the new capability beside them, decide migration on measured parity rather than up front.

If the user picks B or C instead, plan.md adapts (see its note); the acceptance criteria below are written per option so whichever is chosen is already defined.

## Acceptance

### If A (Hybrid)

- Per-model llama-server launch method exists (scripts or a llama-swap config) for at least the benchmark models, reading the same HF-cache snapshot paths as the Modelfiles.
- Launch-flag parameter blocks match docs/parameters.md per profile; llama-server's omitted-param default behavior is documented (verified, not assumed).
- A benchmark run compares llama-server vs Ollama decode throughput on the same GGUF (Qwen self-MTP loadable both sides; Gemma MTP Ollama-only, noted).
- Ollama's claude-local, Open WebUI, and Gemma MTP paths are unchanged and still pass their existing checks.
- Docs updated: architecture.md gains the second lane; a llama.cpp usage note added.

### If B (Full migration)

- #24795 closed upstream and Gemma MTP verified loading + speeding up on-box under stock llama.cpp, OR the Gemma MTP models are explicitly kept on an Ollama instance and "full" is scoped down (recorded as a decision).
- claude-local drives llama-swap `/v1/messages` end-to-end: multi-system-message template gate passes, streaming + tool calls work.
- Open WebUI drives llama-swap OpenAI `/v1` with the correct per-model sampling (injection behavior verified; profiles match docs/parameters.md).
- Model swap + keep-alive works for the keep-set (TTL/router config), within VRAM.
- Ollama daemon retired only after the above pass; disk reclaimed (Ollama blob store removed, host-side vhdx compact).

### If C (Evaluation first)

- A written eval report (throughput, endpoint parity, client compat, VRAM/keep-alive) with primary-source numbers, ending in an explicit A-vs-B verdict for the user.
- The eval harness is reusable (not a throwaway), since standing it up is most of Option A anyway.
