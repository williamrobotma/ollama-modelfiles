# AGENTS.md

Canonical, tooling-agnostic instructions for any coding agent working in this repo. Read this first. Claude-Code-specific notes live in `CLAUDE.md`; deep detail lives in `docs/`.

## What this repo is

Local LLM serving config, organized by model family and use profile. There is no application code and no test suite.
Stock llama.cpp in router mode serves the live lane: fleet in `llamacpp/models.ini`, entrypoint `launch.sh`, on `127.0.0.1:11433`.
The Ollama Modelfiles are the retired legacy build layer, frozen until the P4 purge (`specs/llamacpp-migration`).
The 2026-07-27 fleet reduction already deleted 8 of them (a recorded spec supersede, not freeze drift).
Every served GGUF is a pinned local Hugging Face cache snapshot referenced by absolute path.

## GGUF sourcing convention

Provision with `hf download ORG/REPO file.gguf`; reference absolute pinned snapshot paths in `llamacpp/models.ini`
(`model =`, `model-draft =`, `mmproj =`).

- Snapshot paths are pinned on purpose: a newer `hf download` lands in a new snapshot dir; the preset keeps the old.
- Updating a model is a deliberate two-step: download, then edit the path. That is intended pinning, not drift.
- Vision models need the `mmproj =` key on their entry, or vision is silently absent.
- Legacy: Modelfiles used the same pinned paths via `FROM`; never `FROM hf.co/...` (OCI bridge, config-blob hangs).

## Modelfile layering and naming

Served ids follow `<family>-<stem>`; families are `gemma4`, `qwen3.5`, `qwen3.6`.
Ids and their aliases live in `llamacpp/models.ini`; thin unsuffixed aliases repoint defaults without renames.
Do not rename models - Open WebUI's DB and claude-local reference them by name.
Add-a-model procedure: [llamacpp/README.md](llamacpp/README.md).

The frozen legacy Modelfiles (`modelfiles/<family>/<stem>/`) used three layers via `scripts/ollama-create.sh`:

- **Canonical** (quant-suffixed stem, e.g. `35b-a3b-mtp-ud-q5-k-xl`): full parameter block, absolute `FROM` path.
  - Was the source of truth; `llamacpp/models.ini` is now.
- **Layered / derived**: `FROM` a local model name (inherits weights + params), then overrides or adds directives (e.g. a coding profile layered on an MTP base, or a `DRAFT` line).
- **Thin alias** (unsuffixed stem, e.g. `35b-a3b-coding`): a single `FROM <canonical model name>` line so the default can be repointed without renaming the family.

Stems mirror the exact upstream quant tag verbatim; that convention carries over to new `models.ini` ids.

See [docs/architecture.md](docs/architecture.md) for the full stack diagram.

## The two MTP mechanisms

Speculative decoding via a draft model - two different shapes:

- **Qwen (self-contained)**: one GGUF with embedded MTP tensors; served with `spec-type = draft-mtp` alone.
  Measured ~1.65x (9B, Ollama-era); 98-121 tok/s on the router child (P1 hammer).
- **Gemma (target + separate drafter)**: main GGUF plus a `mtp-gemma-4-*.gguf` drafter (~250 MB, in the QAT repos).
  Wired via `model-draft =` plus `spec-type = draft-mtp`; measured 1.67x (12B) / 1.54x (26B) on the Ollama-era lane.

History: Ollama's Gemma `DRAFT` lane crashed on-box while stock b9860 served the same pair at ~1.8x (2026-07-17 eval).
Since 2026-08-07, llama-server with CUDA graphs ON is the serving lane for all MTP models.
The client cutovers are complete; the P4 validation window and gated purge remain open in the spec's tasks.
Graphs-off reproduces the #24795 drafter load failure (config-gated, not build-gated; still open upstream).
The 26B pair pins its drafter to CPU (`spec-draft-ngl = 0`) against an upstream full-GPU loader crash.
Crash matrix and caveats: [docs/history/2026-07-17-llamacpp-eval.md](docs/history/2026-07-17-llamacpp-eval.md).

## Parameters

Never change a sampling value from memory. All profiles, mandates, and the verification-source URLs are in [docs/parameters.md](docs/parameters.md). The two hard rules:

- **Qwen `repeat_penalty` must be exactly 1.0** - any other value causes structural garbage in code output.
- **CUDA 13.2 corrupts Gemma 4 output** - use CUDA 13.1 or 13.3.

## Chat-template gate for community GGUFs

Some clients send multiple `system`-role messages mid-conversation (for example, Claude Code sends a top-level system message plus session-hook and skill/reminder system messages). A model's embedded Jinja `chat_template` must tolerate non-first and repeated system messages, or every such request fails.

The guard: `raise_exception('System message must be at the beginning.')`.

- Official Qwen 3.5/3.6 default; every fresh Qwen pull carries it.
- Exception: unsloth's Qwen3.6 and 3.5-MTP builds ship `merged_system`.
  - It merges up to two leading system messages and silently drops all others, mid-conversation ones included.
- On llama-server, the guard fires only on the OpenAI endpoint (`/v1/chat/completions` with `--jinja`).
  - A multi-system request there returns 400.
  - `/v1/messages` is immune: system folds into one message before the template runs.
  - Under Ollama it stayed unresolved (Jinja never ran, yet 400s happened); moot since the 2026-08-07 retirement.

Standing rule: serve guarded Qwen GGUFs to OpenAI-style clients under a guard-free template.

- Fix: `--jinja --chat-template-file` with froggeric's `chat_template.jinja`, validated once per (template, build) pair.
  - Validated-pair record: [llamacpp/templates/README.md](llamacpp/templates/README.md).
- Don't wait for an official fix: Qwen says the guard is by design (re-role later system messages to user).

Vetting (store-reported templates lie - Ollama's `ollama show --template` showed one that never ran):

1. Per GGUF: `head -c 30000000 <file>.gguf | grep -ac 'System message must be at the beginning'`.
2. Per GGUF: `head -c 30000000 <file>.gguf | grep -ac 'merged_system'`.
   - Hazard: a hit means silent drops, not a 400 - it never shows up as an error.
3. Per GGUF: one non-first-`system` request to `/v1/chat/completions` - 400 = guarded.
   - Never cold-load onto a busy GPU; `-ngl 0` is fine.
4. Per build: one multi-block-`system` request to `/v1/messages` (immunity check).

Guarded fleet GGUFs ([gate evidence 2026-07-23](docs/history/2026-07-23-chat-template-refresh.md)):

- Current: unsloth Qwen3.5-9B non-MTP and Queen-27B, backing the 3 `chat-template-file` preset entries.
  - OBLITERATUS-27B and Qwopus3.5-9B-coder left the fleet in the 2026-07-27 reduction.
- `merged_system` carriers (step 2 grep, 2026-08-08): unsloth Qwen3.5-9B-MTP, Qwen3.6-27B, -27B-MTP, -35B-A3B-MTP.
  - 4 GGUFs backing 6 preset entries (the 35B GGUF backs three); step 1 clean (no raise_exception guard).
  - No entry has a `chat-template-file` override yet: mid-conversation system messages silently drop today.
- Validated (template, build) pair record: [llamacpp/templates/README.md](llamacpp/templates/README.md).
  - Re-validate the pair when the build record moves.

## Keep-set policy

Every served id corresponds to a `llamacpp/models.ini` entry; the preset is the keep-set.
Rebuilding from a clean checkout is `git clone` + `hf download` - the preset references the cache directly, no build.
Legacy: the Ollama store mirrored the Modelfiles (`ollama rm` for strays); it stays frozen until the P4 purge.

## Build commands (legacy Ollama layer)

The live lane has no build step - the router loads GGUFs straight from `llamacpp/models.ini`.
The commands below build the frozen Modelfile layer and retire with it at the P4 purge.

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

The runtime A/B spins up isolated alternate-port serves.
All suites share ports `11435`-`11438`, so never run two suites concurrently (`all.sh` is sequential and safe).
The three Ollama suites target the retired lane (frozen harnesses); `llamacpp-parity` covers the live engine.
Full detail, ports, and distilled findings: [docs/benchmarking.md](docs/benchmarking.md).

## Serving env constraints

The live serve is `llamacpp/launch.sh`: llama-server router mode on `127.0.0.1:11433`.
Defaults: `--models-max 1` (env `MODELS_MAX`), `--sleep-idle-seconds 86400` (env `SLEEP_IDLE_SECONDS`).
Recommended log home: `~/.local/state/llama-router.log` (survives reboot, unlike `/tmp`).

- **`-fa on` and q8_0 KV must stay paired** (`[*]` block): the quantized V-cache hard-fails without flash attention.
- `ctx-size` is per-entry in `models.ini` and wins; nothing auto-shrinks on OOM (partial offload instead).
- CUDA graphs run ON fleet-wide (P1-validated); never set `GGML_CUDA_DISABLE_GRAPHS` in the launcher env.
  - Children inherit the router env verbatim, and Gemma MTP needs graphs on.
- The retired systemd Ollama service (`11434`) stays frozen - stop/disable and purge tracked in Phase 4.

## WSL disk budget

This runs on WSL2; the guest disk is an `ext4.vhdx` on the Windows `F:` drive that grows and never shrinks by itself.

- Budget against `df -h /mnt/f`, NOT the guest `df -h /` (the guest reports the virtual disk and lies about free host space).
- Under Ollama bytes existed twice (HF blob + re-serialized layer); the live lane serves the HF cache directly.
  - The frozen Ollama store is reclaimed at the P4 purge.
- Bulk copy/download/rebuild operations can balloon the vhdx and crash the host (it has, twice).
- After large in-guest deletions, reclaim host space with `wsl --shutdown` then `Optimize-VHD` (Windows side).

## Markdown style

- rumdl enforces `.rumdl.toml`: 120-col barometer (check-only, never `--fix`); `docs/history/` excluded as immutable.
- Soft-wrap only: never break a line mid-idea - fix long lines by cutting redundancy or splitting into real sub-bullets.

## Doc map

- [README.md](README.md) - what/why, quickstart, model catalog, repo map.
- [llamacpp/README.md](llamacpp/README.md) - the serving lane: preset layout, alias policy, add-a-model.
- [docs/architecture.md](docs/architecture.md) - the stack: source of truth, layering, MTP, serving, disk.
- [docs/parameters.md](docs/parameters.md) - sampling profiles, mandates, verification sources.
- [docs/benchmarking.md](docs/benchmarking.md) - suite mechanics, ports, distilled findings.
- [docs/openwebui.md](docs/openwebui.md) - Open WebUI setup and config-in-DB semantics.
- [docs/history/index.md](docs/history/index.md) - dated, immutable session evidence logs.
- `specs/<feature>/` - spec + tasks for in-flight work, plus plan when the work needs one (tasks.md is the resume point); the run-spec skill (`.claude/skills/run-spec/`) executes a bundle end to end. `specs/README.md` is the roadmap (dependency-ordered sequence).
- `specs/done/<feature>/` - completed bundles, kept for the record. A bundle moves here once its spec.md Acceptance is met (every tasks.md item `[x]` or deferred out of scope); run-spec files it here on completion.
