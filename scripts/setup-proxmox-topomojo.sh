#!/bin/bash
# Creates a Proxmox API token for TopoMojo and updates AppHost configuration

set -e

# Validation
if [ -z "$PROXMOX_HOST" ]; then
    echo "Error: PROXMOX_HOST is not set"
    echo "Example: export PROXMOX_HOST='192.168.1.100'"
    exit 1
fi

SSH_KEY_PATH="${SSH_KEY_PATH:-/home/vscode/.ssh/crucible_proxmox}"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Error: SSH key not found at $SSH_KEY_PATH"
    echo "Set SSH_KEY_PATH to your SSH private key path"
    exit 1
fi

PROXMOX_USER="${PROXMOX_USER:-root}"
TOKEN_NAME="topomojo"

echo "Setting up Proxmox for TopoMojo..."
echo "Host: $PROXMOX_HOST"
echo ""

# Create API token on Proxmox
echo "Creating API token for TopoMojo..."
TOKEN_OUTPUT=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${PROXMOX_USER}@${PROXMOX_HOST}" << 'EOF'
set -e

# Check if token already exists
if pveum user token list root@pam | grep -q "topomojo"; then
    echo "Token 'topomojo' already exists, deleting..."
    pveum user token remove root@pam topomojo
fi

# Create new token with privilege separation disabled (full root permissions)
echo "Creating token with full root privileges..."
pveum user token add root@pam topomojo --privsep 0

# Verify token has Administrator role (should inherit from root@pam)
echo "Verifying token permissions..."
pveum user token list root@pam

EOF
)

echo "$TOKEN_OUTPUT"
echo ""

# Extract token from output
TOKEN_VALUE=$(echo "$TOKEN_OUTPUT" | grep -E "│ value\s+│" | awk -F'│' '{print $3}' | xargs)

if [ -z "$TOKEN_VALUE" ]; then
    echo "Error: Failed to extract token value"
    exit 1
fi

FULL_TOKEN="root@pam!topomojo=${TOKEN_VALUE}"
echo "✓ API token created: ${FULL_TOKEN:0:40}..."
echo ""

# Update AppHost.cs with the token
echo "Updating AppHost.cs with TopoMojo token..."
APPHOST_FILE="/workspaces/crucible-development/Crucible.AppHost/AppHost.cs"

# Use sed to replace the token (use # as delimiter to avoid conflicts with !)
sed -i "s#Pod__AccessToken\", \"root@pam!topomojo=.*\"#Pod__AccessToken\", \"${FULL_TOKEN}\"#" "$APPHOST_FILE"

echo "✓ AppHost.cs updated"
echo ""

echo "==============================================="
echo "SUCCESS!"
echo "==============================================="
echo "TopoMojo Proxmox API token: ${FULL_TOKEN}"
echo ""
echo "Configuration:"
echo "  Host: ${PROXMOX_HOST}"
echo "  VM/Disk Storage: local-lvm"
echo "  ISO Storage: local:iso"
echo ""
echo "Restart TopoMojo API from Aspire dashboard for changes to take effect."
