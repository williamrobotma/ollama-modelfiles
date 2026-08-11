# llamacpp/ - router config home

llama-server router-mode config for the whole local fleet on `127.0.0.1:11433` (`specs/llamacpp-migration`).
One router process; children spawn per entry on demand and sleep after 24 h idle.

## Layout

- `launch.sh` - launcher: absolute `build/bin` path, `LLAMA_CACHE` redirect, and the build record (its single home)
- `models.ini` - the fleet, one `[section]` per config
- `templates/` - froggeric v21.3 `chat_template.jinja` for guarded GGUFs (provenance in `templates/README.md`)
- `mcp/` - vendored web-search MCP server for claude-local, run via pipx (provenance in `mcp/README.md`)

## Naming and alias policy

- An id names the lane, never the quant (2026-08-09). Grammar (this is its single home; other docs point here):
  - `<family>-<size>[-mtp][-profile]`, blank profile = instruct (e.g. `qwen3.6-27b-mtp-coding`, `qwen3.6-35b-a3b`).
  - Variant tokens keep their upstream placement: Gemma's `it-qat`/`it-heretic` sit after the size, before `-mtp`
    (`gemma4-12b-it-qat-mtp`); a finetune name precedes the size (`qwen3.5-queen-27b-coding`).
  - The quant lives in the `model =` path alone, so promoting a new quant is a path edit: no rename, no client churn.
- An alias is an `alias =` key on its owning entry (comma-separated for several); request bodies resolve it.
  - Aliases now exist only for profile defaults; the fleet has one (`qwen3.6-35b-a3b-coding` -> the MTP coding lane).
  - An alias must never equal *its own* section name: that self-collision is silently ignored (reload skips self).
    - A collision with another entry's name or alias is loud instead - startup throws, reload warns and skips.
- `/v1/models` lists canonical ids only, so `.data[].id` pickers never show aliases; point UI clients at canonical ids.

## Chat-template exposure (fleet inventory)

- Guarded GGUFs (embedded guard, served under the froggeric override): unsloth Qwen3.5-9B non-MTP and
  mradermacher Queen-27B - the GGUFs backing the `chat-template-file` entries.
- `merged_system` carriers (silently drop mid-conversation system messages; no override - accepted 2026-08-08,
  no client sends them): unsloth Qwen3.5-9B-MTP + Qwen3.6 27B, 27B-MTP, 35B-A3B, 35B-A3B-MTP.
- Vet procedure: the AGENTS.md chat-template gate; validated (template, build) pairs: `templates/README.md`.

## Add a model

1. `hf download` into the HF cache; use the pinned snapshot path in `model =` (never a bare repo id).
2. New `[section]` named per the grammar above: profile sampling + ctx from `docs/parameters.md`.
   Keys the `[*]` section already carries (min-p, n-predict, penalties, top-p) need only per-entry overrides.
3. Vet the embedded chat template per the AGENTS.md chat-template gate; guarded -> `chat-template-file` froggeric.
   - Preset values get no interpolation (`common/preset.cpp:304-330`): the path is a literal absolute string.
     - Cloning to another machine means hand-editing the guarded entries' paths.
   - A CLI `--chat-template-file` is no per-entry fix: base CLI args merge into every entry (`server-models.cpp:551`).
     - It would force one template onto the whole fleet, not just the guarded entries.
4. MTP lane: `spec-type = draft-mtp` + `spec-draft-n-max = 2` (+ `model-draft` for Gemma drafters).
   Vision: `mmproj` on the non-MTP entry only (split policy: docs/parameters.md).
5. Spot-load via `launch.sh`: `/props?model=` matches the profile, one generation OK.
