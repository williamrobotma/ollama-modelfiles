# CLAUDE.md

[AGENTS.md](AGENTS.md) is authoritative for this repo (conventions, build/benchmark commands, doc map); read it first.
This file holds only Claude-Code-specific notes.

## claude-local

- `claude-local` is a `~/.bashrc` function routing Claude Code to the router (`127.0.0.1:11433/v1/messages`).
  - Pins `ANTHROPIC_MODEL` + tier/subagent vars to the 35B coding alias (settings.json models otherwise hit the wire).
  - Execs `claude` with `--disallowedTools=WebSearch` plus the vendored web-search MCP (`llamacpp/mcp/`, via pipx).
  - Secrets live in `~/.config/claude-local.env` (mode 600); cutover validated 2026-08-04, see the P3 history log.
- Claude Code sends multiple `system`-role messages mid-conversation.
  - No guard risk on llama-server's `/v1/messages` (verified per-build).
  - The [AGENTS.md gate](AGENTS.md#chat-template-gate-for-community-ggufs) bites OpenAI-endpoint clients.
  - Vet new community GGUFs per that section's procedure.
- CUDA graphs run ON fleet-wide, including the MTP models claude-local serves (P1-validated 2026-08-03).
  - Crash history: [docs/benchmarking.md](docs/benchmarking.md#mtp-x-cuda-graphs-crash).
