#!/bin/bash
# Create an Alloy Event Template without Caster directory
# For simple on-demand exercises with only a Player View (no infrastructure orchestration)

set -e

ALLOY_API_URL="${ALLOY_API_URL:-http://localhost:4402/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
EVENT_TEMPLATE_NAME="${EVENT_TEMPLATE_NAME:-Alloy Event (No Caster)}"
PLAYER_VIEW_ID="${PLAYER_VIEW_ID}"
DURATION_HOURS="${DURATION_HOURS:-4}"

echo "Creating Alloy Event Template (View Only, No Caster)"
echo ""

# Show current environment variables
echo "Current settings:"
echo "  PLAYER_VIEW_ID: ${PLAYER_VIEW_ID:-<not set>}"
echo ""

# Check for required variables
if [ -z "$PLAYER_VIEW_ID" ]; then
  echo "Error: PLAYER_VIEW_ID environment variable is required"
  echo ""
  echo "Export variable:"
  echo "  export PLAYER_VIEW_ID='your-player-view-template-id'"
  echo ""
  echo "Optional variables:"
  echo "  export EVENT_TEMPLATE_NAME='Custom Event Name'"
  echo "  export DURATION_HOURS='8'"
  echo ""
  echo "Then run this script:"
  echo "  ./scripts/create-alloy-event-without-caster.sh"
  exit 1
fi

echo "  Alloy API: $ALLOY_API_URL"
echo "  Event Template: $EVENT_TEMPLATE_NAME"
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
ALL_TEMPLATES=$(curl -k -s -m 10 -X GET "$ALLOY_API_URL/eventtemplates" \
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

# Create new Event Template (view only, no Caster directory)
echo "Creating event template..."
TEMPLATE_ID=$(cat /proc/sys/kernel/random/uuid)
TEMPLATE_RESPONSE=$(curl -k -s -X POST "$ALLOY_API_URL/eventtemplates" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$TEMPLATE_ID\",
    \"name\": \"$EVENT_TEMPLATE_NAME\",
    \"description\": \"Simple event template with Player view only\",
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
echo "✓ Simple Alloy event template created successfully!"
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
echo "  2. Click 'Launch Event' to provision Player view instance"
echo ""
echo "Note: This event uses Player view only (no Caster infrastructure)"
echo ""
