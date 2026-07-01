#!/usr/bin/env bash
# Reproduce and characterize the Qwen3.5-9B-MTP + CUDA-graphs crash.
#
# Background: the 2026-06-30 9B-coders benchmark crashed once on graphs-on +
# qwen3.5-9b-mtp-coding (ggml-cuda.cu:104 illegal memory access, ~1289 tokens
# in).  That is N=1 - not yet a characterized failure.  This script settles it
# with a 3-cell experiment that isolates the interaction:
#
#   1. MTP     @ graphs-on   the suspect combination
#   2. MTP     @ graphs-off  control: MTP alone (known-good on 2026-06-30)
#   3. non-MTP @ graphs-on   control: graphs alone (known-good on 2026-06-30)
#
# If cell 1 crashes while 2 and 3 stay clean, the crash is the MTP x graphs
# interaction, not either factor alone.  Each cell runs on its own isolated
# `ollama serve` (alternate port, invoking user, systemd store) so the live
# systemd instance is never mutated - same pattern as benchmark-common.sh.
#
# Dry-run by default (prints the plan); pass --execute to actually serve+run.
set -uo pipefail

# --- config ---
host="127.0.0.1:11437"                 # free: systemd=11434, harness=11435/11436
models_dir="/usr/share/ollama/.ollama/models"
prompt_file="$(dirname -- "${BASH_SOURCE[0]}")/benchmark-9b-coders.prompt.long.txt"
runs=3                                  # reps per cell
run_timeout=900                         # per-generation wall-clock cap (s)
ready_timeout=60                        # serve readiness cap (s)

mtp_model="qwen3.5-9b-mtp-coding-ud-q4-k-xl"
base_model="qwen3.5-9b-coding-q4-k-m"

# cell = "<model>|<graphs>"; graphs in {on,off}
cells=(
    "$mtp_model|on"
    "$mtp_model|off"
    "$base_model|on"
)

execute=0
[[ "${1:-}" == "--execute" ]] && execute=1

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$prompt_file" ]] || die "prompt file not found: $prompt_file"

if (( ! execute )); then
    echo "DRY RUN (pass --execute to serve + run). Plan:"
    echo "  host=$host  models_dir=$models_dir  runs=$runs/cell"
    echo "  prompt=$prompt_file"
    for cell in "${cells[@]}"; do
        IFS='|' read -r model graphs <<<"$cell"
        echo "  - $model @ graphs-$graphs  (x$runs)"
    done
    exit 0
fi

# --- execute ---
outdir="$(dirname -- "${BASH_SOURCE[0]}")/benchmark-results/repro-mtp-graphs-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$outdir"
results="$outdir/results.txt"
prompt="$(cat "$prompt_file")"
echo "output: $outdir"

for cell in "${cells[@]}"; do
    IFS='|' read -r model graphs <<<"$cell"
    tag="${model}__graphs-${graphs}"
    celldir="$outdir/$tag"
    mkdir -p "$celldir"
    echo "=== cell: $model @ graphs-$graphs ===" | tee -a "$results"

    # Isolated serve; graphs-off adds the disable env, graphs-on leaves it unset.
    serve_env=(
        env
        "OLLAMA_HOST=$host"
        "OLLAMA_MODELS=$models_dir"
        "OLLAMA_CONTEXT_LENGTH=131072"
        "OLLAMA_KEEP_ALIVE=24h"
        "OLLAMA_FLASH_ATTENTION=1"
        "OLLAMA_KV_CACHE_TYPE=q8_0"
        "OLLAMA_NUM_PARALLEL=1"
    )
    [[ "$graphs" == "off" ]] && serve_env+=("GGML_CUDA_DISABLE_GRAPHS=1")

    "${serve_env[@]}" ollama serve >"$celldir/serve.log" 2>&1 &
    serve_pid=$!

    # Wait for ready, aborting if the serve dies first.
    ready=0
    for (( i=0; i<ready_timeout; i++ )); do
        if env "OLLAMA_HOST=$host" ollama ps >/dev/null 2>&1; then ready=1; break; fi
        kill -0 "$serve_pid" 2>/dev/null || { echo "  serve died before ready" | tee -a "$results"; break; }
        sleep 1
    done

    if (( ready )); then
        # Warmup (loads weights; not scored).
        env "OLLAMA_HOST=$host" timeout "$run_timeout" ollama run --verbose --keepalive 30m \
            "$model" "$prompt" >"$celldir/warmup.log" 2>&1
        echo "  warmup exit=$?" | tee -a "$results"

        for (( r=1; r<=runs; r++ )); do
            env "OLLAMA_HOST=$host" timeout "$run_timeout" ollama run --verbose --keepalive 30m \
                "$model" "$prompt" >"$celldir/run-$r.log" 2>&1
            echo "  run $r exit=$?" | tee -a "$results"
            if ! kill -0 "$serve_pid" 2>/dev/null; then
                echo "  SERVE DIED after run $r" | tee -a "$results"
                break
            fi
        done
    fi

    # Tear down this cell's serve by PGID (avoids killing this wrapper).
    pgid="$(ps -o pgid= -p "$serve_pid" 2>/dev/null | tr -d ' ')"
    [[ -n "$pgid" ]] && kill -KILL "-$pgid" 2>/dev/null
    wait "$serve_pid" 2>/dev/null
    sleep 2   # let VRAM release before the next cell
done

echo "=== DONE ===" | tee -a "$results"
echo "grep -c 'illegal memory access' $outdir/*/*.log  # crash count"
