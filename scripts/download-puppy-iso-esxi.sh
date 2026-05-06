#!/bin/bash
# Download Puppy Linux ISO to ESXi datastore

set -e

ESXI_HOST="${ESXI_HOST:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_esxi}"
DATASTORE="${DATASTORE:-datastore1}"
PUPPY_ISO="puppylinux-bionicpup64-8.0-uefi.iso"
PUPPY_URL="http://distro.ibiblio.org/puppylinux/puppy-bionic/bionicpup64/$PUPPY_ISO"

echo "Download Puppy Linux ISO to ESXi"
echo ""

# Prompt for ESXi host if not set
if [ -z "$ESXI_HOST" ]; then
  read -p "Enter ESXi host IP address: " ESXI_HOST
fi

echo "  ESXi Host: $ESXI_HOST"
echo "  Datastore: $DATASTORE"
echo "  ISO: $PUPPY_ISO"
echo ""

# Check if ISO already exists
echo "Checking if ISO exists..."
if ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST "test -f /vmfs/volumes/$DATASTORE/ISO/$PUPPY_ISO"; then
  echo "✓ ISO already exists"
  exit 0
fi

# Download to ESXi
echo "Downloading Puppy Linux ISO to ESXi..."
echo "  URL: $PUPPY_URL"
echo ""

ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST << EOF
  cd /vmfs/volumes/$DATASTORE/ISO/
  wget -q --show-progress -O $PUPPY_ISO $PUPPY_URL
EOF

echo ""
echo "✓ Puppy Linux ISO downloaded"

# Verify file
FILE_SIZE=$(ssh -i "$SSH_KEY_PATH" root@$ESXI_HOST "ls -lh /vmfs/volumes/$DATASTORE/ISO/$PUPPY_ISO | awk '{print \$5}'")
echo "  File: $PUPPY_ISO"
echo "  Size: $FILE_SIZE"
echo ""
echo "Next step:"
echo "  ESXI_HOST=$ESXI_HOST ./scripts/create-puppy-vm-esxi.sh"
