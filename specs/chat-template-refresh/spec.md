# Chat-template refresh: Gemma 4 & Qwen 3.5/3.6

- **Status:** RESEARCH COMPLETE - actions ready, not yet executed. Captured 2026-07-17.
- **Depends on:** PR #9 (`feat/llamacpp-serving`) - `docs/history/2026-07-17-llamacpp-eval.md` and `specs/stack-upkeep/` are cited here but land on that branch. Merge #9 first, or these references dangle; the doc-fix tasks are runnable only post-#9.
- **Scope:** recently fixed/updated chat templates for the `gemma4`, `qwen3.5`, `qwen3.6` families, mapped to serving-stack actions.
- **Goal frame:** complete the stock-llama.cpp migration, drop Ollama (`specs/llamacpp-serving`; eval verdict = option B). llama.cpp lane first.
- **Method:** templates + commits read live from Hugging Face; fleet gate state read on-box, read-only (`ollama show --template`, GGUF-header `grep`); **no inference run**.
- **Author ladder (which fix to prefer):** official (Google, Qwen team) -> third-party (unsloth, ggml-org) -> community (froggeric, OBLITERATUS, mradermacher, Jackrong). Do not stop at official.

## TL;DR

- **Gemma 4:** official template fix shipped 2026-07-15; unsloth re-quantized all 3 QAT repos 2026-07-17. Repo pins a Jun-10 snapshot -> **re-pull + re-pin**. No gate impact (Gemma has no guard).
- **Qwen:** the `System message must be at the beginning` guard is the **official Qwen default** (corrects AGENTS.md:52), so every current *and future* Qwen pull carries it -> the fix is a **family-wide rule**, not a per-model patch.
- **Lane decides urgency:** the Anthropic `/v1/messages` lane is **immune** (structural, a per-build property); only the **OpenAI / Open WebUI lane 400s**.
- **`froggeric/Qwen-Fixed-Chat-Templates`** removes the guard + adds agentic/KV-cache/Anthropic-thinking fixes; drop-in via `--chat-template-file`. Quality + OpenAI-lane compat, not a hotfix.
- **Vetting gate** (`ollama show --template`) is unreliable and Ollama-specific -> replace for the llama.cpp lane.

## Lane model (which client path executes which template)

| Lane | System reaches template as | Guard fires? | Used by |
|---|---|---|---|
| Anthropic `/v1/messages` (stock llama-server) | conversion layer folds system to a single leading turn; `messages[]` cannot hold system roles | **No** - immune *regardless of GGUF template* (a build property, on-box: 2-block system accepted) | claude-local replacement |
| OpenAI `/v1/chat/completions` (stock llama-server `--jinja`) | passed through; a non-first system triggers the guard | **Yes** - 400 (verified on-box) | Open WebUI, OpenAI clients |
| Ollama `/v1` (legacy, retiring) | Ollama does not execute the GGUF Jinja (see Corrections + Caveats) | Contested - moot | today's claude-local + Open WebUI |

Source (rows 1-2): on-box, `docs/history/2026-07-17-llamacpp-eval.md` s4.

## Gemma 4 - state and action

| Item | Value |
|---|---|
| Official fix | Google, 2026-07-15 (tool-calling patched, smoother formatting, "less laziness"); `google/gemma-4-12B-it/chat_template.jinja` header `Published: 2026-07-09`, latest commit `#35` (~07-15) |
| Packaged (third-party) | unsloth QAT re-uploaded 2026-07-17 - 12B `980b060` "Added Gemma official chat template update"; `26B-A4B` + `31B` show same-day update |
| Repo pin | `7102bde` (Jun-10) - **stale** (predates the fix; currency read from commit dates, not header text - GGUF templates are comment-stripped) |
| Guard | none - Gemma `<|turn>` format renders repeated/non-first system with no `raise_exception` |
| Gate status | safe on both lanes |
| Not applicable | FA4 (Hopper-only; box is Ada RTX 4070); vision `max_soft_tokens` 280->1120 is a `parameters.md` concern, not a template one |

**Actions:**

- Confirm first (cheap, no download): read the 2026-07-17 HF commit metadata for all 3 QAT repos (12B `980b060` = template update; verify `26B-A4B` + `31B` carry the same) *before* the multi-GB pulls.
- Then re-pull + re-pin each `FROM` to the confirmed 2026-07-17 snapshot (AGENTS.md two-step: `hf download`, then edit `FROM`).
- Re-run the Gemma MTP drafter (`mtp-gemma-4-*.gguf`) load check after re-pull (pin-and-recheck rule); a re-quant can move the drafter file. Which engine serves the Gemma MTP lane (stock vs Ollama) is `specs/llamacpp-serving`'s call (eval: stock) - the template re-pull applies either way.

## Qwen 3.5/3.6 - the guard is the official default

### Correction to AGENTS.md:52

Present verbatim in official `Qwen/Qwen3.6-27B/chat_template.jinja` (only commit: Apr-22 upload):

```jinja
{%- if message.role == "system" %}
    {%- if not loop.first %}
        {{- raise_exception('System message must be at the beginning.') }}
```

`unsloth`'s Qwen3.6-27B / 3.5-9B-MTP GGUFs patched it out (`merged_system`: merges up to 2 leading system messages, skips the rest). Because the guard is the *official* default, every future Qwen pull re-inherits it - so the fix is a rule, not a one-off.

### Fleet gate state (on-box `ollama show --template`; guard = literal `System message must be at the beginning`)

| Served model(s) | Tier | Template state | OpenAI-lane multi-system |
|---|---|---|---|
| unsloth Qwen3.6-27B + 35B-A3B (all), Qwen3.5-9B-MTP | third-party | `merged_system` patch | passes; **silently drops** 3rd+/mid-convo system |
| unsloth Qwen3.5-9B-coding-ud (non-MTP) | third-party | **guard** | **400** |
| OBLITERATUS Qwen3.6-27B (`obliterated`, `-coding`) | community | **guard (GGUF-embedded-confirmed)** | **400** |
| mradermacher Queen-27B (`coding`, `reasoning`) | community | **guard (GGUF-embedded-confirmed)** | **400** |
| Jackrong qwopus3.5-9B | community | Go template (consolidated `.System`) | passes |

Extends `2026-07-17-llamacpp-eval.md` s4: that guard scan covered the served coding/MTP + Gemma fleet (Qwen3.5-9B-MTP, Gemma 12B/26B, Qwen3.6-27B plain+MTP, 35B-A3B) and found them clean, but did not scan the uncensored community track - OBLITERATUS-27B and Queen-27B carry the guard.

### The family-wide rule (durable fix)

- **Rule:** any Qwen 3.5/3.6 GGUF served to an OpenAI-protocol client (Open WebUI, `/v1/chat/completions`) runs under a guard-free template - `--chat-template-file froggeric` (or equivalent with arbitrary-system-message support). Do not wait for an official Qwen fix; official *is* the guard.
- **Anthropic lane:** no rule needed (immune).
- **First application:** the guarded rows in the fleet table above.
- `merged_system` (unsloth 3.6 / 3.5-MTP) already satisfies the rule, at the cost of silently dropping extra system turns (fidelity caveat).

### The fix: `froggeric/Qwen-Fixed-Chat-Templates` (v21.3, Apache-2.0, 07-02)

| Fix | Relevance here |
|---|---|
| "native support for arbitrary system messages" (removes guard) | OpenAI-lane multi-system compat |
| Anthropic `message.thinking` support | Claude Code reasoning payloads |
| minijinja / C++-safe | llama.cpp, LM Studio, MLX |
| 100% prefix-KV-cache, two-tier agentic error escalation, payload truncation | agentic-loop quality on Qwen coders |

- Install (target lane): `llama-server --jinja --chat-template-file chat_template.jinja` - one file for all Qwen 3.5/3.6 variants, no GGUF surgery. Ships `scripts/minify_jinja.py` + `scripts/test_v21.py`.
- **Validate once per (template, build)** - not per model: run `test_v21.py` + a multi-system + tool-loop smoke on the target llama.cpp build (minijinja != Python Jinja). Per-model is then just launch + one smoke.

## Vetting gate - replace `ollama show --template`

| Problem | Evidence |
|---|---|
| Blind for Gemma | returns 13-byte `{{ .Prompt }}` stub for every Gemma model |
| Shows non-executing template | eval: Ollama does not execute the GGUF Jinja; prints Jinja for some, Go for others |
| Ollama-specific | irrelevant post-migration |

**Replacement (llama.cpp lane), cheapest-first:**

- **Static, per GGUF:** `grep` the GGUF `tokenizer.chat_template` metadata for the `raise_exception` guard (the check this research used). Skip a full source diff - comment-stripping makes it noisy and the smoke supersedes it.
- **Behavioural, per GGUF:** one multi-system `/v1/chat/completions` smoke (records OpenAI-lane exposure), against an already-resident model - never cold-load under VRAM pressure.
- **Once per llama-server build:** one `/v1/messages` multi-system smoke - Anthropic immunity is a build property, not per-GGUF, so it need not repeat per model.
- Reference from `specs/stack-upkeep` ("template gate for new GGUFs").

## Corrections to existing docs

| Doc | Says | Reality (this pass) |
|---|---|---|
| AGENTS.md:52 | canonical Qwen3.6 lacks the guard; only HauhauCS added it | guard is the **official** Qwen default; unsloth 3.6 / 3.5-MTP are the patched exceptions |
| AGENTS.md:52 | Ollama `/v1` executes GGUF Jinja; fix only by patching metadata | eval: Ollama does **not** execute GGUF Jinja; target-lane fix is `--chat-template-file` |
| AGENTS.md:54 (+ CLAUDE.md claude-local note) | vet with `ollama show --template` | blind for Gemma; shows non-executing template -> replace |
| llamacpp-eval s4 | no other fleet GGUF has the guard | scan covered the coding/MTP + Gemma fleet only; OBLITERATUS-27B + Queen-27B (uncensored track) also carry it (embedded-confirmed) |

## Acceptance

- [ ] All 3 Gemma QAT Modelfiles `FROM` a confirmed 2026-07-17 snapshot; MTP drafter load check re-run and passing.
- [ ] Family-wide OpenAI-lane rule in force: each guarded Qwen GGUF facing an OpenAI-protocol client runs a guard-free template (validated froggeric or `merged_system`), or is documented Anthropic-lane-only.
- [ ] `ollama show --template` removed from the vetting rule; replaced by the grep + dual-path smoke above, referenced from `specs/stack-upkeep`.
- [ ] AGENTS.md gate section (:48-54) rewritten per the Corrections table; a dated correction note appended to `2026-07-17-llamacpp-eval.md` s4 narrowing the scan scope (log left otherwise intact).

## Sources

- Repo: `AGENTS.md` (:48-54), `README.md`, `docs/history/2026-07-17-llamacpp-eval.md` (s4 lane immunity + guard scan), `docs/history/2026-06-23-uncensored-models.md` (gate origin).
- Official: [`google/gemma-4-12B-it`](https://huggingface.co/google/gemma-4-12B-it), [`Qwen/Qwen3.6-27B`](https://huggingface.co/Qwen/Qwen3.6-27B); Google Gemma 4 update announcement (@googlegemma, 2026-07-15).
- Third-party: [`unsloth/gemma-4-12B-it-qat-GGUF`](https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF) (`980b060`), `-26B-A4B-`, `-31B-`; [Unsloth changelog](https://unsloth.ai/docs/new/changelog).
- Community fix: [`froggeric/Qwen-Fixed-Chat-Templates`](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates).
- Ollama template mechanism: [`ollama/ollama#10222`](https://github.com/ollama/ollama/issues/10222).
- On-box: `ollama show --template` fleet scan; `head -c 25MB | grep` of OBLITERATUS-27B + Queen-27B GGUF headers (guard embedded-confirmed).

## Caveats (validity)

- **Ollama-lane guard behaviour is contested, unconfirmed here:** the 2026-06-23 HauhauCS log says it fired; the eval says Ollama does not execute the GGUF Jinja (so it should not). Not smoked this session (live multi-system request abandoned - cold-loading under VRAM pressure is the host-crash exposure). Moot once Ollama is dropped.
- **26B-A4B / 31B re-pull assumes** their 2026-07-17 commit is the template update - the Gemma action confirms this before re-pinning (12B confirmed).
- **froggeric is large/complex** - the per-(template, build) validation above is the gate; do not adopt blind.
