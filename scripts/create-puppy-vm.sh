#!/bin/bash
# Create Puppy Linux VM on Proxmox host

set -e

PROXMOX_HOST="${PROXMOX_HOST}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
VM_ID="${VM_ID:-103}"
VM_NAME="${VM_NAME:-puppy-test}"
PUPPY_ISO="fossapup64-9.5.iso"
VM_API_URL="${VM_API_URL:-http://localhost:4302/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo "Creating Puppy Linux VM on Proxmox"
echo "  Host: $PROXMOX_HOST"
echo "  Node: $PROXMOX_NODE"
echo "  VM ID: $VM_ID"
echo "  VM Name: $VM_NAME"
echo ""

# Check if VM already exists on Proxmox
echo "Checking if VM $VM_ID already exists on Proxmox..."
VM_EXISTS=$(ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST \
  "qm status $VM_ID 2>/dev/null && echo 'exists' || echo 'not found'")

# Check if VM already exists in database
echo "Checking if VM $VM_ID exists in Player VM API database..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.vm.admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" 2>/dev/null || true)

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4 || true)
DB_EXISTS=false

if [ -n "$ACCESS_TOKEN" ]; then
  ALL_VMS=$(curl -k -s -X GET "$VM_API_URL/vms" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null || true)

  EXISTING_VM=$(echo "$ALL_VMS" | grep -o "\"proxmoxVmInfo\":{\"id\":$VM_ID[^}]*}" || true)

  if [ -n "$EXISTING_VM" ]; then
    DB_EXISTS=true
  fi
fi

# Decision logic
if [ "$VM_EXISTS" = "exists" ] && [ "$DB_EXISTS" = true ]; then
  echo "✓ VM $VM_ID exists on both Proxmox and database - nothing to do"
  echo ""
  echo "Access at: http://localhost:4303/views/b5e8f7a9-3c4d-4e5f-9a8b-1c2d3e4f5a6b?theme=light-theme"
  exit 0
elif [ "$VM_EXISTS" = "exists" ] && [ "$DB_EXISTS" = false ]; then
  echo "✓ VM $VM_ID exists on Proxmox but not in database"
  echo ""
  echo "Next step to register it:"
  echo "  VM_NAME=$VM_NAME PROXMOX_VM_ID=$VM_ID ./scripts/create-vm-api-record.sh"
  exit 0
elif [ "$VM_EXISTS" = "not found" ] && [ "$DB_EXISTS" = true ]; then
  echo "✓ VM $VM_ID exists in database but not on Proxmox - recreating Proxmox VM"
  echo ""
  echo "To delete the database record instead:"
  echo "  PROXMOX_IDS=$VM_ID ./scripts/remove-vms-from-db.sh"
  echo ""
fi

# Check for duplicate names
if [ -n "$ACCESS_TOKEN" ]; then
  EXISTING_NAME=$(echo "$ALL_VMS" | grep -o "\"name\":\"$VM_NAME\"" || true)

  if [ -n "$EXISTING_NAME" ]; then
    echo "⚠ Warning: A VM named '$VM_NAME' already exists in the database"
    echo ""
    read -p "Continue and create VM with duplicate name? (y/N): " CONTINUE
    if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
      echo "Cancelled by user"
      exit 0
    fi
    echo ""
  fi
fi

echo "✓ Ready to create VM on Proxmox"
echo ""

# Create VM
echo "Creating VM..."
ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST <<EOF
qm create $VM_ID \
  --name $VM_NAME \
  --memory 512 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0 \
  --ide2 local:iso/${PUPPY_ISO},media=cdrom \
  --boot order=ide2 \
  --ostype l26 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:8,format=raw \
  --vga std
EOF

echo ""
echo "✓ Puppy Linux VM created successfully!"
echo ""
echo "VM Details:"
echo "  VM ID: $VM_ID"
echo "  Name: $VM_NAME"
echo "  RAM: 512MB"
echo "  Disk: 8GB"
echo "  Network: virtio (vmbr0)"
echo ""
echo "Start the VM in Proxmox UI or run:"
echo "  ssh -i /home/vscode/.ssh/crucible_proxmox root@$PROXMOX_HOST qm start $VM_ID"
echo ""
echo "Next step - Register VM in Player VM API:"
echo "  VM_NAME=$VM_NAME PROXMOX_VM_ID=$VM_ID ./scripts/create-vm-api-record.sh"
