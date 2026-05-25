#!/bin/bash
# Delete Player views matching a name pattern

set -e

VIEW_NAME_PATTERN="${1:-Proxmox VM Template}"
PLAYER_API_URL="${PLAYER_API_URL:-http://localhost:4301}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USERNAME="${KEYCLOAK_USERNAME:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo "Deleting Player views matching: $VIEW_NAME_PATTERN"

# Get Keycloak token
TOKEN_RESPONSE=$(curl -k -s -X POST "${KEYCLOAK_URL}/realms/crucible/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=player.api" \
    -d "grant_type=password" \
    -d "username=${KEYCLOAK_USERNAME}" \
    -d "password=${KEYCLOAK_PASSWORD}" \
    -d "scope=openid profile player")

KEYCLOAK_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" = "null" ]; then
    echo "Error: Failed to get Keycloak token"
    exit 1
fi

# List all views
VIEWS=$(curl -k -s -X GET "${PLAYER_API_URL}/api/views" \
    -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

# Find and delete matching views
DELETED_COUNT=0
echo "$VIEWS" | jq -r ".[] | select(.name | startswith(\"${VIEW_NAME_PATTERN}\")) | .id" | while read -r VIEW_ID; do
    if [ -n "$VIEW_ID" ]; then
        echo "Deleting view: $VIEW_ID"
        curl -k -s -X DELETE "${PLAYER_API_URL}/api/views/${VIEW_ID}" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" > /dev/null
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

if [ $DELETED_COUNT -eq 0 ]; then
    echo "No matching views found"
else
    echo "✓ Deleted $DELETED_COUNT view(s)"
fi
