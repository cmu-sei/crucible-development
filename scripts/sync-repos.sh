#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/mnt/data/crucible"
MAX_DEPTH=2
USE_PULL=false
GIT_ARGS=()

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" == "--pull" ]]; then
        USE_PULL=true
    else
        GIT_ARGS+=("$arg")
    fi
done

if [[ ! -d "$ROOT_DIR" ]]; then
    echo "Directory not found: $ROOT_DIR" >&2
    exit 1
fi

sync_repository() {
    local dir=$1
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [[ "$USE_PULL" == true ]]; then
            echo "Pulling updates in $dir"
            git -C "$dir" pull "${GIT_ARGS[@]}"
        else
            echo "Fetching updates in $dir"
            git -C "$dir" fetch "${GIT_ARGS[@]}"
        fi
        return 0
    fi
    return 1
}

# Traverse directories up to MAX_DEPTH and stop descending once a repo is synced.
traverse_directory() {
    local dir=$1
    local depth=$2

    if sync_repository "$dir"; then
        return 0
    fi

    if (( depth >= MAX_DEPTH )); then
        echo "Skipping $dir (not a git repository)"
        return 1
    fi

    local repo_found=1

    while IFS= read -r -d '' subdir; do
        if traverse_directory "$subdir" $((depth + 1)); then
            repo_found=0
        fi
    done < <(
        find "$dir" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -not -path '*/.git*' \
            -print0
    )

    if (( repo_found )); then
        echo "Skipping $dir (not a git repository)"
        return 1
    fi

    return 0
}

while IFS= read -r -d '' path; do
    traverse_directory "$path" 1
done < <(
    find "$ROOT_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -not -path '*/.git*' \
        -print0
)
