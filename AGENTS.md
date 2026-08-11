# AGENTS.md

Canonical instructions for any coding agent working in this repo - read this first.
Deep detail lives in `docs/`; `CLAUDE.md` is just `@AGENTS.md` (this repo owns everything about running
things locally, Claude Code included, so even the Claude-specific material is homed here).

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
Renaming a served id is a deliberate act with a cost: Open WebUI stores model names per chat, so old chats break visibly.
Rename only for a naming-rule change, and sweep every client (OpenCode, Codex catalog + default) in the same commit.
Add-a-model procedure: [llamacpp/README.md](llamacpp/README.md).

The frozen legacy Modelfiles (`modelfiles/<family>/<stem>/`) used three layers via `scripts/ollama-create.sh`:

- **Canonical** (quant-suffixed stem, e.g. `35b-a3b-mtp-ud-q5-k-xl`): full parameter block, absolute `FROM` path.
  - Was the source of truth; `llamacpp/models.ini` is now.
- **Layered / derived**: `FROM` a local model name (inherits weights + params), then overrides or adds directives.
  - E.g. a coding profile layered on an MTP base, or a `DRAFT` line.
- **Thin alias** (unsuffixed stem, e.g. `35b-a3b-coding`): a single `FROM <canonical model name>` line.
  - It lets the default repoint without renaming the family.

Served ids name the lane and never the quant (2026-08-09); the id grammar lives in [llamacpp/README.md](llamacpp/README.md).

- This retires the older rule that stems mirror the upstream quant tag; the frozen Modelfile stems still carry them.
- Aliases exist for profile defaults only, never as quant-free stand-ins for a quant-carrying id.

See [docs/architecture.md](docs/architecture.md) for the full stack diagram.

## The two MTP mechanisms

Speculative decoding via a draft model - two shapes, wired differently in `models.ini`:

- **Qwen (self-contained)**: one GGUF with embedded MTP tensors; `spec-type = draft-mtp` alone.
- **Gemma (target + separate drafter)**: adds an explicit `model-draft =` (~250 MB, in the QAT repos).
  - No auto-discovery for local paths: without `model-draft` the child dies at load.

Two config rules that are easy to break:

- The 26B pair pins its drafter to CPU (`spec-draft-ngl = 0`) against an upstream full-GPU loader crash.
- Graphs-off reproduces the #24795 drafter load failure (config-gated, not build-gated; still open upstream).

Mechanism, diagram, and measured speedups: [docs/architecture.md](docs/architecture.md) section 3.
Crash status: [docs/benchmarking.md](docs/benchmarking.md#mtp-crash-investigation-resolved-gpu-core-overclock).

## Parameters

Never change a sampling value from memory.
All profiles, mandates, and the verification-source URLs are in [docs/parameters.md](docs/parameters.md).
The two hard rules:

- **Qwen `repeat_penalty` must be exactly 1.0** - any other value causes structural garbage in code output.
- **CUDA 13.2 corrupts Gemma 4 output** - use CUDA 13.1 or 13.3.

## Chat-template gate for community GGUFs

Some clients send multiple `system`-role messages mid-conversation.
(For example, Claude Code sends a top-level system message plus session-hook and skill/reminder system messages.)
The embedded Jinja `chat_template` must tolerate non-first and repeated system messages, or every such request fails.

The guard: `raise_exception('System message must be at the beginning.')`.

- Official Qwen 3.5/3.6 default; every fresh Qwen pull carries it.
- Exception: unsloth's Qwen3.6 and 3.5-MTP builds ship `merged_system`.
  - It merges up to two leading system messages and silently drops all others, mid-conversation ones included.
- On llama-server, the guard fires only on the OpenAI endpoint (`/v1/chat/completions` with `--jinja`).
  - A multi-system request there fails with the guard's message (identify it by the text - see Vetting step 3).
  - `/v1/messages` is immune: system folds into one message before the template runs.
  - Under Ollama it stayed unresolved (Jinja never ran, yet 400s happened); moot since the 2026-08-07 retirement.

Standing rule: serve guarded Qwen GGUFs to OpenAI-style clients under a guard-free template.

- Fix: `--jinja --chat-template-file` with froggeric's `chat_template.jinja`, validated once per (template, build) pair.
- Don't wait for an official fix: Qwen says the guard is by design (re-role later system messages to user).

Vetting (store-reported templates lie - Ollama's `ollama show --template` showed one that never ran):

1. Per GGUF: `head -c 30000000 <file>.gguf | grep -ac 'System message must be at the beginning'`.
   - The greps certify the first 30 MB only; template strings sit in the GGUF header well inside that (fleet-verified).
2. Per GGUF: `head -c 30000000 <file>.gguf | grep -ac 'merged_system'`.
   - Hazard: a hit means silent drops, not a 400 - it never shows up as an error.
3. Per GGUF: one non-first-`system` request to `/v1/chat/completions` - an error naming the guard = guarded.
   - Match on `System message must be at the beginning`, **not** on the status code: 10326 returned 400 and 10335
     returns 500 for the same guard. A code-only check reads that 500 as "not guarded" and passes a guarded GGUF.
   - Never cold-load onto a busy GPU; `-ngl 0` is fine.
4. Per build: one multi-block-`system` request to `/v1/messages` (immunity check).

Guarded fleet GGUFs ([gate evidence 2026-07-23](docs/history/2026-07-23-chat-template-refresh.md)):

- Current: unsloth Qwen3.5-9B non-MTP and mradermacher Queen-27B; which entries they back is listed in `templates/README.md`.
  - OBLITERATUS-27B and Qwopus3.5-9B-coder left the fleet in the 2026-07-27 reduction.
- `merged_system` carriers (step 2 grep, 2026-08-08): unsloth Qwen3.5-9B-MTP + Qwen3.6 27B, 27B-MTP, 35B-A3B-MTP, 35B-A3B.
  - 5 GGUFs backing 7 preset entries (multi-entry GGUFs: 35B-A3B-MTP x2, 27B x2); step 1 clean on all.
  - No `chat-template-file` overrides: mid-conversation systems would drop - accepted 2026-08-08, no client sends them.
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
benchmarks/all.sh                 # the three Ollama suites, sequential (parity runs alone)
```

The runtime A/B spins up isolated alternate-port serves.
All suites share ports `11435`-`11438`, so never run two suites concurrently (`all.sh` is sequential and safe).
The three Ollama suites target the retired lane (frozen harnesses); `llamacpp-parity` covers the live engine.
Full detail, ports, and distilled findings: [docs/benchmarking.md](docs/benchmarking.md).

## Serving env constraints

The live serve is `llamacpp/launch.sh`: llama-server router mode on `127.0.0.1:11433`.
Defaults: `--models-max 1`, `--sleep-idle-seconds 86400`, and `--cors-origins localhost`.
The launcher takes no env knobs: pass the flag to `launch.sh` instead (defaults are emitted before `"$@"`, last wins).
llama-server itself honors `LLAMA_ARG_*` env vars (common/arg.cpp) - leave them unset so the flags stay the whole story.
Recommended log home: `~/.local/state/llama-router.log` (survives reboot, unlike `/tmp`).

- **`-fa on` and q8_0 KV must stay paired** (`[*]` block): the quantized V-cache hard-fails without flash attention.
- **Capture GPU and host RAM per trial on any GPU run whose numbers you will quote** - the card is shared with
  Windows and RAM is shared through WSL2, and neither is recoverable after the fact.
  - Procedure and the commands: [docs/benchmarking.md](docs/benchmarking.md) (Resource capture).
- `ctx-size` is per-entry in `models.ini` and wins; nothing auto-shrinks on OOM (partial offload instead).
- CUDA graphs run ON fleet-wide (P1-validated); never set `GGML_CUDA_DISABLE_GRAPHS` in the launcher env.
  - It moved to `ggml-cuda/common.cuh:1258` (`ggml_cuda_graph::is_enabled`) in `090b137e`, and tests presence only:
    even `GGML_CUDA_DISABLE_GRAPHS=0` disables graphs. Unset it entirely for a graphs-on baseline.
  - Whether it took effect is visible only in the `CUDA graph warmup ...` debug lines, not in `graphs reused`.
    - `graphs reused` is llama's own graph-reuse counter (`llama-context.cpp:4139`), unrelated to CUDA graphs.
  - Children inherit the router env verbatim, and Gemma MTP needs graphs on.
  - Graphs are not the crash trigger: the large-ctx MTP crashes were this box's GPU core clock offset (resolved
    2026-08-10) - **keep the core offset at or below +120 MHz**. Evidence and status are single-homed in
    [docs/benchmarking.md](docs/benchmarking.md#mtp-crash-investigation-resolved-gpu-core-overclock).
- The retired systemd Ollama service (`11434`) stays frozen - stop/disable and purge tracked in Phase 4.

## claude-local

The launcher for running Claude Code against the router; this section is the canonical spec.
The implementation is the synced `~/.claude/bin/claude-local`; the `~/.bashrc` fn is a one-line shim over it
(2026-08-10 unification).

- Lane = the fleet model serving ALL session roles (B6 fix, 2026-08-08): main + tier + subagent vars together.
  - Pinning `ANTHROPIC_MODEL` is required: settings.json's model otherwise reaches the wire verbatim.
- No flag, no default: the numbered menu picks; Enter re-picks the last lane.
  - Menu source = the live router (`GET /v1/models` ids + their `aliases` fields; repo-independent, user rule
    2026-08-10).
  - Each lane shows its status (loaded / sleeping / unloaded); listing is read-only.
  - Router down -> the menu fails with a clear message; there is no file fallback.
  - Sorting is the whole ordering rule: the naming convention lands each alias beside its canonical for free.
  - The last lane persists in `~/.config/claude-local.last`; non-TTY reuses it or fails with the list.
  - Any entry that is not a menu number is taken as a lane name verbatim (escape hatch); the router 404s
    visibly on a typo.
- Every claude arg passes through untouched (`--model` included); mid-session `/model` moves only the main session.
- Every plugin is disabled per-session (`--settings` override built from `~/.claude/settings.json` at launch,
  never stale); the script always exports the dummy `ANTHROPIC_AUTH_TOKEN` (the router checks nothing).
- Execs `claude` with `--disallowedTools=WebSearch` plus the vendored web-search MCP (`llamacpp/mcp/`, via pipx)
  when `~/.config/claude-local.mcp.json` exists (WSL); machines without it launch with the plugin override only.
  - Only this MCP branch sources `~/.config/claude-local.env` (mode 600: `OLLAMA_API_KEY` plus claude env knobs;
    cutover validated 2026-08-04, see the P3 history log).
  - That env file also arms `OTEL_LOG_RAW_API_BODIES` -> `/tmp/claude-bodies` (B8, held by user). Whether logging
    actually fires is gated by telemetry settings - UNVERIFIED live (the dir is absent; check at the owed live run).
- Rides `/v1/messages` (immune to the multi-system guard - see the chat-template gate above).

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

The claude-local launcher spec is [a section of this file](#claude-local), not a separate doc.

- [README.md](README.md) - what/why, quickstart, model catalog, repo map.
- [llamacpp/README.md](llamacpp/README.md) - the serving lane: preset layout, alias policy, add-a-model.
- [llamacpp/templates/README.md](llamacpp/templates/README.md) - vendored chat templates: shas, validated pairs.
- [llamacpp/mcp/README.md](llamacpp/mcp/README.md) - the vendored web-search MCP server claude-local loads.
- [docs/architecture.md](docs/architecture.md) - the stack: source of truth, layering, MTP, serving, disk.
- [docs/parameters.md](docs/parameters.md) - sampling profiles, mandates, verification sources.
- [docs/benchmarking.md](docs/benchmarking.md) - suite mechanics, ports, distilled findings.
- [docs/openwebui.md](docs/openwebui.md) - Open WebUI setup and config-in-DB semantics.
- [docs/history/index.md](docs/history/index.md) - dated, immutable session evidence logs.
- `specs/<feature>/` - spec + tasks for in-flight work, plus plan when needed; tasks.md is the resume point.
  - The run-spec skill (`.claude/skills/run-spec/`) executes a bundle end to end.
  - `specs/README.md` is the roadmap (dependency-ordered sequence).
- `specs/done/<feature>/` - completed bundles, kept for the record.
  - A bundle moves here once its spec.md Acceptance is met (every tasks.md item `[x]` or deferred out of scope).
  - run-spec files it here on completion.
