#!/bin/bash
# Delete Caster projects matching a name pattern

set -e

PROJECT_NAME_PATTERN="${1:-Proxmox Test}"
CASTER_API_URL="${CASTER_API_URL:-http://localhost:4310}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USERNAME="${KEYCLOAK_USERNAME:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo "Deleting Caster projects matching: $PROJECT_NAME_PATTERN"

# Get Keycloak token
TOKEN_RESPONSE=$(curl -k -s -X POST "${KEYCLOAK_URL}/realms/crucible/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=caster.api" \
    -d "grant_type=password" \
    -d "username=${KEYCLOAK_USERNAME}" \
    -d "password=${KEYCLOAK_PASSWORD}" \
    -d "scope=openid profile caster")

KEYCLOAK_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" = "null" ]; then
    echo "Error: Failed to get Keycloak token"
    exit 1
fi

# List all projects
PROJECTS=$(curl -k -s -X GET "${CASTER_API_URL}/api/projects" \
    -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

# Find and delete matching projects
DELETED_COUNT=0
echo "$PROJECTS" | jq -r ".[] | select(.name | startswith(\"${PROJECT_NAME_PATTERN}\")) | .id" | while read -r PROJECT_ID; do
    if [ -n "$PROJECT_ID" ]; then
        echo "Deleting project: $PROJECT_ID"
        curl -k -s -X DELETE "${CASTER_API_URL}/api/projects/${PROJECT_ID}" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" > /dev/null
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

if [ $DELETED_COUNT -eq 0 ]; then
    echo "No matching projects found"
else
    echo "✓ Deleted $DELETED_COUNT project(s)"
fi
