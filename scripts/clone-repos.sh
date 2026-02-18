#!/bin/bash
set -euo pipefail

MANIFEST=scripts/repos.json
LOCAL_MANIFEST=scripts/repos.local.json

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
        theme) echo "$base_path/theme/$plugin_subdir" ;;
        # Default: use flat structure for non-Moodle plugins or unknown types
        *) echo "$base_path/$plugin_name" ;;
    esac
}

# Merge repos.json and repos.local.json if local exists
if [ -f "$LOCAL_MANIFEST" ]; then
    echo "Merging local repository configuration..."
    MERGED=$(jq -s '
        .[0] as $base | .[1] as $local |
        {
            groups: ($base.groups + ($local.groups // [])),
            repos: ($base.repos + ($local.repos // []))
        }
    ' "$MANIFEST" "$LOCAL_MANIFEST")
    MANIFEST_DATA="$MERGED"
else
    MANIFEST_DATA=$(cat "$MANIFEST")
fi

echo "$MANIFEST_DATA" | jq -c '.groups[]' | while read group; do
    GROUP=$(echo $group | jq -r .name)

    echo "$group" | jq -c '.repos[]' | while read -r repo; do
        NAME=$(echo $repo | jq -r .name)
        URL=$(echo $repo | jq -r .url)

        # Use hierarchical structure for moodle plugins
        if [ "$GROUP" = "moodle" ]; then
            TARGET=$(map_moodle_plugin_path "$NAME" "/mnt/data/crucible/$GROUP")
        else
            TARGET="/mnt/data/crucible/$GROUP/$NAME"
        fi

        mkdir -p "$(dirname "$TARGET")"

        if [ ! -d "$TARGET" ]; then
            echo "Cloning $NAME to $TARGET..."
            git clone "$URL" "$TARGET"
        else
            echo "$NAME already exists at $TARGET, skipping."
        fi
    done
done

echo "$MANIFEST_DATA" | jq -c '.repos[]' | while read -r repo; do
    NAME=$(echo "$repo" | jq -r .name)
    URL=$(echo "$repo" | jq -r .url)
    TARGET="/mnt/data/crucible/$NAME"

    mkdir -p "$(dirname "$TARGET")"

    if [ ! -d "$TARGET" ]; then
        echo "Cloning $NAME..."
        git clone "$URL" "$TARGET"
    else
        echo "$NAME already exists, skipping."
    fi
done
