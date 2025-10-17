#!/bin/bash
set -euo pipefail

MANIFEST=.devcontainer/repos.json

jq -c '.groups[]' $MANIFEST | while read group; do
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

jq -c '.repos[]' "$MANIFEST" | while read -r repo; do
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
