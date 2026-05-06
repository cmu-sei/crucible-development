#!/bin/bash
# Download Alpine Linux ISO to ESXi datastore

set -e

ESXI_HOST="${ESXI_HOST:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_esxi}"
DATASTORE="${DATASTORE:-datastore1}"
ALPINE_VERSION="${ALPINE_VERSION:-3.19.0}"
ALPINE_ISO="alpine-virt-$ALPINE_VERSION-x86_64.iso"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/releases/x86_64/$ALPINE_ISO"

echo "Download Alpine ISO to ESXi"
echo ""

# Prompt for ESXi host if not set
if [ -z "$ESXI_HOST" ]; then
  read -p "Enter ESXi host IP address: " ESXI_HOST
fi

echo "  ESXi Host: $ESXI_HOST"
echo "  Datastore: $DATASTORE"
echo "  Alpine Version: $ALPINE_VERSION"
echo "  ISO: $ALPINE_ISO"
echo ""

# Check if ISO already exists
echo "Checking if ISO exists..."
if ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST "test -f /vmfs/volumes/$DATASTORE/ISO/$ALPINE_ISO"; then
  echo "✓ ISO already exists"
  exit 0
fi

# Download to ESXi
echo "Downloading Alpine ISO to ESXi..."
echo "  URL: $ALPINE_URL"
echo ""

ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST << EOF
  cd /vmfs/volumes/$DATASTORE/ISO/
  wget -q --show-progress -O $ALPINE_ISO $ALPINE_URL
EOF

echo ""
echo "✓ Alpine ISO downloaded"

# Verify file
FILE_SIZE=$(ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST "ls -lh /vmfs/volumes/$DATASTORE/ISO/$ALPINE_ISO | awk '{print \$5}'")
echo "  File: $ALPINE_ISO"
echo "  Size: $FILE_SIZE"
echo ""
echo "Next step:"
echo "  ESXI_HOST=$ESXI_HOST ./scripts/create-alpine-vm-esxi.sh"
