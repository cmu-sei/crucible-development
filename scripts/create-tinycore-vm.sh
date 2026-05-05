#!/bin/bash
# Create Tiny Core Linux VM on Proxmox host

set -e

PROXMOX_HOST="${PROXMOX_HOST:-172.22.71.38}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
VM_ID="${VM_ID:-102}"
VM_NAME="${VM_NAME:-tinycore-test}"
TINYCORE_ISO="TinyCorePure64-14.0.iso"

echo "Creating Tiny Core Linux VM on Proxmox"
echo "  Host: $PROXMOX_HOST"
echo "  Node: $PROXMOX_NODE"
echo "  VM ID: $VM_ID"
echo "  VM Name: $VM_NAME"
echo ""

# Check if VM already exists
echo "Checking if VM $VM_ID already exists..."
VM_EXISTS=$(ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST \
  "qm status $VM_ID 2>/dev/null && echo 'exists' || echo 'not found'")

if [ "$VM_EXISTS" = "exists" ]; then
  echo "✓ VM $VM_ID already exists"
  echo ""
  echo "Next step:"
  echo "  VM_NAME=$VM_NAME PROXMOX_VM_ID=$VM_ID ./scripts/add-vm-only.sh"
  exit 0
fi

# Create VM
echo "Creating VM..."
ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST <<EOF
qm create $VM_ID \
  --name $VM_NAME \
  --memory 512 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0 \
  --ide2 local:iso/${TINYCORE_ISO},media=cdrom \
  --boot order=ide2 \
  --ostype l26 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:1,format=raw \
  --vga std
EOF

echo ""
echo "✓ Tiny Core Linux VM created successfully!"
echo ""
echo "VM Details:"
echo "  VM ID: $VM_ID"
echo "  Name: $VM_NAME"
echo "  RAM: 512MB"
echo "  Disk: 1GB"
echo "  Network: virtio (vmbr0)"
echo ""
echo "Start the VM in Proxmox UI or run:"
echo "  ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST qm start $VM_ID"
echo ""
echo "Next step:"
echo "  VM_NAME=$VM_NAME PROXMOX_VM_ID=$VM_ID ./scripts/add-vm-only.sh"
