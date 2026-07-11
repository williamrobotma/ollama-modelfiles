# Tasks: gemma4 MTP variants

Deferred 2026-07-11. Create MTP versions of the remaining stock QAT gemma4 models.

**Scope:** stock QAT variants only (MTP drafters trained on QAT, not ablated variants).
**Parameters:** inherit from parent model's existing profile; add MTP DRAFT + draft_num_predict.

## Tasks

- [ ] Create `modelfiles/gemma4/12b-it-qat-mtp/Modelfile`
  - FROM: `gemma4-12b-it-qat`
  - DRAFT: `/home/wma/.cache/huggingface/hub/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/7102bdea62863acff919c945405ef29973113d66/mtp-gemma-4-12B-it.gguf`
  - PARAMETER draft_num_predict 2
  - Inherit parent `12b-it-qat` params: num_ctx 200000, temperature 1.0, top_p 0.95, top_k 64, repeat_penalty 1.0, SYSTEM `<|think|>`

- [ ] Create `modelfiles/gemma4/31b-it-qat-mtp/Modelfile`
  - FROM: `gemma4-31b-it-qat`
  - DRAFT: `/home/wma/.cache/huggingface/hub/models--unsloth--gemma-4-31B-it-qat-GGUF/snapshots/365d657136993b4d7c40d868dd45ecb7a48e7ebf/mtp-gemma-4-31B-it.gguf`
  - PARAMETER draft_num_predict 2
  - Inherit parent `31b-it-qat` params: num_ctx 200000, temperature 1.0, top_p 0.95, top_k 64, repeat_penalty 1.0, SYSTEM `<|think|>`

- [ ] Commit both together

## Not in scope

- `12b-it-obliterated` — ablated model; stock drafter mismatch
- `26b-a4b-it-heretic-i1-q4-k-m` — heretic variant; stock drafter mismatch
- `31b-it-heretic-i1-q4-k-m` — heretic variant; stock drafter mismatch
