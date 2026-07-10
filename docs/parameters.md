# Parameter reference

Single authoritative home for the sampling profiles used across the Modelfiles. README and AGENTS.md link here instead of duplicating the tables.

Every value is verified against the official sources before it goes into a Modelfile:

- Gemma 4: <https://unsloth.ai/docs/models/gemma-4>
- Qwen 3.6: <https://unsloth.ai/docs/models/qwen3.6>
- DiffusionGemma: <https://unsloth.ai/docs/models/diffusiongemma>
- Dynamic GGUFs: <https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs>
- Qwen upstream: <https://qwen.readthedocs.io/>

## Mandates (do not deviate)

- **Qwen repeat_penalty must be exactly 1.0.** Unsloth mandates it; any other value causes structural garbage in code output.
- **CUDA 13.2 produces corrupted Gemma 4 output.** Use CUDA 13.1 or 13.3.
- **Gemma 4 thinking** activates only with `<|think|>` at the start of the system prompt. There is no other trigger. The generation channel then uses `<think>...</think>` tags to separate reasoning from the answer.
- **Qwen 3.6 thinking** is enabled by default. Disable with `--chat-template-kwargs '{"enable_thinking":false}'` (llama.cpp) or `/no_think` in the prompt.

## Gemma 4 (Thinking)

For research, open-ended reasoning, and exploration.

| Parameter | Value | Note |
|---|---|---|
| temperature | 1.0 | |
| top_p | 0.95 | |
| top_k | 64 | |
| repeat_penalty | 1.0 | |
| num_ctx | 131072-200000 | 256K max; 12B/31B dense run 200000, 26B-A4B runs 131072 |
| num_predict | 65536 | |
| System trigger | `<|think|>` | Required at start of system prompt to activate reasoning |

## Qwen 3.6 (Precise Coding)

For code generation, debugging, and structured technical work.

| Parameter | Value | Note |
|---|---|---|
| temperature | 0.6 | |
| top_p | 0.95 | |
| top_k | 20 | |
| min_p | 0.0 | |
| presence_penalty | 0.0 | |
| repeat_penalty | 1.0 | Mandated 1.0 - deviating causes structural garbage in code output |
| num_ctx | 131072-262144 | 256K max (1M with YaRN); 27B/9B coders 131072, 35B-A3B MTP tiers 200000-262144 |
| num_predict | 65536 | |

The Qwen 3.5 9B coders reuse this exact precise-coding profile (verified identical to 3.6).

## Qwen 3.6 (General Tasks, thinking)

For non-coding use with thinking mode on.

| Parameter | Value |
|---|---|
| temperature | 1.0 |
| top_p | 0.95 |
| top_k | 20 |
| min_p | 0.0 |
| presence_penalty | 0.0 |
| repeat_penalty | 1.0 |

## Qwen 3.6 (Instruct Mode, non-thinking)

For direct responses without reasoning traces.

| Parameter | Value |
|---|---|
| temperature | 0.7 |
| top_p | 0.8 |
| top_k | 20 |
| min_p | 0.0 |
| presence_penalty | 1.5 |
| repeat_penalty | 1.0 |

## DiffusionGemma

DiffusionGemma uses discrete block diffusion, not autoregressive token generation. It denoises 256-token canvases iteratively. Standard autoregressive parameters (temperature, top_k, top_p) are explicitly insufficient - the model needs a diffusion sampler with a temperature schedule (0.8 -> 0.4 decay) and entropy-bound adaptive stopping. See the DiffusionGemma docs linked above.
