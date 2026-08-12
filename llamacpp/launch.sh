#!/usr/bin/env bash
# Router launcher for the llama.cpp serving stack (specs/llamacpp-migration).
# Binds 127.0.0.1:11433. Nearby ports: 8080 Open WebUI, 11434 Ollama
# (retired 2026-08-07), 11435-11438 benchmarks.
# Children inherit this env verbatim. Keep GGML_CUDA_DISABLE_GRAPHS unset:
# even =0 disables graphs, and Gemma MTP needs graphs on (AGENTS.md Serving).
set -euo pipefail

# Build record (defined here; other files point to it): b10335 (74ce15741)
# on disk since 2026-08-09, re-certified 2026-08-10 (crash matrix + froggeric
# pair). The b10326 re-cert failure was this box's GPU core overclock, not
# the build (docs/benchmarking.md). The build is canonical, never downgraded
# (user, 2026-08-08); rebuilds re-certify per the migration spec rebuild rule.
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

# Flag rationale + CSRF surface: docs/architecture.md section 4.
# Defaults precede "$@": a repeated flag's last value takes effect.
# Extra args merge into EVERY entry; the trailing --host/--port fixes the bind.
"$BIN" --version >&2
# Secret scrub; per-key rationale: docs/architecture.md section 4 (CSRF).
exec env -u OLLAMA_API_KEY -u HF_TOKEN "$BIN" \
    --models-preset "$DIR/models.ini" \
    --sleep-idle-seconds 86400 \
    --models-max 1 \
    --cors-origins localhost \
    "$@" \
    --host 127.0.0.1 --port 11433
