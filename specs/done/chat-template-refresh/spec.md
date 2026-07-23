# Chat-template refresh: Gemma 4 & Qwen 3.5/3.6

## Status and framing

- Status: research complete, actions ready, not yet executed. Captured 2026-07-17.
- Prerequisite (met): PR #9 (`feat/llamacpp-serving`) merged 2026-07-18. The files this spec cites - `docs/history/2026-07-17-llamacpp-eval.md` and `specs/stack-upkeep/` - are now on `main`, so the references resolve once this bundle merges.
- Scope: chat templates that were recently fixed or updated for the `gemma4`, `qwen3.5`, and `qwen3.6` model families, and the concrete serving actions they imply.
- Goal it serves: finishing the move from Ollama to stock llama-server. That migration is planned in `specs/llamacpp-migration` (the "option B" execution bundle, following the 2026-07-17 eval verdict). Recommendations here target the llama-server path first.
- How the facts were gathered: templates and commit history read live from Hugging Face; each installed model's template read on-box, read-only, with `ollama show --template` and by grepping the GGUF file headers. No model was loaded and no inference was run.
- Preference order for whose fix to adopt when more than one exists: the model's own authors first (Google, the Qwen team), then the packager (unsloth, or llama.cpp itself), then community authors (froggeric, OBLITERATUS, mradermacher, Jackrong). Do not stop at the official source - a community fix is sometimes the only one.

## Terms used below

- The guard: a line inside some chat templates that raises an error whenever a `system` message is not the first message. On the OpenAI endpoint this returns HTTP 400, so the request fails.
- The two endpoints llama-server exposes:
  - Anthropic endpoint, `/v1/messages` - the one a claude-local (Claude Code) replacement uses.
  - OpenAI endpoint, `/v1/chat/completions` - the one Open WebUI and other OpenAI-style clients use.
- GGUF: the model file. It carries its own chat template embedded inside it.
- `merged_system`: the name of unsloth's edited template that combines the leading system messages instead of rejecting a later one.

## Which endpoint the guard affects

- Anthropic endpoint (`/v1/messages`, stock llama-server):
  - The server combines all system content into one system message at the front before the template runs, and its `messages` list cannot contain `system` entries.
  - So a non-first system message never reaches the template, and the guard never fires.
  - This holds no matter which template the GGUF carries - it is a property of the llama-server build, not of the model. Confirmed on-box by sending a system value made of two blocks.
- OpenAI endpoint (`/v1/chat/completions`, stock llama-server run with `--jinja`):
  - System messages are passed to the template as-is.
  - A guarded template raises on the first system message that is not at the front, returning HTTP 400. Confirmed on-box.
- Ollama's endpoint (the path being retired):
  - Ollama does not run the GGUF's own Jinja template at all; it converts it to a Go template. So the guard does not fire there. (See Corrections and Caveats - this contradicts the current AGENTS.md.)
- Source for the first two points: on-box testing in `docs/history/2026-07-17-llamacpp-eval.md`, section 4.
- Consequence: the guard only breaks the OpenAI endpoint (Open WebUI and similar). A claude-local replacement on the Anthropic endpoint is unaffected.

## Gemma 4: re-pull the updated template

What changed:

- Google published a fixed Gemma 4 chat template on 2026-07-15: tool-calling bugs fixed, "smoother" conversational formatting, and fewer truncated answers ("less laziness"). The file `google/gemma-4-12B-it/chat_template.jinja` carries the header date `Published: 2026-07-09`, and its latest change is commit `#35` (around 07-15).
- unsloth re-quantized all three QAT GGUF repos on 2026-07-17 to include it: the 12B repo's commit `980b060` is titled "Added Gemma official chat template update", and the `26B-A4B` and `31B` repos show a same-day update.

Where this repo stands:

- The Modelfiles pin the `7102bde` snapshot from Jun-10, which predates the fix, so it is stale. (Judge currency by the commit date, not by the template's header comment - the header comment is stripped out of the embedded GGUF template.)
- Gemma has no guard: its `<|turn>` template format renders repeated or non-first system messages with no error. So Gemma is safe on both endpoints regardless.

Actions:

- Confirm before downloading (this is free): read the 2026-07-17 commit metadata for all three QAT repos. The 12B commit `980b060` is the template update; check that the `26B-A4B` and `31B` commits are the same kind of change before spending the multi-gigabyte download.
- Then re-pull and re-pin: `hf download` each repo, then edit each `FROM` line to the confirmed 2026-07-17 snapshot path (the two-step in AGENTS.md).
- After re-pulling, re-run the Gemma MTP drafter (`mtp-gemma-4-*.gguf`) load check - a re-quantization can move the drafter file. Which engine actually serves the Gemma MTP models (stock llama-server vs Ollama) is decided in `specs/llamacpp-migration` (its "Do now" step: serve them from stock llama-server); the template re-pull is needed either way.
- Not relevant here: FA4 (it is for Hopper GPUs; this box is an Ada RTX 4070), and the vision `max_soft_tokens` change (280 to 1120) is a sampling/parameters concern, not a chat-template one.

## Qwen 3.5 / 3.6: the guard is Qwen's own default

The guard is in the official template, not a community mistake:

- It is present verbatim in the official `Qwen/Qwen3.6-27B/chat_template.jinja` (whose only commit is the Apr-22 upload):

```jinja
{%- if message.role == "system" %}
    {%- if not loop.first %}
        {{- raise_exception('System message must be at the beginning.') }}
```

- unsloth's Qwen3.6-27B and Qwen3.5-9B-MTP GGUFs are the exception: they replaced it with a `merged_system` block that merges up to two leading system messages and skips any others.
- Because the guard is the official default, every future Qwen pull will carry it again. So the fix has to be a standing rule, not a one-time patch of specific files.

Which installed models have the guard (from `ollama show --template`; "the guard" = the literal string `System message must be at the beginning`):

- Has the guard, so returns 400 on the OpenAI endpoint:
  - `qwen3.5-9b-coding-ud` (non-MTP) - unsloth, a third-party build.
  - `qwen3.6-27b-obliterated` and `qwen3.6-27b-obliterated-coding` - OBLITERATUS, community. Confirmed present inside the GGUF file.
  - `qwen3.5-queen-27b-coding` and `qwen3.5-queen-27b-reasoning` - mradermacher, community. Confirmed present inside the GGUF file.
- No guard, passes:
  - All unsloth Qwen3.6-27B and Qwen3.6-35B-A3B models, and unsloth Qwen3.5-9B-MTP - they use the `merged_system` template. It avoids the 400 but silently drops a third or a mid-conversation system message.
  - `qwopus3.5-9b-coder` - Jackrong, community. Ollama serves it with a Go template that merges the system text.
    - Correction (2026-07-23, execution): the GGUF itself carries the guard.
      - The "clean" reading came from `ollama show --template` showing the Go conversion.
      - Moved to the guarded set and validated under froggeric (`docs/history/2026-07-23-chat-template-refresh.md`).
- This extends the eval's finding (`docs/history/2026-07-17-llamacpp-eval.md`, section 4): that scan checked the coding/MTP and Gemma models (Qwen3.5-9B-MTP, Gemma 12B and 26B, Qwen3.6-27B plain and MTP, Qwen3.6-35B-A3B) and found them clean, but it did not scan the uncensored community models - OBLITERATUS-27B and Queen-27B also carry the guard.

The standing rule (the durable fix):

- Rule: any Qwen 3.5 or 3.6 GGUF served to an OpenAI-style client (Open WebUI, or any `/v1/chat/completions` caller) must run under a guard-free template - `--chat-template-file` pointing at froggeric's template, or any template that accepts system messages anywhere. Do not wait for an official Qwen fix: the official template is the guard.
- The Anthropic endpoint needs no rule (the guard cannot fire there).
- First application of the rule: the guarded models listed above.
- This extends step 3 of `specs/llamacpp-migration`, which scopes the multi-system fix to only the single unsloth Qwen3.5-9B (because it inherited the eval's coding/MTP-only scan). The guarded set is larger than that, and the fix is this family-wide rule.
- The `merged_system` models (unsloth 3.6 and 3.5-MTP) already satisfy the rule, but at the cost of silently dropping the extra system messages - acceptable for avoiding the 400, worth knowing when fidelity matters.

The fix to adopt - `froggeric/Qwen-Fixed-Chat-Templates` (version 21.3, Apache-2.0, dated 07-02). What it fixes that matters here:

- Adds "native support for arbitrary system messages" - this is what removes the guard and lets the OpenAI endpoint accept more than one system message.
- Adds support for Anthropic `message.thinking` payloads - relevant to Claude Code's reasoning content.
- Is written to be safe on minijinja / C++ engines - llama.cpp, LM Studio, and MLX (it avoids Python-only Jinja features).
- Also carries quality fixes for agentic use on the Qwen coders: a 100% prefix-KV-cache hit rate, a two-tier agentic error-escalation, and tool-response payload truncation.
- How to use it (on the llama-server path): `llama-server --jinja --chat-template-file chat_template.jinja`. It is one file that covers all Qwen 3.5 and 3.6 variants, and it needs no editing of the GGUF. The repo ships `scripts/minify_jinja.py` and `scripts/test_v21.py`.
- Validate it once per (template, build) pair, not once per model: run `test_v21.py` plus one request that has more than one system message and a tool loop, on the exact llama.cpp build you serve with (minijinja behaves differently from Python's Jinja). After that passes, adding a new model is just launching it and sending one request.

## Vetting a template: replace `ollama show --template`

Why the current check (`ollama show --template <model>`, per AGENTS.md) is not reliable:

- It is blind for Gemma: it returns a 13-byte `{{ .Prompt }}` stub for every Gemma model, which tells you nothing about the real template.
- It shows a template that is not the one that runs: the eval found Ollama does not execute the GGUF's Jinja at all; `ollama show` prints Jinja for some models and a converted Go template for others.
- It is specific to Ollama, which is being retired anyway.

The replacement (on the llama-server path), in order of cost, cheapest first:

- Static, once per GGUF: grep the GGUF's `tokenizer.chat_template` metadata for the `raise_exception` guard (the same check this research used). Do not bother diffing against the source template - the embedded copy is comment-stripped, so a diff is noisy, and the behavioural test below supersedes it.
- Behavioural, once per GGUF: send one request that has more than one system message to `/v1/chat/completions` and see whether it 400s (this records the OpenAI-endpoint exposure). Use an already-loaded model - never cold-load a model for this while other work holds the GPU.
- Once per llama-server build, not per model: send one multi-system request to `/v1/messages` to confirm the Anthropic endpoint stays immune. That immunity is a property of the build, so it does not need repeating for each model.
- Record this procedure under `specs/stack-upkeep` (its planning item "the check each component must pass before an update is trusted").

## Corrections these findings imply for existing docs

- `AGENTS.md` line 52 says the guard is a non-standard thing that "canonical Qwen3.6 lacks" and only two HauhauCS builds added. Correct version: the guard is the official Qwen default; unsloth's 3.6 and 3.5-MTP builds are the exceptions that removed it.
- `AGENTS.md` line 52 also says Ollama's `/v1` path executes the GGUF's Jinja, so the guard "can only be fixed by patching the GGUF metadata". Correct version: the eval found Ollama does not execute the GGUF Jinja; on the target llama-server path the fix is a `--chat-template-file` flag, with no metadata patching.
- `AGENTS.md` line 54 (and the matching CLAUDE.md claude-local note) says to vet a template with `ollama show --template`. Correct version: that is blind for Gemma and shows a non-executing template - replace it with the procedure above.
- `docs/history/2026-07-17-llamacpp-eval.md`, section 4, says "no other fleet GGUF has the guard". Correct version: that scan covered only the coding/MTP and Gemma models; the uncensored community models OBLITERATUS-27B and Queen-27B also carry the guard (confirmed inside the GGUF files).

## Acceptance (done when)

- All three Gemma QAT Modelfiles have a `FROM` line pointing at a confirmed 2026-07-17 snapshot, and the Gemma MTP drafter load check has been re-run and passes.
- The standing rule is in force: every guarded Qwen GGUF that faces an OpenAI-style client is served under a guard-free template (validated froggeric, or `merged_system`), or is documented as Anthropic-endpoint-only.
- `ollama show --template` is removed from the vetting rule and replaced by the grep-plus-two-endpoint-smoke procedure above, referenced from `specs/stack-upkeep`.
- The `AGENTS.md` gate section (lines 48-54) is rewritten to match the corrections above, and a dated correction note is appended to section 4 of the eval log to narrow its scan-scope claim (the log's original text is left intact - the note is appended, not edited in place).

## Sources

- In-repo: `AGENTS.md` (lines 48-54); `README.md`; `docs/history/2026-07-17-llamacpp-eval.md` (section 4: the endpoint immunity and the guard scan); `docs/history/2026-06-23-uncensored-models.md` (where the gate was first found).
- Official: [`google/gemma-4-12B-it`](https://huggingface.co/google/gemma-4-12B-it); [`Qwen/Qwen3.6-27B`](https://huggingface.co/Qwen/Qwen3.6-27B); the Google Gemma 4 update announcement (@googlegemma, 2026-07-15).
- Third-party: [`unsloth/gemma-4-12B-it-qat-GGUF`](https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF) (commit `980b060`), and the `-26B-A4B-` and `-31B-` repos; the [Unsloth changelog](https://unsloth.ai/docs/new/changelog).
- Community fix: [`froggeric/Qwen-Fixed-Chat-Templates`](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates).
- Ollama template handling: [`ollama/ollama` issue #10222](https://github.com/ollama/ollama/issues/10222).
- On-box, this session: the `ollama show --template` scan across the installed models, and a `head -c 25MB | grep` of the OBLITERATUS-27B and Queen-27B GGUF headers (which confirmed the guard is inside those files).

## Caveats

- Whether the guard ever actually fired under Ollama is unresolved, and was not tested this session. The 2026-06-23 HauhauCS log says it did; the eval says Ollama does not run the GGUF Jinja, so it should not. A live multi-system request was deliberately not sent, because cold-loading a model while llama.cpp holds the GPU is the documented host-crash risk. This is moot once Ollama is dropped.
- The 26B-A4B and 31B re-pull assumes their 2026-07-17 commit is the template update; the Gemma actions confirm this before re-pinning (only 12B is confirmed so far).
- froggeric's template is large and complex. The per-(template, build) validation above is the safeguard - do not adopt it blind.
