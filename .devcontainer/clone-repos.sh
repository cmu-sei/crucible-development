#!/bin/bash
set -euo pipefail

MANIFEST=.devcontainer/repos.json

jq -c '.groups[]' "$MANIFEST" | while read -r group; do
    GROUP=$(echo "$group" | jq -r .name)
    REPO_COUNT=$(echo "$group" | jq '.repos | length')

    echo "$group" | jq -c '.repos[]' | while read -r repo; do
        NAME=$(echo "$repo" | jq -r .name)
        URL=$(echo "$repo" | jq -r .url)

        if [ "$REPO_COUNT" -eq 1 ]; then
            TARGET="/mnt/data/crucible/$GROUP"
        else
            TARGET="/mnt/data/crucible/$GROUP/$NAME"
        fi

        mkdir -p "$(dirname "$TARGET")"

        if [ ! -d "$TARGET" ]; then
            echo "Cloning $NAME..."
            git clone "$URL" "$TARGET"
        else
            echo "$NAME already exists, skipping."
        fi
    done
done
