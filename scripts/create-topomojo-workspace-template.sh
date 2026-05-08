#!/bin/bash
# Creates a TopoMojo workspace with two VM templates:
# 1. ISO-only template (boots from ISO, no persistent disk)
# 2. Disk-based template (creates Proxmox template VM with disk)

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
WORKSPACE_DESCRIPTION="${WORKSPACE_DESCRIPTION:-Test workspace with ISO and disk-based templates}"
WORKSPACE_TAGS="${WORKSPACE_TAGS:-test}"
ISO_TEMPLATE_NAME="${ISO_TEMPLATE_NAME:-TinyCore ISO}"
ISO_TEMPLATE_DESCRIPTION="${ISO_TEMPLATE_DESCRIPTION:-Boots from TinyCore ISO}"
ISO_TEMPLATE_ISO="${ISO_TEMPLATE_ISO:-local:iso/TinyCorePure64-14.0.iso}"
DISK_TEMPLATE_NAME="${DISK_TEMPLATE_NAME:-Alpine Template}"
DISK_TEMPLATE_DESCRIPTION="${DISK_TEMPLATE_DESCRIPTION:-Alpine VM with disk}"
DISK_TEMPLATE_ISO="${DISK_TEMPLATE_ISO:-local:iso/alpine-virt-3.19.0-x86_64.iso}"
TEMPLATE_NETWORKS="${TEMPLATE_NETWORKS:-lan}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
PROXMOX_STORAGE="${PROXMOX_STORAGE:-local-lvm}"
PROXMOX_TEMPLATE_VMID="${PROXMOX_TEMPLATE_VMID:-9001}"

echo "Creating TopoMojo workspace with templates..."
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
    echo "  Updating workspace..."

    UPDATE_RESPONSE=$(curl -k -s -X PUT "${TOPOMOJO_API_URL}/api/workspace" \
      -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"id\": \"${WORKSPACE_ID}\",
        \"name\": \"${WORKSPACE_NAME}\",
        \"description\": \"${WORKSPACE_DESCRIPTION}\",
        \"tags\": \"${WORKSPACE_TAGS}\"
      }")

    echo "✓ Workspace updated"
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

    if echo "$WORKSPACE_RESPONSE" | jq -e '.status' > /dev/null 2>&1; then
        echo "Error creating workspace:"
        echo "$WORKSPACE_RESPONSE" | jq '.'
        exit 1
    fi

    WORKSPACE_ID=$(echo "$WORKSPACE_RESPONSE" | jq -r '.id')

    if [ -z "$WORKSPACE_ID" ] || [ "$WORKSPACE_ID" = "null" ]; then
        echo "Error: Failed to get workspace ID"
        echo "Response: $WORKSPACE_RESPONSE"
        exit 1
    fi

    echo "✓ Workspace created: $WORKSPACE_ID"
fi
echo ""

# ======================================
# Template 1: ISO-only (no disk)
# ======================================
echo "Creating ISO-only template..."
ISO_TEMPLATE_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/template-detail" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${ISO_TEMPLATE_NAME}\",
    \"description\": \"${ISO_TEMPLATE_DESCRIPTION}\",
    \"networks\": \"${TEMPLATE_NETWORKS}\",
    \"guestinfo\": \"\",
    \"detail\": \"{\\\"iso\\\": \\\"${ISO_TEMPLATE_ISO}\\\"}\",
    \"isPublished\": false
  }")

if echo "$ISO_TEMPLATE_RESPONSE" | jq -e '.status' > /dev/null 2>&1; then
    echo "Error creating ISO template:"
    echo "$ISO_TEMPLATE_RESPONSE" | jq '.'
    exit 1
fi

ISO_TEMPLATE_ID=$(echo "$ISO_TEMPLATE_RESPONSE" | jq -r '.id')
echo "✓ ISO template created: $ISO_TEMPLATE_ID"

# Link ISO template to workspace
ISO_LINK_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/template" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"templateId\": \"${ISO_TEMPLATE_ID}\",
    \"workspaceId\": \"${WORKSPACE_ID}\"
  }")

ISO_LINKED_ID=$(echo "$ISO_LINK_RESPONSE" | jq -r '.id')
echo "✓ ISO template linked to workspace: $ISO_LINKED_ID"
echo ""

# ======================================
# Template 2: Disk-based (create Proxmox VM template)
# ======================================
echo "Creating Proxmox template VM with disk..."

# Create VM on Proxmox
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${PROXMOX_USER}@${PROXMOX_HOST}" << EOF
set -e

# Check if template already exists
if qm status ${PROXMOX_TEMPLATE_VMID} &>/dev/null; then
    echo "VM ${PROXMOX_TEMPLATE_VMID} already exists, deleting..."
    qm stop ${PROXMOX_TEMPLATE_VMID} || true
    qm destroy ${PROXMOX_TEMPLATE_VMID}
fi

echo "Creating VM ${PROXMOX_TEMPLATE_VMID}..."
qm create ${PROXMOX_TEMPLATE_VMID} \
    --name "${DISK_TEMPLATE_NAME// /-}" \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --ostype l26

echo "Creating disk..."
qm set ${PROXMOX_TEMPLATE_VMID} --scsi0 ${PROXMOX_STORAGE}:10

echo "Attaching ISO..."
qm set ${PROXMOX_TEMPLATE_VMID} --ide2 ${DISK_TEMPLATE_ISO},media=cdrom

echo "Setting boot order..."
qm set ${PROXMOX_TEMPLATE_VMID} --boot "order=scsi0;ide2"

echo "Converting to template..."
qm template ${PROXMOX_TEMPLATE_VMID}

echo "✓ Proxmox template created: ${PROXMOX_TEMPLATE_VMID}"
EOF

echo "✓ Proxmox template VM created"
echo ""

# Create TopoMojo template referencing Proxmox template
echo "Creating disk-based TopoMojo template..."
DISK_TEMPLATE_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/template-detail" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${DISK_TEMPLATE_NAME}\",
    \"description\": \"${DISK_TEMPLATE_DESCRIPTION}\",
    \"networks\": \"${TEMPLATE_NETWORKS}\",
    \"guestinfo\": \"\",
    \"detail\": \"{\\\"template\\\": \\\"${PROXMOX_TEMPLATE_VMID}\\\", \\\"iso\\\": \\\"${DISK_TEMPLATE_ISO}\\\"}\",
    \"isPublished\": false
  }")

if echo "$DISK_TEMPLATE_RESPONSE" | jq -e '.status' > /dev/null 2>&1; then
    echo "Error creating disk template:"
    echo "$DISK_TEMPLATE_RESPONSE" | jq '.'
    exit 1
fi

DISK_TEMPLATE_ID=$(echo "$DISK_TEMPLATE_RESPONSE" | jq -r '.id')
echo "✓ Disk template created: $DISK_TEMPLATE_ID"

# Link disk template to workspace
DISK_LINK_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/template" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"templateId\": \"${DISK_TEMPLATE_ID}\",
    \"workspaceId\": \"${WORKSPACE_ID}\"
  }")

DISK_LINKED_ID=$(echo "$DISK_LINK_RESPONSE" | jq -r '.id')
echo "✓ Disk template linked to workspace: $DISK_LINKED_ID"
echo ""

echo "==============================================="
echo "SUCCESS!"
echo "==============================================="
echo "Workspace ID: $WORKSPACE_ID"
echo "ISO Template ID: $ISO_TEMPLATE_ID (linked: $ISO_LINKED_ID)"
echo "Disk Template ID: $DISK_TEMPLATE_ID (linked: $DISK_LINKED_ID)"
echo "Proxmox Template VMID: $PROXMOX_TEMPLATE_VMID"
echo ""
echo "View in TopoMojo UI:"
echo "  ${TOPOMOJO_API_URL%/api*}/topo/workspace/${WORKSPACE_ID}"
echo ""
echo "To customize, set these environment variables before running:"
echo "  TOPOMOJO_API_URL=\"http://localhost:5000\""
echo "  KEYCLOAK_URL=\"https://localhost:8443\""
echo "  KEYCLOAK_USERNAME=\"admin\""
echo "  KEYCLOAK_PASSWORD=\"admin\""
echo "  PROXMOX_HOST=\"192.168.1.100\""
echo "  PROXMOX_API_TOKEN='root@pam!crucible=xxxx'"
echo "  SSH_KEY_PATH=\"/home/user/.ssh/id_rsa\""
echo "  PROXMOX_USER=\"root\""
echo "  PROXMOX_NODE=\"pve\""
echo "  PROXMOX_STORAGE=\"local-lvm\""
echo "  PROXMOX_TEMPLATE_VMID=\"9001\""
echo "  WORKSPACE_NAME=\"My Workspace\""
echo "  WORKSPACE_DESCRIPTION=\"Description\""
echo "  WORKSPACE_TAGS=\"tag1,tag2\""
echo "  ISO_TEMPLATE_NAME=\"TinyCore ISO\""
echo "  ISO_TEMPLATE_ISO=\"[local] TinyCore-current.iso\""
echo "  DISK_TEMPLATE_NAME=\"Ubuntu Template\""
echo "  DISK_TEMPLATE_ISO=\"[local] ubuntu-22.04-live-server-amd64.iso\""
echo "  TEMPLATE_NETWORKS=\"lan\""
