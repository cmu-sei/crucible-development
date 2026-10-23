#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# One-time jira-cli setup. jira init never asks for the API token: it verifies the login with
# JIRA_API_TOKEN, and the container has no keyring to fall back on. So this saves the token to the
# crucible-dev-jira volume, where new shells export it from (see the Dockerfile's .zshrc lines),
# then runs jira init with it. Arguments are passed through to jira init.
set -euo pipefail

TOKEN_FILE="$HOME/.config/.jira/token"

if [ -s "$TOKEN_FILE" ]; then
    prompt="Jira API token (Enter keeps the saved one): "
else
    prompt="Jira API token: "
fi

# -s keeps the token off the screen and out of the persisted shell history
read -rsp "$prompt" token
echo

if [ -n "$token" ]; then
    (umask 077 && printf '%s' "$token" > "$TOKEN_FILE")
    echo "Saved the token to $TOKEN_FILE" >&2
elif [ ! -s "$TOKEN_FILE" ]; then
    echo "No token entered" >&2
    exit 1
fi

JIRA_API_TOKEN="$(cat "$TOKEN_FILE")" jira init "$@"

echo "Done. Shells opened from now on have JIRA_API_TOKEN; in this one, run: exec zsh" >&2
