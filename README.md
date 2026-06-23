# ollama-modelfiles

Custom Ollama Modelfile configurations for local LLM inference, organized by model and use profile. Canonical models source [Unsloth](https://unsloth.ai) GGUF builds from HuggingFace, and unsuffixed Qwen aliases wrap the current canonical default for that family.

## Models

Canonical Qwen benchmark variants use explicit quant suffixes. Unsuffixed Qwen filenames remain as compatibility aliases so existing model names continue to work.

### Canonical Modelfiles

| Modelfile | Base Model | Mode | Quantization | Approx. Size |
|---|---|---|---|
| `Modelfile.gemma4-12b-it-qat` | Gemma 4 12B IT QAT | Thinking | UD-Q4_K_XL | ~7 GB |
| `Modelfile.gemma4-26b-a4b-it-qat` | Gemma 4 26B A4B IT QAT | Thinking | UD-Q4_K_XL | ~15 GB |
| `Modelfile.qwen3.6-27b-coding-ud-q4-k-xl` | Qwen 3.6 27B | Precise coding | UD-Q4_K_XL | ~17.6 GB |
| `Modelfile.qwen3.6-27b-mtp-coding-ud-q4-k-xl` | Qwen 3.6 27B MTP | Precise coding + MTP | UD-Q4_K_XL | ~17.9 GB |
| `Modelfile.qwen3.6-35b-a3b-coding-ud-q4-k-xl` | Qwen 3.6 35B-A3B | Precise coding | UD-Q4_K_XL | ~22.4 GB |
| `Modelfile.qwen3.6-35b-a3b-mtp-coding-ud-q4-k-xl` | Qwen 3.6 35B-A3B MTP | Precise coding + MTP | UD-Q4_K_XL | ~22.9 GB |

### Compatibility Aliases

| Alias Modelfile | Current Canonical Target |
|---|---|
| `Modelfile.qwen3.6-27b-coding` | `qwen3.6-27b-coding-ud-q4-k-xl` |
| `Modelfile.qwen3.6-27b-mtp-coding` | `qwen3.6-27b-mtp-coding-ud-q4-k-xl` |
| `Modelfile.qwen3.6-35b-a3b-coding` | `qwen3.6-35b-a3b-coding-ud-q4-k-xl` |
| `Modelfile.qwen3.6-35b-a3b-mtp-coding` | `qwen3.6-35b-a3b-mtp-coding-ud-q4-k-xl` |

### Small Coders (fit 12 GB VRAM)

Qwen 3.6's smallest GGUF is 27B (offloads on a 12 GB card), so these use the **Qwen 3.5** dense line, which fits fully GPU-resident. Both run the same precise-coding profile as the Qwen 3.6 coders.

| Modelfile | Base Model | Mode | Quantization | Approx. Size |
|---|---|---|---|
| `Modelfile.qwen3.5-9b-coding-ud-q4-k-xl` | Qwen 3.5 9B | Precise coding | UD-Q4_K_XL | ~6.0 GB |
| `Modelfile.qwopus3.5-9b-coder-q4-k-m` | Qwopus3.5-9B-Coder (Qwen3.5-9B finetune) | Precise coding | Q4_K_M | ~5.6 GB |

Qwopus is an experimental community finetune (Claude-Opus trace-inversion distill); its coding edge over the base 9B is self-reported, which is what the `benchmark-9b-coders` suite tests.

## Quantization

Canonical models use an **Unsloth Dynamic ("UD-")** quant. This is not standard llama.cpp Q4_0:

- **UD-** prefix = Unsloth Dynamic — every layer gets a custom quantization type based on a 1.5M+ token calibration dataset
- **Q4_K_XL** = standard llama.cpp base; **XL** suffix means embedding and output weights are kept at Q8_0 for better accuracy
- Qwen canonical filenames mirror upstream quant tags verbatim
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
# Create a single canonical model from its Modelfile
./ollama-create.sh Modelfile.gemma4-12b-it-qat

# Create a single Qwen benchmark variant
./ollama-create.sh Modelfile.qwen3.6-35b-a3b-coding-ud-q4-k-xl

# Create a compatibility alias; the script builds its canonical dependency first
./ollama-create.sh Modelfile.qwen3.6-35b-a3b-coding

# Create all models at once
./ollama-create.sh
```

Canonical Modelfiles reference their source on HuggingFace via Unsloth's GGUF builds. Qwen alias Modelfiles reference a canonical local model name so the unsuffixed defaults can be repointed later without renaming the model family.

## Benchmarking

The repo includes dry-run-by-default benchmark harnesses for the Qwen, Gemma, and 9B-coders suites:

- `benchmark-qwen.sh` prints the benchmark plan and exact `ollama run --verbose` commands for the canonical Qwen coding variants.
- `benchmark-qwen.matrix.tsv` defines the canonical Qwen variants to compare.
- `benchmark-qwen.runtime.tsv` defines the Qwen runtime A/B profiles, including the current `GGML_CUDA_DISABLE_GRAPHS=1` configuration and a graphs-enabled comparison run.
- `benchmark-qwen.prompt.medium.txt` and `benchmark-qwen.prompt.long.txt` provide fixed coding prompts for repeatable Qwen runs.
- `benchmark-gemma.sh` prints the benchmark plan and exact `ollama run --verbose` commands for the current Gemma thinking profiles.
- `benchmark-gemma.matrix.tsv` defines the first-pass Gemma benchmark set: `gemma4-12b-it-qat` and `gemma4-26b-a4b-it-qat`.
- `benchmark-gemma.runtime.tsv` defines the Gemma runtime A/B profiles. It mirrors the same graphs-off versus graphs-on setup as the Qwen harness.
- `benchmark-gemma.prompt.reasoning.txt` and `benchmark-gemma.prompt.analysis.txt` provide fixed text-only prompts for repeatable Gemma runs.
- `benchmark-9b-coders.sh` prints the plan for the VRAM-fit small coders (Qwen3.5-9B, the Qwopus3.5-9B-Coder finetune, and the `gemma4-12b-it-qat` baseline); `benchmark-9b-coders.matrix.tsv` lists them and `benchmark-9b-coders.prompt.*.txt` reuses the Qwen coding prompts.
- `benchmark-all.sh` runs the Qwen, Gemma, and 9B-coders suites sequentially.

Nothing runs unless you pass `--execute`.

When executed, each harness starts temporary isolated `ollama serve` instances on the hosts defined in its runtime TSV so the graphs-off and graphs-on runs stay separate without editing systemd in place. For the cleanest results, stop or idle the systemd Ollama service before running a benchmark.

The Qwen, Gemma, and 9B-coders runtime TSVs reuse the same alternate hosts (`127.0.0.1:11435` and `127.0.0.1:11436`). Run one harness at a time unless you intentionally change the host assignments; `benchmark-all.sh` runs them sequentially, which is safe.

Gemma benchmarking is intentionally narrower than Qwen benchmarking in this repo. The current Gemma harness covers only the existing Ollama QAT models, uses text-only prompts, and does not assume Gemma MTP support through Ollama because Unsloth documents Gemma MTP for `llama.cpp` and Unsloth Studio, not for Ollama's `hf.co/...` loading path.

```bash
# Inspect the benchmark plan without running anything
./benchmark-qwen.sh

# List the configured models and prompts
./benchmark-qwen.sh --list

# When ready later, execute the benchmark matrix
./benchmark-qwen.sh --execute

# Inspect the Gemma benchmark plan without running anything
./benchmark-gemma.sh

# List the configured Gemma models and prompts
./benchmark-gemma.sh --list

# When ready later, execute the Gemma benchmark matrix
./benchmark-gemma.sh --execute
```

Executed runs write raw logs and timing metadata under `benchmark-results/<timestamp>/` so you can parse or compare them later without rerunning the models immediately.

## Files

| File | Description |
|---|---|
| `benchmark-gemma.sh` | Dry-run-by-default benchmark harness for the current Gemma QAT Ollama models |
| `benchmark-gemma.matrix.tsv` | Benchmark matrix listing the current Gemma model IDs to compare |
| `benchmark-gemma.prompt.*.txt` | Fixed text-only prompt fixtures for repeatable Gemma runs |
| `benchmark-gemma.runtime.tsv` | Runtime A/B matrix for Gemma graphs disabled versus enabled |
| `benchmark-qwen.sh` | Dry-run-by-default benchmark harness for the Qwen canonical variants |
| `benchmark-qwen.matrix.tsv` | Benchmark matrix listing the canonical Qwen model IDs to compare |
| `benchmark-qwen.prompt.*.txt` | Fixed coding prompt fixtures for repeatable Qwen runs |
| `benchmark-qwen.runtime.tsv` | Runtime A/B matrix for CUDA graphs disabled versus enabled |
| `benchmark-common.sh` | Shared harness body sourced by the `benchmark-qwen.sh`, `benchmark-gemma.sh`, and `benchmark-9b-coders.sh` wrappers |
| `benchmark-9b-coders.sh` | Dry-run-by-default harness for small coders that fit 12 GB VRAM |
| `benchmark-9b-coders.matrix.tsv` | Matrix: Qwen3.5-9B, Qwopus3.5-9B-Coder, Gemma baseline |
| `benchmark-9b-coders.runtime.tsv` | Runtime A/B matrix (graphs off vs on) |
| `benchmark-9b-coders.prompt.*.txt` | Fixed coding prompts (copies of the Qwen suite prompts) |
| `benchmark-all.sh` | Runs the Qwen, Gemma, and 9B-coders suites sequentially |
| `ollama-create.sh` | Build script — creates canonical models directly and resolves alias dependencies automatically |
| `session_summary_diffusiongemma.md` | Engineering log: research, iteration, and self-critique for DiffusionGemma configuration |
| `session_summary_9b_coders_vram.md` | Research log: 9B-coders VRAM fit + validation of prior Sonnet research |
| `.task_plan.md` | Active task plan for the current work |
