#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="/mnt/data/crucible"
MAX_DEPTH=2
FETCH_ARGS=("$@")

if [[ ! -d "$ROOT_DIR" ]]; then
    echo "Directory not found: $ROOT_DIR" >&2
    exit 1
fi

fetch_repository() {
    local dir=$1
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Fetching updates in $dir"
        git -C "$dir" fetch "${FETCH_ARGS[@]}"
        return 0
    fi
    return 1
}

# Traverse directories up to MAX_DEPTH and stop descending once a repo is fetched.
traverse_directory() {
    local dir=$1
    local depth=$2

    if fetch_repository "$dir"; then
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
