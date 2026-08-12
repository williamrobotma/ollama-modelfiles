# Parameter reference

This file defines the sampling profiles served across the fleet.
README and AGENTS.md link here instead of duplicating the tables.

Every value is verified against the official sources before it goes into a `llamacpp/models.ini` entry:

- Gemma 4: <https://unsloth.ai/docs/models/gemma-4>
- Qwen 3.6: <https://unsloth.ai/docs/models/qwen3.6>
- DiffusionGemma: <https://unsloth.ai/docs/models/diffusiongemma>
- Dynamic GGUFs: <https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs>
- Qwen upstream: <https://qwen.readthedocs.io/>
- Gemma 4 thinking (Google): <https://ai.google.dev/gemma/docs/capabilities/thinking>
- Qwen model cards (per-model, authoritative over the family pages where they disagree):
  - <https://huggingface.co/Qwen/Qwen3.6-35B-A3B> and <https://huggingface.co/Qwen/Qwen3.6-27B>

Vendor docs conflict in places. Where they do, this file records the conflict and the chosen value rather than
silently picking one - see the Qwen `presence_penalty` note below.

## Mandates (do not deviate)

- **Qwen repeat_penalty must be exactly 1.0.** Unsloth mandates it; any other value causes structural garbage in code output.
- **CUDA 13.2 produces corrupted Gemma 4 output.** Use CUDA 13.1 or 13.3.
- **Gemma 4 thinking is engine-scoped.** The trigger is `<|think|>` at the start of the system prompt.
  - How it gets there differs by engine, so never assume one mechanism carries over.
  - llama.cpp (`--jinja`): the template injects it when the `enable_thinking` kwarg is true, and llama.cpp defaults it true.
  - Ollama (the retired stack): never ran the GGUF's Jinja, so a Modelfile `SYSTEM <|think|>` line supplied it literally.
- **Qwen 3.6 thinking** is enabled by default.
  - Disable at launch with `--reasoning off` (`-rea off`; INI key `reasoning = off`), or with `/no_think` in the prompt.
    - The `--chat-template-kwargs` launch spelling for `enable_thinking` is deprecated on the pinned build.
    - Per request, `chat_template_kwargs {"enable_thinking": false}` is the equivalent.
  - The same control disables Gemma 4 thinking.
- **Strip prior thoughts in multi-turn history.** Google requires it, except inside function-calling sequences.

## Gemma 4 (Thinking)

For research, open-ended reasoning, and exploration.

| Parameter | Value | Note |
|---|---|---|
| temperature | 1.0 | |
| top_p | 0.95 | |
| top_k | 64 | |
| min_p | 0.0 | Repo choice, not a vendor value - see below |
| repeat_penalty | 1.0 | |
| num_ctx | 131072-262144 | 256K max; non-MTP entries serve 262144 full (2026-08-11); MTP ceilings 200000 (12B/31B) and 131072 (26B-A4B) - rationale on the models.ini entries |
| num_predict | 65536 | |
| System trigger | `<|think|>` | Activates reasoning; see the engine-scoped mandate above |

Neither Google nor unsloth publishes a `min_p` for Gemma 4. Bare llama-server injects `min_p 0.05` into any request
that omits it, so entries must set it explicitly or sampling drifts. `0.0` is pinned to match what Ollama served.

## Qwen 3.6 (Precise Coding)

For code generation, debugging, and structured technical work.

| Parameter | Value | Note |
|---|---|---|
| temperature | 0.6 | |
| top_p | 0.95 | |
| top_k | 20 | |
| min_p | 0.0 | |
| presence_penalty | 0.0 | |
| repeat_penalty | 1.0 | Mandated 1.0 - deviating causes structural garbage in code output |
| num_ctx | 200000 | 256K max (1M with YaRN); every `-coding` entry serves 200000 |
| num_predict | 65536 | |

The Qwen 3.5 9B coders reuse this exact precise-coding profile (verified identical to 3.6).

## Qwen 3.6 (General Tasks, thinking)

For non-coding use with thinking mode on.

| Parameter | Value | Note |
|---|---|---|
| temperature | 1.0 | |
| top_p | 0.95 | |
| top_k | 20 | |
| min_p | 0.0 | |
| presence_penalty | 0.0 | Contested per-model - see below |
| repeat_penalty | 1.0 | |
| num_ctx | 262144 | Full 256K max; every `-reasoning` entry serves it uncapped |

`presence_penalty` here is contested and the divergence is per-model, not a stale value.

- The `Qwen3.6-27B` card gives `0.0` for this profile; the `Qwen3.6-35B-A3B` card gives `1.5` for the same profile.
- Both cards agree on the other two profiles, and unsloth's family page gives `0.0`.
- Qwen's own caveat: a higher value reduces repetition but "may occasionally result in language mixing and a slight
  decrease in model performance".
- Qwen READMEs are self-inconsistent elsewhere too (`Qwen/Qwen3.5-9B` discussion #51, unanswered since April).
- Pinned `0.0` in `[*]`; the instruct entries (`qwen3.6-35b-a3b`, `qwen3.6-27b`, `qwen3.5-queen-27b`) override at `1.5`.
- Only `qwen3.6-35b-a3b-mtp-reasoning` diverges from its own card within this profile.
  - A post-migration A/B against `1.5` on that entry is filed in `specs/llamacpp-migration`.

## Qwen 3.6 (Instruct Mode, non-thinking)

For direct responses without reasoning traces.

| Parameter | Value | Note |
|---|---|---|
| temperature | 0.7 | |
| top_p | 0.8 | |
| top_k | 20 | |
| min_p | 0.0 | |
| presence_penalty | 1.5 | |
| repeat_penalty | 1.0 | |
| num_ctx | 262144 | Full 256K max; every instruct entry serves it uncapped |

Serve this profile with `--reasoning off` at launch (`-rea off`; INI key `reasoning = off`).
That flag is what makes it non-thinking on llama.cpp.
The per-request equivalent is `chat_template_kwargs {"enable_thinking": false}`.
Under Ollama the profile's values were set but thinking could not actually be disabled.

## Serving flags (llama.cpp)

The tables above are sampling only. These are the launch-side flags a served model also needs.
Under Ollama they came from the service env. Now `llamacpp/models.ini` sets them fleet-wide in its `[*]` block.

| Flag | Value | Note |
|---|---|---|
| `-fa` | `on` | In both vendors' recommended commands; pairs with quantized KV, which fails to load without it |
| `-ctk` / `-ctv` | q8_0 | KV cache type, settled fleet-wide (decided 2026-08-03 from the on-box KL probe). Numbers and reasoning are in `history/2026-08-03-llamacpp-p1-envelopes.md`. The earlier third-party lead stays directional context only: it was one unreplicated run, on BF16 GGUFs rather than the QAT/UD quants this fleet serves. |
| `-np` | 1 | Vendor MTP cards state `-np > 1` is unsupported with MTP |
| `--jinja` | required | Thinking kwargs and chat templates do nothing without it |
| `--spec-type` | `draft-mtp` | MTP lanes only |
| `--spec-draft-n-max` | 2 | Vendor cards give 2 for Qwen3.6 MTP and 4 for Gemma 4; the repo runs 2 pending a bench |
| `--mmproj` | non-MTP vision entries | Coexists with MTP on build b9860, per the 2026-07-28 P0 probe. The resident projector costs the MTP lane ~35-40% decode (n<=3, one GGUF). |

MTP entries carry no `mmproj`: the fleet splits for speed, not necessity.
Vision lives on the non-MTP sibling (9B, 27B) or the 35B-A3B instruct canonical, serving plain (no `--spec-type`).
