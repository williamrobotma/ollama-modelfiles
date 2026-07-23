# Session summary: uncensored model replacement + 2026 landscape

## Trigger

`qwen3.6-35b-a3b-uncensored-q4-k-m` (HauhauCS abliterated) returned `400` on every
Claude Code request:

```
Unable to generate parser for this template. Automatic parser generation failed:
... line 85 ... raise_exception('System message must be at the beginning.')
```

## Diagnosis (local repro)

- The GGUF's embedded Jinja `chat_template` has a non-standard guard
  (`{%- if message.role == "system" %}{%- if not loop.first %}{{- raise_exception(...) }}`)
  at line 85. Canonical Qwen3.6 does **not** have it (verified: `qwen3.6-35b-a3b-coding`
  has the same `<function=>` tool format but no guard).
- Repro against `/v1/chat/completions`:
  - `[user]` -> 200 OK
  - `[user, system]` -> 400 (the guard)
  - `[system, system, user]` -> 400 ; `[system, user]` -> 200
  - => trigger = **any system message that is not first**, i.e. multiple/non-first system.
- Claude Code (via `ollama launch claude` -> Ollama's Anthropic endpoint at :11434)
  inherently sends multiple `system`-role messages per request. Ground truth from
  `OTEL_LOG_RAW_API_BODIES` (`/tmp/claude-bodies/*.request.json`):
  - top-level `system`: 2 text blocks
  - `messages` roles: `[user, system, assistant, user, ... , user, system]`
  - idx 1 = SessionStart hook context (superpowers); idx 16 = skills-list reminder.
  - This is core Claude Code behavior; cannot be configured off.
- Not fixable from the Modelfile: Ollama 0.30.10's `TEMPLATE` directive is **Go
  text/template** (legacy `/api/generate`); the chat endpoint renders the GGUF's
  **Jinja** template. Pasting Jinja into `TEMPLATE` fails with a Go parse error
  (`function "content" not defined`). No `ollama create` flag supplies a Jinja template.
  Only a GGUF-metadata edit could patch it.

## Decision

Delete the HauhauCS abliteration (its broken template is a packaging defect, not an
abliteration property) and adopt a replacement with a canonical template.

> **Correction (2026-07-23, chat-template-refresh):**
>
> - The guard is the official Qwen 3.5/3.6 default, verbatim in Qwen's own `chat_template.jinja` - not a HauhauCS packaging defect.
> - The "canonical Qwen3.6 does not have it" check above ran against unsloth's `qwen3.6-35b-a3b-coding`, a guard-free `merged_system` repack - not Qwen's template.
> - Details: [2026-07-23-chat-template-refresh.md](2026-07-23-chat-template-refresh.md).

Removed: alias model, `hf.co/HauhauCS/...` base pull, `Modelfile.qwen3.6-35b-a3b-uncensored-q4-k-m`.
Kept: `gemma4-12b-it-uncensored` (DuoNeural; no guard, works).

## 2026 uncensored landscape (researched 2026-06-23)

- **Abliteration removes the refusal direction in the weights; it does not alter the
  chat template or architecture.** So a broken template = packaging quirk, not inherent.
  Reputable providers keep the canonical template (Claude Code compatible).
- **Heretic** (p-e-w, automated, Optuna-driven) is now the leading method: lowest
  capability damage - KL 0.16 vs huihui manual 0.45 vs mlabonne v2 1.04 on Gemma-3-12B,
  same 3/100 refusals. 1000+ Heretic models on HF. Supports Llama/Qwen/Gemma/Mistral +
  several MoE; excludes Mamba/Jamba.
- **Reasoning caveat**: abliteration can misclassify chain-of-thought as refusals and
  dent reasoning; Heretic least so. Verify on-task.

### Recommendations by footprint

| Tier | Model | Footprint | Notes |
|---|---|---|---|
| Offload MoE (early pick) | `huihui_ai/Qwen3.6-abliterated:35b-a3b-q4_K` | 24 GB, 256K | Early candidate; superseded as daily driver by the Gemma-26B-A4B heretic (see Outcome), kept as the vanilla half of the vanilla-vs-distill A/B. Ollama-native; Claude-trace variants `:35b-Claude-4.6/4.7` also exist. |
| Offload, lighter | `huihui_ai/Qwen3.6-abliterated:27b` | 17 GB, 256K | Dense 27B; less RAM, slightly slower/token than MoE. |
| Offload, HF GGUF (Heretic) | `Youssofal/Qwen3.6-35B-A3B-Abliterated-Heretic-GGUF`, `SC117/...-heretic-...-APEX-GGUF`, `llmfan46/...-heretic-Native-MTP-Preserved` | ~19-24 GB | Heretic preserves template; APEX = MoE-aware quant; MTP-preserved keeps spec decoding. |
| Resident <=12 GB | `richardyoung/qwen3-14b-abliterated:q4_K_M` (`:agent` tag) | ~9 GB | Vision + tool calling, fully resident. |
| Resident, alt | `Mistral-Nemo-12B-Uncensored-HERETIC` | ~7-8 GB | Strong general uncensored 12B; less reasoning-tuned. |

(UGI leaderboard leaders Grok-4 69.0 / DeepSeek-V3.2-Speciale 67.9 are out of footprint;
context only.)

### Mandatory vet before adopting any community GGUF as a Claude Code target

```bash
ollama pull <model>
ollama show --template <model> | grep -i "system message must be at the beginning"   # empty = safe
# 3-system smoke test (the shape Claude Code sends):
curl -s localhost:11434/v1/chat/completions \
  -d '{"model":"<model>","messages":[{"role":"system","content":"a"},{"role":"system","content":"b"},{"role":"user","content":"hi"}],"max_tokens":1}'
```

## Sources

- UGI Leaderboard: https://huggingface.co/spaces/DontPlanToEnd/UGI-Leaderboard
- Heretic tool: https://github.com/p-e-w/heretic
- Heretic benchmarks: https://aithinkerlab.com/heretic-ai-abliteration-benchmarks-2026/
- Abliterated models guide: https://dev.to/purpledoubled/abliterated-models-guide-qwen-36-gemma-4-heretic-llama-31-uncensored-download-links-1f4e
- VRAM tier list: https://abolitus.com/blog/best-local-llm-by-vram-8gb-12gb-24gb-uncensored-tier-list-2026
- huihui_ai/Qwen3.6-abliterated (Ollama): https://ollama.com/huihui_ai/Qwen3.6-abliterated

## Outcome / final state (updated 2026-06-23)

The initial pick (huihui Claude-4.7) was built and verified, then the search broadened
(GLM-4.7-Flash, OBLITERATUS/Pliny, darkc0de's UGI-Index) before converging on a Gemma MoE.

### Models built (all Claude-Code-vetted: template guard 0 + 3-system smoke -> 200)
- **`gemma4-26b-a4b-it-heretic-q5-k-m`** - DAILY DRIVER. Gemma-4-26B-A4B MoE (~3.8B
  active), llmfan46 "ultra" Heretic 1.2.0 + ARA (attn.o_proj L11-22), mradermacher
  i1-Q5_K_M (~19 GB). Offloads fast on 12 GB VRAM + 64 GB RAM. Probe: bat-and-ball
  answered correctly ($0.05) with clean CoT in the `<|think|>` channel -> reasoning
  survived the ultra abliteration. Reported: 3/100 refusals, KL 0.1237, MMLU 79.99 vs 82.48.
- **`qwen3.6-35b-a3b-claude4.7-abliterated-q4-k`** - Qwen baseline. huihui abliteration of
  lordx64's Qwen3.6-35B-A3B Claude-4.7-Opus-Reasoning-Distilled (`:35b-Claude-4.7-q4_K`).
- **`gemma4-12b-it-obliterated`** - resident 12B A/B vs DuoNeural (OBLITERATUS/Pliny
  CoT-aware abliteration, hf.co Q4_K_M).
- **`qwen3.6-35b-a3b-abliterated-q4-k`** - vanilla half of the Qwen vanilla-vs-distill
  A/B (huihui plain abliteration `:35b-a3b-q4_K`); pairs with the Claude-4.7 distill above.

### Key learnings
- **UGI-Index (darkc0de)** scores `(UGI*3 + NatInt*2 + Writing*1) * W10` - uncensored-ness
  + general intelligence + writing, NOT agentic tool-calling. Gemma-4-31B/26B-A4B Heretics
  top it among <=64 GB models; GLM-4.7-Flash's agentic edge (tau2 79.5) isn't captured.
- **GLM-4.7-Flash Heretic** = best agentic on paper but Unsloth warns its GGUF has Ollama
  chat-template issues -> skipped for the Ollama + Claude Code stack.
- **Gemma 4 absorbs abliteration well** (KL ~0.05-0.06 on 12B); **MoE needs EGA**
  (expert-granular): dense-only leaves ~29/100 refusals vs EGA's 3/100.
- **QAT + abliteration don't compose**: abliteration perturbs the QAT-calibrated lattice;
  the one QAT-base build (huihui qat-q4_0) ships plain Q4_K + crude non-EGA abliteration,
  no metrics. QAT advantage holds only for the unmodified `gemma4-26b-a4b-it-qat` @ UD-Q4_K_XL.
- **Quant**: i1-Q5_K_M over Q6_K for a higher GPU-resident fraction on 12 GB VRAM at
  negligible quality cost (imatrix narrows it; Q5<->Q6 ~0.1% PPL). UD-Q4_K_XL is Unsloth-only
  (not made for community Heretics), so the menu is mradermacher i1 K-quants.

### Parameter provenance (verified live this session)
- Gemma-26B-A4B heretic: temp 1.0 / top_p 0.95 / top_k 64 + `<|think|>` verified vs
  unsloth.ai/docs/models/gemma-4 (Google defaults); repeat_penalty 1.0 neutral (not
  specified upstream); num_ctx 200000 / num_predict 65536 = repo convention.
- Claude-4.7 Qwen: temp 1.0 / top_p 0.95 / top_k 20 / min_p 0 / presence_penalty 0 /
  repeat_penalty 1.0 verified vs unsloth.ai/docs/models/qwen3.6 (thinking/general profile).
- OBLITERATUS Gemma-12B: mirrors the DuoNeural `gemma4-12b-it-uncensored` profile for A/B.
