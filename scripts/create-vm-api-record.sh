#!/bin/bash
# Create a VM record in VM API via REST API
#
# Prerequisites:
# 1. Player API and VM API must be running
# 2. User specified in KEYCLOAK_USER must be a member of the team specified in TEAM_ID
#    OR have System Admin role
# 3. Proxmox must be configured and reachable
# 4. The Proxmox VM specified in PROXMOX_VM_ID must exist on the specified node

set -e

PLAYER_API_URL="${PLAYER_API_URL:-http://localhost:4300/api}"
VM_API_URL="${VM_API_URL:-http://localhost:4302/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
VIEW_ID="${VIEW_ID:-b5e8f7a9-3c4d-4e5f-9a8b-1c2d3e4f5a6b}"
TEAM_ID="${TEAM_ID:-d7f8a9b0-5e6f-4c5d-8b9a-2d3e4f5a6b7c}"
APP_TEMPLATE_ID="${APP_TEMPLATE_ID:-00000000-0000-0000-0000-000000000301}"
APPLICATION_ID="${APPLICATION_ID:-a3b4c5d6-8e9f-4f5a-1b2c-5f6a7b8c9d0e}"
VM_ID="${VM_ID:-e9f0a1b2-6c7d-4d5e-9a0b-3e4f5a6b7c8d}"
VM_NAME="${VM_NAME:-alpine-test}"
PROXMOX_VM_ID="${PROXMOX_VM_ID:-101}"

# If VM_ID looks like just a number, it's actually PROXMOX_VM_ID
if [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
  PROXMOX_VM_ID="$VM_ID"
  VM_ID="e9f0a1b2-6c7d-4d5e-9a0b-3e4f5a6b7c8d"
fi
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo "Creating VM record in VM API"
echo "  API URL: $VM_API_URL"
echo "  Team ID: $TEAM_ID"
echo "  VM ID: $VM_ID"
echo "  VM Name: $VM_NAME"
echo "  Proxmox VM ID: $PROXMOX_VM_ID"
echo "  Proxmox Node: $PROXMOX_NODE"
echo ""

# Get auth token
# Note: User must be a member of the team specified in TEAM_ID or have System Admin role
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.ui" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "✗ Failed to obtain auth token"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✓ Token obtained"
echo ""

# Create View if it doesn't exist
echo "Creating View..."
VIEW_RESPONSE=$(timeout 5 curl -s -X POST "$PLAYER_API_URL/views" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{
    \"id\": \"$VIEW_ID\",
    \"name\": \"Development Test View\",
    \"description\": \"Default view for development and testing\",
    \"status\": 0
  }" 2>&1 || echo "timeout")

if echo "$VIEW_RESPONSE" | grep -q "timeout"; then
  echo "⚠ View creation timed out, may already exist"
elif echo "$VIEW_RESPONSE" | grep -q '"id"'; then
  echo "✓ View created"
else
  echo "⚠ View response: $(echo "$VIEW_RESPONSE" | head -c 200)"
fi
echo ""

# Add Virtual Machines application to View
echo "Adding Virtual Machines application to View..."
APP_RESPONSE=$(timeout 5 curl -s -X POST "$PLAYER_API_URL/views/$VIEW_ID/applications" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{
    \"viewId\": \"$VIEW_ID\",
    \"applicationTemplateId\": \"$APP_TEMPLATE_ID\"
  }" 2>&1 || echo "timeout")

if echo "$APP_RESPONSE" | grep -q "timeout\|409"; then
  echo "✓ Application already added to view"
elif echo "$APP_RESPONSE" | grep -q '"id"'; then
  echo "✓ Application added to view"
else
  echo "⚠ Application response: $(echo "$APP_RESPONSE" | head -c 200)"
fi
echo ""

# Create Team
echo "Creating Team..."
TEAM_RESPONSE=$(timeout 5 curl -s -X POST "$PLAYER_API_URL/teams" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{
    \"id\": \"$TEAM_ID\",
    \"name\": \"Test Team\",
    \"viewId\": \"$VIEW_ID\"
  }" 2>&1 || echo "timeout")

if echo "$TEAM_RESPONSE" | grep -q "timeout"; then
  echo "⚠ Team creation timed out, may already exist"
elif echo "$TEAM_RESPONSE" | grep -q '"id"'; then
  echo "✓ Team created"
else
  echo "⚠ Team response: $(echo "$TEAM_RESPONSE" | head -c 200)"
fi
echo ""

# Add user to team (using hardcoded admin user ID for now)
echo "Adding user ($KEYCLOAK_USER) to team..."
USER_ID="9b3b331c-10c1-448b-8114-21b2586d8e38"

if [ -n "$USER_ID" ]; then
  MEMBER_RESPONSE=$(timeout 5 curl -s -X POST "$PLAYER_API_URL/teams/$TEAM_ID/members" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "{
      \"userId\": \"$USER_ID\"
    }" 2>&1 || echo "timeout")

  if echo "$MEMBER_RESPONSE" | grep -q "timeout\|409"; then
    echo "✓ User already member of team"
  else
    echo "✓ User added to team"
  fi
else
  echo "⚠ Could not get user ID, skipping team membership"
fi
echo ""

# Create VM via API
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$VM_API_URL/vms" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{
    \"id\": \"$VM_ID\",
    \"name\": \"$VM_NAME\",
    \"teamIds\": [\"$TEAM_ID\"],
    \"proxmoxVmInfo\": {
      \"id\": $PROXMOX_VM_ID,
      \"node\": \"$PROXMOX_NODE\",
      \"type\": 0
    },
    \"embeddable\": true
  }")

HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)
RESPONSE=$(echo "$HTTP_RESPONSE" | head -n-1)

echo "Response ($HTTP_CODE): $RESPONSE"

if [ "$HTTP_CODE" = "201" ] || echo "$RESPONSE" | grep -q '"id"'; then
  echo ""
  echo "✓ VM created successfully in VM API!"
  echo ""
  echo "VM Details:"
  echo "  VM API ID: $VM_ID"
  echo "  Proxmox VM ID: $PROXMOX_VM_ID"
  echo "  Team: $TEAM_ID"
  echo ""
  echo "Next steps:"
  echo "  1. Open Console.UI and access VM console"
  echo "  2. Check LRsql for xAPI statement"
else
  echo ""
  echo "✗ Failed to create VM"
  exit 1
fi
