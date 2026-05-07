#!/bin/bash
# Update appsettings.Development.json files with Proxmox configuration

set -e

PROXMOX_HOST="${PROXMOX_HOST:-172.22.64.132}"
PROXMOX_TOKEN="${PROXMOX_TOKEN}"

if [ -z "$PROXMOX_TOKEN" ]; then
  echo "Error: PROXMOX_TOKEN environment variable is required"
  echo "Usage: PROXMOX_HOST=<ip> PROXMOX_TOKEN=<token> ./scripts/update-proxmox-appsettings.sh"
  exit 1
fi

echo "Updating appsettings with Proxmox configuration"
echo "  Proxmox Host: $PROXMOX_HOST"
echo "  Token: ${PROXMOX_TOKEN:0:20}..."
echo ""

PLAYER_VM_SETTINGS="/mnt/data/crucible/player/vm.api/src/Player.Vm.Api/appsettings.Development.json"
CASTER_SETTINGS="/mnt/data/crucible/caster/caster.api/src/Caster.Api/appsettings.Development.json"

# Update Player VM API settings
if [ -f "$PLAYER_VM_SETTINGS" ]; then
  echo "Updating Player VM API settings..."

  # Use jq to update or add the Proxmox section
  # Port 443 is used when Proxmox has nginx reverse proxy configured (see setup-proxmox-nginx.sh)
  # Port 8006 would be direct access, but websocket auth requires nginx proxy for token injection
  jq --arg host "$PROXMOX_HOST" --arg token "$PROXMOX_TOKEN" \
    '.Proxmox = {
      "Enabled": true,
      "Host": $host,
      "Port": 443,
      "Token": $token,
      "StateRefreshIntervalSeconds": 60
    }' "$PLAYER_VM_SETTINGS" > "$PLAYER_VM_SETTINGS.tmp" && \
    mv "$PLAYER_VM_SETTINGS.tmp" "$PLAYER_VM_SETTINGS"

  echo "✓ Player VM API settings updated: $PLAYER_VM_SETTINGS"
else
  echo "⚠ Player VM API settings not found: $PLAYER_VM_SETTINGS"
fi
echo ""

# Update Caster API settings
if [ -f "$CASTER_SETTINGS" ]; then
  echo "Updating Caster API settings..."

  # Use jq to update or add the Terraform Proxmox configuration
  jq --arg endpoint "https://$PROXMOX_HOST:8006" --arg token "$PROXMOX_TOKEN" \
    '.Terraform.EnvironmentVariables.Direct.PROXMOX_VE_ENDPOINT = $endpoint |
     .Terraform.EnvironmentVariables.Direct.PROXMOX_VE_API_TOKEN = $token |
     .Terraform.EnvironmentVariables.Direct.PROXMOX_VE_INSECURE = "true"' \
    "$CASTER_SETTINGS" > "$CASTER_SETTINGS.tmp" && \
    mv "$CASTER_SETTINGS.tmp" "$CASTER_SETTINGS"

  echo "✓ Caster API settings updated: $CASTER_SETTINGS"
else
  echo "⚠ Caster API settings not found: $CASTER_SETTINGS"
fi
echo ""

echo "✓ Configuration complete!"
echo ""
echo "Modified files:"
echo "  - $PLAYER_VM_SETTINGS"
echo "  - $CASTER_SETTINGS"
echo ""
echo "Restart Player VM API and Caster API to apply changes"
