# Stack upkeep

SCAFFOLD - plan in a fresh session.

## Goal

Keep llama.cpp, Ollama, Open WebUI, and the pinned GGUFs current and tracked.
Today versions are pinned ad hoc, and drift is found by accident.

Amended 2026-08-08: Ollama tracking no longer applies now that Ollama is retired (stopped and disabled 2026-08-07).
Ollama tracking drops out at planning.

## Decide at planning

- What to record, and where.
- When to update: on a schedule, or triggered by a watched fix landing.
- The check each component must pass before an update is trusted.
  - Decided for chat templates (2026-07-23): the AGENTS.md gate section's vetting procedure.
- What stays pinned on purpose.
  - Decided for all components (2026-08-03): llama.cpp, Ollama, Open WebUI, and the GGUFs may stay updated.
  - A pin is a documented last-known-good record only; it moves forward when the component's named check passes.
  - Precedent: the llama.cpp launcher-abort removal (decision record in the 2026-08-03 P1 log).

## Done when

A short procedure doc exists and each component has a named check. No new services.

## Watch items

- The client ecosystem is migrating toward OpenAI's Responses API; this stack deliberately holds Chat Completions.
  - Held: llama-server's Responses path has no stream timings and no stored threads (Codex runs fresh threads only).
  - It also silently drops web_search/namespace-typed tools with HTTP 200 (the invisible Codex MCP failure).
  - Choices held: Open WebUI api_type (docs/openwebui.md) and OpenCode stay on Chat Completions; Codex is Responses-native.
  - Flip triggers: llama-server Responses gains timings, tool-type errors, and state; or a client degrades Chat Completions.
  - The update posture above means no version pin protects these choices: re-check at every rebuild and client upgrade.

## Version snapshot 2026-08-03 (superseded - do not act on)

Superseded once planning starts.

- llama.cpp: local b9860, upstream b10251. No fix merged for the Gemma MTP bugs - don't upgrade for that.
  - #26017 and #24795 are both still open with no linked PR (checked 2026-08-03).
  - Watched fix landed: #25707 (Bonsai ternary group-64 CUDA) merged 2026-07-30 - a concrete rebuild trigger.
  - If rebuilding anyway, re-smoke speculative decoding and the pinned sampling flags.
    - llama-cli was rewritten.
    - b10242 moved penalties sampling to the GPU.
- Ollama: 0.31.2 installed, 0.32.5 out. Low risk, no benefit (vendored engine unchanged).
  - 0.32.x rewrites the CLI into an interactive agent - recheck `ollama launch claude` before any upgrade.
- Open WebUI: 0.11.0 installed = latest (pipx upgrade done), but not started since the upgrade.
  - `~/.open-webui/webui.db` is untouched since Jul 11, so the 0.11.0 DB migration has not run.
  - Pending at first run: the DB migration, then the native-connection sampling check in docs/openwebui.md.
  - Amended 2026-08-08: stale - 0.11.0 first started 2026-08-04 (P3 prep) and ran 9 alembic migrations clean.
    - Browser-validated 2026-08-07; current state: `docs/openwebui.md`.
