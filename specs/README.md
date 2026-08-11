# Specs

Spec-driven work bundles, executed end to end by the run-spec skill. Each `<feature>/` directory holds:

- `spec.md` - its Acceptance section defines done.
- `tasks.md` - the resume point.
- `plan.md` - present when the work needs one.

## Status is the folder

- `specs/<feature>/` - in flight.
- `specs/done/<feature>/` - Acceptance met; kept for the record. run-spec moves it here on completion.
- No status column, so status can't drift out of sync.

## Reference convention

- Refer to a spec by name; this file maps a name to its location.
- Inside a bundle, use plain-text or backtick paths, not `](relative)` links.
  - A bundle can then move to `done/` without rewriting links.

## Scaffold shape

Short `##` sections (goal / decisions / done-when), one idea per bullet, ~15-30 lines total.

## In-flight sequence

Order follows the dependencies; work top-down (stack-upkeep is planned early, run late - see step 4).

1. **llamacpp-migration** - retire Ollama, serve from stock llama-server.
   - The prerequisite for every other bundle; fill plan.md first.
   - Consumes chat-template-refresh (done 2026-07-23).
2. **bonsai-27b** - add the model to the stock llama.cpp serving stack.
   - Blocked until step 1 builds that stack and its config home.
   - Also has an upstream prerequisite, tracked in the bundle.
3. **openwebui-wrapup** - end-to-end Open WebUI pass.
   - Runs after step 1 rewires Open WebUI to llama-server, so the final settings are validated once.
4. **stack-upkeep** - version tracking and per-component checks.
   - The chat-template vetting check is already filed in its planning items.
   - Run as a recurring cadence.
5. **copilot-byok** - VS Code Copilot on the stock llama-server stack (BYOK Custom Endpoint).
   - Runs any time after step 1.
6. **gpu-stability-test** - package the crash matrix as one certifying command.
   - Derives from step 1, which names that crash matrix as its post-rebuild regression test.
   - A sibling bundle rather than nested, so it does not move to `done/` when step 1 does.
