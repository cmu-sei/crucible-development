#!/bin/bash
# Setup SSH key authentication for ESXi host

set -e

ESXI_HOST="${ESXI_HOST:-}"
ESXI_PASSWORD="${ESXI_PASSWORD:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_esxi}"

echo "ESXi SSH Setup"
echo ""

# Prompt for ESXi host if not set
if [ -z "$ESXI_HOST" ]; then
  read -p "Enter ESXi host IP address: " ESXI_HOST
fi

# Prompt for password if not set
if [ -z "$ESXI_PASSWORD" ]; then
  read -s -p "Enter ESXi root password: " ESXI_PASSWORD
  echo ""
fi

echo "  ESXi Host: $ESXI_HOST"
echo "  SSH Key: $SSH_KEY_PATH"
echo ""

# Generate SSH key if doesn't exist
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "Generating SSH key pair..."
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "crucible-esxi"
  echo "✓ SSH key generated"
else
  echo "✓ SSH key already exists"
fi

# Test basic connectivity
echo ""
echo "Testing ESXi connectivity..."
if ! sshpass -p "$ESXI_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$ESXI_HOST "echo connected" > /dev/null 2>&1; then
  echo "✗ Cannot connect to ESXi host"
  echo "  Check:"
  echo "    - ESXi host IP is correct: $ESXI_HOST"
  echo "    - SSH is enabled on ESXi (Troubleshooting Options → Enable SSH)"
  echo "    - Root password is correct"
  echo "    - Network connectivity from this machine to ESXi"
  exit 1
fi
echo "✓ ESXi is reachable"

# Copy public key to ESXi
echo ""
echo "Installing public key on ESXi..."
sshpass -p "$ESXI_PASSWORD" ssh-copy-id -i "$SSH_KEY_PATH.pub" -o StrictHostKeyChecking=no root@$ESXI_HOST

echo "✓ Public key installed"

# Test passwordless authentication
echo ""
echo "Testing passwordless authentication..."
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$ESXI_HOST "echo authenticated" > /dev/null 2>&1; then
  echo "✓ Passwordless SSH authentication working"
else
  echo "✗ Passwordless authentication failed"
  exit 1
fi

# Make SSH persistent across ESXi reboots
echo ""
echo "Making SSH configuration persistent..."
sshpass -p "$ESXI_PASSWORD" ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST << 'EOF'
  /etc/init.d/SSH start
  chkconfig SSH on
EOF
echo "✓ SSH will start automatically on boot"

echo ""
echo "✓ ESXi SSH setup complete"
echo ""
echo "Test connection:"
echo "  ssh -i $SSH_KEY_PATH root@$ESXI_HOST"
echo ""
echo "Next step:"
echo "  ESXI_HOST=$ESXI_HOST ./scripts/configure-esxi-basics.sh"
