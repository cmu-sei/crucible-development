#!/bin/sh
set -e

INPUT_VERSION="${VERSION:-"latest"}"
VERSION_ARG=""

# Process the version if it's not "latest" or empty
if [ "${INPUT_VERSION}" != "latest" ] && [ "${INPUT_VERSION}" != "none" ] && [ -n "${INPUT_VERSION}" ]; then

    # Check if it's already a full version (e.g., 13.4.6)
    if echo "${INPUT_VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        VERSION_ARG="--version ${INPUT_VERSION}"

    # Check if it's a partial prefix (e.g., 13.4)
    elif echo "${INPUT_VERSION}" | grep -qE '^[0-9]+\.[0-9]+$'; then
        echo "Partial version prefix '${INPUT_VERSION}' detected. Resolving latest patch..."

        # Query GitHub to find the latest matching patch version
        RESOLVED_VERSION=$(curl -s https://api.github.com/repos/microsoft/aspire/releases | \
          grep -oE '"tag_name": "v[0-9]+\.[0-9]+\.[0-9]+"' | \
          cut -d'"' -f4 | sed 's/^v//' | \
          grep "^${INPUT_VERSION}\." | sort -V | tail -n1)

        if [ -n "${RESOLVED_VERSION}" ]; then
            echo "Resolved to full version: ${RESOLVED_VERSION}"
            VERSION_ARG="--version ${RESOLVED_VERSION}"
        else
            echo "Warning: Could not resolve a patch version for ${INPUT_VERSION}. Passing as-is."
            VERSION_ARG="--version ${INPUT_VERSION}"
        fi

    else
        # Fallback for pre-releases/tags (e.g., 9.5.0-preview.1.25366.3)
        VERSION_ARG="--version ${INPUT_VERSION}"
    fi
fi

# 3. Execute the command as the remote user
su - "$_REMOTE_USER" -c "curl -sSL https://aspire.dev/install.sh | bash -s -- ${VERSION_ARG}"
