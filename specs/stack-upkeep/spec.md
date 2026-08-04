# Stack upkeep

SCAFFOLD - plan in a fresh session.

## Goal

Keep llama.cpp, Ollama, Open WebUI, and the pinned GGUFs current and tracked. Today versions are pinned ad hoc and drift is found by accident.

## Decide at planning

- What to record, and where.
- When to update: on a schedule, or triggered by a watched fix landing.
- The check each component must pass before an update is trusted.
  - Decided for chat templates (2026-07-23): the AGENTS.md gate section's vetting procedure.
- What stays pinned on purpose.
  - Decided for all components (2026-08-03): nothing is frozen - llama.cpp, Ollama, Open WebUI, and the GGUFs
    may stay updated.
  - A pin is a documented last-known-good record only; it moves forward when the component's named check passes.
  - Precedent: the llama.cpp launcher-abort removal (decision record in the 2026-08-03 P1 log).

## Done when

A short procedure doc exists and each component has a named check. No new services.

## Version snapshot (2026-08-03)

Superseded once planning starts.

- llama.cpp: local b9860, upstream b10251. No fix merged for the Gemma MTP bugs - don't upgrade for that.
  - #26017 and #24795 are both still open with no linked PR (checked 2026-08-03).
  - Watched fix landed: #25707 (Bonsai ternary group-64 CUDA) merged 2026-07-30 - a concrete rebuild trigger.
  - If rebuilding anyway, re-smoke speculative decoding and the pinned sampling flags.
    - llama-cli was rewritten.
    - b10242 moved penalties sampling to the GPU.
    - b10251 added GLM-4.7-Flash MTP.
- Ollama: 0.31.2 installed, 0.32.5 out. Low risk, no benefit (vendored engine unchanged).
  - 0.32.x rewrites the CLI into an interactive agent - recheck `ollama launch claude` before any upgrade.
- Open WebUI: 0.11.0 installed = latest (pipx upgrade done), but not started since the upgrade.
  - `~/.open-webui/webui.db` is untouched since Jul 11, so the 0.11.0 DB migration has not run.
  - Pending at first run: the DB migration, then the native-connection sampling check in docs/openwebui.md.
