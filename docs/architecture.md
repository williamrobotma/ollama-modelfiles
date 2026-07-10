# Architecture

How the local-LLM stack fits together after the 2026-07 migration to hf-downloaded local GGUFs (see [history/2026-07-10-migration-local-ggufs.md](history/2026-07-10-migration-local-ggufs.md) for the migration evidence log).

## 1. The big picture - one source of truth, three consumers

```text
                         Hugging Face Hub (upstream)
                                   |
                                   |  hf download ORG/REPO file.gguf
                                   |  (HF CDN/XET; the OCI bridge is OUT of the loop)
                                   v
              ~/.cache/huggingface/hub/  ..... THE SOURCE OF TRUTH
              models--ORG--REPO/
                blobs/<sha256>                 (actual bytes, keyed by LFS oid)
                snapshots/<commit>/<file>.gguf (symlinks; PINNED paths)
                refs/main
                                   |
          +------------------------+------------------------+
          |                                                  |
          v                                                  v
   git repo (ollama-modelfiles)                     llama.cpp (direct, optional)
   modelfiles/*/*/Modelfile                         ./llama-server --model <same path>
      --> FROM /abs/snapshot/path.gguf              (b9860 CUDA build in ~/Developer/llama.cpp;
          |                                          NOT usable for Gemma MTP: bug #24795)
          |  scripts/ollama-create.sh
          v
   Ollama blob store (/usr/share/ollama/.ollama/models)
   re-serialized layers, deduped by sha256; keep-set == repo Modelfiles, nothing else
```

Key property: the repo's Modelfiles are the *only* mapping layer. Every installed Ollama model is reproducible from `git clone` + `hf download` + `scripts/ollama-create.sh`, and the same cached GGUFs feed llama.cpp without conversion.

## 2. Modelfile layering (inside the repo)

```text
CANONICAL (quant-suffixed, full param block)
  modelfiles/gemma4/26b-a4b-it-qat/Modelfile
      FROM <snapshot>/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf   <- weights
      FROM <snapshot>/mmproj-BF16.gguf                          <- vision projector
                                                                   (2nd FROM or vision is silently dropped)
      PARAMETER ... SYSTEM <|think|>

LAYERED / DERIVED (FROM a local model name)
  modelfiles/gemma4/26b-a4b-it-qat-mtp/Modelfile
      FROM gemma4-26b-a4b-it-qat                                <- inherits weights+mmproj+params
      DRAFT <snapshot>/mtp-gemma-4-26B-A4B-it.gguf              <- separate drafter GGUF
      PARAMETER draft_num_predict 2

  modelfiles/qwen3.6/35b-a3b-mtp-coding-ud-q5-k-xl/Modelfile
      FROM qwen3.6-35b-a3b-mtp-ud-q5-k-xl                       <- profile layered on MTP base
      PARAMETER temperature 0.6 ...                              (coding overrides instruct)

THIN ALIASES (one line, repoint-able defaults)
  modelfiles/qwen3.6/35b-a3b-mtp-coding/Modelfile
      FROM qwen3.6-35b-a3b-mtp-coding-ud-q5-k-xl
```

The model name is `<family>-<stem>` from `modelfiles/<family>/<stem>/Modelfile`. `scripts/ollama-create.sh` resolves this graph bottom-up (canonical -> layered -> alias).

## 3. The two MTP mechanisms (they are not the same thing)

```text
QWEN (self-contained)                      GEMMA (target + drafter)
  one GGUF with embedded MTP tensors         main GGUF + mtp-gemma-4-*.gguf (~250MB)
  Ollama auto-detects, self-drafts           wired via DRAFT directive in the Modelfile
  PARAMETER draft_num_predict 2              PARAMETER draft_num_predict 2
  measured: ~1.65x (9B)                      measured: 1.67x (12B), 1.54x (26B)

  BOTH run on Ollama's CUDA runner (0.31.1, vendored llama.cpp b9840).
  Stock llama.cpp cannot load gemma4-assistant drafters (#24795, open)
  -> Ollama is currently the ONLY working CUDA path for Gemma MTP.
```

## 4. Serving layer and its clients

```text
                    systemd: ollama.service (the one intentional daemon)
                    env: KEEP_ALIVE=24h, FLASH_ATTENTION=1, KV_CACHE_TYPE=q8_0
                    (FA=1 + q8_0 must stay PAIRED: quantized V-cache fails load without FA)
                    (NUM_PARALLEL/CONTEXT_LENGTH removed = defaults; harmless because
                     every Modelfile pins num_ctx, which outranks the env)
                                   127.0.0.1:11434
                                        |
        +-------------------------------+-------------------------------+
        |                               |                               |
   native /api/*                   OpenAI /v1/*                  Anthropic /v1/messages
        |                               |                               |
        v                               v                               v
   OPEN WEBUI  ------uses this     [DISABLED in webui]            CLAUDE-LOCAL
   on-demand: `openwebui`          reason: /v1 injects            `ollama launch claude`
   (no service; Ctrl+C stops)      temp=1.0/top_p=1.0 when        models must pass the
   DATA_DIR=~/.open-webui          omitted, silently overriding   multi-system-message
   config lives in webui.db        Modelfile sampling; native     template gate
   (Admin UI, not env)             endpoint doesn't
   Brave search: engine+key
   in DB, live-tested OK
```

No inbound auth anywhere: `OLLAMA_API_KEY` on the server is client-side only (verified - endpoints answer 200 unauthenticated), everything binds to 127.0.0.1.

## 5. Disk reality (the lesson baked into the design)

```text
Windows F: (1.9TB NTFS) --contains--> ext4.vhdx (WSL2 root; GROWS, never shrinks by itself)
                                          |
     guest `df /` reports the VIRTUAL disk -> always budget against `df /mnt/f` instead
     bytes exist TWICE by design: HF cache blob (source) + ollama layer (re-serialized copy)
     current: ollama store 232GB, HF cache 249GB (~89GB is the same bytes both sides)
     after large in-guest deletions: `wsl --shutdown` + Optimize-VHD (Windows side)
     to return freed space to NTFS
```

## 6. Reproducibility / recovery paths

- Rebuild any model: `scripts/ollama-create.sh modelfiles/<family>/<stem>` (source bytes already cached; create dedups by sha256 -> instant re-link).
- Re-provision from nothing: `hf download` the repos listed in the FROM paths -> same pinned snapshots -> `scripts/ollama-create.sh`.
- Session state: `specs/<feature>/tasks.md` (resume point per feature), [history/2026-07-10-migration-local-ggufs.md](history/2026-07-10-migration-local-ggufs.md) (full migration evidence log), `.migration-artifacts/` (git-excluded: baselines of the pre-migration store, HF inventories, the preseed/migrate/validate scripts).

The one architectural caveat to keep in mind: Modelfiles hard-pin absolute snapshot paths, so an `hf download` that pulls a *newer* repo commit creates a new snapshot dir and the Modelfiles keep pointing at the old (still-cached) one - updating a model is a deliberate two-step (download, then update the FROM path), which is the intended pinning behavior, not drift.
