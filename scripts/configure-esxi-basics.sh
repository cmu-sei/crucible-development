#!/bin/bash
# Configure basic ESXi settings and verify setup

set -e

ESXI_HOST="${ESXI_HOST:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_esxi}"
DATASTORE="${DATASTORE:-datastore1}"

echo "ESXi Basic Configuration"
echo ""

# Prompt for ESXi host if not set
if [ -z "$ESXI_HOST" ]; then
  read -p "Enter ESXi host IP address: " ESXI_HOST
fi

echo "  ESXi Host: $ESXI_HOST"
echo "  Datastore: $DATASTORE"
echo ""

# Setup govc environment
export GOVC_URL="https://$ESXI_HOST"
export GOVC_USERNAME="root"
export GOVC_INSECURE=true

# Check if govc is installed
if ! command -v govc &> /dev/null; then
  echo "✗ govc is not installed"
  echo ""
  echo "Install govc:"
  echo "  curl -L -o - https://github.com/vmware/govmomi/releases/download/v0.37.0/govc_\$(uname -s)_\$(uname -m).tar.gz | sudo tar -C /usr/local/bin -xvzf - govc"
  exit 1
fi

# Try to authenticate with govc using password from environment or prompt
if [ -z "$ESXI_PASSWORD" ]; then
  read -s -p "Enter ESXi root password: " ESXI_PASSWORD
  echo ""
fi
export GOVC_PASSWORD="$ESXI_PASSWORD"

# Test govc connectivity
echo "Testing govc connectivity..."
if ! govc about > /dev/null 2>&1; then
  echo "✗ Cannot connect to ESXi via govc"
  echo "  Check ESXI_HOST and ESXI_PASSWORD"
  exit 1
fi
echo "✓ govc connected"

# Verify datastore exists
echo ""
echo "Checking datastore..."
if ! govc datastore.info -ds="$DATASTORE" > /dev/null 2>&1; then
  echo "✗ Datastore '$DATASTORE' not found"
  echo ""
  echo "Available datastores:"
  govc datastore.info | grep -E "Name:|Free:"
  exit 1
fi
echo "✓ Datastore '$DATASTORE' exists"

# Create ISO directory
echo ""
echo "Creating directory structure..."
ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST << EOF
  mkdir -p /vmfs/volumes/$DATASTORE/ISO
  mkdir -p /vmfs/volumes/$DATASTORE/player
EOF
echo "✓ Directories created"

# Verify VM Network port group
echo ""
echo "Checking VM Network..."
if ! govc host.portgroup.info "VM Network" > /dev/null 2>&1; then
  echo "⚠ VM Network port group not found (may use default)"
  echo ""
  echo "Available port groups:"
  govc host.portgroup.info | grep Name:
else
  echo "✓ VM Network port group available"
fi

echo ""
echo "✓ ESXi basic configuration complete"
echo ""
echo "Datastore layout:"
ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST "ls -lh /vmfs/volumes/$DATASTORE/"
echo ""
echo "Next step:"
echo "  ESXI_HOST=$ESXI_HOST ./scripts/download-alpine-iso-esxi.sh"
