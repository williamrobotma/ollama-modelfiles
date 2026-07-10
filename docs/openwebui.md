# Open WebUI

Open WebUI is the browser chat frontend for the local Ollama stack. Setup and the non-obvious config semantics are captured here; the migration evidence log is [history/2026-07-10-migration-local-ggufs.md](history/2026-07-10-migration-local-ggufs.md).

## Install and launch

- Installed via `pipx`, version 0.10.2.
- No background service (user preference). The launcher `~/.local/bin/openwebui` runs it on demand, in the foreground; Ctrl+C stops it.
- `DATA_DIR=~/.open-webui` is pinned in the launcher. This is load-bearing: the pipx-venv default `DATA_DIR` lives *inside* the venv and is destroyed by `pipx upgrade` (verified in `env.py` source). That trap already ate one install - the admin account plus 7 chats were recovered out of the venv-internal `webui.db` via an sqlite backup into `~/.open-webui`.

## Config lives in the DB, not env

- All settings live in `webui.db` (SQLite under `DATA_DIR`), edited through the Admin UI at <http://127.0.0.1:8080>.
- Environment variables only *seed* the DB on first launch and are then ignored ("PersistentConfig" semantics). To change a setting later, use the Admin UI, not env.
- Verified DB state: `ollama.base_urls=[http://127.0.0.1:11434]`, `web.search.engine=brave`, `web.search.enable=true`, `openai.enable=false`.

## Ollama connection: native, not OpenAI-compat

- Connect to Ollama over the native connection at `http://127.0.0.1:11434`, not the OpenAI-compatible `/v1` endpoint.
- Reason: ollama's `/v1` injects `temperature=1.0` / `top_p=1.0` when the client omits them, silently overriding the Modelfile's own sampling (verified in `openai.go` at v0.31.1). The native connection type passes nothing it is not given, so the Modelfile parameters stand.

## Web search (Brave)

- Engine set to `brave` with the API key stored in `webui.db` (Admin Panel > Settings > Web Search). The key came over with the recovered DB and was live-tested (HTTP 200 against `api.search.brave.com`).

## Auth reality

- No inbound auth anywhere; everything binds to localhost.
- `OLLAMA_API_KEY` on the server is a client-side variable only (used by `ollama launch`/cloud). It does *not* gate inbound requests - `/api/tags` and `/v1/models` answer 200 unauthenticated on-box - so Open WebUI needs no bearer key to reach Ollama.
