# llamacpp/ - the serving stack

One stock `llama-server` process runs in router mode on `127.0.0.1:11433`.
It reads the fleet from `models.ini` and starts one child server per model, on demand.
Only one child is resident at a time (`--models-max 1`): requesting another model evicts the current one.
A child that sits idle for 24 h is put to sleep.
Router mode is stock llama.cpp (`--models-preset`); the preset behaviors quoted below come from its source.
The migration that built this stack is `specs/llamacpp-migration`.

## Layout

- `launch.sh` - starts the router; owns the build record (which llama.cpp build is on disk, and its test state).
- `models.ini` - the fleet: one `[section]` per served model; the `[*]` section holds defaults merged into every entry.
- `templates/` - the vendored froggeric chat template guarded GGUFs serve under (provenance: `templates/README.md`).
- `mcp/` - the web-search MCP server claude-local loads (provenance + wiring: `mcp/README.md`).

## Ids and aliases

An id is the model name a client sends, and it names the entry, not the quant (decided 2026-08-09).
The grammar is defined here; other files point to this section.

- Shape: `<family>[-finetune]-<size>[-variant][-mtp][-profile]`; a blank profile means instruct.
  - `qwen3.6-27b-mtp-coding` - family `qwen3.6`, size `27b`, MTP lane, coding profile.
    - MTP = multi-token prediction, the speculative-decoding lanes (docs/architecture.md section 3).
  - `gemma4-12b-it-qat-mtp` - upstream variant tokens (`it-qat`) keep their upstream spot: after the size.
  - `qwen3.5-queen-27b` - a finetune name (`queen`) sits before the size.
- The quant appears only in the `model =` path, so promoting a new quant is a path edit: no rename, no client churn.
- Softened 2026-08-12 (user): where two separately released builds of one model would otherwise collide, the
  token that tells them apart goes in the id.
  - It rides the `[-variant]` slot, and the file-level quant still stays in the `model =` path.
  - `bonsai-27b-ternary` and `bonsai-27b` - two PrismML repos, different weights, different published quality.
  - This disambiguates releases. It does not license tagging a packaging choice such as `q5` vs `q6`.

An alias is a second name for an entry, written as a key on the entry that owns it:

```ini
[qwen3.6-35b-a3b-mtp-coding]
alias = qwen3.6-35b-a3b-coding
```

- Aliases exist only to give a profile a default entry; the fleet's one alias is the example above.
- Request bodies resolve aliases, but `/v1/models` lists canonical ids only - point UI pickers at canonical ids.
- Never set an alias equal to its own section name: the router skips that silently.
  - A collision with another entry's name or alias is loud instead: startup throws, reload warns and skips.

## Which chat template each entry runs

A chat template is the recipe baked into each GGUF that turns the message list into the model's prompt text.
Some community Qwen GGUFs bake in a template that rejects any request where a `system` message is not first.
That rejection is the "guard", named for its error text: `raise_exception('System message must be at the beginning.')`.
Guarded GGUFs are served under a working replacement template instead, via a per-entry `chat-template-file`.
How to vet a new GGUF is the AGENTS.md chat-template gate.
Which (template, build) pairs passed vetting is recorded in `templates/README.md`.

Guarded GGUFs, served under the froggeric replacement:

- unsloth Qwen3.5-9B non-MTP.
- mradermacher Queen-27B - one GGUF behind all three `qwen3.5-queen-27b*` entries.

`merged_system` GGUFs - their template silently drops mid-conversation `system` messages; they get no override:

- unsloth Qwen3.5-9B-MTP.
- Qwen3.6: 27B, 27B-MTP, 35B-A3B, 35B-A3B-MTP.
- Accepted 2026-08-08: no current client sends mid-conversation system messages, so nothing is dropped today.

## Add a model

1. Download: `hf download ORG/REPO file.gguf`.
2. Add a `[section]` to `models.ini`, named per the id grammar above.
   - `model =` the absolute HF-cache snapshot path (never a bare repo id).
   - Sampling values and ctx-size: copy the matching profile from `docs/parameters.md`.
   - `[*]` already carries the fleet-wide keys; add only what the entry owns (ctx-size, temp, top-k, paths).
3. Vet the embedded chat template (AGENTS.md gate); a guarded GGUF gets `chat-template-file = <froggeric path>`.
4. MTP entry: add `spec-type = draft-mtp` and `spec-draft-n-max = 2`; Gemma also needs its drafter as `model-draft =`.
   - Vision goes as `mmproj =` (the vision-projector GGUF) on the non-MTP sibling only
     (the MTP x vision split: docs/parameters.md).
5. Restart with `launch.sh`; confirm `/props?model=<id>` reports the profile values and one generation succeeds.

Preset behaviors to know while editing (from llama.cpp source; line numbers drift across builds):

- Values are stored literally (`preset.options[opt] = value;`, `common/preset.cpp:322`): no `~` or env expansion.
  - The absolute `model =` and template paths must be re-edited if the repo is cloned to another machine.
- The router's CLI args "overlay ... on top of every model preset" (`tools/server/server-models.cpp:548`).
  - A CLI `--chat-template-file` would therefore hit the whole fleet; per-entry keys are the only per-entry mechanism.
