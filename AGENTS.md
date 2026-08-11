# AGENTS.md

Canonical instructions for any coding agent working in this repo - read this first.
Deep detail lives in `docs/`; `CLAUDE.md` is just `@AGENTS.md`.

## The repo

**Serving config only - no application code, no test suite.**

- The live lane is stock llama.cpp in router mode on `127.0.0.1:11433`: fleet in `llamacpp/models.ini`,
  entrypoint `llamacpp/launch.sh`.
- Every served GGUF is a pinned absolute path into the local Hugging Face cache; the preset is the keep-set.
- Re-provisioning from nothing is `git clone` + `hf download` - no build or import step.
- Do not edit `modelfiles/` - the retired Ollama build layer, frozen until the P4 purge
  (`specs/llamacpp-migration`); its scheme: [docs/architecture.md](docs/architecture.md) section 2.

## Models and sourcing

Provision with `hf download ORG/REPO file.gguf`; reference absolute pinned snapshot paths in
`llamacpp/models.ini` (`model =`, `model-draft =`, `mmproj =`).

- A newer `hf download` lands in a new snapshot dir and the preset keeps serving the old one until the path
  is edited - deliberate pinning, not drift.
- Vision models need `mmproj =` on their entry, or vision is silently absent.
- Ids name the lane, never the quant; grammar and alias policy: [llamacpp/README.md](llamacpp/README.md).
- Renaming a served id breaks stored Open WebUI chats visibly. Rename only for a naming-rule change, and
  sweep every client (OpenCode, Codex catalog + default) in the same commit.
- Add-a-model procedure: [llamacpp/README.md](llamacpp/README.md).

## Parameters

Never change a sampling value from memory - profiles, mandates, and the verification sources:
[docs/parameters.md](docs/parameters.md). The two hard rules:

- **Qwen `repeat_penalty` must be exactly 1.0** - any other value causes structural garbage in code output.
- **CUDA 13.2 corrupts Gemma 4 output** - use CUDA 13.1 or 13.3.

## Chat-template gate for community GGUFs

Some clients send multiple `system`-role messages mid-conversation; a model's embedded Jinja `chat_template`
must tolerate them or every such request fails. The guard: `raise_exception('System message must be at the
beginning.')`. Serve guarded GGUFs to OpenAI-style clients under froggeric's `chat_template.jinja`
(`--jinja --chat-template-file`), validated once per (template, build) pair - the record and the fleet's
exposure inventory: [llamacpp/templates/README.md](llamacpp/templates/README.md) + [llamacpp/README.md](llamacpp/README.md).

Vetting a new GGUF (store-reported templates lie - vet the file and the wire):

1. `head -c 30000000 <file>.gguf | grep -ac 'System message must be at the beginning'` - template strings sit
   in the GGUF header, well inside the first 30 MB.
2. Same grep for `merged_system` - a hit means mid-conversation system messages get silently dropped, never an error.
3. One non-first-`system` request to `/v1/chat/completions`, with `-ngl 0` so it never cold-loads onto a busy GPU.
   - Identify the guard by its message text, never the HTTP status - builds return 400 or 500 for the same
     guard, so a code-only check passes a guarded GGUF.
4. Per build: one multi-block-`system` request to `/v1/messages` (immune - it folds system into one message).

The test: for every served GGUF you can name which chat template it runs under, and why.

## Serving

The live serve is `llamacpp/launch.sh` - llama-server router mode on `127.0.0.1:11433`; the runbook:
[docs/architecture.md](docs/architecture.md) section 4.

- The launcher takes no env knobs: pass flags (defaults are emitted before `"$@"`, last wins). Keep
  `LLAMA_ARG_*` env vars unset - llama-server honors them, invisibly bypassing the flags.
- **`-fa on` and q8_0 KV must stay paired** (`[*]` block): the quantized V-cache hard-fails without flash attention.
- `ctx-size` is per-entry and wins; nothing auto-shrinks on OOM (partial offload instead).
- CUDA graphs run ON fleet-wide; never set `GGML_CUDA_DISABLE_GRAPHS` (presence-only - even `=0` disables,
  and Gemma MTP needs graphs on). MTP wiring, both mechanisms: [docs/architecture.md](docs/architecture.md) section 3.
- The 26B MTP pair keeps `spec-draft-ngl = 0`; graphs-off reproduces the #24795 drafter load failure.
- **Keep the GPU core clock offset at or below +120 MHz** - above it, large-ctx MTP runs crash
  ([why](docs/benchmarking.md#mtp-crash-investigation-resolved-gpu-core-overclock)).
- **Capture GPU + host RAM per trial on any GPU run whose numbers you will quote** - both are shared with
  Windows and unrecoverable after the fact; procedure: [docs/benchmarking.md](docs/benchmarking.md) (Resource capture).
- Router discipline (runbook: [docs/architecture.md](docs/architecture.md) section 4):
  - `launch.sh` refuses to start over a live router - honor the refusal, never work around it.
  - Probe 11433 before any stop or parse-check (`curl -s 127.0.0.1:11433/v1/models`); an answer may be a
    router you did not start - report and ask.
  - Kill only a PID from your own launch, never pgrep/pkill; trust a readout only after your own instance's
    log says it bound.
- WSL disk: budget against `df -h /mnt/f`, never the guest `df /` - the vhdx grows and never shrinks by
  itself, and bulk downloads have crashed the host. After big deletions: `wsl --shutdown` + `Optimize-VHD`.

## Commands

Benchmarks are dry-run by default - nothing runs without `--execute`:

```bash
benchmarks/qwen/run.sh            # print the plan
benchmarks/qwen/run.sh --list     # configured models and prompts
benchmarks/qwen/run.sh --execute  # run the matrix
benchmarks/all.sh                 # the three Ollama suites, sequential (parity runs alone)
```

Suites share ports 11435-11438 - never run two concurrently. Mechanics and findings:
[docs/benchmarking.md](docs/benchmarking.md).
Legacy Ollama builds: `scripts/ollama-create.sh [modelfiles/<family>/<stem>]` (usage header in the script).

## claude-local

**`claude-local` runs Claude Code against the router; this section is its canonical spec.**
Implementation: the synced `~/.claude/bin/claude-local`; a per-machine shim invokes it.

- Lane = the fleet model serving ALL session roles: main + tier + subagent vars together.
  Pinning `ANTHROPIC_MODEL` is required - settings.json's model otherwise reaches the wire verbatim.
- No flag, no default: a numbered menu picks; Enter re-picks the last lane (`~/.config/claude-local.last`);
  non-TTY reuses the last lane or fails with the list.
- Menu source = the live router (`GET /v1/models` ids + each entry's `aliases`), C-sorted so each alias lands
  beside its canonical, each lane showing its router-reported status. Router down -> fail loudly, no file fallback.
- Any entry that is not a menu number is a lane name verbatim (escape hatch); the router 404s on a typo.
- Every claude arg passes through untouched; mid-session `/model` moves only the main session.
- Every plugin is disabled per-session (`--settings` override built from `~/.claude/settings.json` at launch).
- With `~/.config/claude-local.mcp.json` present (WSL): sources `~/.config/claude-local.env` (mode 600) and
  execs with `--disallowedTools=WebSearch` + the vendored web-search MCP (`llamacpp/mcp/`); otherwise the
  plugin override only. That env file also arms raw-body logging to `/tmp/claude-bodies` (B8, user-held;
  whether it fires is telemetry-gated and unverified live).
- Rides `/v1/messages` - immune to the chat-template guard above.

The test: the lane you picked is the model every session role is talking to.

## Doc map

- [README.md](README.md) - what/why, quickstart, catalog pointers, repo map.
- [llamacpp/README.md](llamacpp/README.md) - the serving lane: preset layout, id grammar, alias policy,
  exposure inventory, add-a-model.
- [llamacpp/templates/README.md](llamacpp/templates/README.md) - vendored chat templates: shas, validated pairs.
- [llamacpp/mcp/README.md](llamacpp/mcp/README.md) - the vendored web-search MCP claude-local loads.
- [docs/architecture.md](docs/architecture.md) - the stack: layering, MTP, serving + clients, disk.
- [docs/parameters.md](docs/parameters.md) - sampling profiles, mandates, verification sources.
- [docs/benchmarking.md](docs/benchmarking.md) - suite mechanics, ports, distilled findings.
- [docs/openwebui.md](docs/openwebui.md) - Open WebUI setup and config-in-DB semantics.
- [docs/history/index.md](docs/history/index.md) - dated, immutable session evidence logs.
- `specs/<feature>/` - in-flight work, tasks.md as the resume point; `specs/README.md` is the roadmap.

Markdown: rumdl enforces `.rumdl.toml` (120-col, check-only, never `--fix`); `docs/history/` is excluded as
immutable. Soft-wrap only - fix a long line by cutting or splitting ideas, never a mid-idea break.

Name sets, never their size - written counts drift; the one sanctioned count is a file's own header total
(e.g. `llamacpp/models.ini:1`), checked against the file whenever touched.
