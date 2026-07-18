#!/usr/bin/env bash
# llama.cpp vs Ollama decode-throughput parity suite (specs/llamacpp-serving,
# option C eval). Self-contained: benchmarks/common.sh is Ollama-A/B-specific,
# so this mirrors its CLI and output conventions instead of sourcing it.
# Dry-run by default: prints the plan and the exact commands, runs nothing.
set -euo pipefail

suite_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$suite_dir/../.." && pwd)"
matrix_file="$suite_dir/matrix.tsv"
runtime_file="$suite_dir/runtime.tsv"
output_root="$repo_root/benchmark-results"
llama_bin="${LLAMA_SERVER_BIN:-$HOME/Developer/llama.cpp/build/bin/llama-server}"

readonly server_keepalive="24h"
readonly timestamp_format="%Y%m%dT%H%M%SZ"
readonly server_models_dir="/usr/share/ollama/.ollama/models"
readonly ollama_start_timeout=60
readonly llama_start_timeout=300  # cold ~7 GB GGUF reads from the vhdx are slow
readonly predict_cap=65536        # mirrors the Modelfiles' num_predict
time_format=$'wall_clock_seconds=%e\nmax_rss_kb=%M\nexit_status=%x'
repetitions=2
warmup=1
execute=0
list_only=0
active_pid=""

usage() {
    cat <<EOF
Usage: benchmarks/llamacpp-parity/run.sh [options]

Bench the same GGUFs on Ollama (isolated serve, graphs-off prod target) and
stock llama-server, per this suite's matrix.tsv and runtime.tsv. Decode tok/s
comes from each engine's own primary metrics: \`ollama run --verbose\` eval
rate, and llama-server response \`timings\`.

By default this is a dry run: it prints the plan and the exact commands it
would execute, but runs nothing.

Options:
  --execute                 Run the benchmark instead of printing the plan.
  --list                    Print profiles, models, and prompts, then exit.
  --matrix PATH             Override the model matrix TSV (partial reruns).
  --runtime-matrix PATH     Override the runtime profile TSV (partial reruns).
  --output-dir PATH         Override the benchmark output directory.
  --repetitions N           Measured runs per model/prompt (default: 2).
  --no-warmup               Skip the warmup run for each model/prompt pair.
  -h, --help                Show this help text.

Failed runs (engine crash, request error) are recorded in
<output_dir>/failed-runs.txt and the benchmark continues.

Output layout when executed (under the repo root):
  benchmark-results/<timestamp>/
    manifest.txt  system.txt  matrix.tsv  runtime.tsv  prompts/*.txt
    <profile>/ollama-serve.log                       (ollama engine)
    <profile>/<label>/server.log                     (llamacpp engine)
    <profile>/<label>/<prompt>/{warmup,run-<n>}.log
    <profile>/<label>/<prompt>/run-<n>.time
    <profile>/<label>/<prompt>/run-<n>.json          (llamacpp raw response)

Report: python3 benchmarks/llamacpp-parity/report.py benchmark-results/<ts>
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

cleanup_server() {
    if [[ -n "$active_pid" ]]; then
        kill "$active_pid" >/dev/null 2>&1 || true
        wait "$active_pid" >/dev/null 2>&1 || true
        active_pid=""
    fi
}

trap cleanup_server EXIT

print_quoted_command() {
    local arg
    for arg in "$@"; do
        printf '%q ' "$arg"
    done
    printf '\n'
}

prompt_name() {
    local base="${1##*/}"
    printf '%s\n' "${base%.txt}"
}

model_exists() {
    env "OLLAMA_HOST=$1" ollama show "$2" >/dev/null 2>&1
}

wait_ollama() {
    local host="$1" log="$2" deadline=$((SECONDS + ollama_start_timeout))
    while (( SECONDS < deadline )); do
        env "OLLAMA_HOST=$host" ollama ps >/dev/null 2>&1 && return 0
        kill -0 "$active_pid" >/dev/null 2>&1 || die "ollama serve for $host exited early; see $log"
        sleep 1
    done
    die "timed out waiting for ollama serve on $host; see $log"
}

wait_llama() {
    local port="$1" log="$2" deadline=$((SECONDS + llama_start_timeout))
    while (( SECONDS < deadline )); do
        curl -sf "http://127.0.0.1:$port/health" >/dev/null 2>&1 && return 0
        kill -0 "$active_pid" >/dev/null 2>&1 || {
            tail -5 "$log" >&2
            die "llama-server on port $port exited during load; see $log"
        }
        sleep 1
    done
    die "timed out waiting for llama-server on port $port; see $log"
}

build_request_json() {  # prompt_file system_col out_json
    python3 - "$1" "$2" > "$3" <<'PY'
import json, sys
messages = []
if sys.argv[2] != "-":
    messages.append({"role": "system", "content": sys.argv[2]})
messages.append({"role": "user", "content": open(sys.argv[1]).read()})
json.dump({"model": "parity", "messages": messages}, sys.stdout)
PY
}

extract_timings() {  # run_json out_log
    python3 - "$1" > "$2" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
t = c.get("timings") or {}
choice = (c.get("choices") or [{}])[0]
msg = choice.get("message") or {}
for k, v in (
    ("decode_tok_s", t.get("predicted_per_second")),
    ("predicted_n", t.get("predicted_n")),
    ("prompt_tok_s", t.get("prompt_per_second")),
    ("draft_n", t.get("draft_n")),
    ("draft_n_accepted", t.get("draft_n_accepted")),
    ("finish_reason", choice.get("finish_reason")),
    ("content_chars", len(msg.get("content") or "")),
    ("reasoning_chars", len(msg.get("reasoning_content") or "")),
):
    print(f"{k}={'' if v is None else v}")
PY
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --execute) execute=1 ;;
        --list) list_only=1 ;;
        --matrix)
            [[ $# -ge 2 ]] || die "--matrix requires a path"
            matrix_file="$2"; shift ;;
        --runtime-matrix)
            [[ $# -ge 2 ]] || die "--runtime-matrix requires a path"
            runtime_file="$2"; shift ;;
        --output-dir)
            [[ $# -ge 2 ]] || die "--output-dir requires a path"
            output_root="$2"; shift ;;
        --repetitions)
            [[ $# -ge 2 ]] || die "--repetitions requires an integer"
            repetitions="$2"; shift ;;
        --no-warmup) warmup=0 ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

[[ -f "$matrix_file" ]] || die "matrix file not found: $matrix_file"
[[ -f "$runtime_file" ]] || die "runtime matrix file not found: $runtime_file"
[[ "$repetitions" =~ ^[1-9][0-9]*$ ]] || die "--repetitions must be a positive integer"

shopt -s nullglob
prompts=("$suite_dir"/prompts/*.txt)
shopt -u nullglob
[[ ${#prompts[@]} -gt 0 ]] || die "no prompt files in $suite_dir/prompts"

mapfile -t matrix_rows < <(awk 'BEGIN { FS="\t" } $0 !~ /^#/ && NF >= 8 { print }' "$matrix_file")
[[ ${#matrix_rows[@]} -gt 0 ]] || die "no rows in $matrix_file"
mapfile -t runtime_rows < <(awk 'BEGIN { FS="\t" } $0 !~ /^#/ && NF >= 4 { print }' "$runtime_file")
[[ ${#runtime_rows[@]} -gt 0 ]] || die "no rows in $runtime_file"

runs=()
[[ "$warmup" -eq 1 ]] && runs+=(warmup)
for n in $(seq 1 "$repetitions"); do runs+=("run-$n"); done

if [[ "$list_only" -eq 1 ]]; then
    echo "Runtime profiles:"
    for runtime_row in "${runtime_rows[@]}"; do
        IFS=$'\t' read -r profile host engine description <<<"$runtime_row"
        printf '  %s (engine=%s, host=%s, %s)\n' "$profile" "$engine" "$host" "$description"
    done
    echo
    echo "Models (label: ollama_model | gguf basename | ctx | spec):"
    for row in "${matrix_rows[@]}"; do
        IFS=$'\t' read -r label ollama_model gguf draft_gguf ctx system sampling_flags spec_flags <<<"$row"
        printf '  %s: %s | %s | %s | %s\n' "$label" "$ollama_model" "${gguf##*/}" "$ctx" "$spec_flags"
    done
    echo
    echo "Prompts:"
    printf '  %s\n' "${prompts[@]##*/}"
    exit 0
fi

timestamp="$(date -u +"$timestamp_format")"
output_dir="$output_root/$timestamp"

echo "llama.cpp parity benchmark plan"
echo "  matrix: $matrix_file"
echo "  runtime_matrix: $runtime_file"
echo "  llama_bin: $llama_bin"
echo "  models: ${#matrix_rows[@]}  prompts: ${#prompts[@]}  repetitions: $repetitions  warmup: $warmup"
echo "  output_dir: $output_dir"
echo
echo "For clean results, idle the systemd Ollama models first (ollama ps; ollama stop <model>)."
echo

if [[ "$execute" -eq 0 ]]; then
    echo "Dry run only. Pass --execute to run the benchmark."
    echo
else
    [[ -x "$llama_bin" ]] || die "llama-server binary not found/executable: $llama_bin"
    mkdir -p "$output_dir/prompts"
    cp "$matrix_file" "$output_dir/matrix.tsv"
    cp "$runtime_file" "$output_dir/runtime.tsv"
    cp "${prompts[@]}" "$output_dir/prompts/"
    {
        printf 'timestamp=%s\nsuite=llamacpp-parity\n' "$timestamp"
        printf 'llama_bin=%s\n' "$llama_bin"
        printf 'repetitions=%s\nwarmup=%s\n' "$repetitions" "$warmup"
        printf 'models=%s\nprompts=%s\n' "${#matrix_rows[@]}" "${#prompts[@]}"
    } > "$output_dir/manifest.txt"
    {
        ollama --version
        "$llama_bin" --version 2>&1
        printf '\n'
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    } > "$output_dir/system.txt"
fi

for runtime_row in "${runtime_rows[@]}"; do
    IFS=$'\t' read -r profile host engine _ <<<"$runtime_row"
    profile_dir="$output_dir/$profile"
    echo "Runtime profile: $profile (engine=$engine, host=$host)"

    case "$engine" in
    ollama)
        server_cmd=(
            env
            "OLLAMA_HOST=$host"
            "OLLAMA_MODELS=$server_models_dir"
            # Mirrors the shared prod-target serve env; harmless even for the
            # 200k rows because Modelfile num_ctx outranks it (AGENTS.md) -
            # the matrix ctx column drives the llamacpp side only.
            "OLLAMA_CONTEXT_LENGTH=131072"
            "OLLAMA_KEEP_ALIVE=$server_keepalive"
            "OLLAMA_FLASH_ATTENTION=1"
            "OLLAMA_KV_CACHE_TYPE=q8_0"
            "GGML_CUDA_DISABLE_GRAPHS=1"
            ollama serve
        )
        echo "  Server:"
        print_quoted_command "${server_cmd[@]}"
        if [[ "$execute" -eq 1 ]]; then
            mkdir -p "$profile_dir"
            "${server_cmd[@]}" > "$profile_dir/ollama-serve.log" 2>&1 &
            active_pid=$!
            wait_ollama "$host" "$profile_dir/ollama-serve.log"
            for row in "${matrix_rows[@]}"; do
                IFS=$'\t' read -r label ollama_model _ <<<"$row"
                [[ "$ollama_model" == "-" ]] && continue
                model_exists "$host" "$ollama_model" || die "model not built on $host: $ollama_model"
            done
        fi
        for row in "${matrix_rows[@]}"; do
            IFS=$'\t' read -r label ollama_model _ <<<"$row"
            if [[ "$ollama_model" == "-" ]]; then
                echo "  Model: $label - SKIP (no ollama model)"
                continue
            fi
            echo "  Model: $label ($ollama_model)"
            for prompt_file in "${prompts[@]}"; do
                prompt_label="$(prompt_name "$prompt_file")"
                run_dir="$profile_dir/$label/$prompt_label"
                [[ "$execute" -eq 1 ]] && { mkdir -p "$run_dir"; prompt_text="$(<"$prompt_file")"; }
                for run_name in "${runs[@]}"; do
                    echo "    $run_name: $prompt_label"
                    printf 'PROMPT_FILE=%q; /usr/bin/time -f %q -o %q env OLLAMA_HOST=%q ollama run --verbose %q "$(< \"$PROMPT_FILE\")"\n' \
                        "$prompt_file" "$time_format" "$run_dir/$run_name.time" "$host" "$ollama_model"
                    if [[ "$execute" -eq 1 ]]; then
                        /usr/bin/time -f "$time_format" -o "$run_dir/$run_name.time" \
                            env "OLLAMA_HOST=$host" ollama run --verbose \
                            "$ollama_model" "$prompt_text" > "$run_dir/$run_name.log" 2>&1 \
                            || echo "$profile/$label/$prompt_label/$run_name exit=$? (runner crash? see .log)" \
                                >> "$output_dir/failed-runs.txt"
                    fi
                done
            done
        done
        [[ "$execute" -eq 1 ]] && cleanup_server
        ;;
    llamacpp)
        port="${host##*:}"
        for row in "${matrix_rows[@]}"; do
            IFS=$'\t' read -r label ollama_model gguf draft_gguf ctx system sampling_flags spec_flags <<<"$row"
            if [[ "$gguf" == "-" ]]; then
                echo "  Model: $label - SKIP (no gguf)"
                continue
            fi
            launch_cmd=("$llama_bin" -m "$gguf" --host 127.0.0.1 --port "$port"
                        -ngl 99 -np 1 -c "$ctx" -fa on -ctk q8_0 -ctv q8_0 -n "$predict_cap")
            [[ "$draft_gguf" != "-" ]] && launch_cmd+=(--spec-draft-model "$draft_gguf")
            read -ra flag_words <<<"$sampling_flags"
            launch_cmd+=("${flag_words[@]}")
            if [[ "$spec_flags" != "-" ]]; then
                read -ra flag_words <<<"$spec_flags"
                launch_cmd+=("${flag_words[@]}")
            fi
            echo "  Model: $label"
            echo "  Server:"
            print_quoted_command "${launch_cmd[@]}"
            if [[ "$execute" -eq 1 ]]; then
                [[ -f "$gguf" ]] || die "gguf not found: $gguf"
                mkdir -p "$profile_dir/$label"
                "${launch_cmd[@]}" > "$profile_dir/$label/server.log" 2>&1 &
                active_pid=$!
                wait_llama "$port" "$profile_dir/$label/server.log"
            fi
            for prompt_file in "${prompts[@]}"; do
                prompt_label="$(prompt_name "$prompt_file")"
                run_dir="$profile_dir/$label/$prompt_label"
                req_json="$run_dir/request.json"
                if [[ "$execute" -eq 1 ]]; then
                    mkdir -p "$run_dir"
                    build_request_json "$prompt_file" "$system" "$req_json"
                fi
                for run_name in "${runs[@]}"; do
                    echo "    $run_name: $prompt_label"
                    run_cmd=(/usr/bin/time -f "$time_format" -o "$run_dir/$run_name.time"
                             curl -sf --max-time 3600 "http://$host/v1/chat/completions"
                             -H 'Content-Type: application/json'
                             -d @"$req_json" -o "$run_dir/$run_name.json")
                    print_quoted_command "${run_cmd[@]}"
                    if [[ "$execute" -eq 1 ]]; then
                        if "${run_cmd[@]}"; then
                            extract_timings "$run_dir/$run_name.json" "$run_dir/$run_name.log"
                        else
                            echo "$profile/$label/$prompt_label/$run_name curl_failed (see server.log)" \
                                >> "$output_dir/failed-runs.txt"
                        fi
                        kill -0 "$active_pid" >/dev/null 2>&1 || {
                            echo "$profile/$label server DIED at $prompt_label/$run_name" \
                                >> "$output_dir/failed-runs.txt"
                            break 2
                        }
                    fi
                done
            done
            [[ "$execute" -eq 1 ]] && cleanup_server
        done
        ;;
    *)
        die "unknown engine in runtime.tsv: $engine"
        ;;
    esac
done

if [[ "$execute" -eq 1 ]]; then
    echo "Benchmark complete: $output_dir"
    echo "Report: python3 $suite_dir/report.py $output_dir"
fi
