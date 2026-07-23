# llama.cpp migration (option B)

SCAFFOLD - plan in a fresh session. Follows the 2026-07-17 eval verdict ([eval log](../../docs/history/2026-07-17-llamacpp-eval.md)): move serving off Ollama to stock llama-server.

## Do now (before planning)

Serve the Gemma MTP models from llama-server (CUDA graphs on, moderate ctx) - the Ollama path crashes.

## Steps

1. Find the highest stable ctx for Gemma MTP on llama-server (16k works, 200k crashes).
2. Point Claude Code at llama-server `/v1/messages`; use it for real work.
3. Move Open WebUI over; the Qwen GGUFs that reject multi-system requests need a guard-free template (`--chat-template-file`, froggeric). The guard is the official Qwen default, not one build - unsloth Qwen3.5-9B non-MTP plus the OBLITERATUS-27B and Queen-27B community builds. See [specs/chat-template-refresh](../chat-template-refresh/spec.md).
4. Pick model-switching (llama-server's built-in router mode vs llama-swap); document where per-model serving config lives (the config home for non-Ollama models).
5. Retire the Ollama daemon; reclaim its disk.

## Rules

- Stay on build b9860.
- After any rebuild, re-run the crash matrix (eval log section 2b) before trusting it.

## Watch

A merged fix changes step 1:

- <https://github.com/ggml-org/llama.cpp/issues/24795>
- <https://github.com/ggml-org/llama.cpp/issues/24443>
- <https://github.com/ggml-org/llama.cpp/pull/24942>

## Done when

Everything daily-driven serves from llama-server, Ollama is gone, the per-model serving-config home is documented, and architecture.md and AGENTS.md updated.
