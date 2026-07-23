# ollama-modelfiles

Ollama Modelfile configurations for local LLM inference on a single 12 GB GPU, organized by model family and use profile. Every Modelfile references a local GGUF in the Hugging Face cache (downloaded with `hf download`, pinned to a snapshot path - mostly [Unsloth](https://unsloth.ai) builds). The same cached GGUFs can be loaded directly by llama.cpp. Agents should read [AGENTS.md](AGENTS.md) first.

## Requirements

- Ollama 0.31.1 or newer (the `DRAFT` MTP directive runs on the CUDA runner as of 0.31.1).
- The Hugging Face CLI (`hf`, from `huggingface_hub`) to provision GGUFs.
- An NVIDIA CUDA GPU. The reference box is an RTX 4070 (12 GB, WSL2); models larger than ~12 GB partial-offload to CPU. Use CUDA 13.1 or 13.3 - 13.2 corrupts Gemma 4 output.

## Quickstart

```bash
# 1. Clone
git clone <this repo> && cd ollama-modelfiles

# 2. Download one model's GGUFs into the HF cache (weights + vision projector)
hf download unsloth/gemma-4-12B-it-qat-GGUF \
    gemma-4-12B-it-qat-UD-Q4_K_XL.gguf mmproj-BF16.gguf

# 3. Build the Ollama model from its Modelfile directory
scripts/ollama-create.sh modelfiles/gemma4/12b-it-qat

# 4. Run it
ollama run gemma4-12b-it-qat
```

The model name is always `<family>-<stem>` from `modelfiles/<family>/<stem>/`. `FROM` paths are pinned to a specific snapshot commit; if `hf download` fetches a newer commit, update the `FROM` line in the Modelfile to the new snapshot path (deliberate pinning - see [AGENTS.md](AGENTS.md#gguf-sourcing-convention)). Run `scripts/ollama-create.sh` with no argument to build every model.

## Model catalog

Model name = `<family>-<stem>`. Sizes are the Ollama store size on the reference box.

### Gemma 4 (thinking; vision via mmproj)

| Model | Family | What it is | Quant | Size |
|---|---|---|---|---|
| `gemma4-12b-it-qat` | gemma4 | 12B IT QAT, thinking + vision, resident | UD-Q4_K_XL | 6.9 GB |
| `gemma4-26b-a4b-it-qat` | gemma4 | 26B-A4B MoE IT QAT, thinking + vision | UD-Q4_K_XL | 15 GB |
| `gemma4-26b-a4b-it-qat-mtp` | gemma4 | 26B-A4B + separate MTP drafter (`DRAFT`) | UD-Q4_K_XL | 15 GB |
| `gemma4-31b-it-qat` | gemma4 | 31B dense IT QAT, thinking + vision, offloads | UD-Q4_K_XL | 18 GB |

### Qwen 3.6 coders (precise coding)

| Model | Family | What it is | Quant | Size |
|---|---|---|---|---|
| `qwen3.6-27b-coding-ud-q4-k-xl` | qwen3.6 | 27B dense precise coding | UD-Q4_K_XL | 18 GB |
| `qwen3.6-27b-mtp-coding-ud-q4-k-xl` | qwen3.6 | 27B MTP self-draft coding | UD-Q4_K_XL | 18 GB |
| `qwen3.6-35b-a3b-coding-ud-q4-k-xl` | qwen3.6 | 35B-A3B MoE precise coding | UD-Q4_K_XL | 23 GB |
| `qwen3.6-35b-a3b-mtp-ud-q4-k-xl` | qwen3.6 | 35B-A3B MTP base (instruct profile) | UD-Q4_K_XL | 23 GB |
| `qwen3.6-35b-a3b-mtp-ud-q5-k-xl` | qwen3.6 | 35B-A3B MTP base (instruct profile) | UD-Q5_K_XL | 28 GB |
| `qwen3.6-35b-a3b-mtp-coding-ud-q4-k-xl` | qwen3.6 | 35B-A3B MTP coding profile | UD-Q4_K_XL | 23 GB |
| `qwen3.6-35b-a3b-mtp-coding-ud-q5-k-xl` | qwen3.6 | 35B-A3B MTP coding profile | UD-Q5_K_XL | 28 GB |
| `qwen3.6-35b-a3b-mtp-reasoning-ud-q5-k-xl` | qwen3.6 | 35B-A3B MTP reasoning profile | UD-Q5_K_XL | 28 GB |

### Small coders (fit 12 GB VRAM)

Qwen 3.6's smallest GGUF is 27B (offloads), so these use the Qwen 3.5 dense line, which fits fully resident and runs the same precise-coding profile.

| Model | Family | What it is | Quant | Size |
|---|---|---|---|---|
| `qwen3.5-9b-coding-ud-q4-k-xl` | qwen3.5 | 9B precise coding, resident | UD-Q4_K_XL | 6.9 GB |
| `qwen3.5-9b-mtp-coding-ud-q4-k-xl` | qwen3.5 | 9B MTP self-draft coding | UD-Q4_K_XL | 7.1 GB |
| `qwopus3.5-9b-coder-q4-k-m` | qwopus3.5 | Community Qwen3.5-9B finetune (experimental), coding | Q4_K_M | 6.6 GB |
| `qwen3.5-queen-27b-coding-q4-k-m` | qwen3.5 | Queen-27B community model, coding (verify claims + gate) | i1-Q4_K_M | 16 GB |

### Uncensored (reasoning / research / agentic track)

Community abliterated builds (plain Q4/i1-Q4, not UD-*). Abliteration can dent reasoning/tool-calling - verify on-task; all must pass the [chat-template gate](AGENTS.md#chat-template-gate-for-community-ggufs).

| Model | Family | What it is | Quant | Size |
|---|---|---|---|---|
| `gemma4-12b-it-obliterated` | gemma4 | Uncensored 12B (OBLITERATUS CoT-aware), resident thinking | Q4_K_M | 7.4 GB |
| `gemma4-26b-a4b-it-heretic-i1-q4-k-m` | gemma4 | Uncensored 26B-A4B MoE (Heretic/ARA), reasoning daily driver, offload | i1-Q4_K_M | 16 GB |
| `gemma4-31b-it-heretic-i1-q4-k-m` | gemma4 | Uncensored 31B dense (Heretic), offload | i1-Q4_K_M | 18 GB |
| `qwen3.6-27b-obliterated-q4-k-m` | qwen3.6 | Uncensored 27B (OBLITERATUS), general/thinking | Q4_K_M | 16 GB |
| `qwen3.6-27b-obliterated-coding-q4-k-m` | qwen3.6 | Uncensored 27B (OBLITERATUS), precise coding | Q4_K_M | 16 GB |

### Compatibility aliases

Thin one-line Modelfiles that repoint an unsuffixed default at the current canonical quant, so model names stay stable when the default changes.

| Alias | Current target |
|---|---|
| `qwen3.6-27b-coding` | `qwen3.6-27b-coding-ud-q4-k-xl` |
| `qwen3.6-27b-mtp-coding` | `qwen3.6-27b-mtp-coding-ud-q4-k-xl` |
| `qwen3.6-35b-a3b-coding` | `qwen3.6-35b-a3b-coding-ud-q4-k-xl` |
| `qwen3.6-35b-a3b-mtp-coding` | `qwen3.6-35b-a3b-mtp-coding-ud-q5-k-xl` |
| `qwen3.6-35b-a3b-mtp-reasoning` | `qwen3.6-35b-a3b-mtp-reasoning-ud-q5-k-xl` |
| `qwen3.6-27b-obliterated-coding` | `qwen3.6-27b-obliterated-coding-q4-k-m` |
| `qwen3.5-9b-mtp-coding` | `qwen3.5-9b-mtp-coding-ud-q4-k-xl` |

## Quantization

Canonical Unsloth models use an Unsloth Dynamic ("UD-") quant, which is not standard llama.cpp Q4_0:

- **UD-** = Unsloth Dynamic: every layer gets a custom quant type based on a 1.5M+ token calibration set.
- **Q4_K_XL / Q5_K_XL** = the **XL** suffix keeps embedding and output weights at Q8_0 for better accuracy.
- Gemma 4 QAT repos publish only UD-Q4_K_XL (QAT already targets ~Q4); standard Q4_0 degrades Top-1 from ~89% to ~74% and is larger.
- Community abliterated models are not Unsloth, so their tags are plain Q4_K_M or i1-Q4_K_M, not UD-*.
- See [Unsloth Dynamic 2.0 GGUFs](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs).

Sampling profiles (Gemma thinking, Qwen precise-coding/general/instruct) live in [docs/parameters.md](docs/parameters.md).

## Repo map

| Path | What |
|---|---|
| `modelfiles/<family>/<stem>/Modelfile` | The models; name = `<family>-<stem>`. |
| `scripts/` | `ollama-create.sh` (build), `repro-mtp-graphs.sh` (crash repro). |
| `benchmarks/` | Three dry-run-by-default suites plus shared `common.sh`, `report.py`, `all.sh`. |
| `docs/` | Topic docs; `docs/history/` holds immutable dated session logs. |
| `specs/<feature>/` | Spec + plan + tasks for in-flight work; executed by the run-spec skill. |
| `specs/done/<feature>/` | Completed bundles (spec.md Acceptance met), filed here by the run-spec skill. |
| `AGENTS.md` / `CLAUDE.md` | Canonical agent instructions; thin Claude-specific shim. |

## Benchmarking

Three dry-run-by-default suites (`qwen`, `gemma`, `9b-coders`) time decode throughput and A/B CUDA graphs off vs on. Nothing runs without `--execute`.

```bash
benchmarks/qwen/run.sh            # print the plan (dry-run)
benchmarks/qwen/run.sh --execute  # run it
```

Ports, isolated serves, and distilled findings (MTP speedups, the CUDA-graphs crash, throughput costs): [docs/benchmarking.md](docs/benchmarking.md).

## More

- [AGENTS.md](AGENTS.md) - conventions and commands for any coding agent.
- [docs/architecture.md](docs/architecture.md) - how the stack fits together.
- [docs/parameters.md](docs/parameters.md) - sampling profiles and mandates.
- [docs/openwebui.md](docs/openwebui.md) - the browser frontend.
- [docs/history/index.md](docs/history/index.md) - the research trail.
