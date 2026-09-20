# Roadmap

The in-flight bundles, ordered by dependency; work top-down.
Status lives in the folder layout (`specs/README.md`); this file only orders the work.

1. **llamacpp-migration** - retire Ollama, serve from stock llama-server. CLOSED 2026-09-20.
   - Moved to `specs/done/llamacpp-migration`. The store purge ran that day and the Watch list moved to
     step 6; only the host-side vhdx compact is left, and it changes nothing inside the guest.
   - Kept in place rather than deleted so the steps below keep their numbers and their references to it.
2. **bonsai-27b** - onboard ternary Bonsai-27B onto the stack.
   - In flight, and it does not wait on step 1. The ternary lane serves as of 2026-08-16.
   - What remains is the bench, the 1-bit comparison, and the write-up, all needing the GPU.
3. **kv-cache-ab** - re-test q8_0 vs f16 KV across every family, numerically and behaviourally (scaffold).
   - Raised by step 2, which contributes one arm; the current fleet-wide default rests on a single Gemma probe.
4. **openwebui-wrapup** - the remaining in-browser checks and the model-visibility decision.
5. **brave-search-mcp** - swap claude-local's web search from Ollama's cloud API to Brave (scaffold).
6. **stack-upkeep** - version tracking and per-component checks (scaffold).
   - Planned early, run late, as a recurring cadence; it inherits the migration Watch list at step 1's close.
7. **copilot-byok** - VS Code Copilot on the llama-server stack (BYOK Custom Endpoint).
   - Runs any time; no dependency beyond the stack existing.
8. **gpu-stability-test** - package the crash matrix as one certifying command.
   - A sibling of step 1 rather than nested, so it stays in flight when step 1 moves to `done/`.
9. **writing-guards** - automatic checks + a review pass for the writing rules (scaffold).
   - The work lands in the synced `~/.claude`, not this repo; it runs independently of the other steps.
10. **bonsai-dspark** - speculative decoding for Bonsai-27B (scaffold).
    - Ordered late because it is blocked upstream (llama.cpp #26337, open). Cut from step 2; pure speed work.
11. **qwen3.8-27b** - decide whether Qwen3.8-27B earns a fleet slot beside the qwen3.6 coders.
    - Not yet planned, and there is no spec. Filed 2026-09-20 on a reported open-weights release.
