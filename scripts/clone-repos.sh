#!/bin/bash
set -euo pipefail

MANIFEST=scripts/repos.json
LOCAL_MANIFEST=scripts/repos.local.json

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
        TARGET="/mnt/data/crucible/$GROUP/$NAME"

        if [ ! -d "$TARGET" ]; then
            echo "Cloning $NAME..."
            git clone "$URL" "$TARGET"
        else
            echo "$NAME already exists, skipping."
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
