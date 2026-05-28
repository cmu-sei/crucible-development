#!/bin/bash
# Create Tiny Core Linux VM template on Proxmox
# Tiny (15MB), boots in seconds, has GUI, perfect for testing

set -e

PROXMOX_HOST="${PROXMOX_HOST}"
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_proxmox}"
TEMPLATE_ID="${TEMPLATE_ID:-106}"
TEMPLATE_NAME="tinycore-linux-template"
TINYCORE_VERSION="15.0"
TINYCORE_ISO_URL="http://tinycorelinux.net/15.x/x86/release/TinyCore-current.iso"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Creating Tiny Core Linux VM Template${NC}"
echo ""

if [ -z "$PROXMOX_HOST" ]; then
  echo "Error: PROXMOX_HOST not set"
  exit 1
fi

echo "  Template ID: $TEMPLATE_ID"
echo "  Template Name: $TEMPLATE_NAME"
echo "  Size: ~15MB"
echo "  Features: GUI, copy/paste support"
echo ""

ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << 'VMEOF'
set -e

TEMPLATE_ID=106
TINYCORE_ISO_URL="http://tinycorelinux.net/15.x/x86/release/TinyCore-current.iso"

# Delete existing
if qm list | grep -q "^\s*${TEMPLATE_ID}"; then
  echo "Removing existing VM ${TEMPLATE_ID}..."
  qm stop ${TEMPLATE_ID} || true
  qm destroy ${TEMPLATE_ID} || true
fi

# Download ISO
ISO_PATH="/var/lib/vz/template/iso/TinyCore-current.iso"
if [ ! -f "$ISO_PATH" ]; then
  echo "Downloading Tiny Core ISO..."
  cd /var/lib/vz/template/iso
  wget -q --show-progress "$TINYCORE_ISO_URL"
  echo "✓ Downloaded"
else
  echo "✓ ISO exists"
fi

# Create VM
echo "Creating VM..."
qm create ${TEMPLATE_ID} \
  --name tinycore-linux-template \
  --memory 512 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0 \
  --cdrom local:iso/TinyCore-current.iso \
  --ostype l26 \
  --vga std

# Create disk (4GB is plenty)
echo "Creating disk..."
qm set ${TEMPLATE_ID} --scsi0 local-lvm:4,discard=on

# Boot from disk (Tiny Core runs from RAM after boot)
qm set ${TEMPLATE_ID} --boot c --bootdisk scsi0

# Enable agent
qm set ${TEMPLATE_ID} --agent enabled=1

# Convert to template
echo "Converting to template..."
qm template ${TEMPLATE_ID}

echo "✓ Template created"

VMEOF

echo ""
echo -e "${GREEN}✓ Tiny Core Linux template created${NC}"
echo ""
echo "Features:"
echo "  • GUI desktop (FLWM window manager)"
echo "  • Copy/paste support via SPICE/noVNC"
echo "  • 15MB ISO, boots in seconds"
echo "  • Runs entirely from RAM"
echo ""
echo "Usage:"
echo "  1. Clone template to create VM"
echo "  2. Start VM and open console (use noVNC for GUI)"
echo "  3. Test copy/paste in console"
echo ""
