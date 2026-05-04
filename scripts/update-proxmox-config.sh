#!/bin/bash
# Update Proxmox configuration in appsettings files

set -e

PROXMOX_HOST="${PROXMOX_HOST:-172.22.71.38}"
PROXMOX_TOKEN="${PROXMOX_TOKEN}"

if [ -z "$PROXMOX_TOKEN" ]; then
  echo "Error: PROXMOX_TOKEN environment variable required"
  echo ""
  echo "Usage:"
  echo "  PROXMOX_HOST=172.22.71.38 PROXMOX_TOKEN='root@pam!crucible=...' ./scripts/update-proxmox-config.sh"
  exit 1
fi

echo "Updating Proxmox configuration in appsettings files"
echo "  Host: $PROXMOX_HOST"
echo "  Token: ${PROXMOX_TOKEN:0:30}..."
echo ""

# Update Player VM API
VM_API_CONFIG="/mnt/data/crucible/player/vm.api/src/Player.Vm.Api/appsettings.Development.json"

if [ -f "$VM_API_CONFIG" ]; then
  echo "Updating Player VM API config..."

  # Use jq to update the JSON
  jq --arg host "$PROXMOX_HOST" \
     --arg token "$PROXMOX_TOKEN" \
     '.Proxmox.Host = $host | .Proxmox.Token = $token | .Proxmox.Enabled = true' \
     "$VM_API_CONFIG" > "$VM_API_CONFIG.tmp"

  mv "$VM_API_CONFIG.tmp" "$VM_API_CONFIG"
  echo "✓ Player VM API config updated"
else
  echo "⚠ Player VM API config not found: $VM_API_CONFIG"
fi

echo ""
echo "✓ Configuration updated successfully"
echo ""
echo "Next steps:"
echo "  1. Restart VM API if running"
echo "  2. Create test VM: PROXMOX_HOST=$PROXMOX_HOST PROXMOX_TOKEN='$PROXMOX_TOKEN' ./scripts/create-proxmox-vm.sh"
