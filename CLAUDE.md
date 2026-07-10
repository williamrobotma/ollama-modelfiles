# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Ollama Modelfile configurations for local LLM inference. Canonical quant-suffixed Modelfiles reference **local GGUFs in the Hugging Face cache** (provisioned via `hf download`, pinned snapshot paths); unsuffixed alias Modelfiles reference a canonical local model name. There is no code, no test suite, and only a small build helper script alongside the Modelfiles and research notes.

**GGUF sourcing convention (since migrate/hf-local-ggufs, 2026-07):** do NOT use `FROM hf.co/...` (Ollama's OCI bridge; prone to config-blob hangs) or registry.ollama.ai tags. Provision with `hf download ORG/REPO file.gguf` and reference the absolute snapshot path: `FROM /home/wma/.cache/huggingface/hub/models--ORG--REPO/snapshots/<commit>/<file>.gguf`. The same files serve llama.cpp directly (`--model`/`--model-draft`). Vision models need a second `FROM <...>/mmproj-*.gguf` line or the `vision` capability is silently dropped. Keep-set policy: every installed Ollama model corresponds to a repo Modelfile; anything else gets `ollama rm`'d. See `session_summary_migration_local_ggufs.md`.

## File Structure

```
Modelfile.gemma4-12b-it-qat          — Gemma 4 12B IT QAT, thinking mode (+ mmproj)
Modelfile.gemma4-26b-a4b-it-qat      — Gemma 4 26B A4B IT QAT MoE, thinking mode (+ mmproj)
Modelfile.gemma4-26b-a4b-it-qat-mtp  — 26B-A4B + separate MTP drafter (DRAFT directive; ~1.5x decode)
Modelfile.gemma4-31b-it-qat          — Gemma 4 31B IT QAT dense, thinking mode (+ mmproj; offloads)
Modelfile.qwen3.6-27b-coding-*       — Canonical 27B precise-coding variants by quant
Modelfile.qwen3.6-27b-mtp-coding-*   — Canonical 27B MTP precise-coding variants by quant
Modelfile.qwen3.6-35b-a3b-coding-*   — Canonical 35B-A3B precise-coding variants by quant
Modelfile.qwen3.6-35b-a3b-mtp-ud-q*-k-xl — Canonical 35B-A3B MTP base (instruct profile) by quant
Modelfile.qwen3.6-35b-a3b-mtp-coding-*   — 35B-A3B MTP precise-coding profiles (layered on mtp base)
Modelfile.qwen3.6-35b-a3b-mtp-reasoning-* — 35B-A3B MTP reasoning profile (layered on mtp base)
Modelfile.qwen3.6-27b-coding         — Compatibility alias for the current 27B default quant
Modelfile.qwen3.6-27b-mtp-coding     — Compatibility alias for the current 27B MTP default quant
Modelfile.qwen3.6-35b-a3b-coding     — Compatibility alias for the current 35B-A3B default quant
Modelfile.qwen3.6-35b-a3b-mtp-coding — Compatibility alias (currently -> ud-q5-k-xl coding)
Modelfile.qwen3.6-35b-a3b-mtp-reasoning — Compatibility alias for the MTP reasoning default
Modelfile.qwen3.5-9b-coding-ud-q4-k-xl — Qwen 3.5 9B precise-coding (Unsloth UD-Q4_K_XL), fits 12 GB VRAM
Modelfile.qwen3.5-9b-mtp-coding-ud-q4-k-xl — Qwen 3.5 9B MTP precise-coding (Unsloth UD-Q4_K_XL, self-contained MTP), tight-resident
Modelfile.qwen3.5-9b-mtp-coding        — Compatibility alias for the current 9B MTP default quant
Modelfile.qwen3.5-queen-27b-coding-q4-k-m — Qwen3.5-Queen-27B community model (mradermacher i1-Q4_K_M; verify claims + template gate)
Modelfile.qwopus3.5-9b-coder-q4-k-m    — Qwopus3.5-9B-Coder: community finetune of Qwen3.5-9B (experimental; upstream renamed files to -coder-Exp-)
Modelfile.gemma4-12b-it-obliterated    — Uncensored Gemma 4 12B (OBLITERATUS CoT-aware abliterated), resident, thinking
Modelfile.gemma4-26b-a4b-it-heretic-i1-q4-k-m — Uncensored Gemma 4 26B-A4B MoE (Heretic ARA, i1-Q4_K_M), offload; reasoning/agentic daily driver
Modelfile.gemma4-31b-it-heretic-i1-q4-k-m — Uncensored Gemma 4 31B dense (Heretic, i1-Q4_K_M), offload
Modelfile.qwen3.6-27b-obliterated-q4-k-m          — Uncensored Qwen3.6-27B (OBLITERATUS CoT-aware), general/thinking profile
Modelfile.qwen3.6-27b-obliterated-coding-q4-k-m   — Uncensored Qwen3.6-27B (OBLITERATUS CoT-aware), precise-coding profile
Modelfile.qwen3.6-27b-obliterated-coding           — Alias for qwen3.6-27b-obliterated-coding-q4-k-m

benchmark-qwen.sh                    — Dry-run-by-default Qwen benchmark harness
benchmark-qwen.matrix.tsv            — Canonical Qwen benchmark matrix
benchmark-qwen.runtime.tsv           — Runtime A/B matrix for graphs off vs on
benchmark-qwen.prompt.*.txt          — Fixed prompts for repeatable local runs
benchmark-gemma.sh                   — Dry-run-by-default Gemma benchmark harness
benchmark-gemma.matrix.tsv           — First-pass Gemma benchmark matrix
benchmark-gemma.runtime.tsv          — Runtime A/B matrix for graphs off vs on
benchmark-gemma.prompt.*.txt         — Fixed text-only prompts for repeatable local runs
benchmark-9b-coders.sh               — Dry-run-by-default 9B-coders (VRAM-fit) benchmark harness
benchmark-9b-coders.matrix.tsv       — 9B-coders matrix: Qwen3.5-9B, Qwopus, Gemma baseline
benchmark-9b-coders.runtime.tsv      — Runtime A/B matrix for graphs off vs on
benchmark-9b-coders.prompt.*.txt     — Fixed coding prompts (copies of the Qwen suite prompts)
benchmark-all.sh                     — Runs all suites sequentially: qwen, gemma, 9b-coders
benchmark-common.sh                  — Shared harness body sourced by both benchmark-*.sh wrappers
benchmark-report.py                  — Post-run report: per-prompt throughput mean/stdev + coarse sanity flags
repro-mtp-graphs.sh                   — Dry-run-by-default 3-cell repro for the MTP x CUDA-graphs crash (MTP@on vs MTP@off vs base@on)
pyproject.toml                       — Python floor (>=3.10) and deps (none) for the helper scripts
ollama-create.sh                     — Bash script to build one or all models
session_summary_diffusiongemma.md    — Research log for DiffusionGemma work
session_summary_runtime_ab.md        — Research log: graphs A/B run, CUDA-graphs diagnosis, analysis tool
session_summary_9b_coders_vram.md    — Research log: 9B-coders VRAM fit + validation of prior Sonnet research
session_summary_qwen3.5_9b_mtp_bench.md — Research log: Qwen3.5-9B-MTP staging, ~1.65x speedup, MTP+graphs CUDA crash
session_summary_mtp_graphs_crash.md  — Research log: MTP x CUDA-graphs crash reproduced (~12.5%/run), keep GGML_CUDA_DISABLE_GRAPHS=1
session_summary_migration_local_ggufs.md — Research log: migration to hf-download local GGUFs, Gemma MTP on CUDA via Ollama DRAFT, Open WebUI wiring
.task_plan.md                        — Active task plan
.migration-artifacts/                — Git-excluded working data: baselines, HF inventories, preseed/migrate/validate scripts
```

## Key Conventions

- **UD-Q4_K_XL is the only weight GGUF published for the Gemma 4 QAT repos** (`gemma-4-{12B,26B-A4B,31B}-it-qat-GGUF`) — verified against the HF file listing; no IQ4_XS/UD-IQ4_XS/Q5/Q6/Q8. By design (QAT targets ~Q4), so there is no QAT quant matrix to build. Standard Q4_0 degrades accuracy and is larger. A fuller quant ladder exists only in the non-QAT repos (`gemma-4-*-it-GGUF`), at a quality cost vs QAT-Q4. The QAT repos also ship the `mtp-gemma-4-*.gguf` drafters and `mmproj-*.gguf` projectors used by the MTP and vision setups.
- **Gemma benchmark scope**: the repo's first-pass Gemma Ollama benchmark covers only `gemma4-12b-it-qat` and `gemma4-26b-a4b-it-qat`, using text-only prompts.
- **9B-coders benchmark scope**: `benchmark-9b-coders` covers small coders that fit fully in 12 GB VRAM — `qwen3.5-9b-coding-ud-q4-k-xl`, the `qwen3.5-9b-mtp-coding` MTP self-draft variant (~1.5-2x decode speedup; same Qwen3.5-9B base), and the `qwopus3.5-9b-coder` community finetune, against the `gemma4-12b-it-qat` baseline. Qwen **3.5** is used because Qwen 3.6's smallest GGUF (27B) offloads; Qwen3.5-9B uses the same precise-coding profile as 3.6 (verified). The Qwopus finetune's coding edge is **self-reported only** — the benchmark exists to test it. See `session_summary_9b_coders_vram.md`. (2026-07: the 9b-coding model moved from Ollama-official Q4_K_M back to Unsloth UD-Q4_K_XL — prior graphs-off numbers predate the quant change.)
- **Uncensored / reasoning variants** (separate non-coding track: reasoning/research/agentic): daily driver `gemma4-26b-a4b-it-heretic-i1-q4-k-m` (Gemma-4-26B-A4B MoE ~3.8B active, Heretic/ARA-abliterated, mradermacher i1-Q4_K_M ~16 GB, offload; verified Claude-Code-safe + reasoning intact), plus the dense sibling `gemma4-31b-it-heretic-i1-q4-k-m` (offloads harder). Resident 12B option: `gemma4-12b-it-obliterated` (OBLITERATUS/Pliny CoT-aware). Qwen 27B uncensored: `qwen3.6-27b-obliterated-q4-k-m` (general/thinking) and `qwen3.6-27b-obliterated-coding-q4-k-m` (coding, alias `qwen3.6-27b-obliterated-coding`). (The huihui 35B A/B pair and HauhauCS 35B were dropped 2026-07 with their Modelfiles.) All reference **community abliterated GGUFs** (not Unsloth, so quant tags are plain Q4/i1-Q4, not `UD-*`) and use Gemma `<|think|>` / Qwen thinking. Abliteration can dent reasoning/tool-calling - verify on-task (the "ultra"/higher-KL builds most); all must pass the Claude-Code template gate below. See `session_summary_uncensored_models.md`.
- **Claude-Code compatibility gate for community GGUFs**: claude-local drives Ollama via `ollama launch claude` -> Ollama's Anthropic endpoint. Claude Code sends **multiple `system`-role messages mid-conversation** (top-level system + SessionStart hook + skills/system-reminders). A model's embedded Jinja `chat_template` must tolerate non-first/multiple system messages. Two HauhauCS variants (`qwen3.6-35b-a3b-uncensored-q4-k-m` and `qwen3.6-35b-a3b-uncensored-hauhaucs-aggressive-iq4-xs`) shipped a non-standard guard (`raise_exception('System message must be at the beginning.')`) that canonical Qwen3.6 lacks, so every Claude Code request 400'd; both deleted for that reason. Ollama's Modelfile `TEMPLATE` is Go-only (legacy `/api/generate`) and cannot override the GGUF's Jinja template, so such a guard can only be fixed by patching the GGUF metadata. Vet a community GGUF's `chat_template` (`ollama show --template`) before adding it as a Claude Code target.
- Canonical Qwen benchmark filenames append the exact upstream quant tag. Mirror upstream tags verbatim rather than forcing a repo-local rename scheme.
- **Gemma 4 thinking**: activate with `<|think|>` at the start of the system prompt. There is no other trigger.
- **Gemma 4 MTP**: mechanism = target model + separate drafter (`mtp-gemma-4-*.gguf` in the QAT repos), unlike Qwen's single self-contained MTP GGUF. As of Ollama **0.31.1** the `DRAFT` Modelfile directive runs on the **CUDA/llama.cpp runner** (verified on-box 2026-07-08: serve log shows `draft-mtp` init; 12B pair measured acceptance 0.742, 85.2 vs 51.1 tok/s control = ~1.67x). Earlier 0.2x/0.30.x builds were MLX-only (PR #15980, issue #16019) — that restriction is obsolete. Note: **stock llama.cpp cannot load gemma4-assistant drafters** (issue #24795, open; repro'd on b9553 and b9860 on-box) — Ollama's vendored engine carries the fix, so Ollama is currently the only working CUDA path for Gemma MTP.
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
| num_ctx | 131072-200000 | 256K max; 12B/31B dense run 200000, 26B-A4B 131072 |
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
- **Isolated serve models dir**: those alternate-port serve instances run as the invoking user, so the harness sets `OLLAMA_MODELS=/usr/share/ollama/.ollama/models` (the systemd `ollama` user's store) so `ollama create`d models are visible. This requires the invoking user to be in the `ollama` group for read access.
- **Shared runtime ports**: the Qwen, Gemma, and 9B-coders runtime TSVs all use `127.0.0.1:11435` and `127.0.0.1:11436`, so do not execute more than one harness concurrently unless the host assignments are changed. (`benchmark-all.sh` runs them sequentially, which is safe.)

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
