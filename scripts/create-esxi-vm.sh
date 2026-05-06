#!/bin/bash
# Generic ESXi VM creation script

set -e

# Configuration
ESXI_HOST="${ESXI_HOST:-}"
ESXI_PASSWORD="${ESXI_PASSWORD:-}"
VM_NAME="${VM_NAME:-test-vm}"
VM_MEMORY="${VM_MEMORY:-512}"
VM_CPUS="${VM_CPUS:-1}"
VM_DISK="${VM_DISK:-8G}"
DATASTORE="${DATASTORE:-datastore1}"
ISO_NAME="${ISO_NAME:-alpine.iso}"
VM_NETWORK="${VM_NETWORK:-VM Network}"
POWER_ON="${POWER_ON:-true}"

echo "Creating ESXi VM"
echo ""

# Prompt for ESXi host if not set
if [ -z "$ESXI_HOST" ]; then
  read -p "Enter ESXi host IP address: " ESXI_HOST
fi

# Prompt for password if not set
if [ -z "$ESXI_PASSWORD" ]; then
  read -s -p "Enter ESXi root password: " ESXI_PASSWORD
  echo ""
fi

echo "  ESXi Host: $ESXI_HOST"
echo "  VM Name: $VM_NAME"
echo "  Memory: ${VM_MEMORY}MB"
echo "  CPUs: $VM_CPUS"
echo "  Disk: $VM_DISK"
echo "  ISO: $ISO_NAME"
echo "  Network: $VM_NETWORK"
echo ""

# Setup govc environment
export GOVC_URL="https://$ESXI_HOST"
export GOVC_USERNAME="root"
export GOVC_PASSWORD="$ESXI_PASSWORD"
export GOVC_INSECURE=true

# Check if govc is installed
if ! command -v govc &> /dev/null; then
  echo "✗ govc is not installed"
  echo ""
  echo "Install govc:"
  echo "  curl -L -o - https://github.com/vmware/govmomi/releases/download/v0.37.0/govc_\$(uname -s)_\$(uname -m).tar.gz | sudo tar -C /usr/local/bin -xvzf - govc"
  exit 1
fi

# Test govc connectivity
echo "Testing govc connectivity..."
if ! govc about > /dev/null 2>&1; then
  echo "✗ Cannot connect to ESXi via govc"
  exit 1
fi
echo "✓ Connected"

# Check if VM already exists
echo ""
echo "Checking if VM exists..."
if govc vm.info "$VM_NAME" > /dev/null 2>&1; then
  echo "✗ VM '$VM_NAME' already exists"
  echo ""
  echo "Remove it first:"
  echo "  govc vm.destroy $VM_NAME"
  exit 1
fi
echo "✓ VM name available"

# Create VM
echo ""
echo "Creating VM..."
govc vm.create \
  -m $VM_MEMORY \
  -c $VM_CPUS \
  -disk $VM_DISK \
  -net "$VM_NETWORK" \
  -net.adapter vmxnet3 \
  -iso "[$DATASTORE] ISO/$ISO_NAME" \
  -on=false \
  "$VM_NAME"

echo "✓ VM created: $VM_NAME"

# Power on if requested
if [ "$POWER_ON" = "true" ]; then
  echo ""
  echo "Powering on VM..."
  govc vm.power -on "$VM_NAME"
  echo "✓ VM powered on"
fi

# Display VM info
echo ""
echo "VM Details:"
govc vm.info "$VM_NAME" | grep -E "Name:|UUID:|Guest|State|CPU|Memory|Network"

echo ""
echo "✓ VM creation complete"
echo ""
echo "Next steps:"
echo "  1. Install OS in VM (connect via ESXi web UI or vSphere client)"
echo "  2. Register with VM API:"
echo "     VM_NAME=$VM_NAME ./scripts/register-esxi-vm-api.sh"
