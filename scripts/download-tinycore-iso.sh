#!/bin/bash
# Download Tiny Core Linux ISO to Proxmox host

set -e

PROXMOX_HOST="${PROXMOX_HOST:-172.22.71.38}"
TINYCORE_ISO="TinyCorePure64-14.0.iso"
TINYCORE_URL="http://www.tinycorelinux.net/14.x/x86_64/release/${TINYCORE_ISO}"

echo "Downloading Tiny Core Linux ISO to Proxmox host"
echo "  Host: $PROXMOX_HOST"
echo "  ISO: $TINYCORE_ISO"
echo ""

echo "Checking if ISO already exists..."
EXISTING=$(ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST \
  "test -f /var/lib/vz/template/iso/${TINYCORE_ISO} && echo 'exists' || echo 'not found'")

if [ "$EXISTING" = "exists" ]; then
  echo "✓ ISO already exists on Proxmox host"
  exit 0
fi

echo "Downloading ISO to Proxmox (this may take a few minutes)..."
ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST \
  "cd /var/lib/vz/template/iso && wget -q --show-progress -O ${TINYCORE_ISO} ${TINYCORE_URL}"

echo ""
echo "✓ Tiny Core ISO downloaded successfully!"
echo ""
echo "ISO location: /var/lib/vz/template/iso/${TINYCORE_ISO}"
echo "Proxmox reference: local:iso/${TINYCORE_ISO}"
echo ""
echo "Next step:"
echo "  PROXMOX_HOST=$PROXMOX_HOST ./scripts/create-tinycore-vm.sh"
