#!/bin/bash
# Clear ONLY test data matching specific patterns
# Does NOT delete everything - only removes test resources

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Clear Crucible Test Resources               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will delete ONLY resources matching these patterns:${NC}"
echo "  • Player views: 'Proxmox%'"
echo "  • Player VMs: 'puppy%', 'alpine%', 'tinycore%'"
echo "  • Caster projects: 'Proxmox Test%'"
echo "  • Alloy events: 'Proxmox Test Event%'"
echo "  • TopoMojo workspaces: 'Test Workspace%', 'Moodle Test%'"
echo "  • Steamfitter scenarios: (matching test patterns)"
echo ""
echo -e "${GREEN}Other data is preserved.${NC}"
echo ""

read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Cancelled"
  exit 0
fi

echo ""

# ============================================================
# Clean Player Views (API-based with better error handling)
# ============================================================
echo -e "${BLUE}Cleaning Player views...${NC}"

PLAYER_API_URL="http://localhost:4301/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player-admin-ui" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" 2>/dev/null || echo "{}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "null")

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_VIEWS=$(curl -k -s -X GET "$PLAYER_API_URL/views" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/json" 2>/dev/null || echo "[]")

  # Check if we got valid JSON
  if echo "$ALL_VIEWS" | jq empty 2>/dev/null; then
    DELETED_COUNT=0
    VIEW_IDS=$(echo "$ALL_VIEWS" | jq -r '.[] | select(.name | startswith("Proxmox")) | .id' 2>/dev/null || true)

    for VIEW_ID in $VIEW_IDS; do
      if [ -n "$VIEW_ID" ]; then
        curl -k -s -X DELETE "$PLAYER_API_URL/views/$VIEW_ID" \
          -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null 2>&1
        DELETED_COUNT=$((DELETED_COUNT + 1))
      fi
    done
    echo -e "${GREEN}✓ Deleted $DELETED_COUNT Player views${NC}"
  else
    echo -e "${YELLOW}⚠ Player API returned invalid response, skipping${NC}"
  fi
else
  echo -e "${YELLOW}⚠ Could not authenticate with Player API, skipping${NC}"
fi

echo ""

# ============================================================
# Clean Player VMs
# ============================================================
echo -e "${BLUE}Cleaning Player VMs...${NC}"

VM_API_URL="http://localhost:4302/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=player-vm-admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" 2>/dev/null || echo "{}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "null")

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_VMS=$(curl -k -s -X GET "$VM_API_URL/vms" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  for PATTERN in "puppy" "alpine" "tinycore"; do
    VM_IDS=$(echo "$ALL_VMS" | jq -r ".[] | select(.name | contains(\"$PATTERN\")) | .id" 2>/dev/null || true)

    for VM_ID in $VM_IDS; do
      if [ -n "$VM_ID" ]; then
        curl -k -s -X DELETE "$VM_API_URL/vms/$VM_ID" \
          -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null 2>&1
        DELETED_COUNT=$((DELETED_COUNT + 1))
      fi
    done
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT VM records${NC}"
else
  echo -e "${YELLOW}⚠ Could not authenticate with VM API, skipping${NC}"
fi

echo ""

# ============================================================
# Clean Caster Projects
# ============================================================
echo -e "${BLUE}Cleaning Caster projects...${NC}"

CASTER_API_URL="http://localhost:4310/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=caster-admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" \
  -d "scope=openid profile caster" 2>/dev/null || echo "{}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "null")

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_PROJECTS=$(curl -k -s -X GET "$CASTER_API_URL/projects" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  PROJECT_IDS=$(echo "$ALL_PROJECTS" | jq -r '.[] | select(.name | startswith("Proxmox Test")) | .id' 2>/dev/null || true)

  for PROJECT_ID in $PROJECT_IDS; do
    if [ -n "$PROJECT_ID" ]; then
      curl -k -s -X DELETE "$CASTER_API_URL/projects/$PROJECT_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null 2>&1
      DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT Caster projects${NC}"
else
  echo -e "${YELLOW}⚠ Could not authenticate with Caster API, skipping${NC}"
fi

echo ""

# ============================================================
# Clean Alloy Event Templates
# ============================================================
echo -e "${BLUE}Cleaning Alloy event templates...${NC}"

ALLOY_API_URL="http://localhost:4402/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=alloy-admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" \
  -d "scope=openid profile alloy" 2>/dev/null || echo "{}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "null")

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_TEMPLATES=$(curl -k -s -X GET "$ALLOY_API_URL/eventtemplates" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  TEMPLATE_IDS=$(echo "$ALL_TEMPLATES" | jq -r '.[] | select(.name | startswith("Proxmox Test Event")) | .id' 2>/dev/null || true)

  for TEMPLATE_ID in $TEMPLATE_IDS; do
    if [ -n "$TEMPLATE_ID" ]; then
      curl -k -s -X DELETE "$ALLOY_API_URL/eventtemplates/$TEMPLATE_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null 2>&1
      DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT Alloy event templates${NC}"
else
  echo -e "${YELLOW}⚠ Could not authenticate with Alloy API, skipping${NC}"
fi

echo ""

# ============================================================
# Clean TopoMojo Workspaces
# ============================================================
echo -e "${BLUE}Cleaning TopoMojo workspaces...${NC}"

TOPOMOJO_API_URL="http://localhost:5000"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=topomojo-admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" \
  -d "scope=openid profile topomojo" 2>/dev/null || echo "{}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "null")

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_WORKSPACES=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/workspaces" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  for PATTERN in "Test Workspace" "Moodle Test"; do
    WORKSPACE_IDS=$(echo "$ALL_WORKSPACES" | jq -r ".[] | select(.name | contains(\"$PATTERN\")) | .id" 2>/dev/null || true)

    for WORKSPACE_ID in $WORKSPACE_IDS; do
      if [ -n "$WORKSPACE_ID" ]; then
        curl -k -s -X DELETE "$TOPOMOJO_API_URL/api/workspace/$WORKSPACE_ID" \
          -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null 2>&1
        DELETED_COUNT=$((DELETED_COUNT + 1))
      fi
    done
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT TopoMojo workspaces${NC}"
else
  echo -e "${YELLOW}⚠ Could not authenticate with TopoMojo API, skipping${NC}"
fi

echo ""

# ============================================================
# Clean Steamfitter Scenarios
# ============================================================
echo -e "${BLUE}Cleaning Steamfitter scenarios...${NC}"

STEAMFITTER_API_URL="http://localhost:4400/api"
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=steamfitter-admin" \
  -d "grant_type=password" \
  -d "username=$KEYCLOAK_USER" \
  -d "password=$KEYCLOAK_PASSWORD" 2>/dev/null || echo "{}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "null")

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
  ALL_SCENARIOS=$(curl -k -s -X GET "$STEAMFITTER_API_URL/scenarios" \
    -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "[]")

  DELETED_COUNT=0
  SCENARIO_IDS=$(echo "$ALL_SCENARIOS" | jq -r '.[] | select(.name | startswith("Test") or startswith("Proxmox")) | .id' 2>/dev/null || true)

  for SCENARIO_ID in $SCENARIO_IDS; do
    if [ -n "$SCENARIO_ID" ]; then
      curl -k -s -X DELETE "$STEAMFITTER_API_URL/scenarios/$SCENARIO_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null 2>&1
      DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
  done
  echo -e "${GREEN}✓ Deleted $DELETED_COUNT Steamfitter scenarios${NC}"
else
  echo -e "${YELLOW}⚠ Could not authenticate with Steamfitter API, skipping${NC}"
fi

echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Test Resource Cleanup Complete!            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Refresh your browser tabs"
echo "  2. Run setup: ./scripts/setup-crucible-proxmox.sh"
echo ""
