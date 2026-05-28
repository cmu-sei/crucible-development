#!/bin/bash
# Reset test environment - fresh start for Crucible test resources
# This is a simple wrapper that shows what needs to be cleaned manually

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Reset Test Environment                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Manual cleanup required in web UIs:${NC}"
echo ""
echo -e "${CYAN}1. Player views (http://localhost:4301/views):${NC}"
echo "   Delete all views starting with 'Proxmox'"
echo ""
echo -e "${CYAN}2. Caster projects (http://localhost:4310/projects):${NC}"
echo "   Delete all projects starting with 'Proxmox Test'"
echo ""
echo -e "${CYAN}3. Alloy events (http://localhost:4403/admin/eventtemplates):${NC}"
echo "   Delete all event templates starting with 'Proxmox Test Event'"
echo ""
echo -e "${CYAN}4. TopoMojo workspaces (http://localhost:4201/docs):${NC}"
echo "   Delete 'Test Workspace' and 'Moodle Test' workspaces"
echo ""
echo -e "${YELLOW}Then run:${NC}"
echo "  ./scripts/setup-crucible-proxmox.sh"
echo ""
