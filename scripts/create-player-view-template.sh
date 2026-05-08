#!/bin/bash
# Create a Player View Template with Virtual Machines application

set -e

PLAYER_API_URL="${PLAYER_API_URL:-http://localhost:4300/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
VIEW_NAME="${VIEW_NAME:-Proxmox VM Template}"
VIEW_DESCRIPTION="${VIEW_DESCRIPTION:-Template view with Virtual Machines application}"
VM_APP_TEMPLATE_ID="${VM_APP_TEMPLATE_ID:-ace19f19-8916-4169-84de-ad00565d8456}"

echo "Creating Player View Template"
echo ""

# Show current environment variables
if [ -n "$CASTER_DIRECTORY_ID" ]; then
  echo "Current settings:"
  echo "  CASTER_DIRECTORY_ID: $CASTER_DIRECTORY_ID"
  echo ""
fi

echo "  Player API: $PLAYER_API_URL"
echo "  View Name: $VIEW_NAME"
echo "  VM App Template ID: $VM_APP_TEMPLATE_ID"
echo ""

# Get auth token
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.ui" \
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

# Find next available view name
echo "Finding available view name..."
ALL_VIEWS=$(curl -k -s -X GET "$PLAYER_API_URL/views" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

# Check if base name exists
EXISTING_VIEW=$(echo "$ALL_VIEWS" | jq -r ".[] | select(.name == \"$VIEW_NAME\") | .name" | head -1)

if [ -n "$EXISTING_VIEW" ] && [ "$EXISTING_VIEW" != "null" ]; then
  # Find highest numbered view
  COUNTER=2
  while true; do
    TEST_NAME="${VIEW_NAME} ${COUNTER}"
    EXISTS=$(echo "$ALL_VIEWS" | jq -r ".[] | select(.name == \"$TEST_NAME\") | .name" | head -1)
    if [ -z "$EXISTS" ] || [ "$EXISTS" = "null" ]; then
      VIEW_NAME="$TEST_NAME"
      break
    fi
    COUNTER=$((COUNTER + 1))
  done
  echo "✓ Using name: $VIEW_NAME"
fi

# Create View Template
echo "Creating view template..."
VIEW_ID=$(cat /proc/sys/kernel/random/uuid)
VIEW_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$PLAYER_API_URL/views" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$VIEW_ID\",
    \"name\": \"$VIEW_NAME\",
    \"description\": \"$VIEW_DESCRIPTION\",
    \"status\": \"Active\",
    \"createAdminTeam\": true
  }")

HTTP_CODE=$(echo "$VIEW_RESPONSE" | tail -n1)
RESPONSE=$(echo "$VIEW_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "201" ] || echo "$RESPONSE" | grep -q '"id"'; then
  VIEW_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null || echo "$VIEW_ID")
  echo "✓ View created: $VIEW_ID"
else
  echo "✗ Failed to create view"
  echo "$RESPONSE"
  exit 1
fi
echo ""

# Get the Admin team ID
echo "Getting Admin team..."
TEAMS=$(curl -k -s -X GET "$PLAYER_API_URL/views/$VIEW_ID/teams" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

ADMIN_TEAM_ID=$(echo "$TEAMS" | jq -r '.[] | select(.name == "Admin") | .id' | head -1)

if [ -z "$ADMIN_TEAM_ID" ] || [ "$ADMIN_TEAM_ID" = "null" ]; then
  echo "✗ Failed to get Admin team ID"
  exit 1
fi
echo "✓ Admin team: $ADMIN_TEAM_ID"
echo ""

# Add Virtual Machines application to view
echo "Adding Virtual Machines application..."
APP_ID=$(cat /proc/sys/kernel/random/uuid)
APP_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$PLAYER_API_URL/views/$VIEW_ID/applications" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$APP_ID\",
    \"viewId\": \"$VIEW_ID\",
    \"applicationTemplateId\": \"$VM_APP_TEMPLATE_ID\"
  }")

HTTP_CODE=$(echo "$APP_RESPONSE" | tail -n1)
RESPONSE=$(echo "$APP_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "201" ] || echo "$RESPONSE" | grep -q '"id"'; then
  APP_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null || echo "$APP_ID")
  echo "✓ Application added: $APP_ID"
else
  echo "✗ Failed to add application"
  echo "$RESPONSE"
  exit 1
fi
echo ""

# Add application instance to Admin team
echo "Adding application to Admin team..."
APP_INSTANCE_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$PLAYER_API_URL/teams/$ADMIN_TEAM_ID/application-instances" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"teamId\": \"$ADMIN_TEAM_ID\",
    \"applicationId\": \"$APP_ID\",
    \"displayOrder\": 0
  }")

HTTP_CODE=$(echo "$APP_INSTANCE_RESPONSE" | tail -n1)
RESPONSE=$(echo "$APP_INSTANCE_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "201" ] || echo "$RESPONSE" | grep -q '"id"'; then
  APP_INSTANCE_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null || echo "$APP_INSTANCE_ID")
  echo "✓ Application instance added: $APP_INSTANCE_ID"
else
  echo "✗ Failed to add application instance"
  echo "$RESPONSE"
  exit 1
fi
echo ""

# Mark view as template and set default team
echo "Marking view as template and setting default team..."
TEMPLATE_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X PUT "$PLAYER_API_URL/views/$VIEW_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$VIEW_ID\",
    \"name\": \"$VIEW_NAME\",
    \"description\": \"$VIEW_DESCRIPTION\",
    \"status\": \"Active\",
    \"isTemplate\": true,
    \"defaultTeamId\": \"$ADMIN_TEAM_ID\"
  }")

HTTP_CODE=$(echo "$TEMPLATE_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
  echo "✓ View marked as template with default team set"
else
  echo "✗ Failed to mark as template"
  exit 1
fi
echo ""

echo "✓ Player view template created successfully!"
echo ""
echo "View: $VIEW_NAME ($VIEW_ID)"
echo "Admin Team: $ADMIN_TEAM_ID"
echo ""
echo "Next steps:"
echo "  1. Access Player UI: http://localhost:4301"
echo "  2. Use this view template for Alloy events"
echo ""
echo "Paste this command to set the view ID:"
echo ""
echo "export PLAYER_VIEW_ID='$VIEW_ID'"
echo ""
echo "To create an Alloy event with a Caster directory:"
echo ""
echo "export CASTER_DIRECTORY_ID='your-caster-directory-id'"
echo "export PLAYER_VIEW_ID='$VIEW_ID'"
echo "./scripts/create-alloy-event.sh"
echo ""
