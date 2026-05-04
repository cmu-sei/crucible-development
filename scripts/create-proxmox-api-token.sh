#!/bin/bash
# Create Proxmox API token via SSH
# Requires SSH access to Proxmox host (run setup-proxmox-ssh.sh first)

set -e

# Configuration
PROXMOX_HOST="${PROXMOX_HOST:-172.22.69.122}"
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_proxmox}"
TOKEN_USER="${TOKEN_USER:-root@pam}"
TOKEN_ID="${TOKEN_ID:-crucible}"

echo "Creating Proxmox API token via SSH"
echo "  Host: $PROXMOX_HOST"
echo "  Token User: $TOKEN_USER"
echo "  Token ID: $TOKEN_ID"
echo ""

# Check if SSH key exists
if [[ ! -f "$SSH_KEY_PATH" ]]; then
  echo "Error: SSH key not found: $SSH_KEY_PATH"
  echo "Run setup-proxmox-ssh.sh first"
  exit 1
fi

# Check SSH connectivity
echo "Testing SSH connection..."
if ! ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
  echo "Error: Cannot connect to Proxmox host via SSH"
  echo "Run setup-proxmox-ssh.sh first"
  exit 1
fi
echo "✓ SSH connection successful"
echo ""

# Check if token already exists
echo "Checking if token already exists..."
EXISTING_TOKEN=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" \
  "pveum user token list $TOKEN_USER 2>/dev/null | grep -w '$TOKEN_ID' || true")

if [[ -n "$EXISTING_TOKEN" ]]; then
  echo "Token already exists: $TOKEN_USER!$TOKEN_ID"
  echo ""
  read -p "Delete and recreate? (y/n): " RECREATE
  if [[ "$RECREATE" != "y" ]]; then
    echo "Exiting without changes"
    exit 0
  fi

  echo "Deleting existing token..."
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" \
    "pveum user token delete $TOKEN_USER $TOKEN_ID"
  echo "✓ Existing token deleted"
fi

# Create the token
echo ""
echo "Creating API token..."
TOKEN_OUTPUT=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" \
  "pveum user token add $TOKEN_USER $TOKEN_ID --privsep 0 --output-format json")

# Extract the token value from JSON output
TOKEN_VALUE=$(echo "$TOKEN_OUTPUT" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

if [[ -z "$TOKEN_VALUE" ]]; then
  echo "Error: Failed to extract token value from output"
  echo "Output was:"
  echo "$TOKEN_OUTPUT"
  exit 1
fi

echo "✓ API token created successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Token ID: $TOKEN_USER!$TOKEN_ID"
echo "Token Value: $TOKEN_VALUE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Full token string for configuration:"
echo "  $TOKEN_USER!$TOKEN_ID=$TOKEN_VALUE"
echo ""
echo "Add to appsettings.Development.json:"
echo ""
echo "Player VM API:"
echo '  "Proxmox": {'
echo '    "Enabled": true,'
echo "    \"Host\": \"$PROXMOX_HOST\","
echo '    "Port": 8006,'
echo "    \"Token\": \"$TOKEN_USER!$TOKEN_ID=$TOKEN_VALUE\","
echo '    "StateRefreshIntervalSeconds": 60'
echo '  }'
echo ""
echo "Caster API:"
echo '  "Terraform": {'
echo '    "EnvironmentVariables": {'
echo '      "Direct": {'
echo "        \"PROXMOX_VE_ENDPOINT\": \"https://$PROXMOX_HOST:8006\","
echo "        \"PROXMOX_VE_API_TOKEN\": \"$TOKEN_USER!$TOKEN_ID=$TOKEN_VALUE\","
echo '        "PROXMOX_VE_INSECURE": "true"'
echo '      }'
echo '    }'
echo '  }'
echo ""
echo "IMPORTANT: Save this token value - it cannot be retrieved later!"
echo "           If lost, you must delete and recreate the token."
echo ""
echo "Next step:"
echo "  PROXMOX_HOST=$PROXMOX_HOST ./scripts/download-alpine-iso.sh"
