# Open WebUI wrap-up

Small side task. This spec is its own plan - no separate plan.md; tasks.md is the checklist.

## Why

Open WebUI is set up and verified at the DB level, but it has never been exercised end-to-end in a browser:

- Installed (pipx 0.10.2) and wired to the migrated Ollama stack.
- Settings verified at the DB level: native Ollama connection, Brave search engine + key, `openai.enable=false`.
- Background: docs/openwebui.md and docs/history/2026-07-10-migration-local-ggufs.md.

Three loose ends remain:

- An in-browser smoke pass.
- The chat-template gate on one still-unvetted community model.
- One pending host-side disk reclaim.

## What / acceptance

### 1. In-browser end-to-end pass

Launch `~/.local/bin/openwebui` and open <http://127.0.0.1:8080>.
Each check either works, or gets a written issue in docs/openwebui.md or a history log.

- Login with the recovered admin account (William Ma).
- Chat against a migrated model (any repo Modelfile model) - response streams, sampling looks right.
- Web search round-trip: a query that triggers Brave, results cited in the answer.
  - The key is in the DB and live-tested at HTTP 200; confirm it works in a real chat.
- Native tool calling with a tools-capable model (`qwen3.6-27b-coding`) - a tool call fires and returns.
- Vision: drop an image on a gemma4 model that has an mmproj (`gemma4-12b-it-qat`) - it reads the image.
  - This confirms the second `FROM mmproj` line kept the `vision` capability.

### 2. Chat-template gate on community models

Vet per the AGENTS.md gate procedure (`ollama show --template` is retired - it shows a template that never runs):

- `qwen3.5-queen-27b-coding`: done 2026-07-23 - guarded; froggeric-validated (see the 2026-07-23 history log).
- `gemma4-31b-it-heretic`: still unvetted.

Record pass/fail per model in docs/openwebui.md (the README catalog tables were deleted 2026-08-08).
A failing model is unusable from multi-system clients (claude-local, Open WebUI's own system-message stacking).
Note the failure rather than silently leaving the model as a target for those clients.

### 3. Default model visibility

Decide which models appear in the user-facing model list and which stay hidden.

- Set the choice in the Admin UI (Admin Panel > Settings > Models).
- Record the intended default set so it can be reapplied.
- These settings live in webui.db, not in env - see docs/openwebui.md.

### 4. Host-side disk reclaim (user action, Windows side)

The migration left ~191 GB of orphaned Ollama blobs: old hf.co pulls and create temp files.

- They are listed in `.migration-artifacts/orphans.txt`.
- Deleting them needs sudo: `sudo systemctl stop ollama`, delete the listed files, restart - see the history log.
- A WSL2 vhdx does not return freed space to NTFS on its own.

So, after the orphan deletion:

- User step (Windows): `wsl --shutdown`, then `Optimize-VHD` (or diskpart `compact vdisk`) on the `ext4.vhdx`.
- Expected reclaim on `F:` ~190 GB (the freed orphan blobs), per the history log's space accounting.
