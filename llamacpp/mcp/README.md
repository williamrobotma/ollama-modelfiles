# mcp/ - vendored MCP servers

## web-search-mcp.py

- Upstream: <https://raw.githubusercontent.com/ollama/ollama-python/main/examples/web-search-mcp.py>
  - Fetched 2026-08-04.
- Upstream sha256: `231fc23755ee41abe4fb9378fc7094dc5a78d361499b5ab84df65b422d870287`
- Local change (the only one): PEP-723 dep `"mcp"` -> `"mcp>=1.9,<2"`.
  - mcp 2.0.0 removed FastMCP and Server.tool(); the unpinned upstream script crashes at import (2026-08-04).
- Vendored sha256: `0dd976c08989e9bfbc6fca71392cfb75c727563a02b4c378bd408215a328c8a5`
- Verified 2026-08-04: pipx stdio handshake + live web_search 200 against ollama.com (migration tasks.md, P3).
- Style is upstream-verbatim: exempt from repo Python rules; do not reformat. Only the pin line may change.
- Consumer: `~/.config/claude-local.mcp.json` runs it via `pipx run`.
  - `OLLAMA_API_KEY` comes from the user env file, never this repo.
