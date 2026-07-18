# Stack upkeep

SCAFFOLD - plan in a fresh session.

Goal: a simple routine to keep llama.cpp, Ollama, Open WebUI, and the pinned GGUFs current and tracked. Today versions are pinned ad hoc and drift is found by accident.

Decide at planning: what to record and where; when to update (schedule or triggered by a watched fix landing); the check that must pass per component before an update is trusted; what stays pinned on purpose.

Done when: a short procedure doc exists and each component has a named check. No new services.

Version snapshot 2026-07-17 (superseded once planning starts):

- llama.cpp: local b9860, upstream b10064. No fix merged for the Gemma MTP bugs - don't upgrade for that. If rebuilding anyway: re-smoke speculative decoding, and note llama-cli was rewritten.
- Ollama: 0.31.2 installed, 0.32.1 out. Low risk, no benefit (vendored engine unchanged). Recheck `ollama launch claude` after upgrading.
- Open WebUI: 0.10.2 = latest.
