# CLAUDE.md

[AGENTS.md](AGENTS.md) is authoritative for this repo (conventions, build/benchmark commands, doc map). Read it first. This file holds only Claude-Code-specific notes.

## claude-local

- `claude-local` drives Ollama by `ollama launch claude`, routing Claude Code to Ollama's Anthropic-compatible endpoint (`127.0.0.1:11434/v1/messages`).
- Claude Code sends multiple `system`-role messages mid-conversation (top-level system + session-hook + skills/reminders), so any community GGUF served to it must pass the chat-template gate in [AGENTS.md](AGENTS.md#chat-template-gate-for-community-ggufs). Vet with `ollama show --template <model>` before pointing claude-local at a new community model.
- The MTP models served via claude-local are the ones exposed to the CUDA-graphs crash tracked in [docs/benchmarking.md](docs/benchmarking.md#mtp-x-cuda-graphs-crash) (prod graphs-off fix is pending, needs sudo).
