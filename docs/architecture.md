# Architecture

How the local-LLM stack fits together: HF-cached GGUFs, one llama.cpp router on `127.0.0.1:11433`, four clients.

- Move to local GGUFs: [history/2026-07-10-migration-local-ggufs.md](history/2026-07-10-migration-local-ggufs.md).
- Cutover off Ollama: [the P3 log](history/2026-08-07-llamacpp-p3-cutovers.md).
- Retirement and purge state lives in `specs/llamacpp-migration`, not in this file.

## 1. The big picture - one source of truth, one router

```text
                         Hugging Face Hub (upstream)
                                   |
                                   |  hf download ORG/REPO file.gguf
                                   |  (HF CDN/XET; the OCI bridge is OUT of the loop)
                                   v
              ~/.cache/huggingface/hub/  ..... THE SINGLE LIVE SOURCE
              models--ORG--REPO/
                blobs/<sha256>                 (actual bytes, keyed by LFS oid)
                snapshots/<commit>/<file>.gguf (symlinks; PINNED paths)
                refs/main
                                   |
                                   |  absolute snapshot paths in model = / model-draft = / mmproj =
                                   v
              llamacpp/models.ini  ..... THE ONLY MAPPING LAYER
                                   |
                                   |  llamacpp/launch.sh -> llama-server --models-preset (router mode)
                                   v
              router on 127.0.0.1:11433: stock llama.cpp (build record in launch.sh),
              run from ~/Developer/llama.cpp/build/bin/llama-server
              one child llama-server per served id, spawned on demand

   FROZEN LEGACY (not in the serving path)
              modelfiles/*/*/Modelfile --scripts/ollama-create.sh--> Ollama blob store
              (/usr/share/ollama/.ollama/models)
```

Key property: `llamacpp/models.ini` is the *only* mapping layer.

- Every served model is reproducible from `git clone` + `hf download` + `llamacpp/launch.sh`.
- There is no conversion or import step any more: the child process reads the cached GGUF in place.

Ollama was retired as the serving lane on 2026-08-07: no client points at it any more.

- Its store, binaries, and systemd override are retained on disk until the Phase 4 purge (~2-week validation window).
- Service stop/disable and the purge itself are tracked in `specs/llamacpp-migration`, not here.
- Everything below marked FROZEN LEGACY is retained-not-live in exactly that sense.

## 2. Preset layering (inside the repo)

```text
GLOBAL  [*]  (merged into every child)
  jinja = true, flash-attn = on, cache-type-k/v = q8_0, parallel = 1   <- serving flags
                                                                         (FA + q8_0 stay PAIRED)
  min-p, n-predict, repeat-penalty, top-p, presence-penalty            <- fleet-constant sampling

CANONICAL ENTRY (one [section] per served id; the section name IS the id)
  [gemma4-26b-a4b-it-qat]
      model  = <snapshot>/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf  <- weights
      mmproj = <snapshot>/mmproj-BF16.gguf                        <- vision projector
      ctx-size / temp / top-k                                     <- profile values, override [*]

MTP ENTRY (drafting sibling; carries no mmproj - the MTP x vision split)
  [gemma4-26b-a4b-it-qat-mtp]
      model-draft = <snapshot>/mtp-gemma-4-26B-A4B-it.gguf        <- separate drafter GGUF
      spec-type = draft-mtp, spec-draft-n-max = 2
      spec-draft-ngl = 0                                          <- this entry only: drafter to CPU

ALIAS (a key on its owning entry, never its own section)
  [qwen3.6-35b-a3b-mtp-coding]
      alias = qwen3.6-35b-a3b-coding
```

Ids name the lane, never the quant: the quant lives in the `model =` path only (grammar + rationale: `llamacpp/README.md`).

- The one surviving alias points the unsuffixed coding name at the MTP coding lane.

Aliases resolve inside request bodies but never appear as `/v1/models` ids, so point UI pickers at canonical ids.

- Each entry does carry its `aliases` as a field; the claude-local menu reads it ([AGENTS.md](../AGENTS.md#claude-local)).
- The profile a child actually serves is visible at `/props?model=<id>`; the router's own `/props` returns dummies.
- Guarded GGUFs take `chat-template-file` = the pinned froggeric template in `llamacpp/templates/`.
- Add-a-model procedure and the alias policy: [llamacpp/README.md](../llamacpp/README.md).

FROZEN LEGACY - the Modelfile graph that used to be this mapping layer (see section 1):

- Three layers via `scripts/ollama-create.sh`: canonical (quant-suffixed stem, full parameter block, absolute
  `FROM` path) -> layered/derived (`FROM` a local model name, then overrides - e.g. a coding profile on an MTP
  base, or a `DRAFT` line) -> thin alias (unsuffixed stem, one `FROM <canonical>` line to repoint defaults).
- Canonical files carried weights plus a second `FROM` for the vision projector, which was silently dropped if omitted.

## 3. The two MTP mechanisms (they are not the same thing)

```text
QWEN (self-contained)                      GEMMA (target + drafter)
  one GGUF with embedded MTP tensors         main GGUF + mtp-gemma-4-*.gguf (~250MB)
  spec-type = draft-mtp                      spec-type = draft-mtp + explicit model-draft
  spec-draft-n-max = 2                       spec-draft-n-max = 2
                                             (no auto-discovery: without model-draft the
                                              child dies, "failed to create MTP context")

  Ollama-lane speedups (docs/benchmarking.md): ~1.65x (9B self-draft),
  1.67x (12B pair), 1.54x (26B pair) - measured on the retired lane, not this one.
  Stock b9860 served the Gemma pair at ~1.8x in the 2026-07-17 eval (graphs ON, moderate ctx).

  BOTH now run as router children on stock llama.cpp, CUDA graphs ON fleet-wide.
  #24795 is config-gated, not build-gated: graphs-OFF reproduces the Gemma drafter
  load failure, graphs-ON serves it. Never set GGML_CUDA_DISABLE_GRAPHS on this lane
  (it tests presence only, so even =0 disables; common.cuh:1258).
  P1 (2026-08-03): 36/36 gens across the 12B ctx ladder, 30/30 on the Qwen hammer, 0 crashes.
  26B-A4B exception: its drafter is pinned to CPU (spec-draft-ngl = 0, 241 MiB) because a
  full GPU reports free=0 -> NaN layer split -> devices.at(1) throws
  (llama-model.cpp:1291 at b9860-era source; the line moves across builds).
  Upstream #19973 derived that mechanism and closed unfixed; no fix on master, so a
  rebuild would not help.
```

Per-request MTP acceptance and tok/s show up in the router log's `timings` lines (26B pair 0.62-0.74 at P1).

## 4. Serving layer and its clients

```text
              llamacpp/launch.sh -> llama-server --models-preset llamacpp/models.ini
              user-mode, detached (setsid nohup) - NO daemon, no systemd unit
              --models-max 1               one resident child owns the whole 12 GiB GPU; LRU evicts
              --sleep-idle-seconds 86400   24 h idle, then the child sleeps
              (no launcher env knobs; llama-server itself honors LLAMA_ARG_* env vars,
               common/arg.cpp .set_env - keep them unset; pass flags to launch.sh, last wins)
              LLAMA_CACHE -> an empty dir, so models.ini is the entire served fleet
                                   127.0.0.1:11433
                                        |
        +----------------+--------------+--------------------+------------------------+
        |                |                                   |                        |
   OpenAI /v1/*     OpenAI /v1/*                    Anthropic /v1/messages    Responses /v1/responses
        |                |                                   |                        |
        v                v                                   v                        v
   OPEN WEBUI       OPENCODE 1.16.2                     CLAUDE-LOCAL              CODEX 0.145.0
   0.11.0 on 8080   openai-compatible                   synced script ->          llamacpp-router
   OpenAI conn ->   provider, 13 ids                    lane picked per session   provider, 13 ids
   11433/v1         per-model ctx limits                vendored web-search MCP   fresh threads only
   Ollama conn      no websearch tool                   --disallowedTools=        namespace/web_search
   disabled         exists in this build                WebSearch                 tools DROPPED at 200
```

No inbound auth anywhere: the router checks nothing, and it binds 127.0.0.1, as does Open WebUI on 8080.

- `OLLAMA_API_KEY` is client-side only and now lives in `~/.config/claude-local.env` (mode 600) for the search MCP.
- Every client was cut over and validated against the router on 11433.
  - claude-local, OpenCode, and Codex on 2026-08-04; Open WebUI on 2026-08-07.
- CSRF surface (single home for this analysis; `launch.sh` points here): three unauthenticated endpoints.
  - `POST /models`, `POST /models/load`, `POST /models/unload`; no `--api-key` is set.
    - Site: server.cpp:226-228 in the on-disk source; the line moves across builds.
    - An `--api-key` would not close `POST`/`DELETE /models`: `get_public_endpoints` holds `/models` and is tested
      by path with no method check (server-http.cpp:197, :215), so only `load`/`unload` would end up behind it.
  - CORS-simple (no preflight) and `Host` is unvalidated, so a CSRF page or DNS-rebinding attack reaches them.
  - `load`/`unload` churn force-kills an in-flight generation under `--models-max 1`.
  - Worst case is a drive-by download via `POST /models`, and its impact is more than stray bytes:
    - The download lands in `.cache-empty` and joins the served fleet (cache-sourced models are served).
    - The now-non-empty cache dir wedges the next `launch.sh` (fail-closed guard) until cleared by hand.
    - The bytes grow the never-shrinking vhdx (bulk downloads have crashed the host twice - AGENTS.md, disk budget).
    - `launch.sh` scrubs both secrets from the child env (`env -u`): dropping `HF_TOKEN` caps a triggered
      download at public repos; dropping `OLLAMA_API_KEY` (which llama-server never reads) keeps the MCP client
      credential out of the server's inherited env.
    - `DELETE /models` needs a CORS preflight to run.
      - `--cors-origins localhost` won't grant that preflight to an arbitrary page - effectively gated.
  - The loopback bind (127.0.0.1) is the actual boundary: a same-host threat model, not a remote one.

Per-client detail worth carrying:

- claude-local: picks a lane per session and exports `ANTHROPIC_BASE_URL` + the model vars.
  - Full spec: [AGENTS.md](../AGENTS.md#claude-local).
  - Execs `claude` with all three flags (`--settings`, `--disallowedTools`, `--mcp-config`) in `=VALUE` form -
    the space form swallows `"$@"` into the deny list.
  - The MCP is the official Ollama web-search script, run via pipx on an `mcp>=1.9,<2` pin.
- Open WebUI: started on demand, no background service, OpenAI connection at 11433 ([openwebui.md](openwebui.md)).
- Codex: llama-server silently skips Responses tools typed `namespace` or `web_search` and still returns 200.
  - Codex-side MCP therefore fails invisibly on this lane; plain `function` tools are unaffected.
- The multi-system-message template gate now bites the OpenAI-endpoint clients, not `/v1/messages` (see AGENTS.md).

Runbook:

- The log directory has to exist first: `mkdir -p ~/.local/state`.
- Start: `setsid nohup ~/Developer/ollama-modelfiles/llamacpp/launch.sh > ~/.local/state/llama-router.log 2>&1 &`
  - Then record the pid: `echo $! > ~/.local/state/llama-router.pid`; confirm it is the listener with
    `ss -ltnp | grep 11433` (under interactive job control `$!` can be a short-lived `setsid` wrapper).
- Stop: `kill "$(cat ~/.local/state/llama-router.pid)"` - the children die with it.
  - Never `pgrep`/`pkill` for it instead: that has twice killed a router someone else started
    ([AGENTS.md](../AGENTS.md) Serving).
- Monitor: the `status` field in `/v1/models` (loaded / sleeping / unloaded), the log's `timings` lines, `nvidia-smi`.

FROZEN LEGACY: the Ollama lane's service env carried `KEEP_ALIVE=24h`, `FLASH_ATTENTION=1`, `KV_CACHE_TYPE=q8_0`.

- All three now live in the router: `--sleep-idle-seconds 86400` and the `[*]` `flash-attn` / `cache-type-*` keys.
- The FA + q8_0 pairing rule carried over unchanged; the mandate is in AGENTS.md, the decision in parameters.md.

## 5. Disk reality (the lesson baked into the design)

```text
Windows F: (1.9TB NTFS) --contains--> ext4.vhdx (WSL2 root; GROWS, never shrinks by itself)
                                          |
     guest `df /` reports the VIRTUAL disk -> always budget against `df /mnt/f` instead
     HF cache = the single live source: 199G (du -sh 2026-08-07; the 2026-07-27 cut logged 285G -> 199G)
     ollama store = frozen legacy bytes, freed at the purge: 186G (du -sh 2026-08-07; the spec's
       232G predates that cut)
     after large in-guest deletions: `wsl --shutdown` + Optimize-VHD (Windows side)
     to return freed space to NTFS
```

Bytes used to exist twice by design (HF blob + re-serialized Ollama layer); that duplication is now legacy, not design.

## 6. Reproducibility / recovery paths

- Bring the lane back up (reboot, or after a kill): the runbook start command in section 4. Nothing else is needed.
- Add or repoint a model: edit `llamacpp/models.ini` per [llamacpp/README.md](../llamacpp/README.md), then restart.
  - There is no build or import step: the entry points at the cached snapshot, and the child loads it directly.
- Re-provision from nothing: `hf download` the repos in the `model =` paths -> same pinned snapshots -> `launch.sh`.
- Session state: `specs/<feature>/tasks.md` is the resume point per feature, backed by the dated logs in `history/`.
  - `.migration-artifacts/` is git-excluded: pre-migration store baselines, HF inventories, the migration scripts.
- Rollback: the Ollama store, binaries, and override are retained, so the old lane can be restored until the purge.
  - FROZEN LEGACY rebuild path: `scripts/ollama-create.sh modelfiles/<family>/<stem>` re-created one model.
    - It reused the already-cached bytes, deduping by sha256 into an instant re-link.

Two pins to keep in mind:

- `models.ini` hard-pins absolute snapshot paths, so an `hf download` of a newer repo commit lands in a *new* snapshot.
  - The preset keeps serving the old, still-cached one until the path is edited - a deliberate two-step, not drift.
- `launch.sh` records the on-disk build and its re-cert state; it is a record, not an assertion.
  - The version abort was removed 2026-08-03; rebuilds re-certify per the migration spec's rebuild rule.
