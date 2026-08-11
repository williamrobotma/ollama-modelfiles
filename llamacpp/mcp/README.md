# mcp/ - vendored MCP servers

## web-search-mcp.py

- Upstream: <https://raw.githubusercontent.com/ollama/ollama-python/main/examples/web-search-mcp.py>
  - Fetched 2026-08-04.
- Upstream sha256: `231fc23755ee41abe4fb9378fc7094dc5a78d361499b5ab84df65b422d870287`
- Local changes (the only ones, all in the PEP-723 dep block):
  - 2026-08-04: `"mcp"` -> `"mcp>=1.9,<2"` - mcp 2.0.0 removed FastMCP, which the script imports.
  - 2026-08-08: `rich` dropped (never imported); `ollama` pinned `>=0.6.2,<1` (the pipx-resolved working version).
    - Both were unbounded, re-resolving from PyPI on every `pipx run` with `OLLAMA_API_KEY` in the environment.
  - 2026-08-09: the mcp pin's comment corrected - `Server.tool()` never existed at 1.9; FastMCP removal is the reason.
- Range pins kept deliberately (user, 2026-08-09): in-range re-resolution on pipx cache expiry is an accepted risk.
  - Extended 2026-08-10: the transitive deps (httpx, pydantic, anyio, ...) are fully unpinned and re-resolve the
    same way, with `OLLAMA_API_KEY` in the environment - same accepted risk, same review trigger (an mcp 2.x bump).
- The script's non-FastMCP fallback branch is dead code under the pin; an mcp 2.x bump means a rewrite, not an unpin.
- Vendored sha256: `ce6b5744c332f609d23f5a04cbca0c625cd9f35e434cfaabd89902a12d1bf714`
- Verified 2026-08-04: pipx stdio handshake + live web_search 200 against ollama.com (migration tasks.md, P3).
- Style is upstream-verbatim: exempt from repo Python rules; do not reformat. Only the dep block may change.
- Consumer: `~/.config/claude-local.mcp.json` runs it via `pipx run`.
  - `OLLAMA_API_KEY` comes from the user env file, never this repo.
  - Accepted 2026-08-11 (review): claude-local exports that key into claude's env, so every child inherits it
    (an `env` printout can land it in a transcript) - mcp.json's `${OLLAMA_API_KEY}` expansion requires it there.
