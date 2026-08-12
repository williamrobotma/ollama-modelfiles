# Roadmap

The in-flight bundles, ordered by dependency; work top-down.
Status lives in the folder layout (`specs/README.md`); this file only orders the work.

1. **llamacpp-migration** - retire Ollama, serve from stock llama-server.
   - Serving and every client cutover are live; what remains: the validation window, the store purge
     (~2026-08-21), and spec close-out.
2. **bonsai-27b** - onboard ternary Bonsai-27B onto the stack.
   - Ready at pickup: its build prerequisite is met at b10335.
3. **openwebui-wrapup** - the remaining in-browser checks and the model-visibility decision.
4. **brave-search-mcp** - swap claude-local's web search from Ollama's cloud API to Brave (scaffold).
5. **stack-upkeep** - version tracking and per-component checks (scaffold).
   - Planned early, run late, as a recurring cadence; it inherits the migration Watch list at step 1's close.
6. **copilot-byok** - VS Code Copilot on the llama-server stack (BYOK Custom Endpoint).
   - Runs any time; no dependency beyond the stack existing.
7. **gpu-stability-test** - package the crash matrix as one certifying command.
   - A sibling of step 1 rather than nested, so it stays in flight when step 1 moves to `done/`.
8. **writing-guards** - mechanical + reviewer gates for the writing rules (scaffold).
   - Deliverables land in the synced `~/.claude`, not this repo; independent of the other steps.
