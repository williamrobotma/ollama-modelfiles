#!/usr/bin/env bash
# Entry point for the 9B-coders benchmark suite - small coders that fit fully in
# the 12 GB RTX 4070 (Qwen3.5-9B, the Qwopus3.5-9B-Coder finetune, vs the
# gemma4-12b-it-qat baseline). The harness logic lives in ../common.sh; this
# wrapper only selects the suite, which picks this directory's
# matrix.tsv, runtime.tsv, and prompts/*.txt files.
suite="9b-coders"
suite_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$suite_dir/../common.sh"
