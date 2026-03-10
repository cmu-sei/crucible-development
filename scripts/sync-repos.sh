#!/usr/bin/env bash

set -euo pipefail

MANIFEST=scripts/repos.json
LOCAL_MANIFEST=scripts/repos.local.json
ROOT_DIR="/mnt/data/crucible"
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

# Function to map Moodle plugin names to hierarchical paths
map_moodle_plugin_path() {
    local plugin_name="$1"
    local base_path="$2"
    local plugin_type=$(echo "$plugin_name" | cut -d '_' -f 1)
    local plugin_subdir=$(echo "$plugin_name" | cut -d '_' -f 2-)

    case "$plugin_type" in
        mod) echo "$base_path/mod/$plugin_subdir" ;;
        block) echo "$base_path/blocks/$plugin_subdir" ;;
        tool) echo "$base_path/admin/tool/$plugin_subdir" ;;
        logstore) echo "$base_path/admin/tool/log/store/$plugin_subdir" ;;
        local) echo "$base_path/local/$plugin_subdir" ;;
        qtype) echo "$base_path/question/type/$plugin_subdir" ;;
        qbehaviour) echo "$base_path/question/behaviour/$plugin_subdir" ;;
        qformat) echo "$base_path/question/format/$plugin_subdir" ;;
        aiplacement) echo "$base_path/ai/placement/$plugin_subdir" ;;
        aiprovider) echo "$base_path/ai/provider/$plugin_subdir" ;;
        gradereport) echo "$base_path/grade/report/$plugin_subdir" ;;
        theme) echo "$base_path/theme/$plugin_subdir" ;;
        # Default: use flat structure for non-Moodle plugins or unknown types
        *) echo "$base_path/$plugin_name" ;;
    esac
}

sync_repository() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        echo "Repository not found: $dir (skipping)"
        return 0
    fi

    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [[ "$USE_PULL" == true ]]; then
            echo "Pulling updates in $dir"
            if ! git -C "$dir" pull "${GIT_ARGS[@]}"; then
                echo -e "\033[31mError: Failed to pull in $dir\033[0m" >&2
                return 0
            fi
        else
            echo "Fetching updates in $dir"
            if ! git -C "$dir" fetch "${GIT_ARGS[@]}"; then
                echo -e "\033[31mError: Failed to fetch in $dir\033[0m" >&2
                return 0
            fi
        fi
        return 0
    fi
    echo "Skipping $dir (not a git repository)"
    return 0
}

# Merge repos.json and repos.local.json if local exists
if [ -f "$LOCAL_MANIFEST" ]; then
    echo "Merging local repository configuration..."
    MANIFEST_DATA=$(jq -s '
        .[0] as $base | .[1] as $local |
        {
            groups: ($base.groups + ($local.groups // [])),
            repos: ($base.repos + ($local.repos // []))
        }
    ' "$MANIFEST" "$LOCAL_MANIFEST")
else
    MANIFEST_DATA=$(cat "$MANIFEST")
fi

# Sync grouped repos
echo "$MANIFEST_DATA" | jq -c '.groups[]' | while read group; do
    GROUP=$(echo $group | jq -r .name)

    echo "$group" | jq -c '.repos[]' | while read -r repo; do
        NAME=$(echo $repo | jq -r .name)

        # Use hierarchical structure for moodle plugins
        if [ "$GROUP" = "moodle" ]; then
            TARGET=$(map_moodle_plugin_path "$NAME" "$ROOT_DIR/$GROUP")
        else
            TARGET="$ROOT_DIR/$GROUP/$NAME"
        fi

        sync_repository "$TARGET"
    done
done

# Sync root-level repos
echo "$MANIFEST_DATA" | jq -c '.repos[]' | while read -r repo; do
    NAME=$(echo "$repo" | jq -r .name)
    TARGET="$ROOT_DIR/$NAME"

    sync_repository "$TARGET"
done
