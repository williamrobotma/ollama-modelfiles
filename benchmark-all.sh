#!/usr/bin/env bash
# Unified benchmark runner for the Qwen, Gemma, and 9B-coders suites.
# This script executes the suites sequentially. If one suite fails,
# the others will still be attempted.

set -euo pipefail

usage() {
    cat <<EOF
Usage: ./benchmark-all.sh [options]

Set up or run all benchmark suites (Qwen, Gemma, 9B-coders) against Ollama models.

The benchmark matrix is evaluated across isolated runtime profiles defined in
benchmark-qwen.runtime.tsv, benchmark-gemma.runtime.tsv, and
benchmark-9b-coders.runtime.tsv.
The default profiles A/B the current GGML_CUDA_DISABLE_GRAPHS=1 setting against a graphs-enabled run on a separate Ollama host.

By default this is a dry run: it prints the benchmark plan for both suites,
but does not invoke Ollama.

Options:
  --execute                 Run the benchmark instead of printing the plan.
  --list                    Print the model matrix and prompt files for both suites, then exit.
  --matrix PATH             Override the model matrix TSV file for Qwen.
  --runtime-matrix PATH     Override the runtime profile TSV file for Qwen.
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
    benchmark-gemma.matrix.tsv
    benchmark-gemma.runtime.tsv
    prompts/benchmark-qwen.prompt.*.txt
    prompts/benchmark-gemma.prompt.*.txt
    <runtime-profile>/profile.txt
    <runtime-profile>/ollama-serve.log
    <runtime-profile>/server-state.txt
    <runtime-profile>/<model>/<prompt>/warmup.log
    <runtime-profile>/<model>/<prompt>/run-<n>.log
    <runtime-profile>/<model>/<prompt>/run-<n>.time
EOF
}

# Use ${1:-} to avoid "unbound variable" errors with set -u
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Capture execute flag
execute=0
if [[ "${1:-}" == "--execute" ]]; then
    execute=1
    shift
fi

# Helper to run a suite and ignore its exit status for the next one
run_suite() {
    local suite_script="$1"
    local flag="$2"
    echo "--- Starting $suite_script ---"
    # Run the script. We use a subshell to capture the exit code but
    # don't let it stop the main script.
    if ! "$suite_script" $flag; then
        echo "Warning: $suite_script finished with an error. Proceeding to next suite..." >&2
    fi
    echo "--- Finished $suite_script ---"
    echo
}

if [[ "$execute" -eq 1 ]]; then
    run_suite "./benchmark-qwen.sh" --execute
    run_suite "./benchmark-gemma.sh" --execute
    run_suite "./benchmark-9b-coders.sh" --execute
else
    echo "Dry run only. Pass --execute to run the benchmark."
    echo
    # Just print the plans by calling the scripts without --execute
    echo "--- Qwen Plan ---"
    bash "./benchmark-qwen.sh"
    echo
    echo "--- Gemma Plan ---"
    bash "./benchmark-gemma.sh"
    echo
    echo "--- 9B-Coders Plan ---"
    bash "./benchmark-9b-coders.sh"
fi
