#!/bin/bash
# Clean up all Crucible test resources created by setup scripts
# Removes: Alloy events, Player views, Caster projects, TopoMojo workspaces

set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Crucible Resource Cleanup                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will delete:${NC}"
echo "  • Alloy event templates matching: 'Alloy Event', 'Proxmox Test Event'"
echo "  • Player views matching: 'Proxmox VM', 'Proxmox VMs'"
echo "  • Caster projects matching: 'Proxmox Test'"
echo "  • TopoMojo workspaces matching: 'Test Workspace', 'Moodle Test'"
echo "  • Player VM API records for Proxmox VMs"
echo ""

read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Cancelled"
  exit 0
fi

echo ""

# ============================================================
# Clean Alloy Event Templates
# ============================================================
echo -e "${BLUE}Cleaning Alloy event templates...${NC}"

ALLOY_API_URL="http://localhost:4402/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=alloy.api" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" \
  -d "scope=openid profile alloy")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_TEMPLATES=$(curl -k -s -X GET "$ALLOY_API_URL/eventtemplates" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  for PATTERN in "Alloy Event" "Proxmox Test Event"; do
    echo "  Deleting templates matching: $PATTERN"
    TEMPLATE_IDS=$(echo "$ALL_TEMPLATES" | jq -r ".[] | select(.name | contains(\"$PATTERN\")) | .id" 2>/dev/null || true)

    for TEMPLATE_ID in $TEMPLATE_IDS; do
      if [ -n "$TEMPLATE_ID" ]; then
        curl -k -s -X DELETE "$ALLOY_API_URL/eventtemplates/$TEMPLATE_ID" \
          -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null
        DELETED_COUNT=$((DELETED_COUNT + 1))
      fi
    done
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT Alloy event templates${NC}"
else
  echo -e "${YELLOW}⚠ Could not get Alloy token, skipping${NC}"
fi

echo ""

# ============================================================
# Clean Player Views
# ============================================================
echo -e "${BLUE}Cleaning Player views...${NC}"

PLAYER_API_URL="http://localhost:4301/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.ui" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_VIEWS=$(curl -k -s -X GET "$PLAYER_API_URL/views" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  for PATTERN in "Proxmox"; do
    echo "  Deleting views matching: $PATTERN"
    VIEW_IDS=$(echo "$ALL_VIEWS" | jq -r ".[] | select(.name | contains(\"$PATTERN\")) | .id" 2>/dev/null || true)

    for VIEW_ID in $VIEW_IDS; do
      if [ -n "$VIEW_ID" ]; then
        curl -k -s -X DELETE "$PLAYER_API_URL/views/$VIEW_ID" \
          -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null 2>&1
        DELETED_COUNT=$((DELETED_COUNT + 1))
      fi
    done
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT Player views${NC}"
else
  echo -e "${YELLOW}⚠ Could not get Player token, skipping${NC}"
fi

echo ""

# ============================================================
# Clean Player VM API Records
# ============================================================
echo -e "${BLUE}Cleaning Player VM API records...${NC}"

VM_API_URL="http://localhost:4302/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player.vm.admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_VMS=$(curl -k -s -X GET "$VM_API_URL/vms" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  for PATTERN in "puppy" "alpine" "tinycore"; do
    echo "  Deleting VMs matching: $PATTERN"
    VM_IDS=$(echo "$ALL_VMS" | jq -r ".[] | select(.name | contains(\"$PATTERN\")) | .id" 2>/dev/null || true)

    for VM_ID in $VM_IDS; do
      if [ -n "$VM_ID" ]; then
        curl -k -s -X DELETE "$VM_API_URL/vms/$VM_ID" \
          -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null
        DELETED_COUNT=$((DELETED_COUNT + 1))
      fi
    done
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT VM records${NC}"
else
  echo -e "${YELLOW}⚠ Could not get VM API token, skipping${NC}"
fi

echo ""

# ============================================================
# Clean Caster Projects
# ============================================================
echo -e "${BLUE}Cleaning Caster projects...${NC}"

CASTER_API_URL="http://localhost:4310/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=caster.api" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" \
  -d "scope=openid profile caster")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_PROJECTS=$(curl -k -s -X GET "$CASTER_API_URL/projects" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  echo "  Deleting projects matching: Proxmox Test"
  PROJECT_IDS=$(echo "$ALL_PROJECTS" | jq -r '.[] | select(.name | startswith("Proxmox Test")) | .id' 2>/dev/null || true)

  for PROJECT_ID in $PROJECT_IDS; do
    if [ -n "$PROJECT_ID" ]; then
      curl -k -s -X DELETE "$CASTER_API_URL/projects/$PROJECT_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null
      DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT Caster projects${NC}"
else
  echo -e "${YELLOW}⚠ Could not get Caster token, skipping${NC}"
fi

echo ""

# ============================================================
# Clean TopoMojo Workspaces
# ============================================================
echo -e "${BLUE}Cleaning TopoMojo workspaces...${NC}"

TOPOMOJO_API_URL="http://localhost:5000"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=topomojo.ui" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" \
  -d "scope=openid profile topomojo")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_WORKSPACES=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/workspaces" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

  DELETED_COUNT=0
  for PATTERN in "Test Workspace" "Moodle Test"; do
    echo "  Deleting workspaces matching: $PATTERN"
    WORKSPACE_IDS=$(echo "$ALL_WORKSPACES" | jq -r ".[] | select(.name | contains(\"$PATTERN\")) | .id")

    for WORKSPACE_ID in $WORKSPACE_IDS; do
      if [ -n "$WORKSPACE_ID" ]; then
        curl -k -s -X DELETE "$TOPOMOJO_API_URL/api/workspace/$WORKSPACE_ID" \
          -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null
        DELETED_COUNT=$((DELETED_COUNT + 1))
      fi
    done
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT TopoMojo workspaces${NC}"
else
  echo -e "${YELLOW}⚠ Could not get TopoMojo token, skipping${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Cleanup Complete!                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "Run setup-crucible-proxmox.sh to recreate resources with stable GUIDs"
echo ""
