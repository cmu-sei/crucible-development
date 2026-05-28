#!/bin/bash
# Direct database cleanup for all Crucible test resources
# Deletes records directly from PostgreSQL

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-crucible}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-crucible}"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Crucible Database Cleanup                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will delete all test resources from the database:${NC}"
echo "  • Player views matching 'Proxmox%'"
echo "  • Player VMs matching 'puppy%', 'alpine%', 'tinycore%'"
echo "  • Caster projects matching 'Proxmox Test%'"
echo "  • Caster directories matching 'Proxmox Test%'"
echo "  • Alloy event templates matching 'Proxmox Test Event%'"
echo "  • TopoMojo workspaces matching 'Test Workspace%', 'Moodle Test%'"
echo ""

read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Cancelled"
  exit 0
fi

echo ""

# Export password for psql
export PGPASSWORD="$POSTGRES_PASSWORD"

# ============================================================
# Clean Player Views
# ============================================================
echo -e "${BLUE}Cleaning Player views...${NC}"

DELETED=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d player -t -c \
  "DELETE FROM views WHERE name LIKE 'Proxmox%'; SELECT ROW_COUNT();" 2>/dev/null || echo "0")

echo -e "${GREEN}✓ Deleted $(echo $DELETED | xargs) Player views${NC}"
echo ""

# ============================================================
# Clean Player VMs
# ============================================================
echo -e "${BLUE}Cleaning Player VMs...${NC}"

DELETED=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d player_vm -t -c \
  "DELETE FROM vms WHERE name LIKE 'puppy%' OR name LIKE 'alpine%' OR name LIKE 'tinycore%'; SELECT ROW_COUNT();" 2>/dev/null || echo "0")

echo -e "${GREEN}✓ Deleted $(echo $DELETED | xargs) VM records${NC}"
echo ""

# ============================================================
# Clean Caster Projects
# ============================================================
echo -e "${BLUE}Cleaning Caster projects...${NC}"

DELETED=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d caster -t -c \
  "DELETE FROM projects WHERE name LIKE 'Proxmox Test%'; SELECT ROW_COUNT();" 2>/dev/null || echo "0")

echo -e "${GREEN}✓ Deleted $(echo $DELETED | xargs) Caster projects${NC}"
echo ""

# ============================================================
# Clean Caster Directories
# ============================================================
echo -e "${BLUE}Cleaning Caster directories...${NC}"

DELETED=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d caster -t -c \
  "DELETE FROM directories WHERE name LIKE 'Proxmox Test%'; SELECT ROW_COUNT();" 2>/dev/null || echo "0")

echo -e "${GREEN}✓ Deleted $(echo $DELETED | xargs) Caster directories${NC}"
echo ""

# ============================================================
# Clean Alloy Event Templates
# ============================================================
echo -e "${BLUE}Cleaning Alloy event templates...${NC}"

DELETED=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d alloy -t -c \
  "DELETE FROM event_templates WHERE name LIKE 'Proxmox Test Event%'; SELECT ROW_COUNT();" 2>/dev/null || echo "0")

echo -e "${GREEN}✓ Deleted $(echo $DELETED | xargs) Alloy event templates${NC}"
echo ""

# ============================================================
# Clean TopoMojo Workspaces
# ============================================================
echo -e "${BLUE}Cleaning TopoMojo workspaces...${NC}"

DELETED=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d topomojo -t -c \
  "DELETE FROM workspaces WHERE name LIKE 'Test Workspace%' OR name LIKE 'Moodle Test%'; SELECT ROW_COUNT();" 2>/dev/null || echo "0")

echo -e "${GREEN}✓ Deleted $(echo $DELETED | xargs) TopoMojo workspaces${NC}"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Database Cleanup Complete!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "Run setup-crucible-proxmox.sh to recreate resources with stable GUIDs"
echo ""
