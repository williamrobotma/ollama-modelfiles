# llama.cpp migration (option B)

SCAFFOLD - plan in a fresh session. Follows the 2026-07-17 eval verdict ([docs/history/2026-07-17-llamacpp-eval.md](../../docs/history/2026-07-17-llamacpp-eval.md)): move serving off Ollama to stock llama-server.

Do now, even before planning: serve the Gemma MTP models from llama-server (CUDA graphs on, moderate ctx) - the Ollama path crashes.

Steps, in order:

1. Find the highest stable ctx for Gemma MTP on llama-server (16k works, 200k crashes).
2. Point Claude Code at llama-server `/v1/messages` and use it for real work.
3. Move Open WebUI over; fix or replace the one GGUF that rejects multi-system requests (unsloth Qwen3.5-9B non-MTP).
4. Pick model-switching: llama-server's built-in router mode vs llama-swap.
5. Retire the Ollama daemon; reclaim its disk.

Rules: stay on build b9860; after any rebuild, re-run the crash matrix (eval log section 2b) before trusting it.

Watch - a merged fix changes step 1:

- <https://github.com/ggml-org/llama.cpp/issues/24795>
- <https://github.com/ggml-org/llama.cpp/issues/24443>
- <https://github.com/ggml-org/llama.cpp/pull/24942>

Done when: everything daily-driven serves from llama-server, Ollama is gone, architecture.md and AGENTS.md updated.
