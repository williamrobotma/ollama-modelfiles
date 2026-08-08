# mcp/ - vendored MCP servers

## web-search-mcp.py

- Upstream: <https://raw.githubusercontent.com/ollama/ollama-python/main/examples/web-search-mcp.py>
  - Fetched 2026-08-04.
- Upstream sha256: `231fc23755ee41abe4fb9378fc7094dc5a78d361499b5ab84df65b422d870287`
- Local changes (the only ones, all in the PEP-723 dep block):
  - 2026-08-04: `"mcp"` -> `"mcp>=1.9,<2"` - mcp 2.0.0 removed FastMCP, which the script imports.
  - 2026-08-08: `rich` dropped (never imported); `ollama` pinned `>=0.6.2,<1` (the pipx-resolved working version).
    - Both were unbounded, re-resolving from PyPI on every `pipx run` with `OLLAMA_API_KEY` in the environment.
- Vendored sha256: `4a5248f009c883a3a84accb43672711d2f3c3d13d3829c1176ab019157ee0074`
- Verified 2026-08-04: pipx stdio handshake + live web_search 200 against ollama.com (migration tasks.md, P3).
- Style is upstream-verbatim: exempt from repo Python rules; do not reformat. Only the dep block may change.
- Consumer: `~/.config/claude-local.mcp.json` runs it via `pipx run`.
  - `OLLAMA_API_KEY` comes from the user env file, never this repo.
