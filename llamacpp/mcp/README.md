# mcp/ - vendored MCP servers

## web-search-mcp.py

An MCP stdio server giving claude-local sessions `web_search` and `web_fetch` tools.
Both tools call Ollama's hosted cloud search API on `ollama.com`, keyed by `OLLAMA_API_KEY`.
Brave is not involved; the planned swap to a Brave-backed server is `specs/brave-search-mcp`.

- Upstream origin: <https://raw.githubusercontent.com/ollama/ollama-python/main/examples/web-search-mcp.py>
  - Fetched 2026-08-04; upstream sha256 `231fc23755ee41abe4fb9378fc7094dc5a78d361499b5ab84df65b422d870287`.
- Locally maintained since 2026-08-12: repo Python rules apply. Earlier vendored shas live in git history.
- Current sha256: `d77501af1290c63d9dc2ae05a7506feabd080586d4ad095fc71ead459ac9c882`
- Change log:
  - 2026-08-04: `"mcp"` -> `"mcp>=1.9,<2"` - mcp 2.0.0 removed FastMCP, which the script imports.
  - 2026-08-08: `rich` dropped (never imported); `ollama` pinned `>=0.6.2,<1` (the pipx-resolved working version).
    - Both were unbounded, re-resolving from PyPI on every `pipx run` with `OLLAMA_API_KEY` in the environment.
  - 2026-08-09: the mcp pin's comment corrected - `Server.tool()` never existed at 1.9; FastMCP removal is the reason.
  - 2026-08-12 (user): ruff reformat - 4-space indent, built-in generics, docstring shape.
  - 2026-08-12 (review): dead non-FastMCP fallback branch deleted; dep-block comments point here instead of
    explaining in place; upstream's contradictory env note ("required ... if set") fixed; editor lint flags cleared.
  - 2026-08-12 (loss review): an unverified "requests fail without it" claim removed from the docstring.
  - 2026-08-12 (fidelity review): per-pin rationale hints restored inline in the dep block.
- Range pins kept deliberately (user, 2026-08-09): in-range re-resolution on pipx cache expiry is an accepted risk.
  - Extended 2026-08-10: the transitive deps (httpx, pydantic, anyio, ...) are fully unpinned and re-resolve the
    same way, with `OLLAMA_API_KEY` in the environment - same accepted risk, same review trigger (an mcp 2.x bump).
- An mcp 2.x bump means a rewrite, not an unpin (the removed fallback was never a real escape hatch).
- Verified 2026-08-04: pipx stdio handshake + live web_search 200 against ollama.com (migration tasks.md, Phase 3).
  - Re-verified 2026-08-12 after the fallback removal: pipx stdio handshake + `tools/list` returns both tools
    (record: migration tasks.md, "PR #15 review response - 2026-08-12").
- Consumer (WSL): `~/.config/claude-local.mcp.json` runs it via `pipx run`; Windows contract below.
  - `OLLAMA_API_KEY` comes from the user env file, never this repo.
  - Accepted 2026-08-11 (review): claude-local exports that key into claude's env, so every child inherits it
    (an `env` printout can write it into a transcript) - mcp.json's `${OLLAMA_API_KEY}` expansion requires it there.

## Windows consumer contract (specced 2026-08-11; setup pending)

Same MCP on the Windows/git-bash machine, run by `uv`.
No claude-local change: `~/.config/claude-local.mcp.json` alone activates its MCP branch.
Anything not listed here is the Windows-side agent's call.

- Script: this vendored file, byte-identical (Current sha256 above), at that machine's checkout path.
- Runner: `uv run <script path>` - uv reads the PEP 723 block, so the dep pins apply as written.
  - The re-resolution accepted risk above applies to uv the same way.
- `~/.config/claude-local.mcp.json` (git-bash `$HOME`), server name kept exactly:

  ```json
  { "mcpServers": { "web_search_and_fetch": {
      "type": "stdio",
      "command": "<uv>",
      "args": ["run", "<checkout>/llamacpp/mcp/web-search-mcp.py"],
      "env": { "OLLAMA_API_KEY": "${OLLAMA_API_KEY}" } } } }
  ```

- `~/.config/claude-local.env` exports `OLLAMA_API_KEY`; claude-local fails closed without the file.
  - A file that exports nothing passes launch; only the acceptance probe catches the empty key.
  - Key stays out of both repos; nearest Windows equivalent of mode 600 - agent's pick.
  - The key-inheritance exposure accepted above applies unchanged.
- Acceptance: one live `web_search` in a claude-local session; record date + uv version here on pass.
  - Same pass: sweep the WSL-only claims (AGENTS.md claude-local section; the synced script's comment).
