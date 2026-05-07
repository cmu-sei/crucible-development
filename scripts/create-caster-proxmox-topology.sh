#!/bin/bash
# Create a basic Caster topology using Proxmox VMs

set -e

CASTER_API_URL="${CASTER_API_URL:-http://localhost:4310/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
PROJECT_NAME="${PROJECT_NAME:-Proxmox Test}"
DIRECTORY_NAME="${DIRECTORY_NAME:-Basic Topology}"

echo "Creating Caster topology with Proxmox VMs"
echo "  Caster API: $CASTER_API_URL"
echo "  Project: $PROJECT_NAME"
echo "  Directory: $DIRECTORY_NAME"
echo ""

# Get auth token
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.ui" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "✗ Failed to obtain token"
  exit 1
fi
echo "✓ Token obtained"
echo ""

# Create or get Project
echo "Creating project..."
PROJECT_ID=$(cat /proc/sys/kernel/random/uuid)
PROJECT_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$CASTER_API_URL/projects" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$PROJECT_ID\",
    \"name\": \"$PROJECT_NAME\",
    \"description\": \"Test project for Proxmox VMs\"
  }")

HTTP_CODE=$(echo "$PROJECT_RESPONSE" | tail -n1)
RESPONSE=$(echo "$PROJECT_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "201" ] || echo "$RESPONSE" | grep -q '"id"'; then
  PROJECT_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null || echo "$PROJECT_ID")
  echo "✓ Project created: $PROJECT_ID"
elif echo "$RESPONSE" | grep -q "409\|already exists"; then
  # Get existing project
  ALL_PROJECTS=$(curl -k -s -X GET "$CASTER_API_URL/projects" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  PROJECT_ID=$(echo "$ALL_PROJECTS" | jq -r ".[] | select(.name == \"$PROJECT_NAME\") | .id" | head -1)
  echo "✓ Using existing project: $PROJECT_ID"
else
  echo "✗ Failed to create project"
  echo "$RESPONSE"
  exit 1
fi
echo ""

# Create Directory
echo "Creating directory..."
DIRECTORY_ID=$(cat /proc/sys/kernel/random/uuid)
DIRECTORY_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$CASTER_API_URL/directories" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$DIRECTORY_ID\",
    \"projectId\": \"$PROJECT_ID\",
    \"name\": \"$DIRECTORY_NAME\",
    \"terraformVersion\": \"1.5.0\"
  }")

HTTP_CODE=$(echo "$DIRECTORY_RESPONSE" | tail -n1)
RESPONSE=$(echo "$DIRECTORY_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "201" ] || echo "$RESPONSE" | grep -q '"id"'; then
  DIRECTORY_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null || echo "$DIRECTORY_ID")
  echo "✓ Directory created: $DIRECTORY_ID"
else
  echo "✗ Failed to create directory"
  echo "$RESPONSE"
  exit 1
fi
echo ""

# Create main.tf file with Proxmox provider and VMs
echo "Creating Terraform configuration..."
MAIN_TF='terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_endpoint
  pm_api_token_id     = split("=", var.proxmox_token)[0]
  pm_api_token_secret = split("=", var.proxmox_token)[1]
  pm_tls_insecure     = var.proxmox_insecure
}

resource "proxmox_vm_qemu" "alpine" {
  name        = "alpine-caster-test"
  target_node = "pve"
  clone       = "alpine-test"
  full_clone  = false

  cores   = 1
  memory  = 512

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}

resource "proxmox_vm_qemu" "tinycore" {
  name        = "tinycore-caster-test"
  target_node = "pve"
  clone       = "tinycore-test"
  full_clone  = false

  cores   = 1
  memory  = 512

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}

output "alpine_id" {
  value = proxmox_vm_qemu.alpine.id
}

output "tinycore_id" {
  value = proxmox_vm_qemu.tinycore.id
}'

FILE_ID=$(cat /proc/sys/kernel/random/uuid)
FILE_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$CASTER_API_URL/files" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$FILE_ID\",
    \"directoryId\": \"$DIRECTORY_ID\",
    \"name\": \"main.tf\",
    \"content\": $(echo "$MAIN_TF" | jq -Rs .)
  }")

HTTP_CODE=$(echo "$FILE_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "201" ]; then
  echo "✓ Created main.tf"
else
  echo "✗ Failed to create main.tf"
  exit 1
fi

# Create variables.tf
VARIABLES_TF='variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_token" {
  description = "Proxmox API token (format: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}'

FILE_ID=$(cat /proc/sys/kernel/random/uuid)
FILE_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$CASTER_API_URL/files" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$FILE_ID\",
    \"directoryId\": \"$DIRECTORY_ID\",
    \"name\": \"variables.tf\",
    \"content\": $(echo "$VARIABLES_TF" | jq -Rs .)
  }")

HTTP_CODE=$(echo "$FILE_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "201" ]; then
  echo "✓ Created variables.tf"
else
  echo "✗ Failed to create variables.tf"
  exit 1
fi

echo ""
echo "✓ Caster topology created successfully!"
echo ""
echo "Project: $PROJECT_NAME ($PROJECT_ID)"
echo "Directory: $DIRECTORY_NAME ($DIRECTORY_ID)"
echo ""
echo "Access Caster UI:"
echo "  http://localhost:4311"
echo ""
echo "Note: Environment variables for Proxmox are already configured in Caster API"
echo "The topology will clone the existing VMs (101, 102) as templates"
