# Open WebUI wrap-up

Small side task. This spec is its own plan - no separate plan.md; tasks.md is the checklist.

Rescoped 2026-08-12: the original checklist predated the router cutover; done items folded in, stale framing dropped.

## Why

Open WebUI serves from the router (OpenAI connection at 11433; cut over and browser-validated 2026-08-07).
Login, chat, and Brave-search chats were exercised in that validation.
What never happened:

- Native tool calling and vision, in the browser.
- The user-facing default model list decision.
- One community model's final live template probe.

Background and current state: docs/openwebui.md.

## What / acceptance

### 1. Remaining in-browser checks

- Native tool calling with a tools-capable model (`qwen3.6-27b-coding`): the model issues a tool call and gets a result.
- Vision: drop an image on `gemma4-12b-it-qat` (its entry carries `mmproj =`); the model reads the image.
- Each check either works or gets a written issue in docs/openwebui.md or a history log.

### 2. Chat-template gate residue

- `qwen3.5-queen-27b-coding`: done 2026-07-23 - guarded; served froggeric-validated ever since.
- `gemma4-31b-it-heretic`: template extracted 2026-08-03 with no guard string; its 26B sibling passed a live probe.
  - Residue: one live multi-system probe against the 31B entry itself (AGENTS.md gate step 3).
  - Record the verdict in docs/openwebui.md.

### 3. Default model visibility

- Decide which ids appear in the user-facing model list; set it in Admin Panel > Settings > Models.
- Record the intended set in docs/openwebui.md so it can be reapplied.
  - These settings live in `webui.db`, not in env (docs/openwebui.md explains the storage).

### 4. Host-side disk reclaim

Superseded 2026-08-12: the orphaned-blob deletion folds into the migration's Phase 4 store purge (~2026-08-21),
which deletes the whole Ollama store; the vhdx compact happens there too.
