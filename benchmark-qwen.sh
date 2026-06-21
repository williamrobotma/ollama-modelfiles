#!/usr/bin/env bash
# Entry point for the Qwen benchmark suite. The harness logic lives in
# benchmark-common.sh; this wrapper only selects the suite, which picks the
# benchmark-qwen.{matrix,runtime}.tsv and benchmark-qwen.prompt.*.txt files.
suite="qwen"
source "$(dirname -- "${BASH_SOURCE[0]}")/benchmark-common.sh"
