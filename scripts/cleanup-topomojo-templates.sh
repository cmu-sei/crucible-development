#!/bin/bash
# Clean up duplicate TopoMojo templates and workspaces

set -e

TOPOMOJO_API_URL="${TOPOMOJO_API_URL:-http://localhost:5000}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USERNAME="${KEYCLOAK_USERNAME:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo "Cleaning up TopoMojo templates and workspaces..."

# Get Keycloak token
TOKEN_RESPONSE=$(curl -k -s -X POST "${KEYCLOAK_URL}/realms/crucible/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=topomojo.ui" \
    -d "grant_type=password" \
    -d "username=${KEYCLOAK_USERNAME}" \
    -d "password=${KEYCLOAK_PASSWORD}" \
    -d "scope=openid profile topomojo")

KEYCLOAK_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" = "null" ]; then
    echo "Error: Failed to get Keycloak token"
    exit 1
fi

# Delete "Moodle Test Workspace - Variants"
echo "Deleting Moodle Test Workspace - Variants..."
WORKSPACES=$(curl -k -s -X GET "${TOPOMOJO_API_URL}/api/workspaces" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

VARIANTS_WS_ID=$(echo "$WORKSPACES" | jq -r '.[] | select(.name == "Moodle Test Workspace - Variants") | .id' | head -1)

if [ -n "$VARIANTS_WS_ID" ] && [ "$VARIANTS_WS_ID" != "null" ]; then
  echo "Deleting workspace: $VARIANTS_WS_ID"
  curl -k -s -X DELETE "${TOPOMOJO_API_URL}/api/workspace/${VARIANTS_WS_ID}" \
    -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" > /dev/null
  echo "✓ Workspace deleted"
else
  echo "Workspace not found"
fi

# Delete all duplicate templates created on 5/25/2026
echo ""
echo "Deleting duplicate templates..."
ALL_TEMPLATES=$(curl -k -s -X GET "${TOPOMOJO_API_URL}/api/templates" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

DELETED_COUNT=0

# Delete duplicate Linux-Box-V1, Network-Node-V2, File-Server-V3 templates
for TEMPLATE_NAME in "Linux-Box-V1" "Network-Node-V2" "File-Server-V3"; do
  echo "Deleting $TEMPLATE_NAME templates..."
  TEMPLATE_IDS=$(echo "$ALL_TEMPLATES" | jq -r ".[] | select(.name == \"$TEMPLATE_NAME\") | .id")

  for TEMPLATE_ID in $TEMPLATE_IDS; do
    if [ -n "$TEMPLATE_ID" ]; then
      echo "  Deleting template: $TEMPLATE_ID"
      curl -k -s -X DELETE "${TOPOMOJO_API_URL}/api/template/${TEMPLATE_ID}" \
        -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" > /dev/null
      DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
  done
done

# Keep only the FIRST TinyCore-ISO and Alpine-Disk, delete the rest
for TEMPLATE_NAME in "TinyCore-ISO" "Alpine-Disk"; do
  echo "Cleaning up $TEMPLATE_NAME duplicates..."
  TEMPLATE_IDS=$(echo "$ALL_TEMPLATES" | jq -r ".[] | select(.name == \"$TEMPLATE_NAME\") | .id")

  FIRST=true
  for TEMPLATE_ID in $TEMPLATE_IDS; do
    if [ "$FIRST" = true ]; then
      echo "  Keeping first: $TEMPLATE_ID"
      FIRST=false
    else
      echo "  Deleting duplicate: $TEMPLATE_ID"
      curl -k -s -X DELETE "${TOPOMOJO_API_URL}/api/template/${TEMPLATE_ID}" \
        -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" > /dev/null
      DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
  done
done

# Delete Alpine-Disk-739 and Linux-Box-V1-634 (linked templates)
for TEMPLATE_NAME in "Alpine-Disk-739" "Linux-Box-V1-634"; do
  TEMPLATE_ID=$(echo "$ALL_TEMPLATES" | jq -r ".[] | select(.name == \"$TEMPLATE_NAME\") | .id" | head -1)
  if [ -n "$TEMPLATE_ID" ] && [ "$TEMPLATE_ID" != "null" ]; then
    echo "Deleting linked template: $TEMPLATE_NAME ($TEMPLATE_ID)"
    curl -k -s -X DELETE "${TOPOMOJO_API_URL}/api/template/${TEMPLATE_ID}" \
      -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" > /dev/null
    DELETED_COUNT=$((DELETED_COUNT + 1))
  fi
done

echo ""
echo "✓ Cleanup complete"
echo "  Deleted $DELETED_COUNT templates"
echo "  Kept: 1x TinyCore-ISO, 1x Alpine-Disk in Test Workspace"
