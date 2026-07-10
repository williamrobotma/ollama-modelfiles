#!/usr/bin/env bash
set -euo pipefail

target="${1:-.}"

declare -A built=()

from_target() {
    awk 'tolower($1) == "from" { print $2; exit }' "$1"
}

build_modelfile() {
    local modelfile="$1"
    local base from dep

    [[ -n "${built[$modelfile]:-}" ]] && return

    # FROM names a sibling alias Modelfile to build first; a remote hf.co ref
    # yields a nonexistent path, so -f below rejects it.
    from="$(from_target "$modelfile")"
    if [[ -n "$from" ]]; then
        dep="$(dirname "$modelfile")/Modelfile.$from"
        if [[ -f "$dep" ]]; then
            build_modelfile "$dep"
        fi
    fi

    base="${modelfile##*/}"
    echo "Building ${base} → ${base#Modelfile.}"
    ollama create "${base#Modelfile.}" -f "$modelfile"
    built["$modelfile"]=1
}

if [[ -f "$target" ]]; then
    build_modelfile "$target"
else
    for modelfile in "$target"/Modelfile.*; do
        [[ -f "$modelfile" ]] || continue
        build_modelfile "$modelfile"
    done
fi
