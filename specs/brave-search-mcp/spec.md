# Brave-backed web-search MCP

SCAFFOLD - plan in a fresh session.

Decided 2026-08-12 (PR #15 review): replace the Ollama-cloud web-search MCP with a Brave-backed one.
Until this lands, search rides Ollama's hosted API (`llamacpp/mcp/README.md`).

## Goal

- claude-local's `web_search` / `web_fetch` tools served by the Brave Search API instead of Ollama's cloud API.
- Ends the last Ollama dependency; the local serving stack is already retired.

## Decisions for planning

- Server: reuse an existing Brave MCP server first; adapt the vendored script only if nothing fits.
- Key handling: `BRAVE_API_KEY` through `~/.config/claude-local.env`, same fail-closed pattern as today.
- `web_fetch` backend: Brave's Search API searches but does not fetch pages, so fetch needs its own answer.
- The Windows consumer contract (`llamacpp/mcp/README.md`) follows whatever is chosen here.

## Done when

- One live `web_search` in a claude-local session returns Brave-sourced results.
- `OLLAMA_API_KEY` is retired from `~/.config/claude-local.env`.
- Docs swept: README Web search section, `llamacpp/mcp/README.md`, AGENTS.md doc map.
