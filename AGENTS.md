# AGENTS.md

Canonical, tooling-agnostic instructions for any coding agent working in this repo. Read this first. Claude-Code-specific notes live in `CLAUDE.md`; deep detail lives in `docs/`.

## What this repo is

Ollama Modelfile configurations for local LLM inference, organized by model family and use profile. There is no application code and no test suite - just Modelfiles, a build helper, benchmark harnesses, docs, and immutable research logs. Every Modelfile references a local GGUF in the Hugging Face cache. The same cached GGUFs also feed llama.cpp directly (`--model` / `--model-draft`).

## GGUF sourcing convention

Do NOT use `FROM hf.co/...` (Ollama's OCI bridge; prone to config-blob hangs) or `registry.ollama.ai` tags. Instead:

- Provision with `hf download ORG/REPO file.gguf`.
- Reference the absolute, pinned snapshot path: `FROM /home/wma/.cache/huggingface/hub/models--ORG--REPO/snapshots/<commit>/<file>.gguf`.
- Snapshot paths are pinned on purpose. An `hf download` that pulls a newer repo commit creates a new snapshot dir; the Modelfile keeps pointing at the old (still-cached) one. Updating a model is a deliberate two-step: download, then edit the `FROM` path. That is intended pinning, not drift.
- Vision models need a second `FROM <...>/mmproj-*.gguf` line, or the `vision` capability is silently dropped (the old OCI pull auto-bundled the projector).

## Modelfile layering and naming

Layout is `modelfiles/<family>/<stem>/Modelfile`; families are `gemma4`, `qwen3.5`, `qwen3.6`, `qwopus3.5`. The Ollama model name is computed as `<family>-<stem>` (e.g. `modelfiles/gemma4/12b-it-qat/Modelfile` -> `gemma4-12b-it-qat`). Do not rename models - Open WebUI's DB and claude-local reference them by name.

Three layers (`scripts/ollama-create.sh` resolves them bottom-up):

- **Canonical** (quant-suffixed stem, e.g. `35b-a3b-coding-ud-q4-k-xl`): full parameter block, `FROM` an absolute snapshot path. Source of truth.
- **Layered / derived**: `FROM` a local model name (inherits weights + params), then overrides or adds directives (e.g. a coding profile layered on an MTP base, or a `DRAFT` line).
- **Thin alias** (unsuffixed stem, e.g. `35b-a3b-coding`): a single `FROM <canonical model name>` line so the default can be repointed without renaming the family.

Adding a model: create `modelfiles/<family>/<stem>/Modelfile`, mirror the exact upstream quant tag verbatim in the stem, put the full verified parameter block in the canonical file, keep any alias thin.

See [docs/architecture.md](docs/architecture.md) for the full stack diagram.

## The two MTP mechanisms

Speculative decoding via a draft model - two different shapes:

- **Qwen (self-contained)**: one GGUF with embedded MTP tensors; Ollama auto-detects and self-drafts. Measured ~1.65x (9B).
- **Gemma (target + separate drafter)**: main GGUF plus a `mtp-gemma-4-*.gguf` drafter (~250 MB, shipped in the QAT repos), wired via the `DRAFT` directive in the Modelfile. Measured 1.67x (12B), 1.54x (26B).

Both historically ran on Ollama's CUDA runner (now 0.31.2, vendored llama.cpp b9840), but the 2026-07-17 eval inverted that picture on-box: Ollama's Gemma `DRAFT` lane crashes (illegal memory access on most requests), while stock llama.cpp b9860 serves the same target+drafter pair at ~1.8x - stable only with CUDA graphs ON at moderate ctx. Graphs-off reproduces the #24795 drafter load failure (the bug is config-gated, not build-gated; issue still open upstream). Until the migration spec lands, stock llama-server (graphs-on, capped ctx) is the working CUDA path for Gemma MTP; crash matrix and caveats in [docs/history/2026-07-17-llamacpp-eval.md](docs/history/2026-07-17-llamacpp-eval.md).

## Parameters

Never change a sampling value from memory. All profiles, mandates, and the verification-source URLs are in [docs/parameters.md](docs/parameters.md). The two hard rules:

- **Qwen `repeat_penalty` must be exactly 1.0** - any other value causes structural garbage in code output.
- **CUDA 13.2 corrupts Gemma 4 output** - use CUDA 13.1 or 13.3.

## Chat-template gate for community GGUFs

Some clients send multiple `system`-role messages mid-conversation (for example, Claude Code sends a top-level system message plus session-hook and skill/reminder system messages). A model's embedded Jinja `chat_template` must tolerate non-first and repeated system messages, or every such request fails.

Two HauhauCS Qwen3.6 variants shipped a non-standard guard (`raise_exception('System message must be at the beginning.')`) that canonical Qwen3.6 lacks; every request from a multi-system client 400'd, and both were deleted for it. Ollama's Modelfile `TEMPLATE` directive is Go-only (legacy `/api/generate`) and cannot override the GGUF's Jinja template, so such a guard can only be fixed by patching the GGUF metadata.

Before adding a community GGUF as a target for a multi-system client, vet its template with `ollama show --template <model>`.

## Keep-set policy

Every installed Ollama model corresponds to a repo Modelfile. Anything else gets `ollama rm`'d. Rebuilding the keep-set from a clean checkout is `git clone` + `hf download` + `scripts/ollama-create.sh`.

## Build commands

```bash
# Build all models (resolves canonical -> layered -> alias order automatically)
scripts/ollama-create.sh

# Build one model from its Modelfile directory
scripts/ollama-create.sh modelfiles/gemma4/12b-it-qat

# Building an alias builds its canonical dependency first
scripts/ollama-create.sh modelfiles/qwen3.6/35b-a3b-coding
```

## Benchmark commands

Suites live under `benchmarks/<suite>/` and are dry-run by default - they print the plan and run nothing without `--execute`.

```bash
benchmarks/qwen/run.sh            # print the plan (dry-run)
benchmarks/qwen/run.sh --list     # list configured models and prompts
benchmarks/qwen/run.sh --execute  # actually run the matrix
benchmarks/all.sh                 # all suites, sequential
```

The runtime A/B spins up isolated alternate-port serves. All suites share ports `11435`/`11436`, so never run two suites concurrently (`all.sh` is sequential and safe). Full detail, ports, and distilled findings: [docs/benchmarking.md](docs/benchmarking.md).

## Serving env constraints

The systemd Ollama service (`127.0.0.1:11434`) sets `KEEP_ALIVE=24h`, `FLASH_ATTENTION=1`, `KV_CACHE_TYPE=q8_0`.

- **`FLASH_ATTENTION=1` and `KV_CACHE_TYPE=q8_0` must stay paired**: the quantized V-cache hard-fails to load if flash attention resolves off.
- **Modelfile `num_ctx` outranks the env.** `OLLAMA_NUM_PARALLEL`/`OLLAMA_CONTEXT_LENGTH` being unset is harmless because every repo Modelfile pins `num_ctx`, which wins over the VRAM-tier auto-default and is never auto-shrunk on OOM (it partial-offloads instead).
- Prod currently runs CUDA graphs ON with the MTP crash exposure noted in [docs/benchmarking.md](docs/benchmarking.md#mtp-x-cuda-graphs-crash) (fix needs sudo).

## WSL disk budget

This runs on WSL2; the guest disk is an `ext4.vhdx` on the Windows `F:` drive that grows and never shrinks by itself.

- Budget against `df -h /mnt/f`, NOT the guest `df -h /` (the guest reports the virtual disk and lies about free host space).
- Count hidden copies: bytes exist twice by design - the HF cache blob (source) and the Ollama re-serialized layer both hold the model. A migration that copies + downloads + rebuilds can balloon the vhdx and crash the host (it has, twice).
- After large in-guest deletions, reclaim host space with `wsl --shutdown` then `Optimize-VHD` (Windows side).

## Doc map

- [README.md](README.md) - what/why, quickstart, model catalog, repo map.
- [docs/architecture.md](docs/architecture.md) - the stack: source of truth, layering, MTP, serving, disk.
- [docs/parameters.md](docs/parameters.md) - sampling profiles, mandates, verification sources.
- [docs/benchmarking.md](docs/benchmarking.md) - suite mechanics, ports, distilled findings.
- [docs/openwebui.md](docs/openwebui.md) - Open WebUI setup and config-in-DB semantics.
- [docs/history/index.md](docs/history/index.md) - dated, immutable session evidence logs.
- `specs/<feature>/` - spec + tasks for in-flight work, plus plan when the work needs one (tasks.md is the resume point); the run-spec skill (`.claude/skills/run-spec/`) executes a bundle end to end. `specs/README.md` is the roadmap (dependency-ordered sequence).
- `specs/done/<feature>/` - completed bundles, kept for the record. A bundle moves here once its spec.md Acceptance is met (every tasks.md item `[x]` or deferred out of scope); run-spec files it here on completion.
