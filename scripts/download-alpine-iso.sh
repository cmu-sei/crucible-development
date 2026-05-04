#!/bin/bash
# Download Alpine Linux ISO to Proxmox host

set -e

PROXMOX_HOST="${PROXMOX_HOST:-172.22.71.38}"
ALPINE_VERSION="${ALPINE_VERSION:-3.19.0}"
ALPINE_ISO="alpine-virt-${ALPINE_VERSION}-x86_64.iso"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/${ALPINE_ISO}"

echo "Downloading Alpine Linux ISO to Proxmox host"
echo "  Host: $PROXMOX_HOST"
echo "  Version: $ALPINE_VERSION"
echo "  ISO: $ALPINE_ISO"
echo ""

echo "Checking if ISO already exists..."
EXISTING=$(ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST \
  "test -f /var/lib/vz/template/iso/${ALPINE_ISO} && echo 'exists' || echo 'not found'")

if [ "$EXISTING" = "exists" ]; then
  echo "✓ ISO already exists on Proxmox host"
  exit 0
fi

echo "Downloading ISO to Proxmox (this may take a few minutes)..."
ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST \
  "cd /var/lib/vz/template/iso && wget -q --show-progress -O ${ALPINE_ISO} ${ALPINE_URL}"

echo ""
echo "✓ Alpine ISO downloaded successfully!"
echo ""
echo "ISO location: /var/lib/vz/template/iso/${ALPINE_ISO}"
echo "Proxmox reference: local:iso/${ALPINE_ISO}"
echo ""
echo "Next step:"
echo "  PROXMOX_HOST=$PROXMOX_HOST ./scripts/create-proxmox-vm.sh"
