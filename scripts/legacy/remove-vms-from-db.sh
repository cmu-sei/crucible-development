#!/bin/bash
# Remove VMs from Player VM API database by Proxmox ID

set -e

VM_API_URL="${VM_API_URL:-http://localhost:4302/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
PROXMOX_IDS="${PROXMOX_IDS:-112,113}"

echo "Removing VMs from Player VM API database"
echo "  Proxmox IDs to remove: $PROXMOX_IDS"
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
  exit 1
fi
echo "✓ Token obtained"
echo ""

# Get all VMs from API
ALL_VMS=$(curl -k -s -X GET "$VM_API_URL/vms" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json")

# Process each Proxmox ID
IFS=',' read -ra IDS <<< "$PROXMOX_IDS"
for PROXMOX_ID in "${IDS[@]}"; do
  echo "Looking for VM with Proxmox ID $PROXMOX_ID..."

  # Find VM record with this Proxmox ID
  VM_RECORD=$(echo "$ALL_VMS" | grep -o "{[^{]*\"proxmoxVmInfo\":{\"id\":$PROXMOX_ID[^}]*}[^}]*}" | head -1 || true)

  if [ -z "$VM_RECORD" ]; then
    echo "  ⚠ No VM found with Proxmox ID $PROXMOX_ID"
    echo ""
    continue
  fi

  VM_UUID=$(echo "$VM_RECORD" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  VM_NAME=$(echo "$VM_RECORD" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

  echo "  Found: $VM_NAME (UUID: $VM_UUID)"
  echo "  Deleting from database..."

  DELETE_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X DELETE "$VM_API_URL/vms/$VM_UUID" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

  HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)

  if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "  ✓ Deleted successfully"
  else
    echo "  ✗ Delete failed (code $HTTP_CODE)"
    echo "$DELETE_RESPONSE" | head -n-1
  fi

  echo ""
done

echo "✓ Done!"
