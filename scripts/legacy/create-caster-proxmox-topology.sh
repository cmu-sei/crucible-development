#!/bin/bash
# Create a basic Caster topology using Proxmox VMs

set -e

PROXMOX_HOST="${PROXMOX_HOST}"
PROXMOX_API_TOKEN="${PROXMOX_API_TOKEN}"
CASTER_API_URL="${CASTER_API_URL:-http://localhost:4309/api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
PROJECT_NAME="${PROJECT_NAME:-Proxmox Test}"
DIRECTORY_NAME="${DIRECTORY_NAME:-Basic Topology}"

echo "Creating Caster topology with existing Proxmox VMs"
echo ""

# Check for required variables
if [ -z "$PROXMOX_HOST" ] || [ -z "$PROXMOX_API_TOKEN" ]; then
  echo "Error: PROXMOX_HOST and PROXMOX_API_TOKEN environment variables are required"
  echo ""
  echo "IMPORTANT: Use single quotes to prevent bash ! expansion"
  echo ""
  echo "Export variables:"
  echo "  export PROXMOX_HOST='your-proxmox-ip'"
  echo "  export PROXMOX_API_TOKEN='root@pam!crucible=your-token-here'"
  echo ""
  echo "Then run this script:"
  echo "  ./scripts/create-caster-proxmox-topology.sh"
  exit 1
fi

echo "  Proxmox Host: $PROXMOX_HOST"
echo "  Caster API: $CASTER_API_URL"
echo "  Project: $PROJECT_NAME"
echo "  Directory: $DIRECTORY_NAME"
echo ""

# Get auth token
echo "Obtaining auth token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=caster.ui" \
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

# Find next available project name
echo "Finding available project name..."
ALL_PROJECTS=$(curl -k -s -X GET "$CASTER_API_URL/projects" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

# Check if project already exists
EXISTING_PROJECT_ID=$(echo "$ALL_PROJECTS" | jq -r ".[] | select(.name == \"$PROJECT_NAME\") | .id" | head -1)

if [ -n "$EXISTING_PROJECT_ID" ] && [ "$EXISTING_PROJECT_ID" != "null" ]; then
  if [ "${CLEAN_SETUP}" = "true" ]; then
    echo "Deleting existing project: $PROJECT_NAME ($EXISTING_PROJECT_ID)"
    curl -k -s -X DELETE "$CASTER_API_URL/projects/$EXISTING_PROJECT_ID" \
      -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null
    echo "✓ Project deleted"
  else
    echo "✓ Project already exists: $PROJECT_NAME ($EXISTING_PROJECT_ID)"
    PROJECT_ID="$EXISTING_PROJECT_ID"
    echo ""
    echo "✓ Caster project ready!"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "Project Name: $PROJECT_NAME"
    echo "Project ID:   $PROJECT_ID"
    echo "═══════════════════════════════════════════════════════════"
    exit 0
  fi
fi

# Create new project with hardcoded GUID for idempotency
echo "Creating project..."
# Use different GUIDs for different project names
if [ "$PROJECT_NAME" = "Proxmox Test with Alloy" ]; then
  PROJECT_ID="7fa5b814-d57b-494f-96e8-51c34471c2c1"
else
  PROJECT_ID="3584598e-bebe-4ecb-9f5e-2c52a2971a68"
fi
PROJECT_RESPONSE=$(curl -k -s -X POST "$CASTER_API_URL/projects" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$PROJECT_ID\",
    \"name\": \"$PROJECT_NAME\",
    \"description\": \"Test project for Proxmox VMs\"
  }")

if echo "$PROJECT_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
  PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r '.id')
  echo "✓ Project created: $PROJECT_ID"
else
  echo "✗ Failed to create project"
  echo "$PROJECT_RESPONSE"
  exit 1
fi
echo ""


# Create Directory
echo "Creating directory..."
# Use different GUIDs for different projects
if [ "$PROJECT_NAME" = "Proxmox Test with Alloy" ]; then
  DIRECTORY_ID="704808b2-b864-4997-b4c6-2d25220c5445"
else
  DIRECTORY_ID="62bd916e-dceb-42cd-9f74-c5e219637c47"
fi
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

# Create main.tf file with Proxmox and Crucible providers
echo "Creating Terraform configuration..."
MAIN_TF='terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.106.0"
    }
    crucible = {
      source  = "cmu-sei/crucible"
      version = "~> 2.5"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure = var.proxmox_insecure
}

provider "crucible" {
  username       = var.crucible_username
  password       = var.crucible_password
  auth_url       = var.crucible_auth_url
  token_url      = var.crucible_token_url
  client_id      = var.crucible_client_id
  client_secret  = var.crucible_client_secret
  client_scopes  = ["player", "player-vm"]
  vm_api_url     = var.vm_api_url
  player_api_url = var.player_api_url
  caster_api_url = var.caster_api_url
}

# Create VMs in Proxmox using bpg provider
resource "proxmox_virtual_environment_vm" "alpine" {
  name      = "alpine-caster-test"
  node_name = "pve"

  clone {
    vm_id = 105
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }
}

resource "proxmox_virtual_environment_vm" "tinycore" {
  name      = "tinycore-caster-test"
  node_name = "pve"

  clone {
    vm_id = 102
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }
}

# Create Player View with Teams
resource "crucible_player_view" "proxmox_test" {
  name              = "Proxmox Test View"
  description       = "Test view for Proxmox VMs created via Caster"
  status            = "Active"
  create_admin_team = true

  application {
    name               = "Virtual Machines"
    app_template_id    = "ace19f19-8916-4169-84de-ad00565d8456"
  }

  team {
    name = "Test Team"

    user {
      user_id = "9b3b331c-10c1-448b-8114-21b2586d8e38"
    }

    app_instance {
      name          = "Virtual Machines"
      display_order = 1
    }
  }
}

# Register VMs in Player VM API
resource "crucible_player_virtual_machine" "alpine" {
  name       = proxmox_virtual_environment_vm.alpine.name
  team_ids   = [crucible_player_view.proxmox_test.team[0].team_id]
  embeddable = true

  proxmox_vm_info {
    id   = proxmox_virtual_environment_vm.alpine.vm_id
    node = "pve"
  }

  depends_on = [crucible_player_view.proxmox_test]
}

resource "crucible_player_virtual_machine" "tinycore" {
  name       = proxmox_virtual_environment_vm.tinycore.name
  team_ids   = [crucible_player_view.proxmox_test.team[0].team_id]
  embeddable = true

  proxmox_vm_info {
    id   = proxmox_virtual_environment_vm.tinycore.vm_id
    node = "pve"
  }

  depends_on = [crucible_player_view.proxmox_test]
}

output "view_id" {
  value = crucible_player_view.proxmox_test.id
}

output "alpine_vmid" {
  value = proxmox_virtual_environment_vm.alpine.vm_id
}

output "tinycore_vmid" {
  value = proxmox_virtual_environment_vm.tinycore.vm_id
}

output "alpine_player_id" {
  value = crucible_player_virtual_machine.alpine.id
}

output "tinycore_player_id" {
  value = crucible_player_virtual_machine.tinycore.id
}'

if [ "$PROJECT_NAME" = "Proxmox Test with Alloy" ]; then
  FILE_ID="c0574f10-73fc-474e-a64b-d358370967c8"
else
  FILE_ID="f9b489fe-5bf6-4baa-8840-5e900e5b90d5"
fi
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

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "crucible_username" {
  description = "Crucible username"
  type        = string
}

variable "crucible_password" {
  description = "Crucible password"
  type        = string
  sensitive   = true
}

variable "crucible_auth_url" {
  description = "Crucible auth URL"
  type        = string
}

variable "crucible_token_url" {
  description = "Crucible token URL"
  type        = string
}

variable "crucible_client_id" {
  description = "Crucible OAuth client ID"
  type        = string
  default     = "player.ui"
}

variable "crucible_client_secret" {
  description = "Crucible OAuth client secret"
  type        = string
  default     = ""
}

variable "player_api_url" {
  description = "Player API URL"
  type        = string
  default     = "http://localhost:4302"
}

variable "vm_api_url" {
  description = "VM API URL"
  type        = string
  default     = "http://localhost:4302"
}

variable "caster_api_url" {
  description = "Caster API URL"
  type        = string
  default     = "http://localhost:4309"
}'

if [ "$PROJECT_NAME" = "Proxmox Test with Alloy" ]; then
  FILE_ID="21c1f0a6-61b4-463b-8391-a007dfe326f3"
else
  FILE_ID="a43bc816-be98-410e-bd53-def3522f5bb5"
fi
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

# Create terraform.tfvars with Crucible variables
TERRAFORM_TFVARS="proxmox_endpoint = \"https://${PROXMOX_HOST}:8006\"
proxmox_api_token = \"${PROXMOX_API_TOKEN}\"
proxmox_insecure = true

crucible_username = \"admin\"
crucible_password = \"admin\"
crucible_auth_url = \"https://host.docker.internal:8443/realms/crucible/protocol/openid-connect/auth\"
crucible_token_url = \"https://host.docker.internal:8443/realms/crucible/protocol/openid-connect/token\"
crucible_client_id = \"crucible.provider\"
crucible_client_secret = \"\"

player_api_url = \"http://host.docker.internal:4300/api\"
vm_api_url = \"http://host.docker.internal:4302/api\"
caster_api_url = \"http://localhost:4309\"
"

if [ "$PROJECT_NAME" = "Proxmox Test with Alloy" ]; then
  FILE_ID="20927122-097d-49f5-8696-552a0bdb413f"
else
  FILE_ID="9a52310f-56e5-4ac5-b856-ceddbb653ff4"
fi
FILE_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST "$CASTER_API_URL/files" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"$FILE_ID\",
    \"directoryId\": \"$DIRECTORY_ID\",
    \"name\": \"terraform.tfvars\",
    \"content\": $(echo "$TERRAFORM_TFVARS" | jq -Rs .)
  }")

HTTP_CODE=$(echo "$FILE_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "201" ]; then
  echo "✓ Created terraform.tfvars"
else
  echo "✗ Failed to create terraform.tfvars"
  exit 1
fi

echo ""
echo "✓ Caster topology created successfully!"
echo ""
echo "Project: $PROJECT_NAME ($PROJECT_ID)"
echo "Directory: $DIRECTORY_NAME ($DIRECTORY_ID)"
echo ""
echo "Next steps:"
echo "  1. Access Caster UI: http://localhost:4310"
echo "  2. Terraform variables are pre-configured with defaults (admin/admin)"
echo "  3. Run Terraform plan/apply"
echo ""
echo "What this topology creates:"
echo "  - New Player View: 'Proxmox Test View' with 'Test Team'"
echo "  - 2 new Proxmox VMs (cloned from 101: alpine-test, 102: tinycore-test)"
echo "  - Auto-registers VMs in Player VM API"
echo ""
echo "Providers used:"
echo "  - Proxmox provider v0.106.0 (bpg/proxmox)"
echo "  - Crucible provider v2.5 (manages Views, Teams, VMs)"
