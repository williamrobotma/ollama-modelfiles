# Templates

- `chat_template.jinja` - froggeric/Qwen-Fixed-Chat-Templates v21.3, snapshot `23a40b0b`, Apache-2.0.
  - Upstream-verbatim except one sanctioned local fix (below); re-copy and re-validate at the next upstream release.
    - Upstream sha256 `d203f3342d8a7f8474dd55563eece3a26e71b21c6f667c9db9c93b762b3bf997`.
    - Vendored sha256 `8daaa08a95d04783e7e1b7f47a6e432e235da39bedd8dd6b990777020a24f2e4`.
  - Local fix (2026-08-08, user go): 9 tool-instruction tags `{%-` -> `{%` in the tool_instructions block.
    - v21.3 regression under trim_blocks (the HF + llama.cpp convention); unreported upstream as of 2026-08-08.
    - Symptom: the <IMPORTANT> bullets collapsed onto one line; the blank line before <think> was eaten.
    - Verified on build 10326 (llama-template-analysis) and CPython Jinja2: render diff = the two fixed sites only.
    - Drop this delta at the next upstream re-fetch.
  - Validated pair: v21.3 on b9860 (`docs/history/2026-07-23-chat-template-refresh.md`).
    - Re-validation of the (patched template, 10326) pair is queued with the build re-cert (GPU-gated).
  - Serves the guarded Qwen GGUFs to OpenAI-style clients (embedded templates 400 multi-system requests).
    - Covers 3 preset entries: unsloth Qwen3.5-9B non-MTP, plus the two Queen-27B configs sharing one GGUF.
