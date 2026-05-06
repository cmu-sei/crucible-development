#!/bin/bash
# Create a Puppy Linux VM in Proxmox via API for clipboard testing

set -e

# Configuration (override with environment variables)
PROXMOX_HOST="${PROXMOX_HOST:-172.22.69.122}"
PROXMOX_PORT="${PROXMOX_PORT:-8006}"
PROXMOX_TOKEN="${PROXMOX_TOKEN:-root@pam!crucible=your-token-here}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"

# VM Configuration
VM_ID="${VM_ID:-102}"
VM_NAME="${VM_NAME:-puppy-linux}"
VM_MEMORY="${VM_MEMORY:-1024}"
VM_CORES="${VM_CORES:-2}"
VM_DISK_SIZE="${VM_DISK_SIZE:-4}"
VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"
PUPPY_ISO="${PUPPY_ISO:-local:iso/puppylinux-bionicpup64-8.0-uefi.iso}"

echo "Creating Puppy Linux VM in Proxmox..."
echo "  Host: $PROXMOX_HOST"
echo "  Node: $PROXMOX_NODE"
echo "  VM ID: $VM_ID"
echo "  VM Name: $VM_NAME"
echo "  Memory: ${VM_MEMORY}MB"
echo "  Cores: $VM_CORES"
echo "  Disk: ${VM_DISK_SIZE}GB on $VM_STORAGE"
echo "  ISO: $PUPPY_ISO"
echo ""

# Download Puppy Linux ISO if not exists
echo "Checking if Puppy Linux ISO exists in Proxmox..."
ISO_CHECK=$(curl -k -s \
  -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
  "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/nodes/${PROXMOX_NODE}/storage/local/content" \
  | grep -o "puppylinux" || echo "")

if [ -z "$ISO_CHECK" ]; then
  echo "Puppy Linux ISO not found. Downloading..."
  echo "Download Puppy Linux 8.0 from: https://distro.ibiblio.org/puppylinux/puppy-bionic/bionicpup64/8.0/"
  echo ""
  echo "After download, upload to Proxmox:"
  echo "  scp puppylinux-bionicpup64-8.0-uefi.iso root@${PROXMOX_HOST}:/var/lib/vz/template/iso/"
  echo ""
  echo "Or use Proxmox web UI: Datacenter > Storage > local > ISO Images > Upload"
  echo ""
  echo "Then re-run this script."
  exit 1
fi

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
  --data-urlencode "ide2=${PUPPY_ISO},media=cdrom" \
  --data-urlencode "boot=cdn" \
  --data-urlencode "ostype=l26" \
  --data-urlencode "vga=std" \
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
    echo "Puppy Linux will boot directly to desktop (no installation needed)."
    echo "It runs entirely in RAM for fast testing."
    echo ""
    echo "Next steps:"
    echo "  1. Access Proxmox web UI: https://${PROXMOX_HOST}:${PROXMOX_PORT}"
    echo "  2. Open console for VM $VM_ID"
    echo "  3. Wait for desktop to load (~30 seconds)"
    echo "  4. Test clipboard:"
    echo "     - Open text editor (Menu > Document > Geany)"
    echo "     - Type text and copy (Ctrl+C)"
    echo "     - Paste in your host OS"
    echo "     - Copy text in host OS"
    echo "     - Paste in VM (Ctrl+V)"
    echo ""
    echo "After testing, register it in Player VM API:"
    echo "  VM_ID=$VM_ID VM_NAME=$VM_NAME ./scripts/create-vm-api-record.sh"
  else
    echo "✗ Failed to start VM"
  fi
else
  echo ""
  echo "✗ Failed to create VM. Response:"
  echo "$CREATE_RESPONSE"
  exit 1
fi
