# llamacpp/ - router config home

llama-server router-mode config for the whole local fleet on `127.0.0.1:11433` (`specs/llamacpp-migration`).
One router process; children spawn per entry on demand and sleep after 24 h idle.

## Layout

- `launch.sh` - launcher: absolute `build/bin` path, `LLAMA_CACHE` redirect, and the build record (last known good)
- `models.ini` - the fleet, one `[section]` per config
- `templates/` - froggeric v21.3 `chat_template.jinja` for guarded GGUFs (provenance in `templates/README.md`)

## Alias policy

- An alias is an `alias =` key on its owning entry (comma-separated for several); request bodies resolve it.
- `/v1/models` lists canonical ids only, so `.data[].id` pickers never show aliases; point UI clients at canonical ids.

## Add a model

1. `hf download` into the HF cache; use the pinned snapshot path in `model =` (never a bare repo id).
2. New `[section]` named like the fleet (family-size-variant-quant): profile sampling + ctx from `docs/parameters.md`.
   Keys the `[*]` section already carries (min-p, n-predict, penalties, top-p) need only per-entry overrides.
3. Vet the embedded chat template per the AGENTS.md chat-template gate; guarded -> `chat-template-file` froggeric.
4. MTP lane: `spec-type = draft-mtp` + `spec-draft-n-max = 2` (+ `model-draft` for Gemma drafters).
   Vision: `mmproj` on the non-MTP entry only (split policy: docs/parameters.md).
5. Spot-load via `launch.sh`: `/props?model=` matches the profile, one generation OK.
