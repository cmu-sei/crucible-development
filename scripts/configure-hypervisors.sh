#!/bin/bash
# Configure hypervisor backends for the Crucible AppHost.
#
# Player VM API and Caster support Proxmox AND vSphere/VMC simultaneously
# (vm.api routes per-VM, Caster per-project), so this script writes a nested
# "Launch.Hypervisors" block that can hold BOTH backends at once - useful in
# dev when testing a feature against Proxmox and vSphere together.
#
# TopoMojo is single-backend; "Launch.TopomojoHypervisor" selects which one it
# uses. NOTE: in dev, TopoMojo is actually driven by its own
# appsettings.Development.conf (loaded last via ConfToEnv, overriding AppHost) -
# this script's TopoMojo selection is authoritative only in prod. Use
# toggle-hypervisor.sh / edit the .conf to change TopoMojo in dev.
#
# This script writes Crucible.AppHost/appsettings.Development.json. AppHost
# reads it on startup; restart Aspire to apply.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPHOST_DIR="$(cd "$SCRIPT_DIR/../Crucible.AppHost" && pwd)"
APPSETTINGS_JSON="$APPHOST_DIR/appsettings.Development.json"

# Load saved Proxmox env (PROXMOX_HOST / PROXMOX_API_TOKEN) if present
PROXMOX_CONFIG_FILE="$HOME/.crucible-proxmox"
if [ -f "$PROXMOX_CONFIG_FILE" ]; then
    source "$PROXMOX_CONFIG_FILE"
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

show_usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
  set-proxmox       Add/update the Proxmox backend (vm.api + Caster)
  set-vsphere       Add/update the vSphere on-prem backend (vm.api + Caster)
  set-vmc           Add/update the VMware Cloud (VMC) backend (vm.api + Caster)
  topomojo <name>   Select TopoMojo's backend: Proxmox | Vsphere
  remove <name>     Remove a backend: Proxmox | Vsphere
  show              Print the current Launch.Hypervisors config
  help              Show this help

Options (for set-proxmox):
  --url URL         Proxmox URL (default: https://\$PROXMOX_HOST:443)
  --token TOKEN     API token (default: \$PROXMOX_API_TOKEN)

Options (for set-vsphere / set-vmc):
  --url URL         vCenter SDK URL (e.g. https://vcenter.example.com/sdk)
  --user USER       vCenter username
  --password PASS   vCenter password
  --pool-path PATH  Resource pool path (Datacenter/Cluster/Pool)
  --datastore NAME  Datastore (e.g. "[WorkloadDatastore] topomojo/")

Examples:
  # Configure BOTH backends for dev testing
  $0 set-proxmox
  $0 set-vmc --url https://vcenter.sddc-x.vmwarevmc.com/sdk \\
             --user cloudadmin@vmc.local --password 'pw'
  $0 topomojo Proxmox

  # Drop a backend
  $0 remove Vsphere
EOF
}

ensure_appsettings() {
    if [ ! -f "$APPSETTINGS_JSON" ]; then
        echo "Creating appsettings.Development.json from appsettings.json..."
        cp "$APPHOST_DIR/appsettings.json" "$APPSETTINGS_JSON"
    fi
}

# Merge a JSON object into .Launch.Hypervisors.<Backend>
write_backend() {
    local backend="$1"   # Proxmox | Vsphere
    local json="$2"      # JSON object for that backend
    local tmp
    tmp=$(mktemp)
    jq --arg b "$backend" --argjson cfg "$json" \
       '.Launch = (.Launch // {})
        | .Launch.Hypervisors = (.Launch.Hypervisors // {})
        | .Launch.Hypervisors[$b] = ((.Launch.Hypervisors[$b] // {}) + $cfg)' \
       "$APPSETTINGS_JSON" > "$tmp"
    mv "$tmp" "$APPSETTINGS_JSON"
    echo -e "  ${GREEN}✓ Updated Launch.Hypervisors.$backend${NC}"
}

# Parse --flag value options into named globals
CLI_URL=""; CLI_TOKEN=""; CLI_USER=""; CLI_PASSWORD=""; CLI_POOL=""; CLI_DS=""
parse_opts() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --url) CLI_URL="$2"; shift 2;;
            --token) CLI_TOKEN="$2"; shift 2;;
            --user) CLI_USER="$2"; shift 2;;
            --password) CLI_PASSWORD="$2"; shift 2;;
            --pool-path) CLI_POOL="$2"; shift 2;;
            --datastore) CLI_DS="$2"; shift 2;;
            *) echo -e "${RED}Unknown option: $1${NC}"; exit 1;;
        esac
    done
}

cmd_set_proxmox() {
    parse_opts "$@"
    local url="${CLI_URL:-https://${PROXMOX_HOST:-proxmox.local}:443}"
    local token="${CLI_TOKEN:-${PROXMOX_API_TOKEN:-}}"
    if [ -z "$token" ]; then
        echo -e "${RED}No Proxmox token. Pass --token or set PROXMOX_API_TOKEN in ~/.crucible-proxmox${NC}"
        exit 1
    fi
    ensure_appsettings
    local cfg
    cfg=$(jq -n --arg url "$url" --arg token "$token" \
        '{Url:$url, Token:$token, VmStore:"local-lvm", DiskStore:"local-lvm", IsoStore:"local", SupportsSubfolders:false, UseDatastoreApi:false}')
    write_backend "Proxmox" "$cfg"
    echo -e "${BLUE}Proxmox backend set (vm.api + Caster). URL: $url${NC}"
}

cmd_set_vsphere() {
    local is_vmc="$1"; shift
    parse_opts "$@"
    if [ -z "$CLI_URL" ] || [ -z "$CLI_USER" ] || [ -z "$CLI_PASSWORD" ]; then
        echo -e "${RED}--url, --user, and --password are required${NC}"
        exit 1
    fi
    ensure_appsettings
    local ds="${CLI_DS}"
    if [ -z "$ds" ] && [ "$is_vmc" = "true" ]; then ds="[WorkloadDatastore] topomojo/"; fi
    local pool="${CLI_POOL}"
    if [ -z "$pool" ] && [ "$is_vmc" = "true" ]; then pool="SDDC-Datacenter/Cluster-1/Compute-ResourcePool"; fi
    local subfolders="true"
    local datastore_api="false"; [ "$is_vmc" = "true" ] && datastore_api="true"
    local cfg
    cfg=$(jq -n \
        --arg url "$CLI_URL" --arg user "$CLI_USER" --arg pw "$CLI_PASSWORD" \
        --arg pool "$pool" --arg ds "$ds" \
        --argjson subf "$subfolders" --argjson dsapi "$datastore_api" \
        '{Url:$url, User:$user, Password:$pw, PoolPath:$pool, VmStore:$ds, DiskStore:$ds, IsoStore:$ds, SupportsSubfolders:$subf, UseDatastoreApi:$dsapi}')
    write_backend "Vsphere" "$cfg"
    echo -e "${BLUE}vSphere backend set (vm.api + Caster). URL: $CLI_URL${NC}"
}

cmd_topomojo() {
    local name="$1"
    case "$name" in
        Proxmox|proxmox) name="Proxmox";;
        Vsphere|vsphere|vmc|VMC) name="Vsphere";;
        *) echo -e "${RED}topomojo expects: Proxmox | Vsphere${NC}"; exit 1;;
    esac
    ensure_appsettings
    local tmp; tmp=$(mktemp)
    jq --arg n "$name" '.Launch = (.Launch // {}) | .Launch.TopomojoHypervisor = $n' \
       "$APPSETTINGS_JSON" > "$tmp"
    mv "$tmp" "$APPSETTINGS_JSON"
    echo -e "  ${GREEN}✓ TopomojoHypervisor = $name${NC}"
    echo -e "  ${YELLOW}Note: in dev, also set TopoMojo's appsettings.Development.conf (it overrides AppHost).${NC}"
}

cmd_remove() {
    local name="$1"
    case "$name" in
        Proxmox|proxmox) name="Proxmox";;
        Vsphere|vsphere) name="Vsphere";;
        *) echo -e "${RED}remove expects: Proxmox | Vsphere${NC}"; exit 1;;
    esac
    [ -f "$APPSETTINGS_JSON" ] || { echo "No appsettings file"; exit 0; }
    local tmp; tmp=$(mktemp)
    jq --arg n "$name" 'if .Launch.Hypervisors then .Launch.Hypervisors |= del(.[$n]) else . end' \
       "$APPSETTINGS_JSON" > "$tmp"
    mv "$tmp" "$APPSETTINGS_JSON"
    echo -e "  ${GREEN}✓ Removed Launch.Hypervisors.$name${NC}"
}

cmd_show() {
    [ -f "$APPSETTINGS_JSON" ] || { echo "No appsettings file"; exit 0; }
    echo -e "${BLUE}Current Launch.Hypervisors:${NC}"
    jq '.Launch | {Hypervisors, TopomojoHypervisor}' "$APPSETTINGS_JSON"
}

case "${1:-help}" in
    set-proxmox) shift; cmd_set_proxmox "$@";;
    set-vsphere) shift; cmd_set_vsphere "false" "$@";;
    set-vmc)     shift; cmd_set_vsphere "true" "$@";;
    topomojo)    shift; cmd_topomojo "$@";;
    remove)      shift; cmd_remove "$@";;
    show)        cmd_show;;
    help|--help|-h) show_usage;;
    *) echo -e "${RED}Unknown command: $1${NC}"; echo ""; show_usage; exit 1;;
esac
