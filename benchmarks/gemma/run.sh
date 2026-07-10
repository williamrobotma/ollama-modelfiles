#!/usr/bin/env bash
# Entry point for the Gemma benchmark suite. The harness logic lives in
# ../common.sh; this wrapper only selects the suite, which picks this
# directory's matrix.tsv, runtime.tsv, and prompts/*.txt files.
suite="gemma"
suite_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$suite_dir/../common.sh"
