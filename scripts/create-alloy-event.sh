#!/bin/bash
# Create an Alloy Event that links to a Caster Directory and Player View Template

set -e

ALLOY_API_URL="${ALLOY_API_URL:-http://localhost:4402/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
EVENT_TEMPLATE_NAME="${EVENT_TEMPLATE_NAME:-Proxmox Test Event}"
CASTER_DIRECTORY_ID="${CASTER_DIRECTORY_ID}"
PLAYER_VIEW_ID="${PLAYER_VIEW_ID}"
DURATION_HOURS="${DURATION_HOURS:-4}"

echo "Creating Alloy Event Template"
echo ""

# Show current environment variables
echo "Current settings:"
echo "  CASTER_DIRECTORY_ID: ${CASTER_DIRECTORY_ID:-<not set>}"
echo "  PLAYER_VIEW_ID: ${PLAYER_VIEW_ID:-<not set>}"
echo ""

# Check for required variables
if [ -z "$CASTER_DIRECTORY_ID" ] || [ -z "$PLAYER_VIEW_ID" ]; then
  echo "Error: CASTER_DIRECTORY_ID and PLAYER_VIEW_ID environment variables are required"
  echo ""
  echo "To get these IDs:"
  echo "  1. Run ./scripts/create-caster-proxmox-topology.sh"
  echo "     - Outputs Directory ID in the success message"
  echo "  2. After Terraform apply, check outputs:"
  echo "     - PLAYER_VIEW_ID from 'view_id' output"
  echo "     - Or query Caster API: GET /api/directories/{directoryId}"
  echo ""
  echo "Export variables:"
  echo "  export CASTER_DIRECTORY_ID='uuid-from-caster-script'"
  echo "  export PLAYER_VIEW_ID='uuid-from-terraform-output'"
  echo ""
  echo "Optional variables:"
  echo "  export EVENT_TEMPLATE_NAME='Custom Event Name'"
  echo "  export DURATION_HOURS='8'"
  echo ""
  echo "Then run this script:"
  echo "  ./scripts/create-alloy-event.sh"
  exit 1
fi

echo "  Alloy API: $ALLOY_API_URL"
echo "  Event Template: $EVENT_TEMPLATE_NAME"
echo "  Caster Directory: $CASTER_DIRECTORY_ID"
echo "  Player View: $PLAYER_VIEW_ID"
echo "  Duration: $DURATION_HOURS hours"
echo ""

# Get auth token
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=alloy.ui" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "✗ Failed to obtain token"
  exit 1
fi
echo "✓ Token obtained"
echo ""

# Find next available event template name
echo "Finding available event template name..."
ALL_TEMPLATES=$(curl -k -s -X GET "$ALLOY_API_URL/eventtemplates" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

# Check if base name exists
EXISTING_TEMPLATE=$(echo "$ALL_TEMPLATES" | jq -r ".[] | select(.name == \"$EVENT_TEMPLATE_NAME\") | .name" | head -1)

if [ -n "$EXISTING_TEMPLATE" ] && [ "$EXISTING_TEMPLATE" != "null" ]; then
  # Find highest numbered template
  COUNTER=2
  while true; do
    TEST_NAME="${EVENT_TEMPLATE_NAME} ${COUNTER}"
    EXISTS=$(echo "$ALL_TEMPLATES" | jq -r ".[] | select(.name == \"$TEST_NAME\") | .name" | head -1)
    if [ -z "$EXISTS" ] || [ "$EXISTS" = "null" ]; then
      EVENT_TEMPLATE_NAME="$TEST_NAME"
      break
    fi
    COUNTER=$((COUNTER + 1))
  done
  echo "✓ Using name: $EVENT_TEMPLATE_NAME"
fi

# Create new Event Template
echo "Creating event template..."
TEMPLATE_ID=$(cat /proc/sys/kernel/random/uuid)
TEMPLATE_RESPONSE=$(curl -k -s -X POST "$ALLOY_API_URL/eventtemplates" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$TEMPLATE_ID\",
    \"name\": \"$EVENT_TEMPLATE_NAME\",
    \"description\": \"Event template linking Caster directory and Player view\",
    \"directoryId\": \"$CASTER_DIRECTORY_ID\",
    \"viewId\": \"$PLAYER_VIEW_ID\",
    \"durationHours\": $DURATION_HOURS,
    \"useDynamicHost\": false,
    \"isPublished\": true
  }")

if echo "$TEMPLATE_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
  TEMPLATE_ID=$(echo "$TEMPLATE_RESPONSE" | jq -r '.id')
  echo "✓ Event template created: $TEMPLATE_ID"
else
  echo "✗ Failed to create event template"
  echo "$TEMPLATE_RESPONSE"
  exit 1
fi

echo ""
echo "✓ Alloy event template created successfully!"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Event Template Name: $EVENT_TEMPLATE_NAME"
echo "Event Template ID:   $TEMPLATE_ID"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Direct link to event template:"
echo "  http://localhost:4403/templates/$TEMPLATE_ID"
echo ""
echo "Next steps:"
echo "  1. Open the template URL above"
echo "  2. Click 'Launch Event' to create and deploy an event instance"
echo ""
echo "Additional links:"
echo "  - Caster Directory: http://localhost:4310 (Directory ID: $CASTER_DIRECTORY_ID)"
echo "  - Player View: http://localhost:4301 (View ID: $PLAYER_VIEW_ID)"
echo ""
