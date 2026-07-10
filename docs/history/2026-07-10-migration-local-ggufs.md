# Session summary - migration to hf-download local GGUFs + Open WebUI (2026-07-07..10)

Branch: `migrate/hf-local-ggufs`. Goal: every Modelfile references GGUFs
provisioned by `hf download` (HF cache, llama.cpp-convention files) instead of
`hf.co/...` OCI pulls or registry.ollama.ai tags; Gemma MTP working; Open WebUI
wired to the result. All load-bearing claims below were verified against
primary sources (code at tags, live API/DB reads, on-box runs) during the
session; research JSONs live in `.migration-artifacts/`.

## What changed

### 1. Modelfiles -> pinned local HF-cache paths
- 16 canonical Modelfiles rewritten from `FROM hf.co/...` / registry tags to
  `FROM /home/wma/.cache/huggingface/hub/models--ORG--REPO/snapshots/<commit>/<file>.gguf`.
- Vision models carry a second `FROM <...>/mmproj-*.gguf` line - the OCI pull
  used to auto-bundle the projector; a bare main-GGUF FROM silently drops the
  `vision` capability (verified on 26B before/after).
- Thin aliases unchanged (FROM canonical local model name). Fixed
  `Modelfile.qwen3.6-27b-obliterated-coding` to point at the *coding* profile
  (was aliasing the general one).
- `Modelfile.qwen3.5-9b-coding-q4-k-m` -> `Modelfile.qwen3.5-9b-coding-ud-q4-k-xl`:
  back on Unsloth UD-Q4_K_XL. The 2026-06-30 "OCI bridge hang" was HF's
  GGUF->OCI registry bridge only; plain `hf download` works (5.97 GB pull
  verified). Benchmark matrix updated; memory note updated.

### 2. Blob pre-seed (avoided ~200 GB re-download)
- ollama's blob store digests are plain sha256 == HF LFS oids. 18 blobs
  (~201 GB) copied from `/usr/share/ollama/.ollama/models/blobs/` into the HF
  cache layout (blobs/<oid> + snapshots/<commit>/<file> symlink + refs/main,
  no trailing newline). hf 0.36.2 accepts pre-placed blobs by filename alone
  (verified in file_download.py source; xet repos still key blobs by
  x-linked-etag == LFS oid).
- Hardlinking is blocked (fs.protected_hardlinks + ollama-owned files), hence
  copies. Remaining ~48 GB (31B qat/heretic, Qwen3.5-9B, Queen-27B, Qwopus
  renamed `-coder-Exp-`) downloaded via `hf download`.
- `ollama create` COPIES local FROM files into its blob store but dedups by
  sha256 - since the preseeds ARE the same bytes, rebuilds re-link instantly.

### 3. Gemma 4 MTP: Ollama DRAFT now works on CUDA (plan-flipping finding)
- Ollama 0.31.1 runs the `DRAFT` directive on the CUDA/llama.cpp runner
  (vendored llama.cpp b9840). On-box: serve log shows `draft-mtp` init;
  12B pair: acceptance 0.742, 85.2 vs 51.1 tok/s control = **1.67x**;
  26B pair: acceptance 0.787, 37.0 vs 24.1 tok/s control = **1.54x**.
- Stock llama.cpp CANNOT load gemma4-assistant drafters: issue #24795 (open,
  no fix PR; regression window b9553..b9587, prime suspect PR #24282) -
  repro'd on-box on BOTH b9553 and b9860 builds
  (`Gemma4Assistant requires ctx_other` -> `vector::_M_range_check`).
  The b9553-works claim from the issue did not hold here; Ollama's vendored
  engine carries a fix stock lacks. So Ollama is currently the only working
  CUDA path for Gemma MTP, inverting the prior "MLX-only, don't stage" note.
- `Modelfile.gemma4-26b-a4b-it-qat-mtp` now: FROM gemma4-26b-a4b-it-qat +
  DRAFT <local mtp-gemma-4-26B-A4B-it.gguf> + draft_num_predict 2.
- llama.cpp checkouts: master rebuilt at b9860 (fdb1db877) with CUDA arch 89;
  known-good-candidate worktree at ../llama.cpp-b9553 (kept for future MTP
  work on stock llama.cpp; remove when #24795 is fixed upstream).

### 4. Ollama model store cleanup (user directive: keep-set = repo Modelfiles)
- Retired all hf.co/*, registry huihui/HauhauCS/DuoNeural/E4B, qwen3.5:9b,
  and stale names from deleted Modelfiles. Pre-migration state of every
  removed model is captured in `.migration-artifacts/baselines/`
  (ollama show + --modelfile for all 47 pre-migration models).

### 5. Open WebUI (pipx, v0.10.2) wired to the migrated stack
- No background service (user preference): launcher `~/.local/bin/openwebui`
  runs it on demand (foreground, Ctrl+C to stop) with `DATA_DIR=~/.open-webui`
  pinned - the pipx default DATA_DIR lives INSIDE the venv and is destroyed by
  `pipx upgrade` (verified in env.py source).
- Recovered the pre-existing install from exactly that trap: admin account
  (William Ma) + 7 chats found in the venv-internal webui.db (created
  2026-06-19); adopted via sqlite backup (WAL folded in) into ~/.open-webui
  together with uploads/ + vector_db/. Old copy left in place as fallback;
  fresh seed DB kept as webui.db.fresh-seed.bak.
- Config lives in the DB/Admin UI (env vars only seed the DB on first launch -
  "PersistentConfig" semantics), verified in the adopted DB:
  ollama.base_urls=[http://127.0.0.1:11434], web.search.engine=brave,
  web.search.enable=true, openai.enable=false.
- OpenAI-compat connection deliberately disabled: ollama's /v1 endpoint
  injects temperature=1.0/top_p=1.0 when the client omits them, silently
  overriding Modelfile sampling (openai.go verified at v0.31.1) - the native
  Ollama connection type does not.
- REMAINING (user action): paste the Brave API key in Admin Panel > Settings >
  Web Search (no key found on disk), log in at http://127.0.0.1:8080.

## Systemd env review (user edited override.conf mid-session)
Live env now: OLLAMA_API_KEY, KEEP_ALIVE=24h, FLASH_ATTENTION=1,
KV_CACHE_TYPE=q8_0; NUM_PARALLEL and CONTEXT_LENGTH commented out;
GGML_CUDA_DISABLE_GRAPHS=1 still commented out. Verified against v0.31.1
source (envconfig/config.go, sched.go, llama_server.go):
- NUM_PARALLEL unset = fixed 1 (not auto): n_ctx = num_ctx * 1, no hidden
  multiplication. qwen35/qwen35moe are forced parallel=1 anyway. Commenting
  it out: no behavior change.
- CONTEXT_LENGTH unset = VRAM-tier auto (4096 on a 12 GB card) - but only for
  models WITHOUT a Modelfile num_ctx. All repo models pin num_ctx, which
  outranks the env, so no change for them; and a Modelfile num_ctx is never
  auto-shrunk on OOM (partial offload instead).
- KEEP q8_0 + FLASH_ATTENTION=1 paired: quantized V-cache hard-fails load if
  FA resolves off; explicit =1 avoids auto's per-model fallback.
- OLLAMA_API_KEY on the server does NOT gate inbound requests: /api/tags and
  /v1/models answered 200 unauthenticated on-box. It is a client-side var
  (ollama launch/cloud). Open WebUI therefore needs no bearer key.
- STILL OPEN (needs sudo): prod runs CUDA graphs ON; the
  session_summary_mtp_graphs_crash.md action item (uncomment
  GGML_CUDA_DISABLE_GRAPHS=1) was never applied - MTP models served via
  claude-local remain exposed to the ~12.5%/run crash.

## Disk incident (2026-07-10) and the space story
The migration's copies crashed the system: preseed (~201 GB) + downloads
(~48 GB) + `ollama create` re-serializing local FROM GGUFs into its blob
store all grew the WSL2 ext4.vhdx on the host's F: drive to ~0 free. Guest
`df -h /` was misleading throughout - it reports the virtual disk, and a
vhdx never returns freed space to NTFS without a host-side compact. The user
had to delete games; not the first such incident (rule now in auto-memory:
budget against `df -h /mnt/f`, count hidden copies, reclaim before
acquiring).

Recovery/cleanup:
- Repo, HF cache, ollama store, Open WebUI DB all intact after reboot.
- b9553 worktree removed; stale qwen3.5-9b-coding-q4-k-m retired.
- 191.2 GB of orphaned ollama blobs (old hf.co pulls + create temp files)
  listed in `.migration-artifacts/orphans.txt` - deleting them needs sudo
  (`sudo systemctl stop ollama`, delete listed files, restart).
- A further ~89 GB is the same bytes held twice by design (HF cache blob +
  ollama re-serialized layer for the 15 biggest models). If that price is
  too high, the HF-cache copy of models NOT used via llama.cpp directly can
  go - `hf download` restores any of them on demand; the Modelfiles pin
  exact snapshot paths either way.
- Host-side after any big deletion: `wsl --shutdown` then Optimize-VHD
  (or diskpart compact vdisk) on ext4.vhdx to hand space back to NTFS.

## Method notes
- Research ran as adversarially-verified workflow fan-outs; full structured
  findings: `.migration-artifacts/research_results.json` (+ the Open WebUI
  run's journal). Load-bearing claims were re-verified by second agents
  fetching primary sources; the "b9553 works" secondhand claim was then
  empirically refuted on-box - summaries stay leads, not findings.
- `.migration-artifacts/` (git-excluded via .git/info/exclude) holds:
  baselines/, hf-inventory/ (per-repo file+oid listings), acquisition_plan
  .json, preseed.py, migrate_modelfiles.py, validate_vs_baselines.py,
  research_results.json.
