#!/bin/bash
# Creates TopoMojo workspace with templates that reference Proxmox template VMs
# Following official Proxmox.md documentation workflow

set -e

# Validation
if [ -z "$TOPOMOJO_API_URL" ]; then
    echo "Error: TOPOMOJO_API_URL is not set"
    echo "Example: export TOPOMOJO_API_URL='http://localhost:5000'"
    exit 1
fi

if [ -z "$PROXMOX_HOST" ]; then
    echo "Error: PROXMOX_HOST is not set"
    echo "Example: export PROXMOX_HOST='192.168.1.100'"
    exit 1
fi

if [ -z "$PROXMOX_API_TOKEN" ]; then
    echo "Error: PROXMOX_API_TOKEN is not set"
    echo "Example: export PROXMOX_API_TOKEN='root@pam!crucible=xxxx-xxxx-xxxx'"
    exit 1
fi

SSH_KEY_PATH="${SSH_KEY_PATH:-/home/vscode/.ssh/crucible_proxmox}"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Error: SSH key not found at $SSH_KEY_PATH"
    echo "Set SSH_KEY_PATH to your SSH private key path"
    exit 1
fi

# Get Keycloak token if not provided
if [ -z "$KEYCLOAK_TOKEN" ]; then
    KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
    KEYCLOAK_USERNAME="${KEYCLOAK_USERNAME:-admin}"
    KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

    echo "Getting Keycloak token..."
    TOKEN_RESPONSE=$(curl -k -s -X POST "${KEYCLOAK_URL}/realms/crucible/protocol/openid-connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d "client_id=topomojo.ui" \
        -d "grant_type=password" \
        -d "username=${KEYCLOAK_USERNAME}" \
        -d "password=${KEYCLOAK_PASSWORD}" \
        -d "scope=openid profile topomojo")

    KEYCLOAK_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

    if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" = "null" ]; then
        echo "Error: Failed to get Keycloak token"
        echo "Response: $TOKEN_RESPONSE"
        exit 1
    fi

    echo "✓ Token acquired"
fi

# Script parameters
WORKSPACE_NAME="${WORKSPACE_NAME:-Test Workspace}"
WORKSPACE_DESCRIPTION="${WORKSPACE_DESCRIPTION:-Test workspace with Proxmox-based templates}"
WORKSPACE_TAGS="${WORKSPACE_TAGS:-test}"
ISO_TEMPLATE_NAME="${ISO_TEMPLATE_NAME:-TinyCore-ISO}"
ISO_TEMPLATE_DESCRIPTION="${ISO_TEMPLATE_DESCRIPTION:-TinyCore boots from ISO}"
ISO_TEMPLATE_ISO="${ISO_TEMPLATE_ISO:-local:iso/TinyCore-current.iso}"
DISK_TEMPLATE_NAME="${DISK_TEMPLATE_NAME:-Alpine-Disk}"
DISK_TEMPLATE_DESCRIPTION="${DISK_TEMPLATE_DESCRIPTION:-Alpine with disk}"
DISK_TEMPLATE_ISO="${DISK_TEMPLATE_ISO:-local:iso/TinyCore-current.iso}"
PUPPY_TEMPLATE_NAME="${PUPPY_TEMPLATE_NAME:-Puppy-Linux}"
PUPPY_TEMPLATE_DESCRIPTION="${PUPPY_TEMPLATE_DESCRIPTION:-Puppy Linux with GUI}"
PUPPY_TEMPLATE_ISO="${PUPPY_TEMPLATE_ISO:-local:iso/fossapup64-9.5.iso}"
TEMPLATE_NETWORKS="${TEMPLATE_NETWORKS:-lan}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
PROXMOX_STORAGE="${PROXMOX_STORAGE:-local-lvm}"
ISO_PROXMOX_VMID="${ISO_PROXMOX_VMID:-9001}"
DISK_PROXMOX_VMID="${DISK_PROXMOX_VMID:-9002}"
PUPPY_PROXMOX_VMID="${PUPPY_PROXMOX_VMID:-103}"

echo "Creating TopoMojo workspace with Proxmox-backed templates..."
echo "API URL: $TOPOMOJO_API_URL"
echo "Proxmox Host: $PROXMOX_HOST"
echo "Workspace: $WORKSPACE_NAME"
echo ""

# Check if workspace exists
echo "Checking if workspace exists..."
LIST_RESPONSE=$(curl -k -s -X GET "${TOPOMOJO_API_URL}/api/workspaces" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

WORKSPACE_ID=$(echo "$LIST_RESPONSE" | jq -r ".[] | select(.name == \"${WORKSPACE_NAME}\") | .id" | head -1)

if [ -n "$WORKSPACE_ID" ] && [ "$WORKSPACE_ID" != "null" ]; then
    echo "✓ Workspace already exists: $WORKSPACE_ID"
else
    echo "Creating new workspace..."
    WORKSPACE_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/workspace" \
      -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"${WORKSPACE_NAME}\",
        \"description\": \"${WORKSPACE_DESCRIPTION}\",
        \"tags\": \"${WORKSPACE_TAGS}\"
      }")

    WORKSPACE_ID=$(echo "$WORKSPACE_RESPONSE" | jq -r '.id')
    echo "✓ Workspace created: $WORKSPACE_ID"
fi
echo ""

# ======================================
# Template 1: ISO-only Proxmox Template
# ======================================
echo "Creating Proxmox template VM for ISO-only..."
ISO_PROXMOX_NAME="${ISO_TEMPLATE_NAME// /-}"

ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${PROXMOX_USER}@${PROXMOX_HOST}" << EOF
set -e

if qm status ${ISO_PROXMOX_VMID} &>/dev/null; then
    echo "VM ${ISO_PROXMOX_VMID} exists, deleting..."
    qm stop ${ISO_PROXMOX_VMID} || true
    qm destroy ${ISO_PROXMOX_VMID}
fi

echo "Creating VM ${ISO_PROXMOX_VMID}..."
qm create ${ISO_PROXMOX_VMID} \
    --name "${ISO_PROXMOX_NAME}" \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --ostype l26

echo "Attaching ISO..."
qm set ${ISO_PROXMOX_VMID} --ide2 ${ISO_TEMPLATE_ISO},media=cdrom
qm set ${ISO_PROXMOX_VMID} --boot "order=ide2"

echo "Converting to template..."
qm template ${ISO_PROXMOX_VMID}

echo "✓ Proxmox template ${ISO_PROXMOX_VMID} created"
EOF

echo "✓ Proxmox template VM created: ${ISO_PROXMOX_NAME}"
echo ""

# Create TopoMojo template pointing to Proxmox template
echo "Creating TopoMojo template..."

ISO_DETAIL_JSON=$(jq -n \
  --arg template "$ISO_PROXMOX_NAME" \
  --arg iso "$ISO_TEMPLATE_ISO" \
  '{
    template: $template,
    iso: $iso,
    ram: 2,
    cpu: "1x2",
    eth: [{net: "lan"}],
    disks: []
  }')

ISO_TEMPLATE_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/template-detail" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  --data-binary @- <<JSON_EOF
{
  "name": "${ISO_TEMPLATE_NAME}",
  "description": "${ISO_TEMPLATE_DESCRIPTION}",
  "networks": "${TEMPLATE_NETWORKS}",
  "guestinfo": "",
  "detail": $(echo "$ISO_DETAIL_JSON" | jq -Rs .),
  "isPublished": true,
  "workspaceId": null
}
JSON_EOF
)

ISO_TEMPLATE_ID=$(echo "$ISO_TEMPLATE_RESPONSE" | jq -r '.id')
echo "✓ TopoMojo template created: $ISO_TEMPLATE_NAME ($ISO_TEMPLATE_ID)"
echo ""

# ======================================
# Template 2: Disk-based Proxmox Template
# ======================================
echo "Creating Proxmox template VM with disk..."
DISK_PROXMOX_NAME="${DISK_TEMPLATE_NAME// /-}"

ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${PROXMOX_USER}@${PROXMOX_HOST}" << EOF
set -e

if qm status ${DISK_PROXMOX_VMID} &>/dev/null; then
    echo "VM ${DISK_PROXMOX_VMID} exists, deleting..."
    qm stop ${DISK_PROXMOX_VMID} || true
    qm destroy ${DISK_PROXMOX_VMID}
fi

echo "Creating VM ${DISK_PROXMOX_VMID}..."
qm create ${DISK_PROXMOX_VMID} \
    --name "${DISK_PROXMOX_NAME}" \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --ostype l26

echo "Creating disk..."
qm set ${DISK_PROXMOX_VMID} --scsi0 ${PROXMOX_STORAGE}:10

echo "Attaching ISO..."
qm set ${DISK_PROXMOX_VMID} --ide2 ${DISK_TEMPLATE_ISO},media=cdrom
qm set ${DISK_PROXMOX_VMID} --boot "order=scsi0;ide2"

echo "Converting to template..."
qm template ${DISK_PROXMOX_VMID}

echo "✓ Proxmox template ${DISK_PROXMOX_VMID} created"
EOF

echo "✓ Proxmox template VM created: ${DISK_PROXMOX_NAME}"
echo ""

# Create TopoMojo template
echo "Creating TopoMojo disk template..."

DISK_DETAIL_JSON=$(jq -n \
  --arg template "$DISK_PROXMOX_NAME" \
  --arg iso "$DISK_TEMPLATE_ISO" \
  '{
    template: $template,
    iso: $iso,
    ram: 2,
    cpu: "1x2",
    eth: [{net: "lan"}],
    disks: []
  }')

DISK_TEMPLATE_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/template-detail" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  --data-binary @- <<JSON_EOF
{
  "name": "${DISK_TEMPLATE_NAME}",
  "description": "${DISK_TEMPLATE_DESCRIPTION}",
  "networks": "${TEMPLATE_NETWORKS}",
  "guestinfo": "",
  "detail": $(echo "$DISK_DETAIL_JSON" | jq -Rs .),
  "isPublished": true,
  "workspaceId": null
}
JSON_EOF
)

DISK_TEMPLATE_ID=$(echo "$DISK_TEMPLATE_RESPONSE" | jq -r '.id')
echo "✓ TopoMojo template created: $DISK_TEMPLATE_NAME ($DISK_TEMPLATE_ID)"
echo ""

# ======================================
# Template 3: Puppy Linux
# ======================================
echo "Creating Puppy Linux TopoMojo template..."

PUPPY_PROXMOX_NAME="puppy-test"

PUPPY_DETAIL_JSON=$(jq -n \
  --arg template "$PUPPY_PROXMOX_NAME" \
  --arg iso "$PUPPY_TEMPLATE_ISO" \
  '{
    template: $template,
    iso: $iso,
    ram: 0.5,
    cpu: "1x1",
    eth: [{net: "lan"}],
    disks: []
  }')

PUPPY_TEMPLATE_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/template-detail" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  --data-binary @- <<JSON_EOF
{
  "name": "${PUPPY_TEMPLATE_NAME}",
  "description": "${PUPPY_TEMPLATE_DESCRIPTION}",
  "networks": "${TEMPLATE_NETWORKS}",
  "guestinfo": "",
  "detail": $(echo "$PUPPY_DETAIL_JSON" | jq -Rs .),
  "isPublished": true,
  "workspaceId": null
}
JSON_EOF
)

PUPPY_TEMPLATE_ID=$(echo "$PUPPY_TEMPLATE_RESPONSE" | jq -r '.id')
echo "✓ TopoMojo template created: $PUPPY_TEMPLATE_NAME ($PUPPY_TEMPLATE_ID)"
echo ""

# ======================================
# Add Templates to Workspace
# ======================================
echo "Adding templates to workspace..."

# Add ISO template to workspace
curl -k -s -X POST "${TOPOMOJO_API_URL}/api/workspace/${WORKSPACE_ID}/template" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"templateId\": \"${ISO_TEMPLATE_ID}\"}" > /dev/null

echo "✓ Added $ISO_TEMPLATE_NAME to workspace"

# Add Disk template to workspace
curl -k -s -X POST "${TOPOMOJO_API_URL}/api/workspace/${WORKSPACE_ID}/template" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"templateId\": \"${DISK_TEMPLATE_ID}\"}" > /dev/null

echo "✓ Added $DISK_TEMPLATE_NAME to workspace"

# Add Puppy template to workspace
curl -k -s -X POST "${TOPOMOJO_API_URL}/api/workspace/${WORKSPACE_ID}/template" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"templateId\": \"${PUPPY_TEMPLATE_ID}\"}" > /dev/null

echo "✓ Added $PUPPY_TEMPLATE_NAME to workspace"
echo ""

echo "==============================================="
echo "SUCCESS!"
echo "==============================================="
echo "Workspace ID: $WORKSPACE_ID"
echo "ISO Template: $ISO_TEMPLATE_ID (Proxmox VM ${ISO_PROXMOX_VMID})"
echo "Disk Template: $DISK_TEMPLATE_ID (Proxmox VM ${DISK_PROXMOX_VMID})"
echo "Puppy Template: $PUPPY_TEMPLATE_ID (Proxmox VM ${PUPPY_PROXMOX_VMID})"
echo ""
echo "View in TopoMojo: http://localhost:5000/topo/workspace/${WORKSPACE_ID}"
echo ""
echo "These templates reference Proxmox template VMs."
echo "Add them to a workspace and Deploy (not Initialize) to create linked clones."
