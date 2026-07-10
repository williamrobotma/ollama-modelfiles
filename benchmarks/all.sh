#!/usr/bin/env bash
# Runs the Qwen, Gemma, and 9B-coders benchmark suites sequentially; a failing
# suite is reported and the rest still run. Dry-run by default (prints each
# suite's plan); pass --execute to run. All per-suite options live on the suite
# scripts -- see ./benchmark-qwen.sh --help.
set -euo pipefail

usage() {
    cat <<EOF
Usage: ./benchmark-all.sh [--execute]

Run the Qwen, Gemma, and 9B-coders benchmark suites sequentially. Dry-run by
default (prints each suite's plan); pass --execute to run them.

Per-suite options (--matrix, --keepalive, --repetitions, ...) are not accepted
here; run the individual suite directly. See ./benchmark-qwen.sh --help.

Options:
  --execute     Run the benchmarks instead of printing the plans.
  -h, --help    Show this help text.
EOF
}

# ${1:-} guards against unbound $1 under set -u.
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

execute_flag=""
[[ "${1:-}" == "--execute" ]] && execute_flag="--execute"

run_suite() {
    local suite_script="$1"
    echo "--- Starting $suite_script ---"
    "$suite_script" $execute_flag \
        || echo "Warning: $suite_script exited nonzero; proceeding to next suite." >&2
    echo "--- Finished $suite_script ---"
    echo
}

if [[ -z "$execute_flag" ]]; then
    echo "Dry run only. Pass --execute to run the benchmarks."
    echo
fi

run_suite ./benchmark-qwen.sh
run_suite ./benchmark-gemma.sh
run_suite ./benchmark-9b-coders.sh
