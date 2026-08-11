#!/usr/bin/env bash
# Router launcher for the llama.cpp lane (specs/llamacpp-migration).
# Port 11433: 8080 = Open WebUI, 11434 = Ollama (retired 2026-08-07), 11435-11438 = benchmarks.
# Children inherit this environment verbatim (no per-model env in router mode):
# CUDA graphs stays ON fleet-wide - never set GGML_CUDA_DISABLE_GRAPHS here (Gemma MTP needs graphs on).
# The var lives at ggml-cuda/common.cuh:1258 and tests presence only, so even =0 disables graphs.
set -euo pipefail

# Build record: on-disk 10335 (74ce15741) since 2026-08-09, re-certified 2026-08-10 (crash matrix + froggeric
# (template, 10335) pair). The 10326 re-cert failure resolved to this box's GPU core overclock, not any build
# (crash status: docs/benchmarking.md).
# Decided 2026-08-08 (user): the on-disk build is canonical - downgrades are never an option; serve it as-is.
# Rebuilds re-certify per the migration spec's rebuild rule (crash matrix + froggeric pair; P1 log 2026-08-03).
BIN=/home/wma/Developer/llama.cpp/build/bin/llama-server
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Refuse to launch over a live router (AGENTS.md Serving: live-probe 11433 first, every time).
# Fail closed if curl is missing: a probe that cannot run must not read as "nothing is listening".
command -v curl >/dev/null || { echo "launch.sh: curl not found - cannot probe for a live router" >&2; exit 1; }
if curl -s --max-time 2 http://127.0.0.1:11433/v1/models >/dev/null 2>&1; then
    echo "launch.sh: 127.0.0.1:11433 already answers - refusing to launch over a live router" >&2
    exit 1
fi

# The preset is the entire served fleet: router mode unconditionally auto-serves
# every GGUF in the HF cache, so point LLAMA_CACHE (first in the cache resolution
# order) at an empty directory. Preset entries use absolute paths and never
# resolve through the cache.
export LLAMA_CACHE="$DIR/.cache-empty"
mkdir -p "$LLAMA_CACHE"
if [ -n "$(ls -A "$LLAMA_CACHE")" ]; then
    echo "launch.sh: $LLAMA_CACHE is not empty - a stray GGUF would join the served fleet" >&2
    exit 1
fi

# --sleep-idle-seconds 86400 matches Ollama's KEEP_ALIVE=24h; --models-max 1 gives a lone
# resident child the whole GPU (P3 pressure findings, 2026-08-07).
# Override either on the command line (./launch.sh --sleep-idle-seconds 30 for the sleep-idle
# smoke): both handlers are last-wins and these flags are emitted before "$@".
# Extra args pass through, but they overlay EVERY preset entry (router CLI args
# merge into each model's config) and cannot move the bind (trailing --host/--port wins).
# --cors-origins localhost limits browser reads; the unauthenticated management endpoints (POST /models,
# /models/load, /models/unload) stay CSRF-reachable - full analysis: docs/architecture.md section 4 (CSRF surface).
"$BIN" --version >&2
# The env scrub is load-bearing, for two different reasons: HF_TOKEN feeds POST /models downloads
# (server-models.cpp), so scrubbing it caps a CSRF-triggered download at public repos; OLLAMA_API_KEY is never
# read by llama-server - it is scrubbed to keep the MCP client credential out of the env every child inherits.
exec env -u OLLAMA_API_KEY -u HF_TOKEN "$BIN" \
    --models-preset "$DIR/models.ini" \
    --sleep-idle-seconds 86400 \
    --models-max 1 \
    --cors-origins localhost \
    "$@" \
    --host 127.0.0.1 --port 11433
