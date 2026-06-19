#!/usr/bin/env bash
set -euo pipefail

target="${1:-.}"

if [[ -f "$target" ]]; then
    ollama create "${target##*/Modelfile.}" -f "$target"
else
    for modelfile in "$target"/Modelfile.*; do
        [[ -f "$modelfile" ]] || continue
        ollama create "${modelfile##*/Modelfile.}" -f "$modelfile"
    done
fi
