#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
matrix_file="$script_dir/benchmark-qwen.matrix.tsv"
runtime_file="$script_dir/benchmark-qwen.runtime.tsv"
output_root="$script_dir/benchmark-results"
keepalive="30m"
server_keepalive="24h"
server_context_length="131072"
server_flash_attention="1"
server_kv_cache_type="q8_0"
time_format=$'wall_clock_seconds=%e\nmax_rss_kb=%M\nexit_status=%x'
repetitions=2
warmup=1
execute=0
list_only=0
server_start_timeout=60
active_server_pid=""
active_server_log=""

declare -a server_env_args=()

usage() {
    cat <<'EOF'
Usage: ./benchmark-qwen.sh [options]

Set up or run a fixed Qwen benchmark matrix against Ollama models.

The benchmark matrix is evaluated across isolated runtime profiles defined in
benchmark-qwen.runtime.tsv. The default profiles A/B the current
GGML_CUDA_DISABLE_GRAPHS=1 setting against a graphs-enabled run on a separate
Ollama host.

By default this is a dry run: it prints the benchmark plan and the exact commands
it would execute, but does not invoke Ollama.

Options:
  --execute                 Run the benchmark instead of printing the plan.
  --list                    Print the model matrix and prompt files, then exit.
  --matrix PATH             Override the model matrix TSV file.
  --runtime-matrix PATH     Override the runtime profile TSV file.
  --output-dir PATH         Override the benchmark output directory.
  --keepalive DURATION      Keepalive passed to ollama run (default: 30m).
  --repetitions N           Number of measured runs per model/prompt (default: 2).
  --no-warmup               Skip the warmup run for each model/prompt pair.
  -h, --help                Show this help text.

Output layout when executed:
  benchmark-results/<timestamp>/
    manifest.txt
    system.txt
    benchmark-qwen.matrix.tsv
    benchmark-qwen.runtime.tsv
    prompts/benchmark-qwen.prompt.*.txt
    <runtime-profile>/profile.txt
    <runtime-profile>/ollama-serve.log
    <runtime-profile>/server-state.txt
    <runtime-profile>/<model>/<prompt>/warmup.log
    <runtime-profile>/<model>/<prompt>/run-<n>.log
    <runtime-profile>/<model>/<prompt>/run-<n>.time
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

cleanup_server() {
    if [[ -n "$active_server_pid" ]]; then
        kill "$active_server_pid" >/dev/null 2>&1 || true
        wait "$active_server_pid" >/dev/null 2>&1 || true
        active_server_pid=""
        active_server_log=""
    fi
}

trap cleanup_server EXIT

prompt_files() {
    local prompt
    shopt -s nullglob
    for prompt in "$script_dir"/benchmark-qwen.prompt.*.txt; do
        printf '%s\n' "$prompt"
    done | sort
    shopt -u nullglob
}

prompt_name() {
    local prompt_file="$1"
    local base
    base="${prompt_file##*/}"
    base="${base#benchmark-qwen.prompt.}"
    printf '%s\n' "${base%.txt}"
}

model_exists() {
    local host="$1"
    local model="$2"
    env "OLLAMA_HOST=$host" ollama show "$model" >/dev/null 2>&1
}

print_quoted_command() {
    local arg
    for arg in "$@"; do
        printf '%q ' "$arg"
    done
    printf '\n'
}

print_prompt_run_command() {
    local host="$1"
    local keepalive_value="$2"
    local model="$3"
    local prompt_file="$4"

    printf 'PROMPT_FILE=%q; env OLLAMA_HOST=%q ollama run --verbose --keepalive %q %q "$(< \"$PROMPT_FILE\")"\n' \
        "$prompt_file" "$host" "$keepalive_value" "$model"
}

print_timed_prompt_command() {
    local host="$1"
    local keepalive_value="$2"
    local model="$3"
    local prompt_file="$4"
    local run_time="$5"

    printf 'PROMPT_FILE=%q; /usr/bin/time -f %q -o %q env OLLAMA_HOST=%q ollama run --verbose --keepalive %q %q "$(< \"$PROMPT_FILE\")"\n' \
        "$prompt_file" "$time_format" "$run_time" "$host" "$keepalive_value" "$model"
}

build_server_env() {
    local host="$1"
    local cuda_graphs="$2"

    server_env_args=(
        env
        "OLLAMA_HOST=$host"
        "OLLAMA_CONTEXT_LENGTH=$server_context_length"
        "OLLAMA_KEEP_ALIVE=$server_keepalive"
        "OLLAMA_FLASH_ATTENTION=$server_flash_attention"
        "OLLAMA_KV_CACHE_TYPE=$server_kv_cache_type"
    )

    case "$cuda_graphs" in
        disabled)
            server_env_args+=("GGML_CUDA_DISABLE_GRAPHS=1")
            ;;
        enabled)
            ;;
        *)
            die "unknown cuda_graphs runtime value: $cuda_graphs"
            ;;
    esac
}

wait_for_server() {
    local host="$1"
    local timeout="$2"
    local server_pid="$3"
    local server_log="$4"
    local deadline=$((SECONDS + timeout))

    while (( SECONDS < deadline )); do
        if env "OLLAMA_HOST=$host" ollama ps >/dev/null 2>&1; then
            return 0
        fi
        if ! kill -0 "$server_pid" >/dev/null 2>&1; then
            die "Ollama server for $host exited before becoming ready; see $server_log"
        fi
        sleep 1
    done

    die "timed out waiting for Ollama server on $host; see $server_log"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --execute)
            execute=1
            ;;
        --list)
            list_only=1
            ;;
        --matrix)
            [[ $# -ge 2 ]] || die "--matrix requires a path"
            matrix_file="$2"
            shift
            ;;
        --runtime-matrix)
            [[ $# -ge 2 ]] || die "--runtime-matrix requires a path"
            runtime_file="$2"
            shift
            ;;
        --output-dir)
            [[ $# -ge 2 ]] || die "--output-dir requires a path"
            output_root="$2"
            shift
            ;;
        --keepalive)
            [[ $# -ge 2 ]] || die "--keepalive requires a duration"
            keepalive="$2"
            shift
            ;;
        --repetitions)
            [[ $# -ge 2 ]] || die "--repetitions requires an integer"
            repetitions="$2"
            shift
            ;;
        --no-warmup)
            warmup=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
    shift
done

[[ -f "$matrix_file" ]] || die "matrix file not found: $matrix_file"
[[ -f "$runtime_file" ]] || die "runtime matrix file not found: $runtime_file"
[[ "$repetitions" =~ ^[1-9][0-9]*$ ]] || die "--repetitions must be a positive integer"

mapfile -t prompts < <(prompt_files)
[[ ${#prompts[@]} -gt 0 ]] || die "no benchmark prompt files found in $script_dir"

mapfile -t matrix_rows < <(awk 'BEGIN { FS="\t" } $0 !~ /^#/ && NF >= 4 { print $0 }' "$matrix_file")
[[ ${#matrix_rows[@]} -gt 0 ]] || die "no benchmark rows found in $matrix_file"

mapfile -t runtime_rows < <(awk 'BEGIN { FS="\t" } $0 !~ /^#/ && NF >= 4 { print $0 }' "$runtime_file")
[[ ${#runtime_rows[@]} -gt 0 ]] || die "no runtime rows found in $runtime_file"

if [[ "$list_only" -eq 1 ]]; then
    echo "Runtime profiles:"
    for runtime_row in "${runtime_rows[@]}"; do
        IFS=$'\t' read -r profile host cuda_graphs description <<<"$runtime_row"
        printf '  %s (%s, host=%s, %s)\n' "$profile" "$cuda_graphs" "$host" "$description"
    done
    echo

    echo "Models:"
    printf '  %s\n' "${matrix_rows[@]%%$'\t'*}"
    echo
    echo "Prompts:"
    printf '  %s\n' "${prompts[@]##*/}"
    exit 0
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output_dir="$output_root/$timestamp"

echo "Benchmark plan"
echo "  matrix: $matrix_file"
echo "  runtime_matrix: $runtime_file"
echo "  runtime_profiles: ${#runtime_rows[@]}"
echo "  prompts: ${#prompts[@]}"
echo "  repetitions: $repetitions"
echo "  warmup: $warmup"
echo "  keepalive: $keepalive"
echo "  output_dir: $output_dir"
echo
echo "For clean A/B results, stop or idle the systemd Ollama service before --execute."
echo

if [[ "$execute" -eq 0 ]]; then
    echo "Dry run only. Pass --execute to run the benchmark."
    echo
else
    mkdir -p "$output_dir/prompts"
    cp "$matrix_file" "$output_dir/benchmark-qwen.matrix.tsv"
    cp "$runtime_file" "$output_dir/benchmark-qwen.runtime.tsv"
    for prompt_file in "${prompts[@]}"; do
        cp "$prompt_file" "$output_dir/prompts/"
    done

    {
        printf 'timestamp=%s\n' "$timestamp"
        printf 'matrix_file=%s\n' "$matrix_file"
        printf 'runtime_file=%s\n' "$runtime_file"
        printf 'runtime_profiles=%s\n' "${#runtime_rows[@]}"
        printf 'keepalive=%s\n' "$keepalive"
        printf 'server_keepalive=%s\n' "$server_keepalive"
        printf 'server_context_length=%s\n' "$server_context_length"
        printf 'server_flash_attention=%s\n' "$server_flash_attention"
        printf 'server_kv_cache_type=%s\n' "$server_kv_cache_type"
        printf 'repetitions=%s\n' "$repetitions"
        printf 'warmup=%s\n' "$warmup"
        printf 'models=%s\n' "${#matrix_rows[@]}"
        printf 'prompts=%s\n' "${#prompts[@]}"
    } > "$output_dir/manifest.txt"

    {
        ollama --version
        printf '\n'
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    } > "$output_dir/system.txt"
fi

for runtime_row in "${runtime_rows[@]}"; do
    IFS=$'\t' read -r profile host cuda_graphs description <<<"$runtime_row"
    profile_dir="$output_dir/$profile"

    echo "Runtime profile: $profile ($cuda_graphs, host=$host, $description)"
    build_server_env "$host" "$cuda_graphs"
    echo "  Server:"
    print_quoted_command "${server_env_args[@]}" ollama serve

    if [[ "$execute" -eq 1 ]]; then
        mkdir -p "$profile_dir"
        {
            printf 'profile=%s\n' "$profile"
            printf 'host=%s\n' "$host"
            printf 'cuda_graphs=%s\n' "$cuda_graphs"
            printf 'description=%s\n' "$description"
        } > "$profile_dir/profile.txt"

        active_server_log="$profile_dir/ollama-serve.log"
        "${server_env_args[@]}" ollama serve > "$active_server_log" 2>&1 &
        active_server_pid=$!
        wait_for_server "$host" "$server_start_timeout" "$active_server_pid" "$active_server_log"

        {
            env "OLLAMA_HOST=$host" ollama ps || true
        } > "$profile_dir/server-state.txt"

        for row in "${matrix_rows[@]}"; do
            IFS=$'\t' read -r model _ <<<"$row"
            model_exists "$host" "$model" || die "model is not built locally on $host: $model"
        done
    fi

    for row in "${matrix_rows[@]}"; do
        IFS=$'\t' read -r model family mode quant approx_size <<<"$row"
        echo "  Model: $model ($family, $mode, $quant, $approx_size)"

        for prompt_file in "${prompts[@]}"; do
            prompt_label="$(prompt_name "$prompt_file")"
            model_dir="$profile_dir/$model/$prompt_label"

            if [[ "$execute" -eq 1 ]]; then
                mkdir -p "$model_dir"
                prompt_text="$(<"$prompt_file")"
            fi

            if [[ "$warmup" -eq 1 ]]; then
                warmup_log="$model_dir/warmup.log"
                echo "    Warmup: $prompt_label"
                print_prompt_run_command "$host" "$keepalive" "$model" "$prompt_file"
                if [[ "$execute" -eq 1 ]]; then
                    env "OLLAMA_HOST=$host" ollama run --verbose --keepalive "$keepalive" "$model" "$prompt_text" >"$warmup_log" 2>&1
                fi
            fi

            for run in $(seq 1 "$repetitions"); do
                run_log="$model_dir/run-$run.log"
                run_time="$model_dir/run-$run.time"
                echo "    Run $run: $prompt_label"
                print_timed_prompt_command "$host" "$keepalive" "$model" "$prompt_file" "$run_time"
                if [[ "$execute" -eq 1 ]]; then
                    /usr/bin/time -f "$time_format" -o "$run_time" \
                        env "OLLAMA_HOST=$host" ollama run --verbose --keepalive "$keepalive" "$model" "$prompt_text" >"$run_log" 2>&1
                fi
            done
        done
    done

    if [[ "$execute" -eq 1 ]]; then
        cleanup_server
    fi
done

if [[ "$execute" -eq 0 ]]; then
    exit 0
fi

echo "Benchmark complete: $output_dir"