# Roadmap

The in-flight bundles, ordered by dependency; work top-down.
Status lives in the folder layout (`specs/README.md`); this file only orders the work.

1. **llamacpp-migration** - retire Ollama, serve from stock llama-server.
   - Serving and every client cutover are live; what remains: the validation window, the store purge
     (~2026-08-21), and spec close-out.
2. **bonsai-27b** - onboard ternary Bonsai-27B onto the stack.
   - Pre-flight review done 2026-08-12; cleared to start in its own session, and it does not wait on step 1.
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
    - Last because it is blocked upstream (llama.cpp #26337, open). Cut from step 2; pure speed work.
