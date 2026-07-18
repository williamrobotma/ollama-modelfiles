# Chat-template refresh: Gemma 4 & Qwen 3.5/3.6

- **Status:** RESEARCH COMPLETE - actions ready, not yet executed. Captured 2026-07-17.
- **Scope:** recently fixed/updated chat templates for the `gemma4`, `qwen3.5`, `qwen3.6` families, mapped to serving-stack actions.
- **Goal frame:** complete the stock-llama.cpp migration, drop Ollama (`specs/llamacpp-serving`). Recommendations target the llama.cpp lane first.
- **Method:** templates + commits read live from Hugging Face; fleet gate state read on-box, read-only (`ollama show --template`, GGUF-header `grep`); **no inference run**.
- **Author ladder (which fix to prefer):** official (Google, Qwen team) -> third-party (unsloth, ggml-org) -> community (froggeric, OBLITERATUS, mradermacher, Jackrong). Do not stop at official.

## TL;DR

- **Gemma 4:** official template fix shipped 2026-07-15; unsloth re-quantized all 3 QAT repos 2026-07-17. Repo pins a Jun-10 snapshot -> **re-pull + re-pin**. No gate impact (Gemma has no guard).
- **Qwen:** the `System message must be at the beginning` guard is the **official Qwen default** (corrects AGENTS.md:52), embedded in 5 fleet GGUFs incl. the uncensored community track.
- **Lane decides urgency:** on the migration target, the Anthropic `/v1/messages` lane is **immune**; only the **OpenAI / Open WebUI lane 400s**. So the guard is an OpenAI-lane concern, not a claude-local one.
- **`froggeric/Qwen-Fixed-Chat-Templates`** removes the guard + adds agentic/KV-cache/Anthropic-thinking fixes; drop-in via `--chat-template-file`. Treat as quality + OpenAI-lane compat, not a hotfix.
- **Vetting gate** (`ollama show --template`) is unreliable and Ollama-specific -> replace for the llama.cpp lane.

## Lane model (which client path executes which template)

| Lane | System reaches template as | Guard fires? | Used by |
|---|---|---|---|
| Anthropic `/v1/messages` (stock llama-server) | top-level param -> single leading system turn; `messages[]` cannot hold system roles | **No** - immune (on-box: 2-block system accepted) | claude-local replacement |
| OpenAI `/v1/chat/completions` (stock llama-server `--jinja`) | passed through; a non-first system triggers the guard | **Yes** - 400 (verified on-box) | Open WebUI, OpenAI clients |
| Ollama `/v1` (legacy, retiring) | Ollama does not execute the GGUF Jinja (Go conversion) | Contested - moot (see Corrections) | today's claude-local + Open WebUI |

Source for the first two rows: on-box, `docs/history/2026-07-17-llamacpp-eval.md` s4.

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

- Re-pull + re-pin all 3 Gemma QAT repos (`12B`, `26B-A4B`, `31B`) to their 2026-07-17 snapshots (AGENTS.md two-step: `hf download`, then edit `FROM`). Confirm the `26B-A4B`/`31B` commits carry the template update before re-pinning.
- Re-run the Gemma MTP drafter (`mtp-gemma-4-*.gguf`) load check after re-pull (pin-and-recheck rule); a re-quant can move the drafter file.
- Per the eval, serve the Gemma MTP lane on stock llama-server (graphs-on, capped ctx), not Ollama's crashing `DRAFT` lane - record in `specs/llamacpp-serving`, which owns the lane decision.

## Qwen 3.5/3.6 - state and action

### The guard is the official default (corrects AGENTS.md:52)

Present verbatim in official `Qwen/Qwen3.6-27B/chat_template.jinja` (only commit: Apr-22 upload):

```jinja
{%- if message.role == "system" %}
    {%- if not loop.first %}
        {{- raise_exception('System message must be at the beginning.') }}
```

`unsloth`'s Qwen3.6-27B / 3.5-9B-MTP GGUFs are the exception - they replaced it with a `merged_system` block (merges up to 2 leading system messages, skips the rest).

### Fleet gate state (on-box `ollama show --template`; guard = literal `System message must be at the beginning`)

| Served model(s) | Tier | Template state | OpenAI-lane multi-system |
|---|---|---|---|
| unsloth Qwen3.6-27B + 35B-A3B (all), Qwen3.5-9B-MTP | third-party | `merged_system` patch | passes; **silently drops** 3rd+/mid-convo system (fidelity, not a gate issue) |
| unsloth Qwen3.5-9B-coding-ud (non-MTP) | third-party | **guard** | **400** |
| OBLITERATUS Qwen3.6-27B (`obliterated`, `-coding`) | community | **guard (GGUF-embedded-confirmed)** | **400** |
| mradermacher Queen-27B (`coding`, `reasoning`) | community | **guard (GGUF-embedded-confirmed)** | **400** |
| Jackrong qwopus3.5-9B | community | Go template (consolidated `.System`) | passes |

Corrects `llamacpp-eval` s5 scope - see Corrections.

### Community fix: `froggeric/Qwen-Fixed-Chat-Templates` (v21.3, Apache-2.0, 07-02)

| Fix | Relevance here |
|---|---|
| "native support for arbitrary system messages" (removes guard) | OpenAI-lane multi-system compat |
| Anthropic `message.thinking` support | Claude Code reasoning payloads |
| minijinja / C++-safe | llama.cpp, LM Studio, MLX |
| 100% prefix-KV-cache, two-tier agentic error escalation, payload truncation | agentic-loop quality on Qwen coders |

- Install (target lane): `llama-server --jinja --chat-template-file chat_template.jinja` - no GGUF surgery.
- Ships `scripts/minify_jinja.py` (one-line form) + `scripts/test_v21.py` (test suite).

**Actions (lane-aware):**

- **Anthropic lane (claude-local replacement):** no guard action needed. Optional: adopt froggeric for the agentic/KV-cache/thinking wins on Qwen coders.
- **OpenAI lane (Open WebUI + other `/v1/chat/completions` clients):** front every guarded model (current set: fleet-gate table; the guard is the family default, so future Qwen pulls inherit this rule) with `--jinja --chat-template-file froggeric`. Validate once per (template, llama.cpp build) pair - `test_v21.py` + a multi-system + tool-loop smoke (minijinja differs from Python Jinja); per-model check is then just launch + one request.

## Vetting gate - replace `ollama show --template`

| Problem | Evidence |
|---|---|
| Blind for Gemma | returns 13-byte `{{ .Prompt }}` stub for every Gemma model |
| Shows non-executing template | prints Jinja for some, Go for others; none of it executes (see lane model) |
| Ollama-specific | irrelevant post-migration |

**Replacement (llama.cpp lane):**

- Read the shipped template directly: dump the GGUF `tokenizer.chat_template` metadata and `grep` for `raise_exception` (the method used for this scan); diff vs the source `chat_template.jinja` only when debugging (comment-stripping makes the diff noisy).
- Gate by behaviour on the served build: one multi-system request on `/v1/chat/completions` per new GGUF (records OpenAI-lane exposure), against an already-resident model - never cold-load under VRAM pressure. Check `/v1/messages` immunity once per llama-server build upgrade, not per model (it is structural, not per-GGUF).
- Home: the rewritten AGENTS.md chat-template-gate section (one edit together with the Corrections below); `specs/stack-upkeep` references it.

## Corrections to existing docs

| Doc | Says | Reality (this pass) |
|---|---|---|
| AGENTS.md:52 | canonical Qwen3.6 lacks the guard; only HauhauCS added it | guard is the **official** Qwen default; unsloth 3.6 / 3.5-MTP are the patched exceptions |
| AGENTS.md:52 | Ollama `/v1` executes GGUF Jinja; fix only by patching metadata | eval: Ollama does **not** execute GGUF Jinja; target-lane fix is `--chat-template-file` |
| AGENTS.md:54 | vet with `ollama show --template` | blind for Gemma; shows non-executing template -> replace |
| llamacpp-eval s5 | no other fleet GGUF has the guard | scan covered only coding/MTP set; OBLITERATUS-27B + Queen-27B also carry it (embedded-confirmed) |

## Acceptance

- [ ] All 3 Gemma QAT Modelfiles `FROM` a 2026-07-17 snapshot; MTP drafter load check re-run and passing.
- [ ] Each guarded Qwen model that faces an OpenAI-protocol client is either fronted by a validated froggeric template or documented as Anthropic-lane-only.
- [ ] AGENTS.md chat-template-gate section (currently :52/:54) rewritten in one pass: `ollama show --template` dropped, GGUF-`chat_template` dump/grep + OpenAI-lane smoke in its place, Corrections folded in; referenced from `specs/stack-upkeep`.
- [ ] `llamacpp-eval` s5 scope corrected by a dated appended note (history logs are immutable - no inline edits).

## Sources

- Repo: `AGENTS.md` (:48-54), `README.md`, `docs/history/2026-07-17-llamacpp-eval.md` (s4 lane immunity; s5 guard scan), `docs/history/2026-06-23-uncensored-models.md` (gate origin).
- Official: [`google/gemma-4-12B-it`](https://huggingface.co/google/gemma-4-12B-it), [`Qwen/Qwen3.6-27B`](https://huggingface.co/Qwen/Qwen3.6-27B); Google Gemma 4 update announcement (@googlegemma, 2026-07-15).
- Third-party: [`unsloth/gemma-4-12B-it-qat-GGUF`](https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF) (`980b060`), `-26B-A4B-`, `-31B-`; [Unsloth changelog](https://unsloth.ai/docs/new/changelog).
- Community fix: [`froggeric/Qwen-Fixed-Chat-Templates`](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates).
- Ollama template mechanism: [`ollama/ollama#10222`](https://github.com/ollama/ollama/issues/10222).
- On-box: `ollama show --template` fleet scan; `head -c 25MB | grep` of OBLITERATUS-27B + Queen-27B GGUF headers (guard embedded-confirmed).

## Caveats

- **Ollama-lane guard behaviour is contested, unconfirmed here:** 2026-06-23 HauhauCS log says it fired; the eval says Ollama does not execute the Jinja. Not smoked this session (live multi-system request abandoned - cold-loading under VRAM pressure is the host-crash exposure). Moot once Ollama is dropped.
