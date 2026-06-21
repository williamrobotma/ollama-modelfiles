# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Ollama Modelfile configurations for local LLM inference. Gemma files are self-contained HuggingFace-backed Modelfiles. Qwen benchmark variants use canonical quant-suffixed Modelfiles that reference HuggingFace directly, plus unsuffixed alias Modelfiles that reference a canonical local model name. There is no code, no test suite, and only a small build helper script alongside the Modelfiles and research notes.

## File Structure

```
Modelfile.gemma4-12b-it-qat          — Gemma 4 12B IT QAT, thinking mode
Modelfile.gemma4-26b-a4b-it-qat      — Gemma 4 26B A4B IT QAT, thinking mode
Modelfile.qwen3.6-27b-coding-*       — Canonical 27B precise-coding variants by quant
Modelfile.qwen3.6-27b-mtp-coding-*   — Canonical 27B MTP precise-coding variants by quant
Modelfile.qwen3.6-35b-a3b-coding-*   — Canonical 35B-A3B precise-coding variants by quant
Modelfile.qwen3.6-35b-a3b-mtp-coding-* — Canonical 35B-A3B MTP precise-coding variants by quant
Modelfile.qwen3.6-27b-coding         — Compatibility alias for the current 27B default quant
Modelfile.qwen3.6-27b-mtp-coding     — Compatibility alias for the current 27B MTP default quant
Modelfile.qwen3.6-35b-a3b-coding     — Compatibility alias for the current 35B-A3B default quant
Modelfile.qwen3.6-35b-a3b-mtp-coding — Compatibility alias for the current 35B-A3B MTP default quant
benchmark-qwen.sh                    — Dry-run-by-default Qwen benchmark harness
benchmark-qwen.matrix.tsv            — Canonical Qwen benchmark matrix
benchmark-qwen.runtime.tsv           — Runtime A/B matrix for graphs off vs on
benchmark-qwen.prompt.*.txt          — Fixed prompts for repeatable local runs
benchmark-gemma.sh                   — Dry-run-by-default Gemma benchmark harness
benchmark-gemma.matrix.tsv           — First-pass Gemma benchmark matrix
benchmark-gemma.runtime.tsv          — Runtime A/B matrix for graphs off vs on
benchmark-gemma.prompt.*.txt         — Fixed text-only prompts for repeatable local runs
benchmark-common.sh                  — Shared harness body sourced by both benchmark-*.sh wrappers
ollama-create.sh                     — Bash script to build one or all models
session_summary_diffusiongemma.md    — Research log for DiffusionGemma work
.task_plan.md                        — Active task plan
```

## Key Conventions

- **UD-Q4_K_XL** is the only recommended quantization for Gemma 4 QAT models. Standard Q4_0 degrades accuracy and is actually larger.
- **Gemma benchmark scope**: the repo's first-pass Gemma Ollama benchmark covers only `gemma4-12b-it-qat` and `gemma4-26b-a4b-it-qat`, using text-only prompts.
- Canonical Qwen benchmark filenames append the exact upstream quant tag. Mirror upstream tags verbatim rather than forcing a repo-local rename scheme.
- Qwen 27B IQ variants are published as `IQ4_XS`, while 35B-A3B IQ variants are published as `UD-IQ4_XS`.
- **Gemma 4 thinking**: activate with `<|think|>` at the start of the system prompt. There is no other trigger.
- **Gemma 4 MTP**: documented by Unsloth for `llama.cpp` and Unsloth Studio, but not confirmed for Ollama `hf.co/...` loading, so do not stage Gemma MTP variants here unless Ollama support is verified.
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

- **Canonical quant-suffixed Modelfiles are the source of truth** — keep the full parameter block there.
- **Unsuffixed Qwen aliases should stay thin** — they should only point to one canonical local model via `FROM <model-name>`.
- **Add a new benchmark variant**: create `Modelfile.<name>-<quant-tag>`, mirror the exact upstream quant tag in the filename, and include verified parameters.
- **Verify parameters** against the official sources before changing values:
  - Gemma 4: https://unsloth.ai/docs/models/gemma-4
  - Qwen 3.6: https://unsloth.ai/docs/models/qwen3.6
  - DiffusionGemma: https://unsloth.ai/docs/models/diffusiongemma
  - Dynamic GGUFs: https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs
- **Build script**: `./ollama-create.sh` creates all models; it resolves canonical dependencies before alias wrappers when building the whole repo or a single alias Modelfile.
- **Benchmark harness**: `./benchmark-qwen.sh` is dry-run by default and should stay that way; require an explicit `--execute` to run Ollama.
- **Gemma benchmark harness**: `./benchmark-gemma.sh` is also dry-run by default and should stay text-only unless the repo intentionally adds multimodal benchmarking inputs.
- **Runtime A/B**: benchmark runtime profiles should compare the current `GGML_CUDA_DISABLE_GRAPHS=1` setup against a graphs-enabled run using isolated alternate-port `ollama serve` instances, not by mutating systemd mid-run.
- **Shared runtime ports**: the current Qwen and Gemma runtime TSVs both use `127.0.0.1:11435` and `127.0.0.1:11436`, so do not execute both harnesses concurrently unless the host assignments are changed.

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
