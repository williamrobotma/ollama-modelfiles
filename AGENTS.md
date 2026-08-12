# AGENTS.md

Canonical instructions for any coding agent working in this repo - read this first.
The detail is defined in the files under `docs/`, and this file points to them.
`CLAUDE.md` is just `@AGENTS.md`.

## The repo

**Serving config only - no application code, no test suite.**

- The live serving stack is stock llama.cpp in router mode on `127.0.0.1:11433`: the fleet is defined in
  `llamacpp/models.ini`, and the entrypoint is `llamacpp/launch.sh`.
- Every served GGUF is a pinned absolute path into the local Hugging Face cache, and the preset lists every
  model kept on disk.
- Re-provisioning from nothing is `git clone` + `hf download` - no build or import step.
- The retired Ollama layer (`modelfiles/`, `scripts/`, `benchmarks/`) was removed 2026-08-12; git history
  preserves it. Only the on-disk store remains, until the purge tracked in `specs/llamacpp-migration`.

## Models and sourcing

Provision with `hf download ORG/REPO file.gguf`, then reference the absolute pinned snapshot paths in
`llamacpp/models.ini` (`model =`, `model-draft =`, `mmproj =`).

- A newer `hf download` writes a new snapshot directory, and the preset keeps serving the old one until the
  path is edited. That is deliberate pinning, not drift.
- Vision models need `mmproj =` on their entry, or vision is silently absent.
- Ids name the entry, never the quant. The id grammar and alias policy are in [llamacpp/README.md](llamacpp/README.md).
- Renaming a served id breaks stored Open WebUI chats visibly. Rename only for a naming-rule change, and
  sweep every client (OpenCode, Codex catalog + default) in the same commit.
- The add-a-model procedure is in [llamacpp/README.md](llamacpp/README.md).

## Parameters

Never change a sampling value from memory. The profiles, mandates, and verification sources are defined in
[docs/parameters.md](docs/parameters.md). The two hard rules:

- **Qwen `repeat_penalty` must be exactly 1.0** - any other value causes structural garbage in code output.
- **CUDA 13.2 corrupts Gemma 4 output** - use CUDA 13.1 or 13.3.

## Chat-template gate for community GGUFs

Some clients send multiple `system`-role messages mid-conversation. A model's embedded Jinja `chat_template`
must tolerate them, or every such request fails.

- The guard is the call `raise_exception('System message must be at the beginning.')` inside that template.
- Serve guarded GGUFs to OpenAI-style clients under froggeric's `chat_template.jinja`
  (`--jinja --chat-template-file`), validated once per (template, build) pair.
- The validation record is in [llamacpp/templates/README.md](llamacpp/templates/README.md), and the list of
  which template each entry runs is in [llamacpp/README.md](llamacpp/README.md).

Vet a new GGUF with the steps below. The only template that runs is the one embedded in the GGUF - read it
there, not from a tool or a repo listing, and check both the GGUF file and one live request.

1. `head -c 30000000 <file>.gguf | grep -ac 'System message must be at the beginning'` - template strings sit
   in the GGUF header, well inside the first 30 MB.
2. Same grep for `merged_system` - a hit means mid-conversation system messages get silently dropped, never an error.
3. One non-first-`system` request to `/v1/chat/completions`, with `-ngl 0` so it never cold-loads onto a busy GPU.
   - Identify the guard by its message text, never the HTTP status - builds return 400 or 500 for the same
     guard, so a code-only check passes a guarded GGUF.
4. Per build: one multi-block-`system` request to `/v1/messages` (immune - it folds system into one message).

The test: for every served GGUF you can name which chat template it runs under, and why.

## Serving

The live serve is `llamacpp/launch.sh`, which starts llama-server in router mode on `127.0.0.1:11433`.
The runbook is [docs/architecture.md](docs/architecture.md) section 4.

Launch flags - the launcher reads no env vars of its own, so configuration is passed as flags:

- Defaults are emitted before `"$@"`, so the last value given takes effect.
- Keep `LLAMA_ARG_*` env vars unset - llama-server reads them and applies them, invisibly bypassing the flags.
- **`-fa on` and q8_0 KV must stay paired** (`[*]` block): the quantized V-cache hard-fails without flash attention.
- `ctx-size` is set per entry and overrides `[*]`. Nothing auto-shrinks on OOM; the entry partial-offloads instead.

GPU and stability:

- CUDA graphs stay on fleet-wide. Never set `GGML_CUDA_DISABLE_GRAPHS`.
  - It disables graphs on presence alone, even `=0`, and Gemma MTP needs graphs on.
  - MTP wiring, both mechanisms: [docs/architecture.md](docs/architecture.md) section 3.
- The 26B MTP pair keeps `spec-draft-ngl = 0`; graphs-off reproduces the #24795 drafter load failure.
- **Keep the GPU core clock offset at or below +120 MHz** - above it, large-ctx MTP runs crash
  ([why](docs/benchmarking.md#mtp-crash-investigation-resolved-gpu-core-overclock)).
- **Capture GPU + host RAM per trial on any GPU run whose numbers you will quote.** Both are shared with
  Windows and unrecoverable after the fact.
  - The capture procedure is in [docs/benchmarking.md](docs/benchmarking.md) (Resource capture).
- Budget WSL disk against `df -h /mnt/f`, never the guest `df /`. The vhdx grows and never shrinks by itself,
  and bulk downloads have crashed the host.
  - After big deletions, run `wsl --shutdown` + `Optimize-VHD`.

Router discipline (runbook: [docs/architecture.md](docs/architecture.md) section 4):

- `launch.sh` refuses to start over a live router - honor the refusal, never work around it.
- Probe 11433 before any stop or parse-check (`curl -s 127.0.0.1:11433/v1/models`); an answer may be a
  router you did not start - report and ask.
- Kill only a PID from your own launch, never pgrep/pkill; trust a readout only after your own instance's
  log says it bound.

## claude-local

**`claude-local` runs Claude Code against the router; this section is its canonical spec.**
The implementation is the synced `~/.claude/bin/claude-local`, which a per-machine shim invokes.

- A lane is the one fleet model that serves every session role at once: main, tier, and subagent vars together.
  - Pinning `ANTHROPIC_MODEL` is required, or settings.json's model is sent to the router verbatim.
- There is no flag and no default lane: a numbered menu picks one.
  - Enter re-picks the last lane, stored in `~/.config/claude-local.last`.
  - A non-TTY run reuses the last lane, or fails and prints the list.
- The menu is built from the live router: `GET /v1/models` ids plus each entry's `aliases`.
  - It is C-sorted, so each alias is listed next to its canonical id; each lane shows its router-reported status.
  - If the router is down the launch fails loudly; there is no fallback to a file.
- Any input that is not a menu number is used verbatim as a lane name (the fallback). The router 404s on a typo.
- Every claude arg passes through untouched; mid-session `/model` moves only the main session.
- Every plugin is disabled per-session (`--settings` override built from `~/.claude/settings.json` at launch).
- With `~/.config/claude-local.mcp.json` present (WSL), it sources `~/.config/claude-local.env` (mode 600) and
  execs with `--disallowedTools=WebSearch` plus the vendored web-search MCP (`llamacpp/mcp/`). Without that
  file, only the plugin override applies.
  - That env file also enables raw-body logging to `/tmp/claude-bodies` (B8, a review item the owner has not
    released); whether it logs anything depends on the telemetry settings, and that is unverified live.
- Sends requests to `/v1/messages` - immune to the chat-template guard above.

The test: the lane you picked is the model every session role is talking to.

## Doc map

- [README.md](README.md) - what/why, quickstart, catalog pointers, repo map.
- [llamacpp/README.md](llamacpp/README.md) - the serving stack: preset layout, id grammar, alias policy,
  which template each entry runs, add-a-model.
- [llamacpp/templates/README.md](llamacpp/templates/README.md) - vendored chat templates: shas, validated pairs.
- [llamacpp/mcp/README.md](llamacpp/mcp/README.md) - the web-search MCP claude-local loads.
  - Search is Ollama's hosted cloud API, not Brave; the swap to Brave is specced in `specs/brave-search-mcp`.
- [docs/architecture.md](docs/architecture.md) - the stack: layering, MTP, serving + clients, disk.
- [docs/parameters.md](docs/parameters.md) - sampling profiles, mandates, verification sources.
- [docs/benchmarking.md](docs/benchmarking.md) - the retired-suite record, resource capture, distilled findings.
- [docs/openwebui.md](docs/openwebui.md) - Open WebUI setup, and how its settings are stored in the database.
- [docs/history/index.md](docs/history/index.md) - dated, immutable session evidence logs.
- `specs/<feature>/` - in-flight work, tasks.md as the resume point; `specs/README.md` is the roadmap.

Markdown: rumdl enforces `.rumdl.toml` (120-col, check-only, never `--fix`); `docs/history/` is excluded as
immutable. Soft-wrap only - fix a long line by cutting or splitting ideas, never a mid-idea break.

Name sets, never their size, because written counts drift. The one sanctioned count is a file's own header
total (e.g. `llamacpp/models.ini:1`); check it against the file whenever you touch that file.
