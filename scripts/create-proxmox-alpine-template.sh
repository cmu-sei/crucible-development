#!/bin/bash
# Create Alpine Linux VM template on Proxmox using cloud image
# Fast, automated template creation - no manual installation needed

set -e

# Configuration
PROXMOX_HOST="${PROXMOX_HOST}"
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_proxmox}"
TEMPLATE_ID="${TEMPLATE_ID:-105}"
TEMPLATE_NAME="alpine-linux-template"
ALPINE_VERSION="3.19"
ALPINE_CLOUD_IMAGE="nocloud_alpine-${ALPINE_VERSION}.2-x86_64-uefi-cloudinit-r0.qcow2"
ALPINE_CLOUD_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/cloud/${ALPINE_CLOUD_IMAGE}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Creating Alpine Linux VM Template (Cloud Image)${NC}"
echo ""

if [ -z "$PROXMOX_HOST" ]; then
  echo -e "${RED}Error: PROXMOX_HOST not set${NC}"
  exit 1
fi

echo "  Template ID: $TEMPLATE_ID"
echo "  Template Name: $TEMPLATE_NAME"
echo "  Alpine Version: $ALPINE_VERSION"
echo "  Using: Cloud image (automated)"
echo ""

# Download and setup template on Proxmox
echo -e "${YELLOW}Creating template from cloud image...${NC}"
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << 'VMEOF'
set -e

TEMPLATE_ID=105
ALPINE_VERSION="3.19"
ALPINE_CLOUD_IMAGE="nocloud_alpine-${ALPINE_VERSION}.2-x86_64-uefi-cloudinit-r0.qcow2"
ALPINE_CLOUD_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/cloud/${ALPINE_CLOUD_IMAGE}"

# Delete existing VM/template if exists
if qm list | grep -q "^\s*${TEMPLATE_ID}"; then
  echo "Removing existing VM ${TEMPLATE_ID}..."
  qm stop ${TEMPLATE_ID} || true
  qm destroy ${TEMPLATE_ID} || true
fi

# Download cloud image if not present
IMAGE_PATH="/var/lib/vz/template/iso/${ALPINE_CLOUD_IMAGE}"
if [ ! -f "$IMAGE_PATH" ]; then
  echo "Downloading Alpine cloud image..."
  cd /var/lib/vz/template/iso
  wget -q --show-progress "$ALPINE_CLOUD_URL"
  echo "✓ Cloud image downloaded"
else
  echo "✓ Cloud image already exists"
fi

# Create VM
echo "Creating VM ${TEMPLATE_ID}..."
qm create ${TEMPLATE_ID} \
  --name alpine-linux-template \
  --memory 512 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26

# Import cloud image as disk
echo "Importing cloud image as disk..."
qm importdisk ${TEMPLATE_ID} "$IMAGE_PATH" local-lvm

# Attach disk
echo "Attaching disk..."
qm set ${TEMPLATE_ID} --scsi0 local-lvm:vm-${TEMPLATE_ID}-disk-0,discard=on

# Configure boot (Proxmox 8+ format)
qm set ${TEMPLATE_ID} --boot c --bootdisk scsi0

# Enable QEMU guest agent
qm set ${TEMPLATE_ID} --agent enabled=1

# Add cloud-init drive
echo "Adding cloud-init configuration..."
qm set ${TEMPLATE_ID} --ide2 local-lvm:cloudinit

# Set cloud-init defaults
qm set ${TEMPLATE_ID} --ciuser root
qm set ${TEMPLATE_ID} --cipassword password
qm set ${TEMPLATE_ID} --ipconfig0 ip=dhcp

# Add serial console
qm set ${TEMPLATE_ID} --serial0 socket --vga serial0

# Convert to template
echo "Converting to template..."
qm template ${TEMPLATE_ID}

echo "✓ Template created successfully"

VMEOF

echo ""
echo -e "${GREEN}✓ Alpine Linux template created${NC}"
echo ""
echo "Template details:"
echo "  ID: $TEMPLATE_ID"
echo "  Name: alpine-linux-template"
echo "  Type: Cloud-init enabled"
echo "  Credentials: root / password"
echo ""
echo "Usage:"
echo "  • TopoMojo: Reference template ID $TEMPLATE_ID"
echo "  • Caster: Use vm_id = $TEMPLATE_ID in Terraform"
echo "  • Clone: Right-click template in Proxmox UI → Clone"
echo ""
