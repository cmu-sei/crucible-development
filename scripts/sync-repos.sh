#!/usr/bin/env bash

set -euo pipefail

MANIFEST=scripts/repos.json
LOCAL_MANIFEST=scripts/repos.local.json
ROOT_DIR="/mnt/data/crucible"
USE_PULL=false
PURGE=false
GIT_ARGS=()

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" == "--pull" ]]; then
        USE_PULL=true
    elif [[ "$arg" == "--purge" ]]; then
        PURGE=true
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

# Delete local branches whose upstream tracking branch has been removed from
# the remote (i.e. marked "[gone]" by git after a --prune fetch).
purge_local_branches() {
    local dir=$1
    local current
    current=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "")

    local gone_branches
    gone_branches=$(git -C "$dir" branch -vv | { grep ': gone]' || true; } | \
        awk '{ if ($1 == "*" || $1 == "+") print $2; else print $1 }')

    if [[ -z "$gone_branches" ]]; then
        return 0
    fi

    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue
        if [[ "$branch" == "$current" ]]; then
            echo "Skipping current branch $branch in $dir (remote gone, but checked out)"
            continue
        fi
        if git -C "$dir" worktree list 2>/dev/null | grep -q "\[$branch\]"; then
            echo "Skipping branch $branch in $dir (remote gone, but checked out in another worktree)"
            continue
        fi
        local err_file
        err_file=$(mktemp)
        if git -C "$dir" branch -d "$branch" 2>"$err_file"; then
            echo "Deleted local branch $branch in $dir (remote gone)"
        elif grep -q "not fully merged" "$err_file"; then
            echo "Skipping branch $branch in $dir (remote gone, but has unmerged commits - delete manually with 'git branch -D' if intentional)"
        else
            cat "$err_file" >&2
            echo -e "\033[31mError: Failed to delete branch $branch in $dir\033[0m" >&2
        fi
        rm -f "$err_file"
    done <<< "$gone_branches"
}

sync_repository() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        echo "Repository not found: $dir (skipping)"
        return 0
    fi

    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local git_args=("${GIT_ARGS[@]}")
        if [[ "$PURGE" == true ]]; then
            git_args+=("--prune")
        fi

        if [[ "$USE_PULL" == true ]]; then
            echo "Pulling updates in $dir"
            if ! git -C "$dir" pull "${git_args[@]}"; then
                echo -e "\033[31mError: Failed to pull in $dir\033[0m" >&2
                return 0
            fi
        else
            echo "Fetching updates in $dir"
            if ! git -C "$dir" fetch "${git_args[@]}"; then
                echo -e "\033[31mError: Failed to fetch in $dir\033[0m" >&2
                return 0
            fi
        fi

        if [[ "$PURGE" == true ]]; then
            purge_local_branches "$dir"
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
