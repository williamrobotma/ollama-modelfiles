# Specs

Spec-driven work bundles. Each `<feature>/` holds `spec.md` (its Acceptance defines done) and `tasks.md` (the resume point), plus `plan.md` when the work needs one. The run-spec skill executes a bundle end to end.

## Status is the folder

- `specs/<feature>/` - in flight.
- `specs/done/<feature>/` - Acceptance met; kept for the record. run-spec moves it here on completion.
- No status column, so status can't drift out of sync.

## Reference convention

- Refer to a spec by name; this file maps a name to its location.
- Inside a bundle, use plain-text or backtick paths, not `](relative)` links, so the bundle can move to `done/` without rewriting links.

## In-flight sequence

Order follows the dependencies; work top-down (stack-upkeep is planned early, run late - see step 4).

1. **llamacpp-migration** - the spine: retire Ollama, serve from stock llama-server. Fill plan.md first. Consumes chat-template-refresh (done 2026-07-23).
2. **bonsai-27b** - add the model to the llama.cpp lane. Blocked until step 1 builds the lane and its config home; also has an upstream gate (tracked in the bundle).
3. **openwebui-wrapup** - end-to-end Open WebUI pass. Runs after step 1 rewires Open WebUI to llama-server, so the final config is validated once.
4. **stack-upkeep** - version tracking and per-component checks. The chat-template vetting check is already filed in its planning items; run as a recurring cadence.
