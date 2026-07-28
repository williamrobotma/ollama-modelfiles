# Templates

- `chat_template.jinja` - froggeric/Qwen-Fixed-Chat-Templates v21.3, snapshot `23a40b0b`, Apache-2.0.
  - Byte-identical copy of the HF snapshot; never edit in place - re-copy and re-validate instead.
    - sha256 `d203f3342d8a7f8474dd55563eece3a26e71b21c6f667c9db9c93b762b3bf997`.
  - Validated pair: v21.3 on b9860 (`docs/history/2026-07-23-chat-template-refresh.md`).
  - Serves the guarded Qwen GGUFs to OpenAI-style clients (embedded templates 400 multi-system requests).
    - Covers 3 preset entries: unsloth Qwen3.5-9B non-MTP, plus the two Queen-27B configs sharing one GGUF.
