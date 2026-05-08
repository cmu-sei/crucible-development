#!/bin/bash
# Register Proxmox VMs to Player teams

set -e

PLAYER_VM_API_URL="${PLAYER_VM_API_URL:-http://localhost:4302/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
VM_IDS="${VM_IDS}"
TEAM_ID="${TEAM_ID}"

echo "Register Proxmox VMs to Player Team"
echo ""

# Check for required variables
if [ -z "$VM_IDS" ] || [ -z "$TEAM_ID" ]; then
  echo "Error: VM_IDS and TEAM_ID environment variables are required"
  echo ""
  echo "Export variables:"
  echo "  export VM_IDS='vmid1,vmid2'  # Comma-separated Proxmox VM IDs"
  echo "  export TEAM_ID='your-player-team-id'"
  echo ""
  echo "Optional:"
  echo "  export PROXMOX_NODE='pve'  # Default: pve"
  echo ""
  echo "Then run this script:"
  echo "  ./scripts/register-proxmox-vms-to-player.sh"
  exit 1
fi

echo "  Player VM API: $PLAYER_VM_API_URL"
echo "  VM IDs: $VM_IDS"
echo "  Team ID: $TEAM_ID"
echo "  Proxmox Node: $PROXMOX_NODE"
echo ""

# Get auth token
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=vm.ui" \
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

# Split VM_IDS by comma
IFS=',' read -ra VMID_ARRAY <<< "$VM_IDS"

for VMID in "${VMID_ARRAY[@]}"; do
  echo "Registering VM $VMID..."

  VM_ID=$(cat /proc/sys/kernel/random/uuid)
  VM_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$PLAYER_VM_API_URL/vms" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"id\": \"$VM_ID\",
      \"name\": \"VM-$VMID\",
      \"teamIds\": [\"$TEAM_ID\"],
      \"allowedNetworks\": [],
      \"url\": null,
      \"embeddable\": true,
      \"proxmoxVmInfo\": {
        \"id\": $VMID,
        \"node\": \"$PROXMOX_NODE\"
      }
    }")

  HTTP_CODE=$(echo "$VM_RESPONSE" | tail -n1)
  RESPONSE=$(echo "$VM_RESPONSE" | head -n-1)

  if [ "$HTTP_CODE" = "201" ] || echo "$RESPONSE" | grep -q '"id"'; then
    CREATED_VM_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null || echo "$VM_ID")
    echo "  ✓ VM $VMID registered: $CREATED_VM_ID"
  else
    echo "  ✗ Failed to register VM $VMID"
    echo "  $RESPONSE"
  fi
done

echo ""
echo "✓ VM registration complete!"
echo ""
echo "Check your Player view at: http://localhost:4301"
echo ""
