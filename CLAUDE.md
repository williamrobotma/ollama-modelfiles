# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Ollama Modelfile configurations for local LLM inference. Each `Modelfile.*` is a self-contained Ollama build file that references a base model on HuggingFace via Unsloth's UD-Q4_K_XL quantized GGUF builds. There is no code, no build system, no tests — just Modelfiles, a build script, and research notes.

## File Structure

```
Modelfile.gemma4-12b-it-qat          — Gemma 4 12B IT QAT, thinking mode
Modelfile.gemma4-26b-a4b-it-qat      — Gemma 4 26B A4B IT QAT, thinking mode
Modelfile.qwen3.6-27b-coding         — Qwen 3.6 27B, precise coding profile
Modelfile.qwen3.6-35b-a3b-coding     — Qwen 3.6 35B-A3B, precise coding profile
ollama-create.sh                     — Bash script to build one or all models
session_summary_diffusiongemma.md    — Research log for DiffusionGemma work
.task_plan.md                        — Active task plan
```

## Key Conventions

- **UD-Q4_K_XL** is the only recommended quantization for Gemma 4 QAT models. Standard Q4_0 degrades accuracy and is actually larger.
- **Gemma 4 thinking**: activate with `<|think|>` at the start of the system prompt. There is no other trigger.
- **Qwen 3.6 thinking**: enabled by default. Disable with `--chat-template-kwargs '{"enable_thinking":false}'` or `/no_think` in the prompt.
- **Qwen 3.6 repeat_penalty**: must be exactly 1.0. Unsloth docs mandate this — any other value causes structural garbage in code output.
- **CUDA 13.2 produces corrupted outputs** for Gemma 4. Use 13.1 or 13.3.
- **DiffusionGemma** uses block diffusion, not autoregressive generation. Standard autoregressive params (temperature, top_k, top_p) are explicitly noted as insufficient — the model requires a diffusion sampler with temperature schedule and entropy-bound adaptive stopping.

## Parameter Reference

All values verified against [Unsloth docs](https://unsloth.ai/docs/models/) and [Qwen docs](https://qwen.readthedocs.io/).

### Gemma 4 (Thinking)
| Parameter | Value | Note |
|---|---|---|
| temperature | 1.0 | |
| top_p | 0.95 | |
| top_k | 64 | |
| repeat_penalty | 1.0 | |
| num_ctx | 131072 | 256K max |
| num_predict | 65536 | |

### Qwen 3.6 (Precise Coding)
| Parameter | Value | Note |
|---|---|---|
| temperature | 0.6 | |
| top_p | 0.95 | |
| top_k | 20 | |
| min_p | 0.0 | |
| presence_penalty | 0.0 | |
| repeat_penalty | 1.0 | **Must be 1.0** |
| num_ctx | 131072 | 256K max, 1M with YaRN |
| num_predict | 65536 | |

### Qwen 3.6 (General Tasks, thinking)
| Parameter | Value |
|---|---|
| temperature | 1.0 |
| top_p | 0.95 |
| top_k | 20 |
| min_p | 0.0 |
| presence_penalty | 0.0 |
| repeat_penalty | 1.0 |

### Qwen 3.6 (Instruct Mode, non-thinking)
| Parameter | Value |
|---|---|
| temperature | 0.7 |
| top_p | 0.8 |
| top_k | 20 |
| min_p | 0.0 |
| presence_penalty | 1.5 |
| repeat_penalty | 1.0 |

## Making Changes

- **Edit a Modelfile directly** — each file is self-contained. Only touch the parameters you need to change.
- **Add a new model**: create `Modelfile.<name>`, reference the correct Unsloth GGUF path, and include verified parameters.
- **Verify parameters** against the official sources before changing values:
  - Gemma 4: https://unsloth.ai/docs/models/gemma-4
  - Qwen 3.6: https://unsloth.ai/docs/models/qwen3.6
  - DiffusionGemma: https://unsloth.ai/docs/models/diffusiongemma
  - Dynamic GGUFs: https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs
- **Build script**: `./ollama-create.sh` creates all models; `./ollama-create.sh Modelfile.<name>` creates a single one.

## Common Commands

```bash
# Create all models
./ollama-create.sh

# Create a single model
./ollama-create.sh Modelfile.gemma4-12b-it-qat

# List local models
ollama list

# Run a model
ollama run <model-name>
```
