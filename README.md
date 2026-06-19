# ollama-modelfiles

Custom Ollama Modelfile configurations for local LLM inference, organized by model and use profile. All models sourced from [Unsloth](https://unsloth.ai) GGUF builds on HuggingFace.

## Models

| Modelfile | Base Model | Quantization | VRAM |
|---|---|---|---|
| `Modelfile.gemma4-12b-it-qat` | Gemma 4 12B IT QAT | UD-Q4_K_XL | ~7 GB |
| `Modelfile.gemma4-26b-a4b-it-qat` | Gemma 4 26B A4B IT QAT | UD-Q4_K_XL | ~15 GB |
| `Modelfile.qwen3.6-27b-coding` | Qwen 3.6 27B | UD-Q4_K_XL | ~18 GB |
| `Modelfile.qwen3.6-35b-a3b-coding` | Qwen 3.6 35B-A3B | UD-Q4_K_XL | ~22 GB |

## Quantization

All models use **Unsloth Dynamic UD-Q4_K_XL** — Unsloth's proprietary per-layer dynamic quantization method. This is not standard llama.cpp Q4_0:

- **UD-** prefix = Unsloth Dynamic — every layer gets a custom quantization type based on a 1.5M+ token calibration dataset
- **Q4_K_XL** = standard llama.cpp base; **XL** suffix means embedding and output weights are kept at Q8_0 for better accuracy
- For Gemma 4 QAT models, standard Q4_0 degrades accuracy from ~89% to ~74% Top-1% and is actually *larger* (6.98 GB vs 6.72 GB for UD-Q4_K_XL)
- See [Unsloth Dynamic 2.0 GGUFs](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs)

## Profiles

Two tuning profiles, each suited to a different mode of use.

### Thinking (Gemma 4)

For research, open-ended reasoning, and exploration.

| Parameter | Value | Source |
|---|---|---|
| `temperature` | 1.0 | [Unsloth Gemma 4 docs](https://unsloth.ai/docs/models/gemma-4) |
| `top_p` | 0.95 | |
| `top_k` | 64 | |
| `repeat_penalty` | 1.0 | |
| `num_ctx` | 131072 | 256K max for 12B/26B-A4B/31B variants |
| `num_predict` | 65536 | |
| System trigger | `<|think|>` | Required at start of system prompt to activate reasoning |

**Note:** CUDA 13.2 produces corrupted outputs. Use CUDA 13.1 or 13.3.

### Precise Coding (Qwen 3.6)

For code generation, debugging, and structured technical work.

| Parameter | Value | Source |
|---|---|---|
| `temperature` | 0.6 | [Unsloth Qwen 3.6 docs](https://unsloth.ai/docs/models/qwen3.6) |
| `top_p` | 0.95 | |
| `top_k` | 20 | |
| `min_p` | 0.0 | |
| `presence_penalty` | 0.0 | |
| `repeat_penalty` | 1.0 | Mandated by Unsloth — deviating causes structural garbage in code output |
| `num_ctx` | 131072 | 256K max (expandable to 1M via YaRN) |
| `num_predict` | 65536 | |

Qwen 3.6 has **thinking enabled by default**. To disable: `--chat-template-kwargs '{"enable_thinking":false}'` (llama.cpp) or `/no_think` in the prompt.

### General Tasks (Qwen 3.6)

For non-coding use with thinking mode:

| Parameter | Value |
|---|---|
| `temperature` | 1.0 |
| `top_p` | 0.95 |
| `top_k` | 20 |
| `min_p` | 0.0 |
| `presence_penalty` | 0.0 |
| `repeat_penalty` | 1.0 |

### Instruct Mode (Qwen 3.6, non-thinking)

For direct responses without reasoning traces:

| Parameter | Value |
|---|---|
| `temperature` | 0.7 |
| `top_p` | 0.8 |
| `top_k` | 20 |
| `min_p` | 0.0 |
| `presence_penalty` | 1.5 |
| `repeat_penalty` | 1.0 |

### DiffusionGemma

DiffusionGemma uses **discrete block diffusion**, not autoregressive token generation. It generates 256-token canvases simultaneously through iterative denoising. Standard autoregressive parameters (temperature, top_k, top_p) are explicitly noted as insufficient — the model requires a diffusion sampler with a temperature schedule (0.8→0.4 decay) and entropy-bound adaptive stopping. See [DiffusionGemma docs](https://unsloth.ai/docs/models/diffusiongemma).

## Usage

```bash
# Create a single model from its Modelfile
./ollama-create.sh Modelfile.gemma4-12b-it-qat

# Create all models at once
./ollama-create.sh
```

Each Modelfile references its source on HuggingFace via Unsloth's GGUF builds. Run `ollama create` to pull and register the model locally.

## Files

| File | Description |
|---|---|
| `ollama-create.sh` | Build script — creates all models or a single one from its Modelfile |
| `session_summary_diffusiongemma.md` | Engineering log: research, iteration, and self-critique for DiffusionGemma configuration |
| `.task_plan.md` | Active task plan for ongoing modelfile review work |
