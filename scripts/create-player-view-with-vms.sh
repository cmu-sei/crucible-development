#!/bin/bash
# Create a Player View with actual VMs registered and running

set -e

PLAYER_API_URL="${PLAYER_API_URL:-http://localhost:4300/api}"
VM_API_URL="${VM_API_URL:-http://localhost:4302/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
VIEW_NAME="${VIEW_NAME:-Proxmox Demo}"
VIEW_DESCRIPTION="${VIEW_DESCRIPTION:-Live view with running Proxmox VMs}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"

# Stable GUIDs for idempotency
VIEW_ID="3c7e9a2f-8b4d-4e1a-9f5c-2d8b6e3a7c1f"
VM_APP_ID="4d8f0b3e-9c5e-4f2b-af6d-3e9c7f4b8d2a"
MAP_APP_ID="5e9g1c4f-ad6f-5g3c-bg7e-4fad8g5c9e3b"
PUPPY_VM_ID="6fah2d5g-be7g-6h4d-ch8f-5gbe9h6daf4c"
ALPINE_VM_ID="7gbi3e6h-cf8h-7i5e-di9g-6hcfai7ebg5d"
TINYCORE_VM_ID="8hcj4f7i-dg9i-8j6f-ej0h-7idgbj8fch6e"

# Proxmox VM IDs
PUPPY_PROXMOX_ID="${PUPPY_PROXMOX_ID:-103}"
ALPINE_PROXMOX_ID="${ALPINE_PROXMOX_ID:-105}"
TINYCORE_PROXMOX_ID="${TINYCORE_PROXMOX_ID:-106}"

echo "Creating Player View with live VMs"
echo "  View: $VIEW_NAME"
echo ""

# Get auth token
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.vm.admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "✗ Failed to obtain token"
  exit 1
fi
echo "✓ Token obtained"
echo ""

# Check if view exists
echo "Checking if view exists..."
ALL_VIEWS=$(curl -k -s -X GET "$PLAYER_API_URL/views" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

EXISTING_VIEW_ID=$(echo "$ALL_VIEWS" | jq -r ".[] | select(.name == \"$VIEW_NAME\") | .id" | head -1)

if [ -n "$EXISTING_VIEW_ID" ] && [ "$EXISTING_VIEW_ID" != "null" ]; then
  if [ "${CLEAN_SETUP}" = "true" ]; then
    echo "Deleting existing view: $VIEW_NAME ($EXISTING_VIEW_ID)"
    curl -k -s -X DELETE "$PLAYER_API_URL/views/$EXISTING_VIEW_ID" \
      -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null
    echo "✓ View deleted"
  else
    echo "✓ View already exists: $VIEW_NAME ($EXISTING_VIEW_ID)"
    VIEW_ID="$EXISTING_VIEW_ID"
    echo ""
    echo "View ready at: http://localhost:4303/views/$VIEW_ID"
    exit 0
  fi
fi

# Create View
echo "Creating view..."
VIEW_RESPONSE=$(curl -k -s -X POST "$PLAYER_API_URL/views" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$VIEW_ID\",
    \"name\": \"$VIEW_NAME\",
    \"description\": \"$VIEW_DESCRIPTION\",
    \"status\": \"Active\"
  }")

if echo "$VIEW_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
  VIEW_ID=$(echo "$VIEW_RESPONSE" | jq -r '.id')
  echo "✓ View created: $VIEW_ID"
else
  echo "✗ Failed to create view"
  echo "$VIEW_RESPONSE"
  exit 1
fi
echo ""

# Get Admin team ID
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

# Register VMs in Player VM API
echo "Registering VMs in Player VM API..."

# Get VM API auth token (different scope)
VM_TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.vm.admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

VM_ACCESS_TOKEN=$(echo "$VM_TOKEN_RESPONSE" | jq -r '.access_token')

# Register Puppy VM
echo "Registering Puppy Linux VM..."
curl -k -s -X POST "$VM_API_URL/vms" \
  -H "Authorization: Bearer $VM_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$PUPPY_VM_ID\",
    \"name\": \"puppy-test\",
    \"teamIds\": [\"$ADMIN_TEAM_ID\"],
    \"proxmoxVmInfo\": {
      \"id\": $PUPPY_PROXMOX_ID,
      \"node\": \"$PROXMOX_NODE\"
    }
  }" > /dev/null

echo "✓ Puppy VM registered"

# Register Alpine VM
echo "Registering Alpine VM..."
curl -k -s -X POST "$VM_API_URL/vms" \
  -H "Authorization: Bearer $VM_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$ALPINE_VM_ID\",
    \"name\": \"alpine-linux-template\",
    \"teamIds\": [\"$ADMIN_TEAM_ID\"],
    \"proxmoxVmInfo\": {
      \"id\": $ALPINE_PROXMOX_ID,
      \"node\": \"$PROXMOX_NODE\"
    }
  }" > /dev/null

echo "✓ Alpine VM registered"

# Register TinyCore VM
echo "Registering TinyCore VM..."
curl -k -s -X POST "$VM_API_URL/vms" \
  -H "Authorization: Bearer $VM_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$TINYCORE_VM_ID\",
    \"name\": \"tinycore-linux-template\",
    \"teamIds\": [\"$ADMIN_TEAM_ID\"],
    \"proxmoxVmInfo\": {
      \"id\": $TINYCORE_PROXMOX_ID,
      \"node\": \"$PROXMOX_NODE\"
    }
  }" > /dev/null

echo "✓ TinyCore VM registered"
echo ""

# Add Virtual Machines application to view
echo "Adding Virtual Machines application..."
VM_APP_TEMPLATE_ID="ace19f19-8916-4169-84de-ad00565d8456"
VM_APP_RESPONSE=$(curl -k -s -X POST "$PLAYER_API_URL/views/$VIEW_ID/applications" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$VM_APP_ID\",
    \"applicationTemplateId\": \"$VM_APP_TEMPLATE_ID\"
  }")

if echo "$VM_APP_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
  echo "✓ VM application added"
else
  echo "⚠ Failed to add VM application"
fi

# Add Map application to view
echo "Adding Map application..."
MAP_APP_TEMPLATE_ID="a4c361cc-b43f-4c44-99a7-7e2e2b3a9f88"
MAP_APP_RESPONSE=$(curl -k -s -X POST "$PLAYER_API_URL/views/$VIEW_ID/applications" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$MAP_APP_ID\",
    \"applicationTemplateId\": \"$MAP_APP_TEMPLATE_ID\"
  }")

if echo "$MAP_APP_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
  echo "✓ Map application added"
else
  echo "⚠ Failed to add Map application"
fi
echo ""

echo "✓ Player view with VMs created successfully!"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "View Name: $VIEW_NAME"
echo "View ID:   $VIEW_ID"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Access at: http://localhost:4303/views/$VIEW_ID?theme=light-theme"
echo ""
echo "VMs registered:"
echo "  • Puppy Linux (ID: $PUPPY_PROXMOX_ID)"
echo "  • Alpine Linux (ID: $ALPINE_PROXMOX_ID)"
echo "  • TinyCore Linux (ID: $TINYCORE_PROXMOX_ID)"
echo ""
