#!/usr/bin/env bash
# Router launcher for the llama.cpp lane (specs/llamacpp-migration).
# Port 11433: 8080 = Open WebUI, 11434 = Ollama until retired, 11435-11438 = benchmarks.
# Children inherit this environment verbatim (no per-model env in router mode):
# CUDA graphs stays ON fleet-wide - never set GGML_CUDA_DISABLE_GRAPHS here (Gemma MTP needs graphs on).
set -euo pipefail

BIN=/home/wma/Developer/llama.cpp/build/bin/llama-server
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pin enforcement: the router spawns children from its own binary, so a wrong
# binary silently runs the whole fleet off-pin. Abort unless it is b9860.
ver="$("$BIN" --version 2>&1 | head -n 1)"
if [[ "$ver" != *"version: 9860 (fdb1db877)"* ]]; then
    echo "launch.sh: refusing to start: $BIN reports '$ver', expected 'version: 9860 (fdb1db877)'" >&2
    exit 1
fi

# The preset is the entire served fleet: router mode unconditionally auto-serves
# every GGUF in the HF cache, so point LLAMA_CACHE (first in the cache resolution
# order) at an empty directory. Preset entries use absolute paths and never
# resolve through the cache.
export LLAMA_CACHE="$DIR/.cache-empty"
mkdir -p "$LLAMA_CACHE"

# SLEEP_IDLE_SECONDS=30 ./launch.sh for the sleep-idle smoke; default matches
# Ollama's KEEP_ALIVE=24h. Extra args pass through to the router.
exec "$BIN" \
    --models-preset "$DIR/models.ini" \
    --host 127.0.0.1 --port 11433 \
    --sleep-idle-seconds "${SLEEP_IDLE_SECONDS:-86400}" \
    "$@"
