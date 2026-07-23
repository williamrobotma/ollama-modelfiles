# Plan: Bonsai-27B onboarding

Blocked until `specs/llamacpp-migration` builds the serving lane (`specs/llamacpp-serving` already landed its verdict). Re-verify research.md facts at implementation time - especially the #25707 gate, which may have cleared by then.

## Phase 0 - gate check + re-verify

- Confirm `specs/llamacpp-migration` has put per-model serving config somewhere (llamacpp-serving Phase 2/4 already landed) -> verify: the config home exists and is documented.
- Re-check #25707 via api.github.com (merged? which build?). If merged: plan the llama.cpp rebuild - a rebuild re-triggers the Gemma MTP load re-check (docs/history/2026-07-17-llamacpp-eval.md, verdict item 5).
- Spec review: record the three decisions (ternary path / sampling profile / intended role) in tasks.md.

## Phase 1 - 1-bit lane

- `hf download prism-ml/Bonsai-27B-gguf` for `Bonsai-27B-Q1_0.gguf` (3.8 GB) + `Bonsai-27B-dspark-Q4_1.gguf` (1.79 GB) + `Bonsai-27B-mmproj-Q8_0.gguf` (0.63 GB); pin the snapshot path per AGENTS.md sourcing convention -> verify: `df -h /mnt/f` before/after, ~6.2 GB delta.
- Template vet: multi-system `/v1/chat/completions` probe against a running instance -> verify: no 400; record pass/fail next to the fleet's guard-scan note.
- Launch under llama-server from the pinned path with the full decided profile as flags -> verify: `/props default_generation_settings` matches the profile; coding smoke prompt returns coherent output with timings.

## Phase 2 - bench (1-bit)

- Add parity-suite rows (`bonsai27b-q1`, `bonsai27b-q1-dspark`) to `benchmarks/llamacpp-parity/matrix.tsv` with `ollama_model` = `-`; bench against `qwen3.6-27b-coding-ud-q4-k-xl` - same base, so this is a clean quant-vs-quant comparison -> verify: report.py output with warmup + reps, not smoke N=1.
- DSpark A/B: `-md` + `--spec-draft-n-*` flags on vs off -> verify: decode tok/s delta and acceptance recorded; adopt only on a win.
- VRAM/ctx envelope on the 4070: resident footprint at the Modelfile-class contexts; find where it stops being fully resident -> verify: `nvidia-smi` figures in the results dir.
- Optional: mmproj load + one vision smoke (first `--mmproj` use on this lane).

## Phase 3 - ternary (the end state)

- When the Phase-0 ternary gate clears: download `Ternary-Bonsai-27B-Q2_g64.gguf` (7.59 GB) + its dspark Q4_1 (1.95 GB) - or the fork-format files if the fork decision went that way - and repeat Phases 1-2 on it.
- Three-way comparison: ternary vs 1-bit vs `qwen3.6-27b-coding-ud-q4-k-xl` on throughput, VRAM, and spot quality; the vendor retention deltas (94.6% vs 89.5%) are the hypothesis under test.
- Long-context check: community figures put ternary at 13.7 GiB at 100K ctx - establish the actual resident ceiling with the lane's KV quantization before claiming long-ctx support.
- Write the serving-role verdict; wire the winner into the serving config chosen by the llamacpp follow-on.

## Phase 4 - document

- docs/parameters.md: Bonsai-27B profile section (values + source URLs + the repeat_penalty stance).
- docs/benchmarking.md: the new rows and distilled findings; watch items (#25707, #13668) recorded alongside the existing llamacpp watch list.
- research.md: append a dated resolution note per gated fact (merged / still open / superseded).

## Risks / notes

- Vendor quality and speed numbers are unbenched marketing until Phase 2/3 - do not promote the model on them.
- DSpark can be a net slowdown on some hardware (-37% on DGX Spark); treat the drafter as an experiment, not a default.
- Fork lane, if chosen, is a second engine to build and maintain - prefer upstream unless #25707 stalls badly.
- VRAM contention while benchmarking: same posture as the parity suite (idle the systemd Ollama during runs).
