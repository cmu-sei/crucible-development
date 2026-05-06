#!/bin/bash
# Register ESXi VM with Player VM API

set -e

# Configuration
VM_API_URL="${VM_API_URL:-http://localhost:4302/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
VIEW_ID="${VIEW_ID:-b5e8f7a9-3c4d-4e5f-9a8b-1c2d3e4f5a6b}"
TEAM_ID="${TEAM_ID:-c351c81c-ff56-4eb0-9eba-18f263f0b586}"
VM_NAME="${VM_NAME:-}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo "Registering ESXi VM with VM API"
echo "  API URL: $VM_API_URL"
echo "  Team ID: $TEAM_ID"
echo ""

# Prompt for VM name if not set
if [ -z "$VM_NAME" ]; then
  read -p "Enter VM name (as shown in ESXi): " VM_NAME
fi

echo "  VM Name: $VM_NAME"
echo ""

# Obtain auth token
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.vm.admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r .access_token)

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "✗ Failed to obtain token"
  echo ""
  echo "Response:"
  echo $TOKEN_RESPONSE | jq .
  exit 1
fi

echo "✓ Token obtained"
echo ""

# Generate VM ID
VM_ID=$(cat /proc/sys/kernel/random/uuid)
echo "Generated VM ID: $VM_ID"
echo ""

# Create View if it doesn't exist (optional - may already exist)
echo "Creating/verifying View..."
curl -s -X POST "$VM_API_URL/views" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$VIEW_ID\",
    \"name\": \"Test View\",
    \"status\": \"Active\"
  }" > /dev/null 2>&1 || true

# Create Team if it doesn't exist (optional - may already exist)
echo "Creating/verifying Team..."
curl -s -X POST "$VM_API_URL/teams" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$TEAM_ID\",
    \"name\": \"Test Team\",
    \"viewId\": \"$VIEW_ID\"
  }" > /dev/null 2>&1 || true

# Create VM record
echo "Registering VM..."
VM_RESPONSE=$(curl -s -X POST "$VM_API_URL/vms" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$VM_ID\",
    \"name\": \"$VM_NAME\",
    \"teamIds\": [\"$TEAM_ID\"],
    \"embeddable\": true
  }")

echo ""
echo "Response:"
echo $VM_RESPONSE | jq .

# Check for errors
if echo $VM_RESPONSE | jq -e .errors > /dev/null 2>&1; then
  echo ""
  echo "✗ VM registration failed"
  exit 1
fi

echo ""
echo "✓ VM registered with VM API"
echo ""
echo "VM Details:"
echo "  ID: $VM_ID"
echo "  Name: $VM_NAME"
echo "  Type: Vsphere (auto-detected by VM API)"
echo "  Team: $TEAM_ID"
echo "  View: $VIEW_ID"
echo ""
echo "The VM should now appear in Player VM UI"
echo "Console access: http://localhost:4303/vm/$VM_ID/console"
