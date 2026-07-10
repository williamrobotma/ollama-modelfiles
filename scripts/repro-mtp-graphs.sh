#!/usr/bin/env bash
# Characterize the intermittent Qwen3.5-9B-MTP + CUDA-graphs crash.
#
# Background: the 2026-06-30 9B-coders benchmark crashed once on graphs-on +
# qwen3.5-9b-mtp (ggml-cuda.cu:104 illegal memory access, ~1289 tokens in).
# A 3-cell isolation re-run on 2026-07-01 found MTP@graphs-on ran 4/4 clean
# (two full 65536-token, ~10 min each) - so the crash is NOT deterministic.
# The open question is its *rate*, so this hammers the exact suspect
# combination on one warm serve and counts crashes over N runs.
#
# Each run is bounded to `num_predict` tokens (3x past the observed 1289-token
# crash point) via the /api/generate options, so a rep is ~40 s not ~10 min -
# many reps in bounded time.  If this comes back clean, the trigger is likely
# NOT the warm MTP x graphs pair itself but yesterday's differing conditions
# (serve churn / 4-model swaps); the complementary experiment is then
# restart-the-serve-per-run, not more warm reps.
#
# Runs on an isolated alternate-port serve (never mutates the systemd
# instance), same pattern as benchmarks/common.sh.  Dry-run by default; pass
# --execute to serve + run.
set -uo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# --- config ---
readonly host="127.0.0.1:11437"        # free alternate port; systemd=11434, harness=11435/11436
readonly models_dir="/usr/share/ollama/.ollama/models"
prompt_file="$repo_root/benchmarks/9b-coders/prompts/long.txt"
model="qwen3.5-9b-mtp-coding-ud-q4-k-xl"
readonly runs=30                        # reps against the one warm serve
readonly num_predict=4096               # per-run token cap (> the 1289 crash point)
run_timeout=180                         # per-run wall-clock cap (s)
ready_timeout=60                        # serve readiness cap (s)
readonly keep_alive="24h"               # OLLAMA_KEEP_ALIVE; same as benchmarks/common.sh's server_keepalive

execute=0
[[ "${1:-}" == "--execute" ]] && execute=1

die() { echo "ERROR: $*" >&2; exit 1; }
[[ -f "$prompt_file" ]] || die "prompt file not found: $prompt_file"

if (( ! execute )); then
    echo "DRY RUN (pass --execute to serve + run). Plan:"
    echo "  $model @ graphs-on, x$runs runs on one warm serve"
    echo "  host=$host  num_predict=$num_predict/run  models_dir=$models_dir"
    echo "  prompt=$prompt_file"
    exit 0
fi

# --- execute ---
outdir="$repo_root/benchmark-results/repro-mtp-graphs-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$outdir"
results="$outdir/results.txt"
serve_log="$outdir/serve.log"
prompt="$(cat "$prompt_file")"
echo "output: $outdir" | tee "$results"
echo "config: $model @ graphs-on, $runs runs, num_predict=$num_predict" | tee -a "$results"

# Isolated graphs-on serve (GGML_CUDA_DISABLE_GRAPHS deliberately unset).
env \
    "OLLAMA_HOST=$host" \
    "OLLAMA_MODELS=$models_dir" \
    "OLLAMA_CONTEXT_LENGTH=131072" \
    "OLLAMA_KEEP_ALIVE=$keep_alive" \
    "OLLAMA_FLASH_ATTENTION=1" \
    "OLLAMA_KV_CACHE_TYPE=q8_0" \
    "OLLAMA_NUM_PARALLEL=1" \
    ollama serve >"$serve_log" 2>&1 &
serve_pid=$!
# Kill the serve by PID on any exit (NOT by PGID - the backgrounded serve
# shares this non-interactive script's process group, so a PGID kill would
# also kill this wrapper, as it did in the 3-cell version).
trap 'kill "$serve_pid" 2>/dev/null; wait "$serve_pid" 2>/dev/null' EXIT

# Wait for ready, aborting if the serve dies first.
ready=0
for (( i=0; i<ready_timeout; i++ )); do
    if env "OLLAMA_HOST=$host" ollama ps >/dev/null 2>&1; then ready=1; break; fi
    kill -0 "$serve_pid" 2>/dev/null || die "serve died before ready; see $serve_log"
    sleep 1
done
(( ready )) || die "serve not ready in ${ready_timeout}s; see $serve_log"

# Warmup: load weights + confirm 100% GPU (a CPU-offloaded load would make any
# later OOM a VRAM-contention artifact, not the MTP x graphs interaction).
curl -sf "http://$host/api/generate" \
    -d "{\"model\":\"$model\",\"prompt\":\"warmup\",\"stream\":false,\"options\":{\"num_predict\":8}}" \
    >/dev/null 2>&1
echo "warmup placement:" | tee -a "$results"
env "OLLAMA_HOST=$host" ollama ps 2>&1 | tee -a "$results"

# Hammer: N bounded runs, count crashes via serve.log delta + API failure.
crashes=0
first_crash=""
req="$(python3 -c "
import json,sys
print(json.dumps({'model':'$model','prompt':sys.stdin.read(),
                  'stream':False,'options':{'num_predict':$num_predict}}))
" <<<"$prompt")"

for (( r=1; r<=runs; r++ )); do
    before="$(grep -c 'illegal memory access\|CUDA error' "$serve_log" 2>/dev/null || echo 0)"
    body="$(curl -s --max-time "$run_timeout" "http://$host/api/generate" -d "$req" 2>&1)"
    api_ok=0
    echo "$body" | grep -q '"done":true' && api_ok=1
    after="$(grep -c 'illegal memory access\|CUDA error' "$serve_log" 2>/dev/null || echo 0)"

    evc="$(echo "$body" | python3 -c "import json,sys;print(json.load(sys.stdin).get('eval_count','?'))" 2>/dev/null || echo '?')"

    if (( after > before )) || (( ! api_ok )); then
        (( crashes++ ))
        [[ -z "$first_crash" ]] && first_crash="$r"
        echo "  run $r: CRASH (api_ok=$api_ok, crash_lines +$((after-before)), eval_count=$evc)" | tee -a "$results"
        # A crash kills the model runner; the serve parent may survive but is
        # in an unknown state, so stop here rather than measure a poisoned rate.
        kill -0 "$serve_pid" 2>/dev/null || { echo "  serve parent also died" | tee -a "$results"; break; }
        echo "  (serve parent alive; stopping to avoid a poisoned rate)" | tee -a "$results"
        break
    fi
    echo "  run $r: ok (eval_count=$evc)" | tee -a "$results"
done

echo "=== SUMMARY: $crashes crash(es) in up to $runs runs; first at run ${first_crash:-none} ===" | tee -a "$results"
