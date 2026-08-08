#!/usr/bin/env bash
# Router launcher for the llama.cpp lane (specs/llamacpp-migration).
# Port 11433: 8080 = Open WebUI, 11434 = Ollama until retired, 11435-11438 = benchmarks.
# Children inherit this environment verbatim (no per-model env in router mode):
# CUDA graphs stays ON fleet-wide - never set GGML_CUDA_DISABLE_GRAPHS here (Gemma MTP needs graphs on).
set -euo pipefail

# Build record: last known good 9860 (fdb1db877); on-disk 10326 (3653e6d6d) FAILED re-cert 2026-08-08 (tasks.md).
# Rebuilds re-certify per the migration spec's rebuild rule (crash matrix + froggeric pair; P1 log 2026-08-03).
BIN=/home/wma/Developer/llama.cpp/build/bin/llama-server
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The preset is the entire served fleet: router mode unconditionally auto-serves
# every GGUF in the HF cache, so point LLAMA_CACHE (first in the cache resolution
# order) at an empty directory. Preset entries use absolute paths and never
# resolve through the cache.
export LLAMA_CACHE="$DIR/.cache-empty"
mkdir -p "$LLAMA_CACHE"

# SLEEP_IDLE_SECONDS=30 ./launch.sh for the sleep-idle smoke; default matches
# Ollama's KEEP_ALIVE=24h. MODELS_MAX default 1: a lone resident child gets the
# whole GPU (P3 pressure findings, 2026-08-07).
# Extra args pass through, but they overlay EVERY preset entry (router CLI args
# merge into each model's config) and cannot move the bind (trailing --host/--port wins).
# --cors-origins localhost: only localhost-origin pages get CORS read access (browser-only mechanism;
# non-browser clients send no Origin). POST /models still executes regardless of CORS or --api-key at
# this build (path-only public-endpoint exemption upstream); the loopback bind is the real boundary.
# POST /models is CORS-simple (no preflight) and Host is unvalidated, so a browser CSRF / DNS-rebinding
# page can still reach it; verified impact ceiling is low: drive-by into gitignored .cache-empty; DELETE gated upstream.
exec "$BIN" \
    --models-preset "$DIR/models.ini" \
    --sleep-idle-seconds "${SLEEP_IDLE_SECONDS:-86400}" \
    --models-max "${MODELS_MAX:-1}" \
    --cors-origins localhost \
    "$@" \
    --host 127.0.0.1 --port 11433
