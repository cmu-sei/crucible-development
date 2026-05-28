#!/bin/bash
# Reset all Crucible applications by clearing PostgreSQL database
# WARNING: This deletes ALL data from ALL Crucible apps

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║   RESET ALL CRUCIBLE APPLICATIONS             ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${RED}WARNING: This will delete ALL data from:${NC}"
echo "  • Player (views, teams, applications)"
echo "  • Player VM (VMs, templates)"
echo "  • Caster (projects, directories, workspaces)"
echo "  • Alloy (events, definitions)"
echo "  • TopoMojo (workspaces, templates, gamespaces)"
echo "  • Steamfitter (scenarios, tasks)"
echo "  • CITE (evaluations, submissions)"
echo "  • Gallery (collections, exhibits, cards)"
echo "  • Blueprint (MSELs, injects)"
echo "  • Gameboard (challenges, players)"
echo ""
echo -e "${YELLOW}This cannot be undone!${NC}"
echo ""

read -p "Type 'DELETE ALL DATA' to confirm: " confirm
if [ "$confirm" != "DELETE ALL DATA" ]; then
  echo "Cancelled"
  exit 0
fi

echo ""
echo -e "${BLUE}Stopping Aspire...${NC}"
# User must manually stop Aspire via dashboard or Ctrl+C

POSTGRES_CONTAINER=$(docker ps --filter "name=crucible-postgres" --format "{{.Names}}" | head -1)

if [ -z "$POSTGRES_CONTAINER" ]; then
  echo -e "${RED}Error: PostgreSQL container not found${NC}"
  echo "Make sure Aspire is running first"
  exit 1
fi

echo -e "${YELLOW}Found PostgreSQL container: $POSTGRES_CONTAINER${NC}"
echo ""

echo -e "${BLUE}Stopping PostgreSQL container...${NC}"
docker stop "$POSTGRES_CONTAINER"

echo -e "${BLUE}Removing PostgreSQL container...${NC}"
docker rm "$POSTGRES_CONTAINER"

echo -e "${BLUE}Removing PostgreSQL volume...${NC}"
docker volume rm crucible-postgres-data 2>/dev/null || echo "(Volume not found, may be named differently)"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Database Reset Complete!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Restart Aspire: aspire run"
echo "  2. Wait for all services to be healthy"
echo "  3. Run setup: ./scripts/setup-crucible-proxmox.sh"
echo ""
