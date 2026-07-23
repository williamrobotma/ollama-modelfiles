# Spec: gemma4 MTP variants

## Why

`26b-a4b-it-qat-mtp` exists; `12b-it-qat-mtp` and `31b-it-qat-mtp` do not. All three stock QAT
gemma4 repos have MTP drafters cached locally. This brings parity.

## What

Create two Modelfiles that pair each stock QAT model with its Unsloth MTP drafter via the
`DRAFT` command, following the exact pattern established by `26b-a4b-it-qat-mtp`.

## Constraints

- Stock QAT only - heretic/obliterated variants use ablated models; stock drafters mismatch.
- Parameters inherit from parent (num_ctx, temperature, top_p, top_k, repeat_penalty, SYSTEM).
- `draft_num_predict 2` (Unsloth's recommended starting value for gemma4 MTP).
- Local GGUF paths from HF cache (consistent with existing gemma4 modelfiles).

## Acceptance

- `rumdl check` clean.
- Both Modelfiles parse without error (`ollama create` dry-run).
