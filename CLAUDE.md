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
  - Crash history: [docs/benchmarking.md](docs/benchmarking.md#mtp-x-cuda-graphs-crash).
  - Amended 2026-08-08: build 10326 failed re-cert (Qwen hammer 2/30).
  - It also crash-looped live at ~88k ctx on the Gemma 12B MTP lane.
  - Isolated 2026-08-09: MTP is the trigger (p = 0.002). CUDA graphs were tested and are not (p = 0.50).
  - Attribution moved 2026-08-09 to a local GPU hardware fault; no upstream filing until a stock-clock test clears it.
  - See [the 2026-08-08 recert-crash log](docs/history/2026-08-08-llamacpp-recert-crash-diagnosis.md).
