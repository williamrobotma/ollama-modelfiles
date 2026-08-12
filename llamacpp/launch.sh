#!/usr/bin/env bash
# Starts the llama.cpp router on 127.0.0.1:11433 (specs/llamacpp-migration).
# Port neighbors: 8080 Open WebUI; 11434 was Ollama (retired 2026-08-07).
# Children inherit this env verbatim, so env hygiene here is fleet-wide.
# Never set GGML_CUDA_DISABLE_GRAPHS: any value, even =0, turns CUDA graphs
# off, and the Gemma MTP drafter fails to load without them (AGENTS.md).
set -euo pipefail

# Build record (defined here; other files point to it):
#   b10335 (74ce15741), on disk since 2026-08-09.
#   Re-certified 2026-08-10: crash matrix + froggeric pair passed.
#   The earlier b10326 re-cert failure was the GPU core overclock, not the
#   build (docs/benchmarking.md).
#   Canonical = whatever is on disk, never downgraded (user, 2026-08-08);
#   rebuilds re-certify per the migration spec's rebuild rule.
BIN=/home/wma/Developer/llama.cpp/build/bin/llama-server
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Refuse to launch over a live router (AGENTS.md Serving).
# No curl = fail closed: an unrun probe must not read as "port free".
command -v curl >/dev/null || { echo "launch.sh: curl not found - cannot probe for a live router" >&2; exit 1; }
if curl -s --max-time 2 http://127.0.0.1:11433/v1/models >/dev/null 2>&1; then
    echo "launch.sh: 127.0.0.1:11433 already answers - refusing to launch over a live router" >&2
    exit 1
fi

# Empty LLAMA_CACHE: router mode would auto-serve every GGUF in the HF cache.
export LLAMA_CACHE="$DIR/.cache-empty"
mkdir -p "$LLAMA_CACHE"
if [ -n "$(ls -A "$LLAMA_CACHE")" ]; then
    echo "launch.sh: $LLAMA_CACHE is not empty - a stray GGUF would join the served fleet" >&2
    exit 1
fi

# Flags: defaults first, then "$@" - the last value of a repeated flag wins,
# so callers can override any default.
# The bind stays after "$@": loopback is the security boundary (CSRF
# analysis: docs/architecture.md section 4), so no caller may rebind it.
# Caution: router CLI args merge into EVERY entry (llamacpp/README.md).
"$BIN" --version >&2   # log the served build
# Scrub secrets from the fleet env: no HF_TOKEN caps a CSRF-triggered
# download at public repos; OLLAMA_API_KEY is the MCP client's key, which
# llama-server never reads. Analysis: docs/architecture.md section 4.
exec env -u OLLAMA_API_KEY -u HF_TOKEN "$BIN" \
    --models-preset "$DIR/models.ini" \
    --sleep-idle-seconds 86400 \
    --models-max 1 \
    --cors-origins localhost \
    "$@" \
    --host 127.0.0.1 --port 11433
