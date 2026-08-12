# templates/ - vendored chat templates

A chat template is Jinja code embedded in a GGUF; the server runs it to turn a chat's message list into prompt text.
Some community Qwen GGUFs embed a "guarded" template: it rejects any chat where a `system` message is not first.
The guard is this exact line of template code: `raise_exception('System message must be at the beginning.')`.
Clients do send `system` messages mid-conversation, so a guarded model would fail those chats.
The fix: entries backed by guarded GGUFs serve `chat_template.jinja` (this directory) instead of the embedded one.
`models.ini` wires that per entry with `chat-template-file` under `--jinja`.
The guarded GGUF list lives in `../README.md`; the vetting steps are the AGENTS.md chat-template gate.

## Provenance

- Source: [froggeric/Qwen-Fixed-Chat-Templates](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates),
  v21.3, snapshot `23a40b0b`, Apache-2.0.
- Upstream sha256: `d203f3342d8a7f8474dd55563eece3a26e71b21c6f667c9db9c93b762b3bf997`.
- Vendored sha256: `8daaa08a95d04783e7e1b7f47a6e432e235da39bedd8dd6b990777020a24f2e4`.
- The vendored file is upstream-verbatim except for the one sanctioned local fix below.
- At the next upstream release: re-copy, re-validate, and drop the local fix.

## Local fix

2026-08-08 (user-approved): nine tags in the tool-instructions block changed from `{%-` to `{%`.

- `{%-` strips the whitespace before a tag; llama.cpp and HF also run Jinja with `trim_blocks` (strip after).
- Under that combination v21.3 over-strips - a regression, unreported upstream as of 2026-08-08.
- Symptom: the template's `<IMPORTANT>` bullets collapsed onto one line, and the blank line before `<think>` was eaten.
- Verified on build b10326 (llama-template-analysis) and on CPython Jinja2.
  - The render diff shows exactly two changed sites from the nine tags, and nothing else.

## Validated pairs

Both the template file and the llama.cpp build affect what a request sees, so validation is per (template, build) pair.
A template is identified by its sha256; the prefixes below abbreviate the full values in Provenance.
PASS = probe requests carrying a mid-conversation `system` message succeeded, with no rejection from the guard.
A FAIL row would name the failing probe.

| Template | Build | Date | Result | Notes |
|---|---|---|---|---|
| upstream, unpatched (`d203f334`) | b9860 | 2026-07-23 | PASS | `docs/history/2026-07-23-chat-template-refresh.md` |
| vendored, patched (`8daaa08a`) | b10326 | 2026-08-08 | PASS | Both guarded GGUFs; details below |
| vendored, patched (`8daaa08a`) | b10335 | 2026-08-10 | PASS | All 3 then-guarded entries; details below |

Re-validate whichever pair is live whenever the build record (`../launch.sh`) moves.

Details for the b10326 pair:

- The probe returned 200 on both guarded GGUFs, with no guard rejection.
- The 9B returned visible text; Queen-27B spent the probe's whole 32-token budget thinking, so its reply was empty.
  - Empty-but-200 still passes: the probe tests template acceptance, not answer quality.
- b10326 failed its same-day recertification (post-rebuild crash tests) on an unrelated Qwen-MTP crash.
  - Whether a build is accepted for serving is recorded in `../launch.sh`, not here; this probe alone decides nothing.

Details for the b10335 pair:

- The probe returned 200 on all 3 then-guarded entries (the 9B plus the two Queen-27B entries of 2026-08-10).
- All three replies were empty: same 32-token-budget reason as above, a pass at the protocol level.
  - The 9B returned text at b10326 and none here; the token budget is the difference, not the template.
- Control run - the same 9B GGUF, no replacement template, `-ngl 0`: the embedded guard rejected the probe.
  - So the replacement template is doing the work on this build; it is not vestigial.
  - Sanity check on that control server: a request with one leading `system` message returned 200.
- **The guard's HTTP status changed across builds: 400 at b10326, 500 at b10335.**
  - The error text stayed verbatim: `Jinja Exception: System message must be at the beginning.`
  - So vetting must match the guard's message text, never the HTTP status (AGENTS.md gate, step 3).
