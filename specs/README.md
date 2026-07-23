# Specs

Spec-driven work bundles. Each `<feature>/` holds `spec.md` (its Acceptance defines done), `plan.md`, and `tasks.md` (the resume point). The run-spec skill (`.claude/skills/run-spec/`) executes a bundle end to end.

## Status is the folder

- `specs/<feature>/` - in flight.
- `specs/done/<feature>/` - Acceptance met; kept for the record. run-spec moves it here on completion.
- There is no status column anywhere; the folder is the status.

## Reference convention

- Refer to a spec by name; this file maps a name to its location.
- Inside a bundle, use plain-text or backtick paths, not `](relative)` links, so the bundle can move to `done/` without rewriting links.

## In-flight sequence

Order follows the dependencies; work top-down.

1. **chat-template-refresh** - re-pull the Gemma templates, adopt the guard-free Qwen rule, fix the AGENTS.md gate docs. Feeds migration step 3 and stack-upkeep's vetting check. Its validation overlaps into step 2 (it needs the llama-server lane).
2. **llamacpp-migration** - the spine: retire Ollama, serve from stock llama-server. Fill plan.md first. Consumes step 1.
3. **bonsai-27b** - add the model to the llama.cpp lane. Blocked until step 2 builds the lane and its config home; also gated upstream on #25707 / #24795.
4. **openwebui-wrapup** - end-to-end Open WebUI pass. Runs after step 2 rewires Open WebUI to llama-server, so the final config is validated once.
5. **stack-upkeep** - version tracking and per-component checks. Plan early as the home for step 1's vetting check; then run it as a recurring cadence.
