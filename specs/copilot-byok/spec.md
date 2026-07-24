# VS Code Copilot on the llama-server lane (BYOK Custom Endpoint)

SCAFFOLD - research done and verified 2026-07-23; evidence: `docs/history/2026-07-23-llamacpp-migration-planning.md`.

## Goal

- Point VS Code Copilot chat/agent mode at the local llama-server router (`127.0.0.1:11433`) as a BYOK model.
- Non-blocking for `specs/llamacpp-migration`; must not be dropped after it - Copilot is a daily tool.

## Known facts (verified from VS Code docs, 2026-07-23)

- The BYOK "Custom Endpoint" provider supports three per-model API types: Chat Completions, Responses, Messages.
- Config: Chat model picker -> Manage Language Models -> Add Models -> Custom Endpoint (`chatLanguageModels.json`).
- Agent mode requires `toolCalling: true` on the model entry, and a model that actually does function calling.
- BYOK works without a GitHub account or Copilot plan, including fully local models.
- The old Ollama BYOK provider is deprecated (separate extension now) - not our path; Custom Endpoint is.
- All Copilot agent tools are client-executed; no server-side tool parity issues with llama-server.

## Decisions (at spec review, later)

1. API type: `chat-completions` (boring default) vs `messages` against llama-server's Anthropic endpoint.
2. Which models to expose (likely the coding lane only).
3. Web search: the "Web Search for Copilot" extension is client-side (own Tavily key).
   - Its summarization step may depend on a Copilot-plan model under BYOK - UNVERIFIED; test, then decide.

## Done when

- A Copilot agent-mode session completes edits + terminal runs against a router-served model.
- Whether a keyless local endpoint needs a dummy API key, and the web-search-extension behavior under BYOK, are recorded.
- Config documented in `llamacpp/README.md` alongside the other clients.
