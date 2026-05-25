#!/bin/bash
# Master setup script for Crucible with Proxmox
# Automates: Proxmox config, VM templates, TopoMojo workspaces, Caster projects, Player views, Alloy events

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Track created resources
CREATED_VMS=""
CREATED_TEMPLATES=""
CREATED_WORKSPACES=""
CREATED_CASTER_PROJECTS=""
CREATED_PLAYER_VIEWS=""
CREATED_ALLOY_EVENTS=""

# Configuration
PROXMOX_HOST="${PROXMOX_HOST}"
CLEAN_SETUP="${CLEAN_SETUP:-false}"  # Set to 'true' to delete existing resources before creating
CREATE_VM_TEMPLATES="${CREATE_VM_TEMPLATES:-true}"
CREATE_TOPOMOJO_WORKSPACES="${CREATE_TOPOMOJO_WORKSPACES:-true}"
CREATE_CASTER_PROJECTS="${CREATE_CASTER_PROJECTS:-true}"
CREATE_PLAYER_VIEWS="${CREATE_PLAYER_VIEWS:-true}"
CREATE_ALLOY_EVENTS="${CREATE_ALLOY_EVENTS:-true}"

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   Crucible Proxmox Setup                                   ║
║   Automated environment configuration                      ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

# Check for required variables
if [ -z "$PROXMOX_HOST" ]; then
  echo -e "${RED}Error: PROXMOX_HOST environment variable not set${NC}"
  echo ""
  echo "Usage:"
  echo "  export PROXMOX_HOST='<proxmox-ip>'"
  echo "  $0"
  echo ""
  echo "Optional environment variables:"
  echo "  CREATE_VM_TEMPLATES=true|false"
  echo "  CREATE_TOPOMOJO_WORKSPACES=true|false"
  echo "  CREATE_CASTER_PROJECTS=true|false"
  echo "  CREATE_PLAYER_VIEWS=true|false"
  echo "  CREATE_ALLOY_EVENTS=true|false"
  exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Proxmox Host: $PROXMOX_HOST"
echo "  Clean Setup: $CLEAN_SETUP"
echo "  Create VM Templates: $CREATE_VM_TEMPLATES"
echo "  Create TopoMojo Workspaces: $CREATE_TOPOMOJO_WORKSPACES"
echo "  Create Caster Projects: $CREATE_CASTER_PROJECTS"
echo "  Create Player Views: $CREATE_PLAYER_VIEWS"
echo "  Create Alloy Events: $CREATE_ALLOY_EVENTS"
echo ""

read -p "Continue with setup? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Setup cancelled"
  exit 0
fi

echo ""

# ============================================================
# Phase 1: Proxmox Infrastructure Setup
# ============================================================
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Phase 1: Proxmox Infrastructure Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Running complete Proxmox setup...${NC}"
if [ ! -f "$SCRIPT_DIR/setup-proxmox-complete.sh" ]; then
  echo -e "${RED}Error: setup-proxmox-complete.sh not found${NC}"
  exit 1
fi

export PROXMOX_HOST
bash "$SCRIPT_DIR/setup-proxmox-complete.sh"

echo ""
echo -e "${GREEN}✓ Proxmox infrastructure configured${NC}"
echo ""

# ============================================================
# Phase 2: VM Template Creation
# ============================================================
if [ "$CREATE_VM_TEMPLATES" = "true" ]; then
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}Phase 2: Creating VM Templates${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo ""

  # Auto-confirm prompts for VM creation
  export AUTO_CONFIRM=y

  echo -e "${CYAN}Creating Alpine Linux VM template (ID: 105)...${NC}"
  if [ -f "$SCRIPT_DIR/create-proxmox-alpine-template.sh" ]; then
    bash "$SCRIPT_DIR/create-proxmox-alpine-template.sh" || {
      echo -e "${YELLOW}⚠ Alpine template creation failed, continuing...${NC}"
    }
  else
    echo -e "${YELLOW}⚠ create-proxmox-alpine-template.sh not found, skipping${NC}"
  fi

  echo ""
  echo -e "${CYAN}Creating Tiny Core Linux VM template (ID: 106, GUI, 15MB)...${NC}"
  if [ -f "$SCRIPT_DIR/create-proxmox-tinycore-template.sh" ]; then
    bash "$SCRIPT_DIR/create-proxmox-tinycore-template.sh" || {
      echo -e "${YELLOW}⚠ Tiny Core template creation failed, continuing...${NC}"
    }
  else
    echo -e "${YELLOW}⚠ create-proxmox-tinycore-template.sh not found, skipping${NC}"
  fi

  echo ""
  echo -e "${CYAN}Downloading Puppy Linux ISO...${NC}"
  if [ -f "$SCRIPT_DIR/download-puppy-iso.sh" ]; then
    bash "$SCRIPT_DIR/download-puppy-iso.sh" || {
      echo -e "${YELLOW}⚠ Puppy ISO download failed, skipping Puppy VM${NC}"
    }
  fi

  echo ""
  echo -e "${CYAN}Creating Puppy Linux VM (ID: 103, GUI, full-featured)...${NC}"
  if [ -f "$SCRIPT_DIR/create-puppy-vm.sh" ]; then
    bash "$SCRIPT_DIR/create-puppy-vm.sh" || {
      echo -e "${YELLOW}⚠ Puppy VM creation failed, continuing...${NC}"
    }
  else
    echo -e "${YELLOW}⚠ create-puppy-vm.sh not found, skipping${NC}"
  fi

  # Capture created VMs/templates
  CREATED_VMS=$(ssh -i ~/.ssh/crucible_proxmox root@$PROXMOX_HOST "qm list | tail -n +2" || true)

  echo ""
  echo -e "${GREEN}✓ VM templates created${NC}"
  echo ""
else
  echo -e "${YELLOW}Skipping VM template creation${NC}"
  echo ""
fi

# ============================================================
# Phase 3: Wait for Aspire to be ready
# ============================================================
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Phase 3: Waiting for Aspire Services${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Checking if Aspire is running...${NC}"
if ! pgrep -f "Crucible.AppHost" > /dev/null; then
  echo -e "${YELLOW}Aspire not running. Please start it:${NC}"
  echo "  aspire run"
  echo ""
  read -p "Press Enter when Aspire is ready..."
fi

# Wait for services to be healthy
echo -e "${CYAN}Waiting for services to be ready...${NC}"
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
  if curl -s http://localhost:5000/api/player/ping > /dev/null 2>&1 && \
     curl -s http://localhost:4310/api/ping > /dev/null 2>&1 && \
     curl -s http://localhost:4403/api/ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Services are ready${NC}"
    break
  fi
  echo -n "."
  sleep 2
  WAITED=$((WAITED + 2))
done

if [ $WAITED -ge $MAX_WAIT ]; then
  echo -e "${RED}✗ Timeout waiting for services${NC}"
  echo "Ensure Aspire is running and all services are healthy"
  exit 1
fi

echo ""

# ============================================================
# Phase 4: TopoMojo Workspaces
# ============================================================
if [ "$CREATE_TOPOMOJO_WORKSPACES" = "true" ]; then
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}Phase 4: Creating TopoMojo Workspaces${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo ""

  if [ -f "$SCRIPT_DIR/create-topomojo-workspace-template.sh" ]; then
    echo -e "${CYAN}Creating example workspace...${NC}"
    export TOPOMOJO_API_URL="http://localhost:5000"
    export PROXMOX_API_TOKEN=$(grep "^Pod__AccessToken" /mnt/data/crucible/topomojo/topomojo/src/TopoMojo.Api/appsettings.Development.conf | cut -d= -f2 | xargs)
    WORKSPACE_OUTPUT=$(bash "$SCRIPT_DIR/create-topomojo-workspace-template.sh" 2>&1) || {
      echo -e "${YELLOW}⚠ Workspace creation failed, continuing...${NC}"
    }
    echo "$WORKSPACE_OUTPUT"
    # Extract workspace name and ID (handles both formats: with/without dashes)
    WORKSPACE_NAME=$(echo "$WORKSPACE_OUTPUT" | grep "^Workspace:" | head -1 | cut -d: -f2- | xargs)
    WORKSPACE_ID=$(echo "$WORKSPACE_OUTPUT" | grep -oE "Workspace (created|already exists): [a-f0-9-]+" | grep -oE "[a-f0-9-]{32,36}" | head -1 || true)
    # Extract template names and IDs
    TEMPLATE_LINES=$(echo "$WORKSPACE_OUTPUT" | grep "TopoMojo template created:" || true)

    if [ -n "$WORKSPACE_ID" ]; then
      CREATED_WORKSPACES="$WORKSPACE_NAME ($WORKSPACE_ID)"
    fi
    if [ -n "$TEMPLATE_LINES" ]; then
      CREATED_TEMPLATES=$(echo "$TEMPLATE_LINES" | while read line; do
        # Extract "Name (ID)" format from "✓ TopoMojo template created: Name (ID)"
        TMPL_INFO=$(echo "$line" | sed 's/.*created: //')
        echo "$TMPL_INFO"
      done)
    fi
  else
    echo -e "${YELLOW}⚠ create-topomojo-workspace-template.sh not found${NC}"
  fi

  echo ""
  echo -e "${CYAN}Creating workspace with variants...${NC}"
  if [ -f "$SCRIPT_DIR/create-topomojo-workspace-with-variants.sh" ]; then
    VARIANTS_OUTPUT=$(bash "$SCRIPT_DIR/create-topomojo-workspace-with-variants.sh" 2>&1) || {
      echo -e "${YELLOW}⚠ Variants workspace creation failed, continuing...${NC}"
    }
    echo "$VARIANTS_OUTPUT"
    # Extract additional workspace name and ID
    VARIANTS_NAME=$(echo "$VARIANTS_OUTPUT" | grep "^Workspace:" | head -1 | cut -d: -f2- | xargs)
    VARIANTS_ID=$(echo "$VARIANTS_OUTPUT" | grep -oE "Workspace (created|already exists): [a-f0-9-]+" | grep -oE "[a-f0-9-]{32,36}" | head -1 || true)
    # Extract variant template lines
    VARIANT_TEMPLATE_LINES=$(echo "$VARIANTS_OUTPUT" | grep "TopoMojo template created:" || true)

    if [ -n "$VARIANTS_ID" ]; then
      CREATED_WORKSPACES="${CREATED_WORKSPACES}
$VARIANTS_NAME ($VARIANTS_ID)"
    fi
    if [ -n "$VARIANT_TEMPLATE_LINES" ]; then
      VARIANT_TEMPLATES=$(echo "$VARIANT_TEMPLATE_LINES" | while read line; do
        TMPL_INFO=$(echo "$line" | sed 's/.*created: //')
        echo "$TMPL_INFO"
      done)
      CREATED_TEMPLATES="${CREATED_TEMPLATES}
${VARIANT_TEMPLATES}"
    fi
  else
    echo -e "${YELLOW}⚠ create-topomojo-workspace-with-variants.sh not found${NC}"
  fi

  echo ""
  echo -e "${GREEN}✓ TopoMojo workspaces created${NC}"
  echo ""
else
  echo -e "${YELLOW}Skipping TopoMojo workspace creation${NC}"
  echo ""
fi

# ============================================================
# Phase 5: Caster Projects
# ============================================================
if [ "$CREATE_CASTER_PROJECTS" = "true" ]; then
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}Phase 5: Creating Caster Projects${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo ""

  if [ -f "$SCRIPT_DIR/create-caster-proxmox-topology.sh" ]; then
    echo -e "${CYAN}Creating example Caster project...${NC}"
    export PROXMOX_API_TOKEN=$(grep "^Pod__AccessToken" /mnt/data/crucible/topomojo/topomojo/src/TopoMojo.Api/appsettings.Development.conf | cut -d= -f2 | xargs)
    export CLEAN_SETUP
    CASTER_OUTPUT=$(bash "$SCRIPT_DIR/create-caster-proxmox-topology.sh" 2>&1) || {
      echo -e "${YELLOW}⚠ Caster project creation failed, continuing...${NC}"
    }
    echo "$CASTER_OUTPUT"
    CREATED_CASTER_PROJECTS=$(echo "$CASTER_OUTPUT" | grep -oE "Project:.*\([a-f0-9-]+\)" || true)
  else
    echo -e "${YELLOW}⚠ create-caster-proxmox-topology.sh not found${NC}"
  fi

  echo ""
  echo -e "${GREEN}✓ Caster projects created${NC}"
  echo ""
else
  echo -e "${YELLOW}Skipping Caster project creation${NC}"
  echo ""
fi

# ============================================================
# Phase 6: Player Views
# ============================================================
if [ "$CREATE_PLAYER_VIEWS" = "true" ]; then
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}Phase 6: Creating Player Views${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo ""

  if [ -f "$SCRIPT_DIR/create-player-view-template.sh" ]; then
    echo -e "${CYAN}Creating example Player view...${NC}"
    export CLEAN_SETUP
    PLAYER_OUTPUT=$(bash "$SCRIPT_DIR/create-player-view-template.sh" 2>&1) || {
      echo -e "${YELLOW}⚠ Player view creation failed, continuing...${NC}"
    }
    echo "$PLAYER_OUTPUT"
    CREATED_PLAYER_VIEWS=$(echo "$PLAYER_OUTPUT" | grep -oE "View:.*\([a-f0-9-]+\)" || true)
  else
    echo -e "${YELLOW}⚠ create-player-view-template.sh not found${NC}"
  fi

  echo ""
  echo -e "${GREEN}✓ Player views created${NC}"
  echo ""
else
  echo -e "${YELLOW}Skipping Player view creation${NC}"
  echo ""
fi

# ============================================================
# Phase 7: Alloy Events
# ============================================================
if [ "$CREATE_ALLOY_EVENTS" = "true" ]; then
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}Phase 7: Creating Alloy Events${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo ""

  if [ -f "$SCRIPT_DIR/create-alloy-event-without-caster.sh" ]; then
    echo -e "${CYAN}Creating example Alloy event...${NC}"
    # Extract Player View ID from previous step
    PLAYER_VIEW_GUID=$(echo "$PLAYER_OUTPUT" | grep -oE "View created: [a-f0-9-]+" | grep -oE "[a-f0-9-]{36}" || true)
    if [ -n "$PLAYER_VIEW_GUID" ]; then
      export PLAYER_VIEW_ID="$PLAYER_VIEW_GUID"
      echo "Using Player View ID: $PLAYER_VIEW_ID"
    fi
    export CLEAN_SETUP
    ALLOY_OUTPUT=$(bash "$SCRIPT_DIR/create-alloy-event-without-caster.sh" 2>&1) || {
      echo -e "${YELLOW}⚠ Alloy event creation failed, continuing...${NC}"
    }
    echo "$ALLOY_OUTPUT"
    CREATED_ALLOY_EVENTS=$(echo "$ALLOY_OUTPUT" | grep -oE "Event:.*\([a-f0-9-]+\)" || true)
  else
    echo -e "${YELLOW}⚠ create-alloy-event-without-caster.sh not found${NC}"
  fi

  echo ""
  echo -e "${GREEN}✓ Alloy events created${NC}"
  echo ""
else
  echo -e "${YELLOW}Skipping Alloy event creation${NC}"
  echo ""
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   ✓ Crucible Environment Setup Complete!                  ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

echo -e "${YELLOW}Summary:${NC}"
echo ""
echo -e "${CYAN}Proxmox:${NC}"
echo "  • Web UI: https://$PROXMOX_HOST/"
echo "  • API: https://$PROXMOX_HOST/api2/json/"
echo "  • SSH: ssh root@$PROXMOX_HOST"
echo ""

echo -e "${CYAN}Crucible Services (via Aspire):${NC}"
echo "  • TopoMojo: http://localhost:4201"
echo "  • Caster: http://localhost:4310"
echo "  • Player: http://localhost:4301"
echo "  • Alloy: http://localhost:4403"
echo "  • Aspire Dashboard: http://localhost:15888"
echo ""

echo -e "${CYAN}Resources Created:${NC}"
echo ""

if [ "$CREATE_VM_TEMPLATES" = "true" ] && [ -n "$CREATED_VMS" ]; then
  echo -e "${YELLOW}Proxmox VMs/Templates:${NC}"
  echo "$CREATED_VMS" | while read -r line; do
    echo "  $line"
  done
  echo ""
fi

if [ -n "$CREATED_WORKSPACES" ]; then
  echo -e "${YELLOW}TopoMojo Workspaces:${NC}"
  echo "  Workspace: $CREATED_WORKSPACES"
  echo ""
fi

if [ -n "$CREATED_TEMPLATES" ]; then
  echo -e "${YELLOW}TopoMojo VM Templates:${NC}"
  echo "$CREATED_TEMPLATES" | while read -r line; do
    [ -n "$line" ] && echo "  Template: $line"
  done
  echo ""
fi

if [ -n "$CREATED_CASTER_PROJECTS" ]; then
  echo -e "${YELLOW}Caster Projects:${NC}"
  echo "  $CREATED_CASTER_PROJECTS"
  echo ""
fi

if [ -n "$CREATED_PLAYER_VIEWS" ]; then
  echo -e "${YELLOW}Player Views:${NC}"
  echo "  $CREATED_PLAYER_VIEWS"
  echo ""
fi

if [ -n "$CREATED_ALLOY_EVENTS" ]; then
  echo -e "${YELLOW}Alloy Events:${NC}"
  echo "  $CREATED_ALLOY_EVENTS"
  echo ""
fi

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Access the Crucible services using the URLs above"
echo "  2. Log in with admin credentials from Keycloak"
echo "  3. Explore the example workspaces, projects, and events"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  • Restart Aspire: aspire run"
echo "  • Toggle hypervisor: ./scripts/toggle-topomojo-hypervisor.sh"
echo "  • View Aspire logs: Use Aspire Dashboard"
echo ""
