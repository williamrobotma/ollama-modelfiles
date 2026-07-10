#!/usr/bin/env bash
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

# Map every model name to its Modelfile path up front, so a FROM dependency
# lookup doesn't need to re-split names into family/stem (ambiguous: qwen3.5
# vs qwen3.6 share a "qwen3." prefix).
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

    # FROM naming another local model (matches a name_to_path key) is an alias
    # dependency and must be built first; an absolute path or hf.co ref has no
    # entry in the map and is left to ollama create itself.
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
