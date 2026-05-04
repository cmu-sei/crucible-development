#!/bin/bash
# Create an Alpine Linux VM in Proxmox via API

set -e

# Configuration (override with environment variables)
PROXMOX_HOST="${PROXMOX_HOST:-172.22.69.122}"
PROXMOX_PORT="${PROXMOX_PORT:-8006}"
PROXMOX_TOKEN="${PROXMOX_TOKEN:-root@pam!crucible=your-token-here}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"

# VM Configuration
VM_ID="${VM_ID:-101}"
VM_NAME="${VM_NAME:-alpine-test}"
VM_MEMORY="${VM_MEMORY:-512}"
VM_CORES="${VM_CORES:-1}"
VM_DISK_SIZE="${VM_DISK_SIZE:-2}"
VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"
ALPINE_ISO="${ALPINE_ISO:-local:iso/alpine-virt-3.19.0-x86_64.iso}"

echo "Creating Alpine Linux VM in Proxmox..."
echo "  Host: $PROXMOX_HOST"
echo "  Node: $PROXMOX_NODE"
echo "  VM ID: $VM_ID"
echo "  VM Name: $VM_NAME"
echo "  Memory: ${VM_MEMORY}MB"
echo "  Cores: $VM_CORES"
echo "  Disk: ${VM_DISK_SIZE}GB on $VM_STORAGE"
echo "  ISO: $ALPINE_ISO"
echo ""

# Check if VM already exists
echo "Checking if VM $VM_ID already exists..."
EXISTING=$(curl -k -s \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
  "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/status/current" \
  | grep -o '"status"' || echo "")

if [ -n "$EXISTING" ]; then
  echo "Error: VM $VM_ID already exists. Use a different VM_ID or delete the existing VM."
  exit 1
fi

# Create VM
echo "Creating VM $VM_ID..."
CREATE_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
  --data-urlencode "vmid=${VM_ID}" \
  --data-urlencode "name=${VM_NAME}" \
  --data-urlencode "memory=${VM_MEMORY}" \
  --data-urlencode "cores=${VM_CORES}" \
  --data-urlencode "net0=virtio,bridge=${VM_BRIDGE}" \
  --data-urlencode "scsi0=${VM_STORAGE}:${VM_DISK_SIZE}" \
  --data-urlencode "scsihw=virtio-scsi-pci" \
  --data-urlencode "ide2=${ALPINE_ISO},media=cdrom" \
  --data-urlencode "boot=cdn" \
  --data-urlencode "ostype=l26" \
  "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/nodes/${PROXMOX_NODE}/qemu")

echo "$CREATE_RESPONSE"

if echo "$CREATE_RESPONSE" | grep -q '"data"'; then
  echo ""
  echo "✓ VM $VM_ID ($VM_NAME) created successfully!"
  echo ""
  echo "Starting VM..."

  START_RESPONSE=$(curl -k -s -X POST \
    -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
    "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/status/start")

  if echo "$START_RESPONSE" | grep -q '"data"'; then
    echo "✓ VM started!"
    echo ""
    echo "Next steps:"
    echo "  1. Access Proxmox web UI: https://${PROXMOX_HOST}:${PROXMOX_PORT}"
    echo "  2. Open console for VM $VM_ID"
    echo "  3. Login as root (no password on Alpine virt)"
    echo "  4. Run setup-alpine in the VM console"
    echo ""
    echo "After VM setup is complete, register it in Player VM API:"
    echo "  VM_ID=$VM_ID ./scripts/create-vm-api-record.sh"
  else
    echo "✗ Failed to start VM"
  fi
else
  echo ""
  echo "✗ Failed to create VM. Response:"
  echo "$CREATE_RESPONSE"
  exit 1
fi
