#!/bin/bash
# Deletes a TopoMojo workspace and all its templates

set -e

WORKSPACE_NAME="${WORKSPACE_NAME:-Test Workspace}"
TOPOMOJO_API_URL="${TOPOMOJO_API_URL:-http://localhost:5000}"

echo "Deleting TopoMojo workspace: $WORKSPACE_NAME"
echo ""

# Get Keycloak token
echo "Getting Keycloak token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "https://localhost:8443/realms/crucible/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=topomojo.ui" \
    -d "grant_type=password" \
    -d "username=admin" \
    -d "password=admin" \
    -d "scope=openid profile topomojo")

KEYCLOAK_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" = "null" ]; then
    echo "Error: Failed to get Keycloak token"
    exit 1
fi

echo "✓ Token acquired"
echo ""

# Get workspace ID
WORKSPACE_ID=$(curl -k -s -X GET "${TOPOMOJO_API_URL}/api/workspaces" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r ".[] | select(.name == \"${WORKSPACE_NAME}\") | .id")

if [ -z "$WORKSPACE_ID" ] || [ "$WORKSPACE_ID" = "null" ]; then
    echo "Workspace not found: $WORKSPACE_NAME"
    exit 0
fi

echo "Found workspace: $WORKSPACE_ID"
echo ""

# Get all template IDs and parent IDs
WORKSPACE_DATA=$(curl -k -s -X GET "${TOPOMOJO_API_URL}/api/workspace/${WORKSPACE_ID}" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

TEMPLATE_IDS=$(echo "$WORKSPACE_DATA" | jq -r '.templates[].id')
PARENT_IDS=$(echo "$WORKSPACE_DATA" | jq -r '.templates[].parentId' | sort -u)

# Unlink all child templates
echo "Unlinking child templates..."
for TEMPLATE_ID in $TEMPLATE_IDS; do
    echo "  Unlinking: $TEMPLATE_ID"
    curl -k -s -X POST "${TOPOMOJO_API_URL}/api/template/unlink" \
      -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"templateId\": \"${TEMPLATE_ID}\", \"workspaceId\": \"${WORKSPACE_ID}\"}" > /dev/null
done

echo "✓ Templates unlinked"
echo ""

# Delete parent templates
echo "Deleting parent templates..."
for PARENT_ID in $PARENT_IDS; do
    if [ -n "$PARENT_ID" ] && [ "$PARENT_ID" != "null" ]; then
        echo "  Deleting parent: $PARENT_ID"
        curl -k -s -X DELETE "${TOPOMOJO_API_URL}/api/template-detail/${PARENT_ID}" \
          -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" > /dev/null
    fi
done

echo "✓ Parent templates deleted"
echo ""

# Delete workspace
echo "Deleting workspace..."
RESPONSE=$(curl -k -s -X DELETE "${TOPOMOJO_API_URL}/api/workspace/${WORKSPACE_ID}" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

if echo "$RESPONSE" | grep -q "error\|Error"; then
    echo "Error deleting workspace:"
    echo "$RESPONSE"
    exit 1
fi

echo "✓ Workspace deleted"
echo ""
echo "SUCCESS! Workspace and all templates deleted."
