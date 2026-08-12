# Templates

`chat_template.jinja` serves the guarded Qwen GGUFs to OpenAI-style clients, whose embedded templates reject
multi-system requests (the vet rule is under Validated pairs, below). It covers every entry that sets
`chat-template-file`: unsloth Qwen3.5-9B non-MTP, plus the Queen-27B entries (coding, reasoning, and the
instruct entry added 2026-08-11) that share one GGUF.

## Provenance

- Source: froggeric/Qwen-Fixed-Chat-Templates v21.3, snapshot `23a40b0b`, Apache-2.0.
- Upstream sha256: `d203f3342d8a7f8474dd55563eece3a26e71b21c6f667c9db9c93b762b3bf997`.
- Vendored sha256: `8daaa08a95d04783e7e1b7f47a6e432e235da39bedd8dd6b990777020a24f2e4`.
- The vendored file is upstream-verbatim except for the one sanctioned local fix below.
- Re-copy and re-validate at the next upstream release, and drop the local fix then.

## Local fix

2026-08-08 (user go): 9 tool-instruction tags changed from `{%-` to `{%` in the tool_instructions block.

- Cause: a v21.3 regression under trim_blocks, the HF + llama.cpp convention; unreported upstream as of 2026-08-08.
- Symptom: the <IMPORTANT> bullets collapsed onto one line, and the blank line before <think> was eaten.
- Verified on build b10326 (llama-template-analysis) and on CPython Jinja2.
  - Render diff = two sites, nine tags only.

## Validated pairs

A pair is one template file, identified by its sha256, on one llama.cpp build. The sha256 prefixes below are the
full values in Provenance. PASS means the multi-system probes returned 200 with no rejection from the embedded
guard; a FAIL row would name the point at which the probe failed.

| Template | Build | Date | Result | Notes |
|---|---|---|---|---|
| upstream, unpatched (`d203f334`) | b9860 | 2026-07-23 | PASS | `docs/history/2026-07-23-chat-template-refresh.md` |
| vendored, patched (`8daaa08a`) | b10326 | 2026-08-08 | PASS | Both guarded GGUFs; details below |
| vendored, patched (`8daaa08a`) | b10335 | 2026-08-10 | PASS | All 3 guarded entries; details below |

Re-validate whichever pair is live whenever the build record moves.

Details for the b10326 pair:

- Multi-system `/v1/chat/completions`: 200 and no guard 400 on both guarded GGUFs; the 9B answered in content.
- Queen spent its 32-token cap inside reasoning and returned empty content: a status-level pass, not visible text.
- The same-day b10326 re-cert failed on an unrelated Qwen-MTP crash.
  - The build disposition is not this file's to state: the record and the canonical-build rule live in `../launch.sh`.
- Whether this becomes the served pair follows the build disposition, not this probe.

Details for the b10335 pair:

- Multi-system `/v1/chat/completions`: 200 on all 3 guarded entries (the 9B, plus both Queen-27B configs).
- All three spent the 32-token cap inside reasoning and returned empty content: a status-level pass, not visible text.
  - The 9B answered in content at b10326 and did not here. The cap is the difference, not the template.
- Control, the same 9B GGUF with no template override and `-ngl 0`: the embedded guard rejected the request.
  - The override is therefore required on this build.
  - Sanity check on that same server: a single leading system message returned 200.
- **The guard returned HTTP 500 on b10335, not the 400 seen at b10326.** The message was verbatim
  `Jinja Exception: System message must be at the beginning.` Vet on the text, never the status code.
