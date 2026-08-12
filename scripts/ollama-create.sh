#!/usr/bin/env bash
# Legacy Ollama build layer (frozen until the Phase 4 purge).
# Usage: scripts/ollama-create.sh [modelfiles/<family>/<stem>]
#   No arg = build all. Canonical -> layered -> alias order is automatic:
#   an alias builds its canonical dependency first.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
modelfiles_root="$repo_root/modelfiles"

target="${1:-$modelfiles_root}"
if [[ -e "$target" ]]; then
    target="$(cd -- "$(dirname -- "$target")" && pwd)/$(basename -- "$target")"
fi

declare -A built=()
declare -A name_to_path=()

# model name = "<family>-<stem>" from modelfiles/<family>/<stem>/Modelfile
model_name_for() {
    local stem_dir family stem
    stem_dir="$(dirname "$1")"
    family="$(basename "$(dirname "$stem_dir")")"
    stem="$(basename "$stem_dir")"
    printf '%s-%s\n' "$family" "$stem"
}

# Name -> path map up front: FROM lookups must not re-split names into
# family/stem (qwen3.5 vs qwen3.6 share the "qwen3." prefix).
while IFS= read -r modelfile; do
    name_to_path["$(model_name_for "$modelfile")"]="$modelfile"
done < <(find "$modelfiles_root" -name Modelfile | sort)

from_target() {
    awk 'tolower($1) == "from" { print $2; exit }' "$1"
}

build_modelfile() {
    local modelfile="$1"
    local name from

    [[ -n "${built[$modelfile]:-}" ]] && return

    name="$(model_name_for "$modelfile")"

    # A FROM matching a local model name is an alias dependency: build it
    # first. Absolute paths and hf.co refs are left to ollama create itself.
    from="$(from_target "$modelfile")"
    if [[ -n "$from" && -n "${name_to_path[$from]:-}" ]]; then
        build_modelfile "${name_to_path[$from]}"
    fi

    echo "Building ${modelfile#"$repo_root"/} -> ${name}"
    ollama create "$name" -f "$modelfile"
    built["$modelfile"]=1
}

if [[ -f "$target" ]]; then
    build_modelfile "$target"
elif [[ -d "$target" ]]; then
    while IFS= read -r modelfile; do
        build_modelfile "$modelfile"
    done < <(find "$target" -name Modelfile | sort)
else
    echo "error: not found: $target" >&2
    exit 1
fi
