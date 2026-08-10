# CLAUDE.md

[AGENTS.md](AGENTS.md) is authoritative for this repo (conventions, build/benchmark commands, doc map); read it first.
This file holds only Claude-Code-specific notes.

## claude-local

- `claude-local`: a `~/.bashrc` fn routing Claude Code to the router (11433, `/v1/messages`) via a lane menu.
  - Lane = the fleet model serving ALL session roles (B6 fix, 2026-08-08): main + tier + subagent vars together.
    - Pinning `ANTHROPIC_MODEL` is required: settings.json's model otherwise reaches the wire verbatim.
  - No flag, no default: the numbered menu (models.ini ids + aliases, sorted) picks; Enter re-picks the last lane.
    - Sorting is the whole ordering rule: the naming convention lands each alias beside its canonical for free.
    - The last lane persists in `~/.config/claude-local.last`; non-TTY reuses it or fails with the list.
    - Any non-numeric entry is taken as a lane name verbatim (escape hatch); the router 404s visibly on a typo.
  - Every claude arg passes through untouched (`--model` included); mid-session `/model` moves only the main session.
  - Execs `claude` with `--disallowedTools=WebSearch` plus the vendored web-search MCP (`llamacpp/mcp/`, via pipx).
  - Secrets live in `~/.config/claude-local.env` (mode 600); cutover validated 2026-08-04, see the P3 history log.
- Claude Code sends multiple `system`-role messages mid-conversation.
  - No guard risk on llama-server's `/v1/messages` (verified per-build).
  - The [AGENTS.md gate](AGENTS.md#chat-template-gate-for-community-ggufs) bites OpenAI-endpoint clients.
  - Vet new community GGUFs per that section's procedure.
- CUDA graphs run ON fleet-wide, including the MTP models claude-local serves (P1-validated 2026-08-03).
  - Crash status is single-homed: [docs/benchmarking.md](docs/benchmarking.md#mtp-x-cuda-graphs-crash).
    - Resolved 2026-08-10: the large-ctx MTP crashes were this box's +230 MHz GPU core offset. Keep it at 0.
