# Templates

- `chat_template.jinja` - froggeric/Qwen-Fixed-Chat-Templates v21.3, snapshot `23a40b0b`, Apache-2.0.
  - Upstream-verbatim except one sanctioned local fix (below); re-copy and re-validate at the next upstream release.
    - Upstream sha256 `d203f3342d8a7f8474dd55563eece3a26e71b21c6f667c9db9c93b762b3bf997`.
    - Vendored sha256 `8daaa08a95d04783e7e1b7f47a6e432e235da39bedd8dd6b990777020a24f2e4`.
  - Local fix (2026-08-08, user go): 9 tool-instruction tags `{%-` -> `{%` in the tool_instructions block.
    - v21.3 regression under trim_blocks (the HF + llama.cpp convention); unreported upstream as of 2026-08-08.
    - Symptom: the <IMPORTANT> bullets collapsed onto one line; the blank line before <think> was eaten.
    - Verified on build 10326 (llama-template-analysis) and CPython Jinja2: render diff = two sites, nine tags only.
    - Drop this delta at the next upstream re-fetch.
  - Validated pairs, keyed by file sha256 (shas above):
    - Upstream v21.3 (unpatched) on b9860: validated 2026-07-23 (`docs/history/2026-07-23-chat-template-refresh.md`).
    - Vendored patched file on build 10326: probes PASSED 2026-08-08.
      - Multi-system `/v1/chat/completions`: 200 + no guard 400 on both guarded GGUFs; the 9B answered in content.
      - Queen spent its 32-token cap inside reasoning (empty content): a status-level pass, not visible text.
      - The same-day 10326 re-cert FAILED on an unrelated Qwen-MTP crash; build disposition is not this file's
        to state - the record and the canonical-build rule live in `../launch.sh`.
      - Whether this becomes the served pair follows the build disposition, not this probe.
    - Vendored patched file on build 10335: probes PASSED 2026-08-10.
      - Multi-system `/v1/chat/completions`: 200 on all 3 guarded entries (9B, plus both Queen-27B configs).
      - All three spent the 32-token cap inside reasoning (empty content): a status-level pass, not visible text.
        - The 9B answered in content at 10326 and did not here. The cap is the difference, not the template.
      - Control - same 9B GGUF, no template override, `-ngl 0`: the embedded guard fired, so the override is
        load-bearing on this build. Sanity check on that same server: a single leading system message returned 200.
        - **The guard returned HTTP 500 on 10335, not the 400 seen at 10326**, message verbatim
          `Jinja Exception: System message must be at the beginning.` Vet on the text, never the status code.
    - Re-validate whichever pair is live whenever the build record moves.
  - Serves the guarded Qwen GGUFs to OpenAI-style clients (their embedded templates reject multi-system
    requests - the vet rule above).
    - Covers 3 preset entries: unsloth Qwen3.5-9B non-MTP, plus the two Queen-27B configs sharing one GGUF.
