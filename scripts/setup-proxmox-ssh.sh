#!/bin/bash
# Setup SSH key authentication to Proxmox host
# This script generates an SSH key pair and configures the Proxmox host for passwordless access

set -e

# Configuration
PROXMOX_HOST="${PROXMOX_HOST:-172.22.69.122}"
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_proxmox}"
SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"

echo "Setting up SSH key authentication to Proxmox host"
echo "  Host: $PROXMOX_HOST"
echo "  User: $PROXMOX_USER"
echo "  Key Path: $SSH_KEY_PATH"
echo ""

# Create .ssh directory if it doesn't exist
mkdir -p "$(dirname "$SSH_KEY_PATH")"
chmod 700 "$(dirname "$SSH_KEY_PATH")"

# Generate SSH key pair if it doesn't exist
if [[ -f "$SSH_KEY_PATH" ]]; then
  echo "✓ SSH key already exists: $SSH_KEY_PATH"
else
  echo "Generating SSH key pair..."
  ssh-keygen -t "$SSH_KEY_TYPE" -f "$SSH_KEY_PATH" -N "" -C "crucible-dev@proxmox"
  echo "✓ SSH key generated: $SSH_KEY_PATH"
fi

echo ""

# Check if we can already connect without password
if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
  echo "✓ Passwordless SSH already configured!"
  echo ""
  echo "You can connect with:"
  echo "  ssh -i $SSH_KEY_PATH $PROXMOX_USER@$PROXMOX_HOST"
  exit 0
fi

# Need to install the key
echo "Installing SSH key to Proxmox host..."
echo "You will be prompted for the Proxmox root password (set during installation)"
echo ""

# Check if ssh-copy-id is available
if ! command -v ssh-copy-id &> /dev/null; then
  echo "Error: ssh-copy-id not found. Installing key manually..."

  # Read password
  read -s -p "Enter Proxmox root password: " PROXMOX_PASSWORD
  echo ""

  # Create authorized_keys directory and add key via SSH
  PUB_KEY=$(cat "${SSH_KEY_PATH}.pub")
  sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUB_KEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

  if [[ $? -eq 0 ]]; then
    echo "✓ SSH key installed successfully"
  else
    echo "✗ Failed to install SSH key"
    echo ""
    echo "Manual installation:"
    echo "  1. Copy the public key:"
    echo "     cat ${SSH_KEY_PATH}.pub"
    echo "  2. SSH to Proxmox: ssh $PROXMOX_USER@$PROXMOX_HOST"
    echo "  3. Add to authorized_keys:"
    echo "     mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    echo "     echo '<paste-public-key>' >> ~/.ssh/authorized_keys"
    echo "     chmod 600 ~/.ssh/authorized_keys"
    exit 1
  fi
else
  # Use ssh-copy-id (preferred method)
  ssh-copy-id -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST"

  if [[ $? -eq 0 ]]; then
    echo "✓ SSH key installed successfully"
  else
    echo "✗ Failed to install SSH key"
    exit 1
  fi
fi

echo ""
echo "Testing passwordless SSH connection..."
if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
  echo "✓ Passwordless SSH working!"
else
  echo "✗ Passwordless SSH test failed"
  exit 1
fi

echo ""
echo "✓ SSH key authentication configured successfully!"
echo ""
echo "Usage:"
echo "  ssh -i $SSH_KEY_PATH $PROXMOX_USER@$PROXMOX_HOST"
echo ""
echo "To add to SSH config, add this to ~/.ssh/config:"
echo ""
echo "Host proxmox proxmox-ve"
echo "    HostName $PROXMOX_HOST"
echo "    User $PROXMOX_USER"
echo "    IdentityFile $SSH_KEY_PATH"
echo "    StrictHostKeyChecking no"
echo ""
echo "Then connect with: ssh proxmox"
echo ""
echo "Next step:"
echo "  PROXMOX_HOST=$PROXMOX_HOST ./scripts/create-proxmox-api-token.sh"
