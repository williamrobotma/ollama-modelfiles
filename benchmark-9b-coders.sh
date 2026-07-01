#!/usr/bin/env bash
# Entry point for the 9B-coders benchmark suite — small coders that fit fully in
# the 12 GB RTX 4070 (Qwen3.5-9B, the Qwopus3.5-9B-Coder finetune, vs the
# gemma4-12b-it-qat baseline). The harness logic lives in benchmark-common.sh;
# this wrapper only selects the suite, which picks the
# benchmark-9b-coders.{matrix,runtime}.tsv and benchmark-9b-coders.prompt.*.txt
# files.
suite="9b-coders"
source "$(dirname -- "${BASH_SOURCE[0]}")/benchmark-common.sh"
