# Open WebUI wrap-up

Small side task. This spec is its own plan - no separate plan.md; tasks.md is the checklist.

## Why

Open WebUI is installed (pipx 0.10.2) and wired to the migrated Ollama stack, and its config was verified at the DB level (native Ollama connection, Brave search engine+key, `openai.enable=false`) - but it has never been exercised end-to-end in a browser. See docs/openwebui.md and docs/history/2026-07-10-migration-local-ggufs.md. Three loose ends remain: an in-browser smoke pass, the chat-template gate on two never-vetted community models, and one pending host-side disk reclaim.

## What / acceptance

### 1. In-browser end-to-end pass

Launch `~/.local/bin/openwebui`, open <http://127.0.0.1:8080>. Each check either works or gets a written issue (in docs/openwebui.md or a history log):

- Login with the recovered admin account (William Ma).
- Chat against a migrated model (any repo Modelfile model) - response streams, sampling looks right.
- Web search round-trip: a query that triggers Brave, results cited in the answer (key is in the DB, live-tested HTTP 200 - confirm it works in a real chat).
- Native tool calling with a tools-capable model (`qwen3.6-27b-coding`) - a tool call fires and returns.
- Vision: drop an image on a gemma4 model (`gemma4-12b-it-qat`, has mmproj) - it reads the image. Confirms the second `FROM mmproj` line kept the `vision` capability.

### 2. Chat-template gate on two community models

Per AGENTS.md (multiple mid-conversation system messages must not error), probe both with `ollama show --template <model>` and a multi-system-message request:

- `qwen3.5-queen-27b-coding-q4-k-m`
- `gemma4-31b-it-heretic-i1-q4-k-m`

Record pass/fail per model in the model catalog (README) or docs/openwebui.md. A model that fails the gate is unusable from multi-system clients (claude-local, and Open WebUI's own system-message stacking) - note it, do not silently keep it as such a target.

### 3. Default model visibility

Decide which models appear in the user-facing model list vs stay hidden, and set it in Admin UI (Admin Panel > Settings > Models). Record the intended default set so it can be reapplied (config lives in webui.db, not env - see docs/openwebui.md).

### 4. Host-side disk reclaim (user action, Windows side)

The migration left ~191 GB of orphaned Ollama blobs (old hf.co pulls + create temp files) listed in `.migration-artifacts/orphans.txt`; deleting them needs sudo (`sudo systemctl stop ollama`, delete listed files, restart) - see the history log. A WSL2 vhdx does not return freed space to NTFS on its own. So, after the orphan deletion:

- User step (Windows): `wsl --shutdown`, then `Optimize-VHD` (or diskpart `compact vdisk`) on the `ext4.vhdx`.
- Expected reclaim on `F:` ~190 GB (the freed orphan blobs), per the history log's space accounting.
