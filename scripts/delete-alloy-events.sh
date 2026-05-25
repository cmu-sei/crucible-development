#!/bin/bash
# Delete Alloy events matching a name pattern

set -e

EVENT_NAME_PATTERN="${1:-Alloy Event (No Caster)}"
ALLOY_API_URL="${ALLOY_API_URL:-http://localhost:4403}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USERNAME="${KEYCLOAK_USERNAME:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo "Deleting Alloy events matching: $EVENT_NAME_PATTERN"

# Get Keycloak token
TOKEN_RESPONSE=$(curl -k -s -X POST "${KEYCLOAK_URL}/realms/crucible/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=alloy.api" \
    -d "grant_type=password" \
    -d "username=${KEYCLOAK_USERNAME}" \
    -d "password=${KEYCLOAK_PASSWORD}" \
    -d "scope=openid profile alloy")

KEYCLOAK_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" = "null" ]; then
    echo "Error: Failed to get Keycloak token"
    exit 1
fi

# List all events
EVENTS=$(curl -k -s -X GET "${ALLOY_API_URL}/api/events" \
    -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

# Find and delete matching events
DELETED_COUNT=0
echo "$EVENTS" | jq -r ".[] | select(.name | startswith(\"${EVENT_NAME_PATTERN}\")) | .id" | while read -r EVENT_ID; do
    if [ -n "$EVENT_ID" ]; then
        echo "Deleting event: $EVENT_ID"
        curl -k -s -X DELETE "${ALLOY_API_URL}/api/events/${EVENT_ID}" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" > /dev/null
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

if [ $DELETED_COUNT -eq 0 ]; then
    echo "No matching events found"
else
    echo "✓ Deleted $DELETED_COUNT event(s)"
fi
