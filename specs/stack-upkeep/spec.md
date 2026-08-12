# Stack upkeep

SCAFFOLD - plan in a fresh session.

## Goal

Keep llama.cpp, Open WebUI, and the pinned GGUFs current and tracked.
Today versions are pinned ad hoc, and drift is found by accident.
Ollama left the scope when it was retired (stopped 2026-08-07; repo-side purge 2026-08-12).

## Decide at planning

- What to record, and where.
- When to update: on a schedule, or triggered by a watched fix merging upstream.
- The check each component must pass before an update is trusted.
  - Decided for chat templates (2026-07-23): the AGENTS.md gate section's vetting procedure.
- What stays pinned on purpose.
  - Decided 2026-08-03: every component may stay updated; a pin is a documented last-known-good record
    that moves forward when the component's named check passes.
  - Precedent: the llama.cpp launcher version-abort removal (decision record in the 2026-08-03 P1 log).

## Filed here from other specs

The per-rebuild re-vet checklist, to be formalized at planning:

- The crash matrix (packaged by `specs/gpu-stability-test`) and the froggeric (template, build) pair.
- The router preset INI schema (key names can move across builds).
- The `--mmproj` x MTP incompatibility and the KV q8_0-vs-Gemma question (migration spec pre-flight items;
  filed 2026-08-12 so they keep being monitored).

At the migration spec's close, its still-live upstream Watch issues move here (recorded 2026-08-12).

## Done when

A short procedure doc exists and each component has a named check. No new services.

## Watch items

- The client ecosystem is migrating toward OpenAI's Responses API; this stack deliberately holds Chat Completions.
  - Held: llama-server's Responses path has no stream timings and no stored threads (Codex runs fresh threads only).
  - It also silently drops web_search/namespace-typed tools with HTTP 200 (the invisible Codex MCP failure).
  - Choices held: Open WebUI api_type (docs/openwebui.md) and OpenCode stay on Chat Completions; Codex is Responses-native.
  - Flip triggers: llama-server Responses gains timings, tool-type errors, and state; or a client degrades Chat Completions.
  - No version pin protects these choices (components stay updatable): re-check at every rebuild and client upgrade.

## Planning leads (carried from the 2026-08-03 version snapshot)

- llama.cpp has since moved to b10335 (`llamacpp/launch.sh` is the build record).
- The Gemma MTP issues (#26017, #24795) had no merged fix as of 2026-08-03, so upgrading does not help them;
  their live status sits in the migration Watch list this spec inherits.
- Rebuild cautions recorded then: llama-cli was rewritten; b10242 moved penalties sampling to the GPU;
  re-smoke speculative decoding and the pinned sampling flags after any rebuild.
- Open WebUI 0.11.0: DB migration ran and browser validation passed (2026-08-04/07); state in docs/openwebui.md.
- A Qwen tool-calling fix is waiting in an unbuilt llama.cpp (found at the bonsai-27b pre-flight, 2026-08-12).
  - #26793, merged 2026-08-11: the bare `<function` trigger constrained valid text such as `#include
    <functional>` whenever a client supplied tools. It needs the complete `<function=name>` sequence now.
  - Affects every Qwen coding entry under OpenCode, Codex, and claude-local, which all send tools.
  - This is the first named reason to rebuild past b10335; weigh it against the re-certification cost.
