# CLAUDE.md

[AGENTS.md](AGENTS.md) is authoritative for this repo (conventions, build/benchmark commands, doc map). Read it first. This file holds only Claude-Code-specific notes.

## claude-local

- `claude-local` drives Ollama by `ollama launch claude`, routing Claude Code to Ollama's Anthropic-compatible endpoint (`127.0.0.1:11434/v1/messages`).
- Claude Code sends multiple `system`-role messages mid-conversation.
  - No guard risk on Anthropic endpoints: Ollama never runs GGUF Jinja; `/v1/messages` folds system first.
  - The [AGENTS.md gate](AGENTS.md#chat-template-gate-for-community-ggufs) bites OpenAI-endpoint clients.
  - Vet new community GGUFs per that section's procedure, not `ollama show --template`.
- The MTP models served via claude-local are the ones exposed to the CUDA-graphs crash tracked in [docs/benchmarking.md](docs/benchmarking.md#mtp-x-cuda-graphs-crash) (prod graphs-off fix is pending, needs sudo).
