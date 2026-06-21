#!/usr/bin/env bash
# Entry point for the Gemma benchmark suite. The harness logic lives in
# benchmark-common.sh; this wrapper only selects the suite, which picks the
# benchmark-gemma.{matrix,runtime}.tsv and benchmark-gemma.prompt.*.txt files.
suite="gemma"
source "$(dirname -- "${BASH_SOURCE[0]}")/benchmark-common.sh"
