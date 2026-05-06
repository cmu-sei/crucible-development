#!/bin/bash
# Create Puppy Linux VM on ESXi

set -e

ESXI_HOST="${ESXI_HOST:-}"
ESXI_PASSWORD="${ESXI_PASSWORD:-}"
VM_NAME="${VM_NAME:-puppy-test}"

export VM_NAME
export VM_MEMORY="${VM_MEMORY:-512}"
export VM_CPUS="${VM_CPUS:-1}"
export VM_DISK="${VM_DISK:-8G}"
export DATASTORE="${DATASTORE:-datastore1}"
export ISO_NAME="puppylinux-bionicpup64-8.0-uefi.iso"
export VM_NETWORK="${VM_NETWORK:-VM Network}"
export POWER_ON="${POWER_ON:-true}"
export ESXI_HOST
export ESXI_PASSWORD

echo "Creating Puppy Linux VM on ESXi"
echo "  VM Name: $VM_NAME"
echo ""

# Call generic create script
./scripts/create-esxi-vm.sh
