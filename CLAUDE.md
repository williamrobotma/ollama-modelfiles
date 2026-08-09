# CLAUDE.md

[AGENTS.md](AGENTS.md) is authoritative for this repo (conventions, build/benchmark commands, doc map); read it first.
This file holds only Claude-Code-specific notes.

## claude-local

- `claude-local [--model <id-or-alias>]` is a `~/.bashrc` function routing Claude Code to the router (11433, `/v1/messages`).
  - One selector for the whole session (B6 fix, 2026-08-08): the wrapper consumes `--model` and repoints
    `ANTHROPIC_MODEL` + tier + subagent vars together; the default id lives in the fn (`_cl_model`).
  - settings.json models otherwise hit the wire verbatim; mid-session `/model` still moves only the main session.
  - Execs `claude` with `--disallowedTools=WebSearch` plus the vendored web-search MCP (`llamacpp/mcp/`, via pipx).
  - Secrets live in `~/.config/claude-local.env` (mode 600); cutover validated 2026-08-04, see the P3 history log.
- Claude Code sends multiple `system`-role messages mid-conversation.
  - No guard risk on llama-server's `/v1/messages` (verified per-build).
  - The [AGENTS.md gate](AGENTS.md#chat-template-gate-for-community-ggufs) bites OpenAI-endpoint clients.
  - Vet new community GGUFs per that section's procedure.
- CUDA graphs run ON fleet-wide, including the MTP models claude-local serves (P1-validated 2026-08-03).
  - Crash history: [docs/benchmarking.md](docs/benchmarking.md#mtp-x-cuda-graphs-crash).
