#!/bin/bash
# Add a VM record to existing View/Team in VM API

set -e

VM_API_URL="${VM_API_URL:-http://localhost:4302/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
VIEW_ID="${VIEW_ID:-b5e8f7a9-3c4d-4e5f-9a8b-1c2d3e4f5a6b}"
TEAM_ID="${TEAM_ID:-c351c81c-ff56-4eb0-9eba-18f263f0b586}"
VM_NAME="${VM_NAME:-tinycore-test}"
PROXMOX_VM_ID="${PROXMOX_VM_ID:-102}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo "Adding VM to existing View/Team"
echo "  VM API URL: $VM_API_URL"
echo "  Team ID: $TEAM_ID"
echo "  VM Name: $VM_NAME"
echo "  Proxmox VM ID: $PROXMOX_VM_ID"
echo "  Proxmox Node: $PROXMOX_NODE"
echo ""

# Get auth token
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.vm.admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "✗ Failed to obtain token"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

echo "✓ Token obtained"
echo ""

# Generate new UUID for VM
VM_ID=$(cat /proc/sys/kernel/random/uuid)

# Create VM
echo "Creating VM in VM API..."
echo "  Generated VM ID: $VM_ID"
VM_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$VM_API_URL/vms" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
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
  }" 2>&1)

HTTP_CODE=$(echo "$VM_RESPONSE" | tail -n1)
VM_RESPONSE=$(echo "$VM_RESPONSE" | head -n-1)

echo "Response ($HTTP_CODE):"
echo "$VM_RESPONSE"

if [ "$HTTP_CODE" = "201" ] || echo "$VM_RESPONSE" | grep -q '"id"'; then
  echo ""
  echo "✓ VM created successfully!"
  echo "  VM ID: $VM_ID"
  echo ""
  echo "Access the VM console at:"
  echo "  http://localhost:4303/views/b5e8f7a9-3c4d-4e5f-9a8b-1c2d3e4f5a6b?theme=light-theme"
else
  echo ""
  echo "✗ Failed to create VM"
  exit 1
fi
