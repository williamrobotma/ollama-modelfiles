# Open WebUI

Open WebUI is the browser chat frontend, now wired to the llama-server router (11433), not Ollama.

Evidence logs:

- [history/2026-07-10-migration-local-ggufs.md](history/2026-07-10-migration-local-ggufs.md) - historical.
- [history/2026-08-07-llamacpp-p3-cutovers.md](history/2026-08-07-llamacpp-p3-cutovers.md) - the router cutover.

## Install and launch

- Installed via `pipx`, version 0.11.0 (upgraded from 0.10.2; `webui.db.bak-pre-0.11.0` backup taken first).
  - First 0.11.0 start ran 9 alembic migrations + 13 seeded config defaults; settings and the Brave key survived.
- No background service (user preference).
  - The launcher `~/.local/bin/openwebui` runs it on demand, in the foreground; Ctrl+C stops it.
- `DATA_DIR=~/.open-webui` is pinned in the launcher. This is load-bearing.
  - The pipx-venv default `DATA_DIR` lives *inside* the venv and is destroyed by `pipx upgrade` (per `env.py`).
  - That trap already ate one install - admin account plus 7 chats were recovered via an sqlite backup.

## Config lives in the DB, not env

- All settings live in `webui.db` (SQLite under `DATA_DIR`), edited through the Admin UI at 127.0.0.1:8080.
- Env vars only *seed* the DB on first launch and are then ignored ("PersistentConfig" semantics).
  - To change a setting later, use the Admin UI, not env.
- Verified DB state (2026-08-07): OpenAI connection to `http://127.0.0.1:11433/v1`; Ollama connection disabled.
  - Connection is external, bearer auth with a dummy key, no model filter, no passthrough params.
- The picker shows the canonical router ids (17 as of 2026-08-08) plus Open WebUI's own built-in "Arena Model".

## Connection: OpenAI-compat at 11433, not native Ollama (inverted from the old guidance)

- Connect over the OpenAI connection to `http://127.0.0.1:11433/v1`, the router's OpenAI-compatible endpoint.
  - This reverses the old rule (native Ollama, not `/v1`); the reason for that rule no longer applies here.
- `open_webui/utils/payload.py:70` applies only non-None params, so sampling neutrality holds at the source.
  - Unset chat params never enter the request body; the router's launch-time profiles govern instead.
- Historical reason for the old rule: Ollama's `/v1` (`openai.go`) injected `temperature=1.0`/`top_p=1.0`.
  - When the client omitted them, silently overriding the Modelfile's sampling (verified at v0.31.1).
  - That was Ollama-side behavior specific to Ollama's own `/v1` shim, not to llama-server or Open WebUI.

## Recommended connection settings

- `connection_type`: external.
  - Sole behavioral effect: which admin task-model setting is used, local vs. external (`utils/task.py:20`).
- `api_type`: Chat Completions, not Responses.
  - Responses loses tok/s display: `stream_options` is popped at `openai.py:1113`.
  - llama-server's Responses stream carries no timings, and it silently drops `web_search`/namespace tools.
- Provider: llama.cpp.
  - Prior-turn reasoning goes back as `reasoning_content`, which chat templates strip from history (standard).
  - Also unlocks the Loaded badge and the admin Eject action via the router's `/models/unload`.
- Auth: the connection's API-key field requires a value, so a dummy bearer key is set; no model filter.

## Metrics (tok/s)

- llama-server attaches a `timings` object to the final streamed chunk.
- Open WebUI merges it into `message.usage` unconditionally.
  - The info icon (hover a finished response) shows that dict, including `predicted_per_second`.
- Enabling a model's "Usage" capability (workspace model settings) adds OpenAI-style token counts.
  - Not required for tok/s to show.

## Web search (Brave)

- A platform per-chat toggle (integrations menu near the message input), not a model tool.
  - Engine `brave`, API key stored in `webui.db`.
- Open WebUI runs the search itself and injects the results.
  - In tool mode the model additionally sees a `search_web` tool in its inventory.
- Verified end-to-end 2026-08-07 on two models (one 5-source chat, one 10-source chat).

## Per-chat Advanced Params

- Controls > Advanced Params: rows tagged `(Ollama)` are dead on this connection.
  - Untagged rows reach the router only when explicitly set.
- A per-chat `repeat_penalty` ~1.05 is the escape hatch if a model falls into a repetition loop.
  - The fleet profiles deliberately carry no repeat penalty.
