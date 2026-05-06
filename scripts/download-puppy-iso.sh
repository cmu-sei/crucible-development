#!/bin/bash
# Download Puppy Linux ISO to Proxmox host

set -e

PROXMOX_HOST="${PROXMOX_HOST:-172.22.71.38}"
PUPPY_ISO="fossapup64-9.5.iso"
PUPPY_URL="http://distro.ibiblio.org/puppylinux/puppy-fossa/${PUPPY_ISO}"

echo "Downloading Puppy Linux ISO to Proxmox host"
echo "  Host: $PROXMOX_HOST"
echo "  ISO: $PUPPY_ISO"
echo ""

echo "Checking if ISO already exists..."
EXISTING=$(ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST \
  "test -f /var/lib/vz/template/iso/${PUPPY_ISO} && echo 'exists' || echo 'not found'")

if [ "$EXISTING" = "exists" ]; then
  echo "✓ ISO already exists on Proxmox host"
  exit 0
fi

echo "Downloading ISO to Proxmox (this may take a few minutes)..."
ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST \
  "cd /var/lib/vz/template/iso && wget -q --show-progress -O ${PUPPY_ISO} ${PUPPY_URL}"

echo ""
echo "✓ Puppy Linux ISO downloaded successfully!"
echo ""
echo "ISO location: /var/lib/vz/template/iso/${PUPPY_ISO}"
echo "Proxmox reference: local:iso/${PUPPY_ISO}"
echo ""
echo "Next step:"
echo "  PROXMOX_HOST=$PROXMOX_HOST ./scripts/create-puppy-vm.sh"
