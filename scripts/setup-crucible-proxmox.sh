#!/bin/bash
# ============================================================
# Crucible Proxmox Environment Manager
# All-in-one script for Proxmox setup, management, and cleanup
# ============================================================
#
# Purpose: Create and manage test environment for Proxmox integration
#          with Player, Caster, Alloy, TopoMojo, and Moodle plugins
#
# Usage:
#   ./crucible-proxmox.sh <command> [options]
#
# Commands:
#   setup    - Full environment setup
#   reset    - Clean all resources and recreate
#   clean    - Remove all resources
#   status   - Show current state
#   fix      - Repair broken state
#
# Options:
#   -h, --proxmox-host HOST        Proxmox IP/hostname (required)
#   --keycloak-url URL             Keycloak URL (default: https://localhost:8443)
#   --keycloak-user USER           Keycloak username (default: admin)
#   --keycloak-password PASS       Keycloak password (default: admin)
#   --skip-infrastructure          Skip Proxmox setup
#   --skip-vms                     Skip VM template creation
#   --skip-topomojo                Skip TopoMojo workspaces
#   --skip-caster                  Skip Caster projects
#   --skip-player                  Skip Player views
#   --skip-alloy                   Skip Alloy events
#   --dry-run                      Show what would be done
#   --help                         Show this help message
#
# Examples:
#   ./crucible-proxmox.sh setup --proxmox-host 192.168.1.100
#   ./crucible-proxmox.sh reset -h 192.168.1.100 --skip-vms
#   ./crucible-proxmox.sh clean --proxmox-host 192.168.1.100 --dry-run
#   ./crucible-proxmox.sh status -h 192.168.1.100
#
# ============================================================

set -e

# ============================================================
# CONFIGURATION & CONSTANTS
# ============================================================

# Version
VERSION="1.0.0"

# ============================================================
# HARDCODED RESOURCE IDS
# ============================================================
# Note: TopoMojo API may ignore these and generate its own IDs
# but we'll try to pass them anyway

readonly WORKSPACE_BASIC_ID="a5a4504b-8aa6-465f-adf5-b043f3813cd5"
readonly WORKSPACE_VARIANTS_ID="af41d5dd-84b1-4672-8439-f03138c0f86e"

# Stock Templates (only 2)
readonly TEMPLATE_TINYCORE_STOCK_ID="4ab31ef8-73c9-4dc3-be25-c9c7fb920951"
readonly TEMPLATE_ALPINE_STOCK_ID="491ffca2-67ae-46c1-acb8-dcda80dd70b8"
readonly TEMPLATE_PUPPY_STOCK_ID="5c72d3f9-84ba-4ef2-a9c3-f1e8a2b3d4c5"

# Linked Templates (in basic workspace, referencing stock templates)
readonly TEMPLATE_TINYCORE_LINKED_ID="1b40e03a-80ef-4653-a080-a0e8811c23a8"
readonly TEMPLATE_ALPINE_LINKED_ID="bebd2ca6-fa2b-4cc8-aa80-847677ee9e03"

# Workspace-Specific Template (in variants workspace, from Puppy VM 103)
readonly TEMPLATE_PUPPY_WORKSPACE_ID="75f5f11e-2b9d-4e26-9585-0fb16297ced6"

# Config file location
CONFIG_FILE="$HOME/.crucible-proxmox"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Resource IDs (hardcoded for idempotency)
declare -A RESOURCE_IDS=(
    # Player Views
    [player_view_template]="8ab5b8c5-63f6-427b-b3f5-076ed2cfdfd2"
    [player_view_live]="3c7e9a2f-8b4d-4e1a-9f5c-2d8b6e3a7c1f"

    # Player Applications
    [vm_app_template]="18229b03-873e-4288-9c30-d4eace3bd042"
    [dashboard_app_template]="635f5bd3-624e-4ab9-ac20-fbbf20b0fd04"
    [vm_app_live]="4d8f0b3e-9c5e-4f2b-af6d-3e9c7f4b8d2a"
    [map_app_live]="5e9g1c4f-ad6f-5g3c-bg7e-4fad8g5c9e3b"

    # Player VMs
    [puppy_vm]="6fah2d5g-be7g-6h4d-ch8f-5gbe9h6daf4c"
    [alpine_vm]="7gbi3e6h-cf8h-7i5e-di9g-6hcfai7ebg5d"
    [tinycore_vm]="8hcj4f7i-dg9i-8j6f-ej0h-7idgbj8fch6e"

    # Caster Projects
    [caster_project1]="3584598e-bebe-4ecb-9f5e-2c52a2971a68"
    [caster_project1_dir]="62bd916e-dceb-42cd-9f74-c5e219637c47"
    [caster_project1_main_tf]="f9b489fe-5bf6-4baa-8840-5e900e5b90d5"
    [caster_project1_variables_tf]="a43bc816-be98-410e-bd53-def3522f5bb5"
    [caster_project1_tfvars]="9a52310f-56e5-4ac5-b856-ceddbb653ff4"

    [caster_project2]="7fa5b814-d57b-494f-96e8-51c34471c2c1"
    [caster_project2_dir]="704808b2-b864-4997-b4c6-2d25220c5445"
    [caster_project2_main_tf]="c0574f10-73fc-474e-a64b-d358370967c8"
    [caster_project2_variables_tf]="21c1f0a6-61b4-463b-8391-a007dfe326f3"
    [caster_project2_tfvars]="20927122-097d-49f5-8696-552a0bdb413f"

    # Alloy Events
    [alloy_event_no_caster]="e8bd8940-023f-4d6e-8255-9538dc21ad4a"
    [alloy_event_with_caster]="7ecc1dca-beb9-4b4a-83d8-b5ee80248a86"
)

# Keycloak client IDs
declare -A KEYCLOAK_CLIENTS=(
    [player]="player.vm.admin"
    [caster]="caster.ui"
    [alloy]="alloy.ui"
    [topomojo]="topomojo.ui"
)

# Default service URLs (can be overridden by environment)
PLAYER_API_URL="${PLAYER_API_URL:-http://localhost:4300/api}"
VM_API_URL="${VM_API_URL:-http://localhost:4302/api}"
CASTER_API_URL="${CASTER_API_URL:-http://localhost:4309/api}"
ALLOY_API_URL="${ALLOY_API_URL:-http://localhost:4402/api}"
TOPOMOJO_API_URL="${TOPOMOJO_API_URL:-http://localhost:5000}"

# Proxmox defaults
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_proxmox}"
SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
TOKEN_NAME="${TOKEN_NAME:-CRUCIBLE}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"

# VM Template IDs on Proxmox
ALPINE_PROXMOX_ID="${ALPINE_PROXMOX_ID:-105}"
TINYCORE_PROXMOX_ID="${TINYCORE_PROXMOX_ID:-106}"
PUPPY_PROXMOX_ID="${PUPPY_PROXMOX_ID:-103}"

# Command-line arguments (set via parse_args or environment)
PROXMOX_HOST="${PROXMOX_HOST:-}"
PROXMOX_API_TOKEN="${PROXMOX_API_TOKEN:-}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
KEYCLOAK_USER="${KEYCLOAK_USER:-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
# Removed skip flags - setup always runs all phases
DRY_RUN=false

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

# Output formatting
log_info() {
    echo -e "${BLUE}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

log_step() {
    echo -e "${CYAN}$1${NC}"
}

print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  $1"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════${NC}"
    echo ""
}

# Load config file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        set +e  # Don't exit on errors during source
        source "$CONFIG_FILE" 2>/dev/null
        set -e
        if [ -n "$PROXMOX_HOST" ]; then
            log_info "Loaded config from $CONFIG_FILE"
            return 0
        fi
    fi
    return 1
}

# Save config file
save_config() {
    # Load existing token if current one is empty (preserves token when skipping infrastructure setup)
    if [ -z "$PROXMOX_API_TOKEN" ] && [ -f "$CONFIG_FILE" ]; then
        local existing_token=$(grep "^export PROXMOX_API_TOKEN=" "$CONFIG_FILE" | cut -d'"' -f2)
        if [ -n "$existing_token" ]; then
            PROXMOX_API_TOKEN="$existing_token"
            log_info "Preserved existing API token from config"
        fi
    fi

    cat > "$CONFIG_FILE" << EOF
# Crucible Proxmox Configuration
# Auto-generated by crucible-proxmox.sh on $(date -Iseconds)
export PROXMOX_HOST="$PROXMOX_HOST"
export PROXMOX_API_TOKEN="$PROXMOX_API_TOKEN"
LAST_SETUP_DATE="$(date -Iseconds)"
SETUP_COMPLETE="true"
EOF
    chmod 600 "$CONFIG_FILE"
    log_success "Config saved to $CONFIG_FILE"
}

# Authentication - Get Keycloak token
get_keycloak_token() {
    local client_id="$1"

    local token_response=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/crucible/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$client_id" \
        -d "grant_type=password" \
        -d "username=$KEYCLOAK_USER" \
        -d "password=$KEYCLOAK_PASSWORD" 2>/dev/null)

    local access_token=$(echo "$token_response" | jq -r '.access_token' 2>/dev/null)

    if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
        log_error "Failed to get Keycloak token for client: $client_id"
        return 1
    fi

    echo "$access_token"
}

# Resource operations - Check if resource exists by name
resource_exists() {
    local service="$1"
    local resource_name="$2"

    case "$service" in
        player-view)
            local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[player]}")
            local response=$(curl -k -s -X GET "$PLAYER_API_URL/views" \
                -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
            echo "$response" | jq -r ".[] | select(.name == \"$resource_name\") | .id" | head -1
            ;;
        caster-project)
            local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[caster]}")
            local response=$(curl -k -s -X GET "$CASTER_API_URL/projects" \
                -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
            echo "$response" | jq -r ".[] | select(.name == \"$resource_name\") | .id" | head -1
            ;;
        alloy-event)
            local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[alloy]}")
            local response=$(curl -k -s -X GET "$ALLOY_API_URL/eventtemplates" \
                -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
            echo "$response" | jq -r ".[] | select(.name == \"$resource_name\") | .id" | head -1
            ;;
        topomojo-workspace)
            local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[topomojo]}")
            local response=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/workspaces" \
                -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
            echo "$response" | jq -r ".[] | select(.name == \"$resource_name\") | .id" | head -1
            ;;
        *)
            log_error "Unknown service: $service"
            return 1
            ;;
    esac
}

# Service health checks
check_service_health() {
    local service_name="$1"
    local api_url="$2"

    # Just check if service responds (any HTTP response)
    if curl -s -m 5 "$api_url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

wait_for_aspire_services() {
    local max_wait=120
    local waited=0

    print_section "Waiting for Aspire Services"

    log_step "Checking service health..."

    while [ $waited -lt $max_wait ]; do
        if check_service_health "Player" "$PLAYER_API_URL" && \
           check_service_health "Caster" "$CASTER_API_URL" && \
           check_service_health "Alloy" "$ALLOY_API_URL"; then
            log_success "All services are ready"
            return 0
        fi
        echo -n "."
        sleep 2
        waited=$((waited + 2))
    done

    log_error "Timeout waiting for services after ${max_wait}s"
    return 1
}

# ============================================================
# PROXMOX INFRASTRUCTURE FUNCTIONS
# ============================================================

setup_proxmox_ssh() {
    log_step "Setting up SSH key authentication..."

    # Create .ssh directory
    mkdir -p "$(dirname "$SSH_KEY_PATH")"
    chmod 700 "$(dirname "$SSH_KEY_PATH")"

    # Generate SSH key if needed
    if [ -f "$SSH_KEY_PATH" ]; then
        log_success "SSH key already exists: $SSH_KEY_PATH"
    else
        log_info "Generating SSH key..."
        ssh-keygen -t "$SSH_KEY_TYPE" -f "$SSH_KEY_PATH" -N "" -C "crucible-dev@proxmox"
        log_success "SSH key generated: $SSH_KEY_PATH"
    fi

    # Check if passwordless SSH works
    if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
        log_success "Passwordless SSH already configured"

        # Configure SSH config for easy access from any terminal
        configure_ssh_config

        return 0
    fi

    # Install SSH key
    log_info "Installing SSH key to Proxmox host..."
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would install SSH key"
        return 0
    fi

    if command -v ssh-copy-id &> /dev/null; then
        ssh-copy-id -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST"
        log_success "SSH key installed"

        # Configure SSH config for easy access from any terminal
        configure_ssh_config
    else
        log_error "ssh-copy-id not found. Please install SSH key manually:"
        echo "  cat ${SSH_KEY_PATH}.pub | ssh $PROXMOX_USER@$PROXMOX_HOST 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'"
        return 1
    fi
}

configure_ssh_config() {
    log_step "Configuring SSH config for easy Proxmox access..."

    local ssh_config="$HOME/.ssh/config"

    # Create .ssh/config if it doesn't exist
    if [ ! -f "$ssh_config" ]; then
        touch "$ssh_config"
        chmod 600 "$ssh_config"
    fi

    # Check if Proxmox entry already exists
    if grep -q "Host.*$PROXMOX_HOST\|Host proxmox" "$ssh_config" 2>/dev/null; then
        log_success "SSH config already has Proxmox entry"
        return 0
    fi

    # Add Proxmox entry to SSH config
    cat >> "$ssh_config" << EOF

# Proxmox server (added by crucible-proxmox.sh)
Host $PROXMOX_HOST proxmox
   HostName $PROXMOX_HOST
   User root
   IdentityFile $SSH_KEY_PATH
   StrictHostKeyChecking no
EOF

    log_success "SSH config updated - you can now use: ssh proxmox"
}

setup_proxmox_nginx() {
    log_step "Setting up nginx reverse proxy..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would setup nginx"
        return 0
    fi

    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" "bash -s" << 'ENDSSH'
set -e

# Install nginx
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    apt-get update -qq
    apt-get install -y nginx
else
    echo "✓ nginx already installed"
fi

systemctl enable nginx

# Get hostname
HOSTNAME=$(hostname)

# Create nginx config
cat > /etc/nginx/sites-available/proxmox-reverse-proxy << 'EOF'
upstream proxmox {
    server "$HOSTNAME";
}

server {
    listen 80 default_server;
    rewrite ^(.*) https://$host$1 permanent;
}

server {
    listen 443 ssl;
    server_name _;
    ssl_certificate /etc/pve/local/pve-ssl.pem;
    ssl_certificate_key /etc/pve/local/pve-ssl.key;
    proxy_redirect off;

    location ~ /api2/json/nodes/.+/qemu/.+/vncwebsocket.* {
        proxy_set_header Authorization "PVEAPIToken=__PROXMOX_TOKEN__";
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass https://localhost:8006;
        proxy_buffering off;
        client_max_body_size 0;
        proxy_connect_timeout 3600s;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
    }

    location / {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass https://localhost:8006;
        proxy_buffering off;
        client_max_body_size 0;
        proxy_connect_timeout 3600s;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
    }
}
EOF

sed -i "s/\$HOSTNAME/$HOSTNAME/g" /etc/nginx/sites-available/proxmox-reverse-proxy

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/proxmox-console
ln -sf /etc/nginx/sites-available/proxmox-reverse-proxy /etc/nginx/sites-enabled/proxmox-reverse-proxy

# Create systemd override
mkdir -p /etc/systemd/system/nginx.service.d
cat > /etc/systemd/system/nginx.service.d/pve-cluster.conf << 'OVERRIDE'
[Unit]
Requires=pve-cluster.service
After=pve-cluster.service
OVERRIDE

systemctl daemon-reload
nginx -t
systemctl restart nginx

echo "✓ nginx configured"
ENDSSH

    log_success "nginx reverse proxy installed"
}

setup_proxmox_token() {
    log_step "Creating Proxmox API token..."

    # Check if token already exists in config
    if [ -n "$PROXMOX_API_TOKEN" ]; then
        log_success "Using existing API token from config"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create API token"
        PROXMOX_API_TOKEN="root@pam!CRUCIBLE=dry-run-token"
        return 0
    fi

    # Check if token already exists - don't regenerate if it does
    local token_exists=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" \
        "pveum user token list root@pam | grep -q '$TOKEN_NAME' && echo 'yes' || echo 'no'")

    if [ "$token_exists" = "yes" ]; then
        log_info "API token already exists, keeping existing token"

        # Load token from config if not in environment
        if [ -z "$PROXMOX_API_TOKEN" ] && [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE" 2>/dev/null || true
        fi

        if [ -n "$PROXMOX_API_TOKEN" ]; then
            log_success "Using token from config file"
            return 0
        else
            log_error "Token exists on Proxmox but secret not in config file"
            log_error "Proxmox only shows token secret once during creation"
            log_error ""
            log_error "To fix: Delete the existing token and re-run setup:"
            log_error "  ssh root@$PROXMOX_HOST 'pveum user token remove root@pam $TOKEN_NAME'"
            log_error "  ./scripts/setup-crucible-proxmox.sh setup"
            return 1
        fi
    fi

    local token_output=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << TOKENEOF
set -e

echo "Creating API token..."
pveum user token add root@pam $TOKEN_NAME --privsep 0
TOKENEOF
)

    local token_value=$(echo "$token_output" | grep -E "│\s+value\s+│" | awk -F'│' '{print $3}' | grep -oE '[0-9a-f-]{36}' | head -1)

    if [ -z "$token_value" ]; then
        log_error "Failed to extract token value"
        return 1
    fi

    PROXMOX_API_TOKEN="root@pam!${TOKEN_NAME}=${token_value}"
    log_success "API token created"

    # Update nginx with token
    if [ "$DRY_RUN" != "true" ]; then
        ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << NGINXEOF
sed -i "s|__PROXMOX_TOKEN__|$PROXMOX_API_TOKEN|g" /etc/nginx/sites-available/proxmox-reverse-proxy
nginx -t
systemctl reload nginx
NGINXEOF
        log_success "nginx updated with API token"
    fi
}

setup_proxmox_nfs() {
    log_step "Setting up NFS export for ISO storage..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would setup NFS"
        return 0
    fi

    local proxmox_network="${PROXMOX_HOST%.*.*}.0.0/16"

    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << NFSEOF
set -e

# Install NFS server
if ! dpkg -l | grep -q nfs-kernel-server; then
    echo "Installing NFS server..."
    apt-get update -qq
    apt-get install -y nfs-kernel-server
else
    echo "✓ NFS server already installed"
fi

# Backup existing exports
if [ -f /etc/exports ] && [ ! -f /etc/exports.backup ]; then
    cp /etc/exports /etc/exports.backup
fi

# Add ISO export
if ! grep -q "/var/lib/vz/template/iso" /etc/exports 2>/dev/null; then
    echo "/var/lib/vz/template/iso $proxmox_network(rw,sync,no_subtree_check,no_root_squash,insecure)" >> /etc/exports
    echo "✓ Added NFS export"
else
    echo "✓ NFS export already exists"
fi

chmod 777 /var/lib/vz/template/iso
exportfs -ra
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

echo "✓ NFS server configured"
NFSEOF

    log_success "NFS export configured"
}

setup_proxmox_oidc() {
    log_step "Configuring Proxmox OIDC authentication realm..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would configure OIDC realm"
        return 0
    fi

    # Detect Keycloak host IP (Windows Hyper-V switch IP that Proxmox can reach)
    # User can override with KEYCLOAK_HOST environment variable
    local KEYCLOAK_HOST="${KEYCLOAK_HOST:-}"

    if [ -z "$KEYCLOAK_HOST" ]; then
        # For Proxmox OIDC, we need the Windows host IP (Hyper-V switch) not Docker IP
        # Standard Hyper-V Default Switch uses x.x.16.1 gateway pattern
        # Extract first 2 octets from PROXMOX_HOST and assume .16.1 gateway
        # e.g., 172.29.24.139 -> 172.29.16.1 (Hyper-V Default Switch gateway)
        local proxmox_subnet=$(echo "$PROXMOX_HOST" | cut -d. -f1-2)
        KEYCLOAK_HOST="${proxmox_subnet}.16.1"

        log_info "Auto-detected KEYCLOAK_HOST: $KEYCLOAK_HOST (Hyper-V Default Switch gateway)"
        log_info "If this is incorrect, set KEYCLOAK_HOST environment variable before running setup"
    fi

    log_info "Using Keycloak host: $KEYCLOAK_HOST"

    # Use HTTP (8080) instead of HTTPS (8443) to avoid SSL certificate issues
    local KEYCLOAK_ISSUER="http://${KEYCLOAK_HOST}:8080/realms/crucible"
    local OIDC_CLIENT_ID="proxmox-web"
    local OIDC_CLIENT_SECRET="proxmox-oidc-secret-change-me"
    local OIDC_REALM_NAME="keycloak-crucible"

    # First, verify Keycloak is accessible from Proxmox
    log_info "Verifying Keycloak accessibility from Proxmox..."

    if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" \
        "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 ${KEYCLOAK_ISSUER}/.well-known/openid-configuration | grep -q '200'"; then
        log_warning "Keycloak not accessible at $KEYCLOAK_ISSUER"
        log_warning "Please ensure:"
        log_warning "  1. Keycloak is running (aspire run)"
        log_warning "  2. Port forwarding is configured on Windows host:"
        log_warning "     netsh interface portproxy add v4tov4 listenaddress=$KEYCLOAK_HOST listenport=8080 connectaddress=127.0.0.1 connectport=8080"
        log_warning "Skipping OIDC configuration"
        return 0
    fi

    log_success "Keycloak is accessible from Proxmox"

    # Ensure Proxmox can resolve "keycloak" hostname (if using hostname in issuer)
    log_step "Configuring Proxmox hosts file for Keycloak..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash <<HOSTSEOF
set -e
# Add keycloak to /etc/hosts if using hostname
if ! grep -q "keycloak" /etc/hosts; then
    echo "$KEYCLOAK_HOST keycloak" >> /etc/hosts
    echo "✓ Added keycloak to /etc/hosts"
else
    # Update existing entry
    sed -i '/keycloak/d' /etc/hosts
    echo "$KEYCLOAK_HOST keycloak" >> /etc/hosts
    echo "✓ Updated keycloak in /etc/hosts"
fi
HOSTSEOF

    # Configure OIDC realm on Proxmox
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash <<OIDCEOF
set -e

REALM_NAME="$OIDC_REALM_NAME"
ISSUER_URL="$KEYCLOAK_ISSUER"
CLIENT_ID="$OIDC_CLIENT_ID"
CLIENT_SECRET="$OIDC_CLIENT_SECRET"

echo "════════════════════════════════════════════════"
echo "Proxmox OIDC Configuration"
echo "════════════════════════════════════════════════"
echo "Realm Name: \$REALM_NAME"
echo "Issuer URL: \$ISSUER_URL"
echo "Client ID: \$CLIENT_ID"
echo ""

# Check if realm already exists
if pveum realm list | grep -q "^\${REALM_NAME}"; then
    echo "⚠ OIDC realm '\${REALM_NAME}' already exists"
    echo "  Removing existing realm..."
    pveum realm delete "\${REALM_NAME}" || true
fi

echo "✓ Creating OIDC realm: \${REALM_NAME}"

# Add OpenID realm
pveum realm add "\${REALM_NAME}" \\
    --type openid \\
    --issuer-url "\${ISSUER_URL}" \\
    --client-id "\${CLIENT_ID}" \\
    --client-key "\${CLIENT_SECRET}" \\
    --username-claim "preferred_username" \\
    --scopes "openid email profile" \\
    --prompt "login" \\
    --autocreate 1 \\
    --default 1

echo "✓ OIDC realm created successfully"
echo ""

# Create Proxmox groups for role mapping
echo "Creating Proxmox groups for Keycloak role mapping..."
echo ""

# Administrators group (full access)
if ! pveum group list | grep -q "^crucible-admins"; then
    pveum group add crucible-admins -comment "Crucible Administrators via Keycloak"
    echo "✓ Created group: crucible-admins"
else
    echo "  Group already exists: crucible-admins"
fi
pveum acl modify / -group crucible-admins -role Administrator

# Content Developers group (VM operator access)
if ! pveum group list | grep -q "^crucible-developers"; then
    pveum group add crucible-developers -comment "Crucible Content Developers via Keycloak"
    echo "✓ Created group: crucible-developers"
else
    echo "  Group already exists: crucible-developers"
fi
pveum acl modify / -group crucible-developers -role PVEVMAdmin

# Test/Observer group (read-only)
if ! pveum group list | grep -q "^crucible-observers"; then
    pveum group add crucible-observers -comment "Crucible Test/Observer users via Keycloak"
    echo "✓ Created group: crucible-observers"
else
    echo "  Group already exists: crucible-observers"
fi
pveum acl modify / -group crucible-observers -role PVEAuditor

echo ""
echo "✓ Proxmox groups created and ACLs configured"
echo ""

# Create group sync script
cat > /usr/local/bin/oidc-group-sync.sh << 'SYNCEOF'
#!/bin/bash
# Sync Keycloak groups to Proxmox groups
# Usage: oidc-group-sync.sh <username@keycloak-crucible> [group1,group2,...]

USER="\$1"
KEYCLOAK_GROUPS="\$2"

if [ -z "\$USER" ]; then
    echo "Usage: \$0 <username@keycloak-crucible> [Administrators,Content Developer,Test]"
    echo ""
    echo "Example:"
    echo "  \$0 admin@keycloak-crucible Administrators"
    echo "  \$0 developer@keycloak-crucible 'Content Developer'"
    echo "  \$0 observer@keycloak-crucible Test"
    exit 1
fi

# Extract username without realm
USERNAME=\${USER%@*}

echo "Syncing groups for user: \$USER"
echo ""

# Remove user from all crucible groups first
for group in crucible-admins crucible-developers crucible-observers; do
    if pveum user list | grep -q "^\$USER"; then
        # Check if user is in group
        if pveum user list | grep "^\$USER" | grep -q "\$group"; then
            echo "  Removing from: \$group"
            pveum user modify "\$USER" -delete 1 -group "\$group" 2>/dev/null || true
        fi
    fi
done

# Assign groups based on Keycloak membership
if [ -z "\$KEYCLOAK_GROUPS" ]; then
    echo ""
    echo "No groups specified. User will have default permissions."
    echo ""
    echo "To assign groups, specify them as second argument:"
    echo "  \$0 \$USER 'Administrators'"
    echo "  \$0 \$USER 'Content Developer'"
    echo "  \$0 \$USER 'Test'"
else
    if echo "\$KEYCLOAK_GROUPS" | grep -qi "Administrator"; then
        echo "✓ Adding to: crucible-admins (Administrator role)"
        pveum user modify "\$USER" -group crucible-admins
    fi

    if echo "\$KEYCLOAK_GROUPS" | grep -qi "Content Developer"; then
        echo "✓ Adding to: crucible-developers (PVEVMAdmin role)"
        pveum user modify "\$USER" -group crucible-developers
    fi

    if echo "\$KEYCLOAK_GROUPS" | grep -qi "Test"; then
        echo "✓ Adding to: crucible-observers (PVEAuditor role)"
        pveum user modify "\$USER" -group crucible-observers
    fi
fi

echo ""
echo "Group sync completed for \$USER"
echo ""
echo "Current group memberships:"
pveum user list | grep "^\$USER"
SYNCEOF

chmod +x /usr/local/bin/oidc-group-sync.sh

echo "✓ Group sync script installed: /usr/local/bin/oidc-group-sync.sh"
echo ""

# Display configuration summary
echo "════════════════════════════════════════════════"
echo "OIDC Configuration Complete"
echo "════════════════════════════════════════════════"
echo ""
echo "Configured Realms:"
pveum realm list
echo ""
echo "Proxmox Groups:"
pveum group list | grep crucible
echo ""
echo "ACL Permissions:"
pveum acl list | grep crucible
echo ""
echo "To test OIDC login:"
echo "  1. Navigate to: https://\$(hostname -I | awk '{print \$1}'):8006"
echo "  2. Select 'Keycloak Crucible Realm' from dropdown"
echo "  3. Login with Keycloak credentials (admin/admin)"
echo "  4. After first login, run group sync:"
echo "     /usr/local/bin/oidc-group-sync.sh <username@keycloak-crucible> <groups>"
echo ""
echo "Example group sync commands:"
echo "  /usr/local/bin/oidc-group-sync.sh admin@keycloak-crucible Administrators"
echo "  /usr/local/bin/oidc-group-sync.sh developer@keycloak-crucible 'Content Developer'"
echo "  /usr/local/bin/oidc-group-sync.sh observer@keycloak-crucible Test"
echo ""
echo "════════════════════════════════════════════════"

OIDCEOF

    # Verify configuration
    log_step "Verifying Proxmox OIDC configuration..."

    local verify_output=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash <<VERIFYEOF
# Check realm exists
if pveum realm list | grep -q "$OIDC_REALM_NAME"; then
    echo "✓ OIDC realm exists: $OIDC_REALM_NAME"
else
    echo "✗ OIDC realm NOT found: $OIDC_REALM_NAME"
    exit 1
fi

# Check groups exist
for group in crucible-admins crucible-developers crucible-observers; do
    if pveum group list | grep -q "\$group"; then
        echo "✓ Group exists: \$group"
    else
        echo "✗ Group NOT found: \$group"
        exit 1
    fi
done

# Check keycloak hostname resolves
if grep -q "keycloak" /etc/hosts; then
    echo "✓ Keycloak in /etc/hosts: \$(grep keycloak /etc/hosts)"
else
    echo "✗ Keycloak NOT in /etc/hosts"
    exit 1
fi

# Test Keycloak accessibility
if curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://keycloak:8080/realms/crucible/.well-known/openid-configuration | grep -q '200'; then
    echo "✓ Keycloak accessible from Proxmox"
else
    echo "✗ Keycloak NOT accessible from Proxmox"
    exit 1
fi

echo "✓ All OIDC configuration verified"
VERIFYEOF
)

    if [ $? -eq 0 ]; then
        log_success "Proxmox OIDC configuration verified"
        echo "$verify_output" | while read line; do
            log_info "  $line"
        done
    else
        log_error "Proxmox OIDC configuration verification FAILED"
        echo "$verify_output"
        return 1
    fi

    log_info "OIDC realm: $OIDC_REALM_NAME"
    log_info "Issuer URL: $KEYCLOAK_ISSUER"
}

toggle_topomojo_hypervisor() {
    log_step "Configuring TopoMojo for Proxmox..."

    local apphost_dir="/mnt/data/crucible/topomojo/topomojo/src/TopoMojo.Api"
    local appsettings_dev="$apphost_dir/appsettings.Development.conf"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would configure TopoMojo"
        return 0
    fi

    # Create appsettings
    cat > "$appsettings_dev" << EOF
Pod__HypervisorType=Proxmox
Pod__Url=https://${PROXMOX_HOST}:443
Pod__AccessToken=${PROXMOX_API_TOKEN}
Pod__VmStore=local-lvm
Pod__DiskStore=local-lvm
Pod__IsoStore=local
Pod__IsoRoot=/mnt/proxmox-iso
Pod__IgnoreCertificateErrors=true
Pod__SupportsSubfolders=false
FileUpload__IsoRoot=/mnt/proxmox-iso
FileUpload__UseDatastoreApi=false
EOF

    log_success "TopoMojo configured for Proxmox"
}

# ============================================================
# VM TEMPLATE FUNCTIONS
# ============================================================

create_alpine_template() {
    log_step "Creating Alpine Linux template (ID: $ALPINE_PROXMOX_ID)..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create Alpine template"
        return 0
    fi

    # Check if VM already exists
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" "qm status 105 >/dev/null 2>&1"; then
        log_info "Alpine template VM 105 already exists, skipping"
        return 0
    fi

    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << 'VMEOF'
set -e

TEMPLATE_ID=105
ALPINE_VERSION="3.19"
ALPINE_CLOUD_IMAGE="nocloud_alpine-${ALPINE_VERSION}.2-x86_64-uefi-cloudinit-r0.qcow2"
ALPINE_CLOUD_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/cloud/${ALPINE_CLOUD_IMAGE}"

# Delete existing VM/template if exists
if qm list | grep -q "^\s*${TEMPLATE_ID}"; then
    echo "Removing existing VM ${TEMPLATE_ID}..."
    qm stop ${TEMPLATE_ID} 2>/dev/null || true
    qm destroy ${TEMPLATE_ID} 2>/dev/null || true
fi

# Download cloud image if not present
IMAGE_PATH="/var/lib/vz/template/iso/${ALPINE_CLOUD_IMAGE}"
if [ ! -f "$IMAGE_PATH" ]; then
    echo "Downloading Alpine cloud image..."
    cd /var/lib/vz/template/iso
    wget -q --show-progress "$ALPINE_CLOUD_URL" || exit 1
fi

# Create VM
qm create ${TEMPLATE_ID} \
  --name alpine-linux-template \
  --memory 512 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26

# Import disk
qm importdisk ${TEMPLATE_ID} "$IMAGE_PATH" local-lvm
qm set ${TEMPLATE_ID} --scsi0 local-lvm:vm-${TEMPLATE_ID}-disk-0,discard=on
qm set ${TEMPLATE_ID} --boot c --bootdisk scsi0
qm set ${TEMPLATE_ID} --agent enabled=1
qm set ${TEMPLATE_ID} --ide2 local-lvm:cloudinit
qm set ${TEMPLATE_ID} --ciuser root
qm set ${TEMPLATE_ID} --cipassword password
qm set ${TEMPLATE_ID} --ipconfig0 ip=dhcp
qm set ${TEMPLATE_ID} --serial0 socket --vga serial0
qm template ${TEMPLATE_ID}

echo "✓ Alpine template created"
VMEOF

    log_success "Alpine Linux template created (ID: $ALPINE_PROXMOX_ID)"
}

create_tinycore_template() {
    log_step "Creating TinyCore Linux template (ID: $TINYCORE_PROXMOX_ID)..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create TinyCore template"
        return 0
    fi

    # Check if VM already exists
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" "qm status 106 >/dev/null 2>&1"; then
        log_info "TinyCore template VM 106 already exists, skipping"
        return 0
    fi

    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << 'VMEOF'
set -e

TEMPLATE_ID=106
ISO_NAME="TinyCore-current.iso"
ISO_URL="http://tinycorelinux.net/15.x/x86/release/TinyCore-current.iso"

# Download ISO if not present
ISO_PATH="/var/lib/vz/template/iso/${ISO_NAME}"
if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading TinyCore ISO..."
    cd /var/lib/vz/template/iso
    wget -q --show-progress "$ISO_URL" || exit 1
fi

# Delete existing VM if exists
if qm list | grep -q "^\s*${TEMPLATE_ID}"; then
    qm stop ${TEMPLATE_ID} 2>/dev/null || true
    qm destroy ${TEMPLATE_ID} 2>/dev/null || true
fi

# Create VM
qm create ${TEMPLATE_ID} \
  --name tinycore-linux-template \
  --memory 512 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26

qm set ${TEMPLATE_ID} --ide2 local:iso/${ISO_NAME},media=cdrom
qm set ${TEMPLATE_ID} --boot "order=ide2"
qm template ${TEMPLATE_ID}

echo "✓ TinyCore template created"
VMEOF

    log_success "TinyCore Linux template created (ID: $TINYCORE_PROXMOX_ID)"
}

create_puppy_vm() {
    log_step "Creating Puppy Linux VM (ID: $PUPPY_PROXMOX_ID)..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create Puppy VM"
        return 0
    fi

    # Check if VM already exists
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" "qm status 103 >/dev/null 2>&1"; then
        log_info "Puppy Linux VM 103 already exists, skipping"
        return 0
    fi

    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << 'VMEOF'
set -e

VMID=103
ISO_NAME="fossapup64-9.5.iso"
ISO_URL="https://distro.ibiblio.org/puppylinux/puppy-fossa/fossapup64-9.5.iso"

# Download ISO if not present
ISO_PATH="/var/lib/vz/template/iso/${ISO_NAME}"
if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading Puppy Linux ISO..."
    cd /var/lib/vz/template/iso
    wget -q --show-progress "$ISO_URL" || exit 1
fi

# Delete existing VM if exists
if qm list | grep -q "^\s*${VMID}"; then
    qm stop ${VMID} 2>/dev/null || true
    qm destroy ${VMID} 2>/dev/null || true
fi

# Create VM
qm create ${VMID} \
  --name puppy-test \
  --memory 512 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26

qm set ${VMID} --ide2 local:iso/${ISO_NAME},media=cdrom
qm set ${VMID} --boot "order=ide2"

echo "✓ Puppy VM created"
VMEOF

    log_success "Puppy Linux VM created (ID: $PUPPY_PROXMOX_ID)"
}

# ============================================================
# TOPOMOJO FUNCTIONS
# ============================================================

create_topomojo_workspace_basic() {
    local workspace_name="Test Workspace"

    log_step "Creating TopoMojo workspace: $workspace_name"

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[topomojo]}")
    if [ -z "$token" ]; then
        log_error "Failed to get TopoMojo token"
        return 1
    fi

    # Check if workspace exists
    local all_workspaces=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/workspaces" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
    local existing_id=$(echo "$all_workspaces" | jq -r ".[] | select(.name == \"$workspace_name\") | .id" | head -1)

    if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
        log_success "TopoMojo workspace already exists: $existing_id"
        # Still create templates if they don't exist
        create_stock_templates_once "$token"
        create_topomojo_templates "$existing_id" "$token" "puppy"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create TopoMojo workspace"
        return 0
    fi

    # Create workspace with hardcoded ID
    local workspace_response=$(curl -k -s -X POST "$TOPOMOJO_API_URL/api/workspace" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$WORKSPACE_BASIC_ID\",
            \"name\": \"$workspace_name\",
            \"description\": \"Test workspace with Proxmox-based templates\",
            \"tags\": \"test\"
        }" 2>/dev/null)

    local workspace_id=$(echo "$workspace_response" | jq -r '.id' 2>/dev/null)

    if [ -z "$workspace_id" ] || [ "$workspace_id" = "null" ]; then
        log_error "Failed to create TopoMojo workspace"
        return 1
    fi

    log_success "TopoMojo workspace created: $workspace_id"

    # Create Proxmox workspace template VMs (9001, 9002)
    create_proxmox_workspace_templates

    # Create stock templates (once, globally)
    create_stock_templates_once "$token"

    # Create workspace-specific templates (some linked, some not)
    create_topomojo_templates "$workspace_id" "$token" "puppy"

    return 0
}

create_topomojo_workspace_with_variants() {
    local workspace_name="Moodle Test Workspace - Variants"

    log_step "Creating TopoMojo workspace with variants: $workspace_name"

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[topomojo]}")
    if [ -z "$token" ]; then
        log_error "Failed to get TopoMojo token"
        return 1
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create TopoMojo workspace with variants"
        return 0
    fi

    # Check if workspace exists
    local all_workspaces=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/workspaces" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
    local existing_id=$(echo "$all_workspaces" | jq -r ".[] | select(.name == \"$workspace_name\") | .id" | head -1)

    if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
        log_success "TopoMojo workspace with variants already exists: $existing_id"
        workspace_id="$existing_id"
        # Continue to ensure templates are configured
        create_stock_templates_once "$token"
        create_topomojo_templates "$workspace_id" "$token" "tinycore"
        return 0
    fi

    # Create challenge spec with 3 variants
    local challenge_json='{
  "text": "# Moodle Test Challenge\n\nThis challenge has 3 variants for testing mod_topomojo random variant assignment.",
  "maxPoints": 0,
  "maxAttempts": 0,
  "transforms": [],
  "variants": [
    {
      "text": "# Variant 1: Linux Basics",
      "sections": [
        {
          "name": "Basic Commands",
          "text": "",
          "questions": [
            {
              "text": "What command lists files?",
              "answer": "ls",
              "example": "ls",
              "hint": "Two letters",
              "penalty": 0,
              "weight": 1
            },
            {
              "text": "What command shows current directory?",
              "answer": "pwd",
              "example": "pwd",
              "hint": "Three letters",
              "penalty": 0,
              "weight": 1
            }
          ]
        }
      ]
    },
    {
      "text": "# Variant 2: File Operations",
      "sections": [
        {
          "name": "File Commands",
          "text": "",
          "questions": [
            {
              "text": "What command copies files?",
              "answer": "cp",
              "example": "cp source dest",
              "hint": "Two letters",
              "penalty": 0,
              "weight": 1
            },
            {
              "text": "What command moves files?",
              "answer": "mv",
              "example": "mv source dest",
              "hint": "Two letters",
              "penalty": 0,
              "weight": 1
            }
          ]
        }
      ]
    },
    {
      "text": "# Variant 3: Directory Operations",
      "sections": [
        {
          "name": "Directory Commands",
          "text": "",
          "questions": [
            {
              "text": "What command creates directories?",
              "answer": "mkdir",
              "example": "mkdir dirname",
              "hint": "Five letters",
              "penalty": 0,
              "weight": 1
            },
            {
              "text": "What command removes directories?",
              "answer": "rmdir",
              "example": "rmdir dirname",
              "hint": "Five letters",
              "penalty": 0,
              "weight": 1
            }
          ]
        }
      ]
    }
  ]
}'

    # Create workspace WITH challenge included in initial POST
    # Note: challenge must be a JSON-encoded STRING, not an object
    log_info "Creating workspace with 3 challenge variants..."
    local challenge_string=$(echo "$challenge_json" | jq -c '.' | jq -Rs '.')
    local workspace_payload=$(jq -n \
        --arg id "$WORKSPACE_VARIANTS_ID" \
        --arg name "$workspace_name" \
        --arg desc "Test workspace with 3 variants for mod_topomojo testing" \
        --arg tags "test,moodle,variants" \
        --argjson challenge "$challenge_string" \
        '{
            id: $id,
            name: $name,
            description: $desc,
            tags: $tags,
            challenge: $challenge
        }')

    local workspace_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X POST "$TOPOMOJO_API_URL/api/workspace" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$workspace_payload" 2>&1)

    local http_code=$(echo "$workspace_response" | grep "HTTP_CODE:" | cut -d: -f2)
    local response_body=$(echo "$workspace_response" | sed '/HTTP_CODE:/d')

    workspace_id=$(echo "$response_body" | jq -r '.id' 2>/dev/null)

    if [ -z "$workspace_id" ] || [ "$workspace_id" = "null" ]; then
        local error_msg=$(echo "$response_body" | jq -r '.message // .title // .detail // .' 2>/dev/null || echo "${response_body:0:500}")
        local errors=$(echo "$response_body" | jq -r '.errors // empty' 2>/dev/null)
        if [ -n "$errors" ]; then
            error_msg="$error_msg | Errors: $errors"
        fi
        log_error "Failed to create workspace (HTTP $http_code): $error_msg"
        return 1
    fi

    # Verify challenge was created (challenge is a JSON string, so parse it)
    local challenge_str=$(echo "$response_body" | jq -r '.challenge' 2>/dev/null)
    local variant_count=$(echo "$challenge_str" | jq -r '.variants | length' 2>/dev/null)
    if [ "$variant_count" = "3" ]; then
        log_success "Workspace with $variant_count challenge variants created: $workspace_id"
    else
        log_warning "Workspace created ($workspace_id) but may not have variants (got $variant_count, challenge length: ${#challenge_str})"
    fi

    # Create stock templates (once, globally)
    create_stock_templates_once "$token"

    # Create TopoMojo templates for this workspace (Puppy for variants)
    create_topomojo_templates "$workspace_id" "$token" "tinycore"

    return 0
}

create_proxmox_workspace_templates() {
    log_step "Creating Proxmox workspace template VMs (9001, 9002, 9003)..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create Proxmox workspace templates"
        return 0
    fi

    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << 'VMEOF'
set -e

# VM 9001: TinyCore-ISO
if qm status 9001 &>/dev/null; then
    qm stop 9001 2>/dev/null || true
    qm destroy 9001 2>/dev/null || true
fi

qm create 9001 \
    --name "TinyCore-ISO" \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --ostype l26

qm set 9001 --ide2 local:iso/TinyCore-current.iso,media=cdrom
qm set 9001 --boot "order=ide2"
qm template 9001

echo "✓ Created workspace template VM 9001 (TinyCore-ISO)"

# VM 9002: Alpine-Disk
if qm status 9002 &>/dev/null; then
    qm stop 9002 2>/dev/null || true
    qm destroy 9002 2>/dev/null || true
fi

qm create 9002 \
    --name "Alpine-Disk" \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --ostype l26

qm set 9002 --scsi0 local-lvm:10
qm set 9002 --ide2 local:iso/TinyCore-current.iso,media=cdrom
qm set 9002 --boot "order=scsi0;ide2"
qm template 9002

echo "✓ Created workspace template VM 9002 (Alpine-Disk)"

# VM 9003: Puppy-Linux (clone from VM 103)
if qm status 9003 &>/dev/null; then
    qm stop 9003 2>/dev/null || true
    qm destroy 9003 2>/dev/null || true
fi

if qm status 103 &>/dev/null; then
    qm clone 103 9003 --name "Puppy-Linux" --full
    qm template 9003
    echo "✓ Created workspace template VM 9003 (Puppy-Linux)"
else
    echo "⚠ VM 103 (puppy-test) not found, skipping Puppy template"
fi
VMEOF

    log_success "Proxmox workspace templates created"
}

create_stock_templates_once() {
    local token="$1"

    # Check if stock templates already exist
    local all_templates=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/templates?filter=stock" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")

    local tinycore_stock=$(echo "$all_templates" | jq -r '.[] | select(.name == "TinyCore-ISO-Stock") | .id' | head -1)
    local alpine_stock=$(echo "$all_templates" | jq -r '.[] | select(.name == "Alpine-Disk-Stock") | .id' | head -1)
    local puppy_stock=$(echo "$all_templates" | jq -r '.[] | select(.name == "Puppy-Linux-Stock") | .id' | head -1)

    # Create TinyCore stock template if doesn't exist
    if [ -z "$tinycore_stock" ] || [ "$tinycore_stock" = "null" ]; then
        log_step "Creating stock template: TinyCore-ISO-Stock"
        local tinycore_detail=$(jq -n \
            --arg template "TinyCore-ISO" \
            --arg iso "local:iso/TinyCore-current.iso" \
            '{
                template: $template,
                iso: $iso,
                ram: 1,
                cpu: "1x1",
                eth: [{net: "lan"}],
                disks: []
            }')

        local tinycore_response=$(curl -k -s -X POST "$TOPOMOJO_API_URL/api/template" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"$TEMPLATE_TINYCORE_STOCK_ID\",
                \"name\": \"TinyCore-ISO-Stock\",
                \"description\": \"Stock TinyCore template (boots from ISO)\",
                \"networks\": \"lan\",
                \"detail\": $(echo "$tinycore_detail" | jq -Rs .),
                \"isPublished\": true
            }" 2>/dev/null)

        tinycore_stock=$(echo "$tinycore_response" | jq -r '.id' 2>/dev/null)
        if [ -n "$tinycore_stock" ] && [ "$tinycore_stock" != "null" ]; then
            log_success "Stock template created: TinyCore-ISO-Stock ($tinycore_stock)"
            RESOURCE_IDS[stock_tinycore]="$tinycore_stock"
        fi
    else
        log_success "Stock template exists: TinyCore-ISO-Stock ($tinycore_stock)"
        RESOURCE_IDS[stock_tinycore]="$tinycore_stock"
    fi

    # Create Alpine stock template if doesn't exist
    if [ -z "$alpine_stock" ] || [ "$alpine_stock" = "null" ]; then
        log_step "Creating stock template: Alpine-Disk-Stock"
        local alpine_detail=$(jq -n \
            --arg template "Alpine-Disk" \
            '{
                template: $template,
                ram: 2,
                cpu: "1x2",
                eth: [{net: "lan"}],
                disks: [{size: "10G"}]
            }')

        local alpine_response=$(curl -k -s -X POST "$TOPOMOJO_API_URL/api/template" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"$TEMPLATE_ALPINE_STOCK_ID\",
                \"name\": \"Alpine-Disk-Stock\",
                \"description\": \"Stock Alpine template (with disk)\",
                \"networks\": \"lan\",
                \"detail\": $(echo "$alpine_detail" | jq -Rs .),
                \"isPublished\": true
            }" 2>/dev/null)

        alpine_stock=$(echo "$alpine_response" | jq -r '.id' 2>/dev/null)
        if [ -n "$alpine_stock" ] && [ "$alpine_stock" != "null" ]; then
            log_success "Stock template created: Alpine-Disk-Stock ($alpine_stock)"
            RESOURCE_IDS[stock_alpine]="$alpine_stock"
        fi
    else
        log_success "Stock template exists: Alpine-Disk-Stock ($alpine_stock)"
        RESOURCE_IDS[stock_alpine]="$alpine_stock"
    fi

    # Create Puppy stock template if doesn't exist
    if [ -z "$puppy_stock" ] || [ "$puppy_stock" = "null" ]; then
        log_step "Creating stock template: Puppy-Linux-Stock"
        local puppy_detail=$(jq -n \
            --arg template "Puppy-Linux" \
            --arg iso "local:iso/fossapup64-9.5.iso" \
            '{
                template: $template,
                iso: $iso,
                ram: 1,
                cpu: "1x1",
                eth: [{net: "lan"}],
                disks: []
            }')

        local puppy_response=$(curl -k -s -X POST "$TOPOMOJO_API_URL/api/template" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"$TEMPLATE_PUPPY_STOCK_ID\",
                \"name\": \"Puppy-Linux-Stock\",
                \"description\": \"Stock Puppy Linux template (boots from ISO)\",
                \"networks\": \"lan\",
                \"detail\": $(echo "$puppy_detail" | jq -Rs .),
                \"isPublished\": true
            }" 2>/dev/null)

        puppy_stock=$(echo "$puppy_response" | jq -r '.id' 2>/dev/null)
        if [ -n "$puppy_stock" ] && [ "$puppy_stock" != "null" ]; then
            log_success "Stock template created: Puppy-Linux-Stock ($puppy_stock)"
            RESOURCE_IDS[stock_puppy]="$puppy_stock"
        fi
    else
        log_success "Stock template exists: Puppy-Linux-Stock ($puppy_stock)"
        RESOURCE_IDS[stock_puppy]="$puppy_stock"
    fi
}

create_topomojo_templates() {
    local workspace_id="$1"
    local token="$2"
    local template_type="${3:-tinycore}"  # Default to tinycore if not specified

    log_step "Creating TopoMojo templates for workspace ($template_type)..."

    # Remove ALL existing templates of the type we're about to create (idempotent)
    log_info "Checking for existing templates to ensure idempotency..."

    # Query ALL templates (not just workspace-linked) to catch orphaned templates
    local all_templates=$(curl -k -s "$TOPOMOJO_API_URL/api/templates" \
        -H "Authorization: Bearer $token" 2>/dev/null)

    # Debug: show what templates are found
    local template_count=$(echo "$all_templates" | jq -r 'length' 2>/dev/null || echo "0")
    log_info "Found $template_count total templates across all workspaces"

    # Determine which template name to look for based on type
    local target_template_name=""
    case "$template_type" in
        puppy)
            target_template_name="puppy-workspace"
            ;;
        tinycore)
            target_template_name="tinycore-workspace"
            ;;
        alpine)
            target_template_name="alpine-workspace"
            ;;
    esac

    # Check how many workspace-specific templates exist (unpublished only)
    if [ -n "$target_template_name" ]; then
        local existing_ids=$(echo "$all_templates" | jq -r ".[] | select(.name | test(\"^${target_template_name}(-[0-9]+)?\$\") and .isPublished == false) | .id")
        local existing_count=$(echo "$existing_ids" | grep -c . || echo "0")

        if [ $existing_count -eq 1 ]; then
            log_success "Exactly one $target_template_name template exists, skipping creation"
            return 0
        elif [ $existing_count -gt 1 ]; then
            log_info "Found $existing_count duplicate $target_template_name templates, removing all..."
            local delete_count=0
            while IFS= read -r template_id; do
                if [ -n "$template_id" ]; then
                    log_info "Deleting duplicate: $target_template_name ($template_id)"
                    local delete_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X DELETE "$TOPOMOJO_API_URL/api/template/$template_id" \
                        -H "Authorization: Bearer $token" 2>&1)
                    local delete_code=$(echo "$delete_response" | grep "HTTP_CODE:" | cut -d: -f2)
                    if [ "$delete_code" = "204" ] || [ "$delete_code" = "200" ]; then
                        delete_count=$((delete_count + 1))
                    else
                        log_warning "Failed to delete template $template_id (HTTP $delete_code)"
                    fi
                fi
            done <<< "$existing_ids"

            if [ $delete_count -gt 0 ]; then
                log_success "Deleted $delete_count duplicate template(s)"
                sleep 2
            fi
        else
            log_info "No existing $target_template_name templates found, will create new one"
        fi
    fi

    # Create workspace-specific template based on type (existing ones already deleted above)
    if [ "$template_type" = "puppy" ]; then
        # Puppy Linux template
        log_info "Creating Puppy Linux workspace template..."
            local puppy_detail=$(jq -n \
                --arg template "Puppy-Linux" \
                --arg iso "local:iso/fossapup64-9.5.iso" \
                '{
                    template: $template,
                    iso: $iso,
                    ram: 1,
                    cpu: "1x1",
                    eth: [{net: "lan"}],
                    disks: []
                }')

            # Build the request payload
            local puppy_payload=$(jq -n \
                --arg name "puppy-workspace" \
                --arg desc "Workspace-specific Puppy Linux (not linked)" \
                --arg networks "lan" \
                --arg detail "$puppy_detail" \
                --argjson published false \
                '{
                    name: $name,
                    description: $desc,
                    networks: $networks,
                    detail: $detail,
                    isPublished: $published
                }')

            local puppy_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X POST "$TOPOMOJO_API_URL/api/template-detail" \
                -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json" \
                -d "$puppy_payload" 2>&1)

            local http_code=$(echo "$puppy_response" | grep "HTTP_CODE:" | cut -d: -f2)
            local response_body=$(echo "$puppy_response" | sed '/HTTP_CODE:/d')
            local puppy_id=$(echo "$response_body" | jq -r '.id' 2>/dev/null)

            if [ -n "$puppy_id" ] && [ "$puppy_id" != "null" ]; then
                # Link to workspace
                local link_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X POST "$TOPOMOJO_API_URL/api/template" \
                    -H "Authorization: Bearer $token" \
                    -H "Content-Type: application/json" \
                    -d "{\"templateId\": \"$puppy_id\", \"workspaceId\": \"$workspace_id\"}" 2>&1)

                local link_http_code=$(echo "$link_response" | grep "HTTP_CODE:" | cut -d: -f2)
                local link_body=$(echo "$link_response" | sed '/HTTP_CODE:/d')
                local link_id=$(echo "$link_body" | jq -r '.id' 2>/dev/null)

                if [ -n "$link_id" ] && [ "$link_id" != "null" ]; then
                    log_success "Workspace template created and linked: puppy-workspace ($link_id)"
                else
                    log_warning "Template created ($puppy_id) but link failed (HTTP $link_http_code): $(echo "$link_body" | jq -r '.message // .' 2>/dev/null)"
                fi
            else
                local error_detail=$(echo "$response_body" | jq -r '.message // .title // .detail // empty' 2>/dev/null)
                if [ -z "$error_detail" ]; then
                    error_detail="${response_body:0:500}"
                fi
                log_warning "Failed to create Puppy workspace template (HTTP $http_code): $error_detail"
            fi
    elif [ "$template_type" = "alpine" ]; then
        # Alpine template
        log_info "Creating Alpine workspace template..."
            local alpine_detail=$(jq -n \
                --arg template "Alpine-Disk" \
                '{
                    template: $template,
                    ram: 2,
                    cpu: "1x2",
                    eth: [{net: "lan"}],
                    disks: [{size: "10G"}]
                }')

            # Build the request payload
            local alpine_payload=$(jq -n \
                --arg name "alpine-workspace" \
                --arg desc "Workspace-specific Alpine (not linked)" \
                --arg networks "lan" \
                --arg detail "$alpine_detail" \
                --argjson published false \
                '{
                    name: $name,
                    description: $desc,
                    networks: $networks,
                    detail: $detail,
                    isPublished: $published
                }')

            local alpine_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X POST "$TOPOMOJO_API_URL/api/template-detail" \
                -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json" \
                -d "$alpine_payload" 2>&1)

            local http_code=$(echo "$alpine_response" | grep "HTTP_CODE:" | cut -d: -f2)
            local response_body=$(echo "$alpine_response" | sed '/HTTP_CODE:/d')
            local alpine_id=$(echo "$response_body" | jq -r '.id' 2>/dev/null)

            if [ -n "$alpine_id" ] && [ "$alpine_id" != "null" ]; then
                # Link to workspace
                local link_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X POST "$TOPOMOJO_API_URL/api/template" \
                    -H "Authorization: Bearer $token" \
                    -H "Content-Type: application/json" \
                    -d "{\"templateId\": \"$alpine_id\", \"workspaceId\": \"$workspace_id\"}" 2>&1)

                local link_http_code=$(echo "$link_response" | grep "HTTP_CODE:" | cut -d: -f2)
                local link_body=$(echo "$link_response" | sed '/HTTP_CODE:/d')
                local link_id=$(echo "$link_body" | jq -r '.id' 2>/dev/null)

                if [ -n "$link_id" ] && [ "$link_id" != "null" ]; then
                    log_success "Workspace template created and linked: alpine-workspace ($link_id)"
                else
                    log_warning "Template created ($alpine_id) but link failed (HTTP $link_http_code): $(echo "$link_body" | jq -r '.message // .' 2>/dev/null)"
                fi
            else
                local error_detail=$(echo "$response_body" | jq -r '.message // .title // .detail // empty' 2>/dev/null)
                if [ -z "$error_detail" ]; then
                    error_detail="${response_body:0:500}"
                fi
                log_warning "Failed to create Alpine workspace template (HTTP $http_code): $error_detail"
            fi
    else
        # TinyCore template (default)
        log_info "Creating TinyCore workspace template..."
            local tinycore_detail=$(jq -n \
                --arg template "TinyCore-ISO" \
                --arg iso "local:iso/TinyCore-current.iso" \
                '{
                    template: $template,
                    iso: $iso,
                    ram: 1,
                    cpu: "1x1",
                    eth: [{net: "lan"}],
                    disks: []
                }')

            local tinycore_response=$(curl -k -s -X POST "$TOPOMOJO_API_URL/api/template-detail" \
                -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json" \
                -d "{
                    \"name\": \"tinycore-workspace\",
                    \"description\": \"Workspace-specific TinyCore (not linked)\",
                    \"networks\": \"lan\",
                    \"detail\": $(echo "$tinycore_detail" | jq -Rs .),
                    \"isPublished\": false
                }" 2>/dev/null)

            local tinycore_id=$(echo "$tinycore_response" | jq -r '.id' 2>/dev/null)
            if [ -n "$tinycore_id" ] && [ "$tinycore_id" != "null" ]; then
                # Link to workspace
                local link_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X POST "$TOPOMOJO_API_URL/api/template" \
                    -H "Authorization: Bearer $token" \
                    -H "Content-Type: application/json" \
                    -d "{\"templateId\": \"$tinycore_id\", \"workspaceId\": \"$workspace_id\"}" 2>&1)

                local link_http_code=$(echo "$link_response" | grep "HTTP_CODE:" | cut -d: -f2)
                local link_body=$(echo "$link_response" | sed '/HTTP_CODE:/d')
                local link_id=$(echo "$link_body" | jq -r '.id' 2>/dev/null)

                if [ -n "$link_id" ] && [ "$link_id" != "null" ]; then
                    log_success "Workspace template created and linked: tinycore-workspace ($link_id)"
                else
                    log_warning "Template created ($tinycore_id) but link failed (HTTP $link_http_code): $(echo "$link_body" | jq -r '.message // .' 2>/dev/null)"
                fi
            else
                log_warning "Failed to create TinyCore workspace template: $(echo "$tinycore_response" | jq -r '.message // .title // "Unknown error"' 2>/dev/null)"
            fi
    fi

    log_success "TopoMojo templates configured for workspace"
}

# ============================================================
# CASTER FUNCTIONS
# ============================================================
# ============================================================
# CASTER FUNCTIONS
# ============================================================

create_caster_project() {
    local project_name="$1"
    local project_id="$2"
    local directory_id="$3"
    local main_tf_id="$4"
    local variables_tf_id="$5"
    local tfvars_id="$6"

    log_step "Creating Caster project: $project_name"

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[caster]}")

    # Check if project exists
    local existing_projects=$(curl -k -s -X GET "$CASTER_API_URL/projects" \
        -H "Authorization: Bearer $token" 2>/dev/null)
    local existing_id=$(echo "$existing_projects" | jq -r ".[] | select(.name == \"$project_name\") | .id" | head -1)

    if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
        log_success "Caster project already exists: $existing_id"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create Caster project: $project_name"
        return 0
    fi

    # Create project
    local project_response=$(curl -k -s -X POST "$CASTER_API_URL/projects" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$project_id\",
            \"name\": \"$project_name\",
            \"description\": \"Test project for Proxmox VMs\"
        }" 2>/dev/null)

    if ! echo "$project_response" | jq -e '.id' > /dev/null 2>&1; then
        log_error "Failed to create Caster project"
        return 1
    fi

    log_success "Caster project created: $project_id"

    # Create directory
    local directory_response=$(curl -k -s -X POST "$CASTER_API_URL/directories" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$directory_id\",
            \"projectId\": \"$project_id\",
            \"name\": \"Basic Topology\",
            \"terraformVersion\": \"1.5.0\"
        }" 2>/dev/null)

    if ! echo "$directory_response" | jq -e '.id' > /dev/null 2>&1; then
        log_warning "Failed to create directory"
        return 1
    fi

    log_success "Directory created: $directory_id"

    # Create main.tf
    local main_tf_content='terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.106.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

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
    vm_id = 106
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }
}

resource "proxmox_virtual_environment_vm" "puppy" {
  name      = "puppy-caster-test"
  node_name = "pve"

  clone {
    vm_id = 103
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024
  }
}'

    curl -k -s -X POST "$CASTER_API_URL/files" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$main_tf_id\",
            \"directoryId\": \"$directory_id\",
            \"name\": \"main.tf\",
            \"content\": $(echo "$main_tf_content" | jq -Rs .)
        }" > /dev/null 2>&1

    log_success "Created main.tf"

    # Create variables.tf
    local variables_tf_content='variable "proxmox_endpoint" {
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
}'

    curl -k -s -X POST "$CASTER_API_URL/files" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$variables_tf_id\",
            \"directoryId\": \"$directory_id\",
            \"name\": \"variables.tf\",
            \"content\": $(echo "$variables_tf_content" | jq -Rs .)
        }" > /dev/null 2>&1

    log_success "Created variables.tf"

    # Create terraform.tfvars
    local tfvars_content="proxmox_endpoint = \"https://${PROXMOX_HOST}:8006\"
proxmox_api_token = \"${PROXMOX_API_TOKEN}\"
proxmox_insecure = true"

    curl -k -s -X POST "$CASTER_API_URL/files" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$tfvars_id\",
            \"directoryId\": \"$directory_id\",
            \"name\": \"terraform.tfvars\",
            \"content\": $(echo "$tfvars_content" | jq -Rs .)
        }" > /dev/null 2>&1

    log_success "Created terraform.tfvars"

    return 0
}

create_caster_project1() {
    create_caster_project \
        "Proxmox Test" \
        "${RESOURCE_IDS[caster_project1]}" \
        "${RESOURCE_IDS[caster_project1_dir]}" \
        "${RESOURCE_IDS[caster_project1_main_tf]}" \
        "${RESOURCE_IDS[caster_project1_variables_tf]}" \
        "${RESOURCE_IDS[caster_project1_tfvars]}"
}

create_caster_project2() {
    create_caster_project \
        "Proxmox Test with Alloy" \
        "${RESOURCE_IDS[caster_project2]}" \
        "${RESOURCE_IDS[caster_project2_dir]}" \
        "${RESOURCE_IDS[caster_project2_main_tf]}" \
        "${RESOURCE_IDS[caster_project2_variables_tf]}" \
        "${RESOURCE_IDS[caster_project2_tfvars]}"
}

# ============================================================
# PLAYER FUNCTIONS
# ============================================================

create_player_view_template() {
    local view_name="Proxmox On-Demand Template"
    local view_id="${RESOURCE_IDS[player_view_template]}"

    log_step "Creating Player view template: $view_name"

    # Check if exists
    local existing_id=$(resource_exists "player-view" "$view_name")
    if [ -n "$existing_id" ]; then
        log_success "Player view template already exists: $existing_id"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create Player view template"
        return 0
    fi

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[player]}")

    # Create view
    local view_response=$(curl -k -s -X POST "$PLAYER_API_URL/views" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$view_id\",
            \"name\": \"$view_name\",
            \"description\": \"Template view with VMs and Dashboard\",
            \"status\": \"Active\",
            \"createAdminTeam\": true
        }" 2>/dev/null)

    if echo "$view_response" | jq -e '.id' > /dev/null 2>&1; then
        log_success "Player view template created: $view_id"

        # Get Admin team ID
        local teams=$(curl -k -s -X GET "$PLAYER_API_URL/views/$view_id/teams" \
            -H "Authorization: Bearer $token" 2>/dev/null)
        local admin_team_id=$(echo "$teams" | jq -r '.[] | select(.name == "Admin") | .id' | head -1)

        # Add VM application
        local vm_app_id="${RESOURCE_IDS[vm_app_template]}"
        curl -k -s -X POST "$PLAYER_API_URL/views/$view_id/applications" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"$vm_app_id\",
                \"viewId\": \"$view_id\",
                \"applicationTemplateId\": \"ace19f19-8916-4169-84de-ad00565d8456\"
            }" > /dev/null 2>&1

        # Add Dashboard application
        local dash_app_id="${RESOURCE_IDS[dashboard_app_template]}"
        curl -k -s -X POST "$PLAYER_API_URL/views/$view_id/applications" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"$dash_app_id\",
                \"viewId\": \"$view_id\",
                \"applicationTemplateId\": \"a4c361cc-b43f-4c44-99a7-7e2e2b3a9f88\"
            }" > /dev/null 2>&1

        # Mark as template
        curl -k -s -X PUT "$PLAYER_API_URL/views/$view_id" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"$view_id\",
                \"name\": \"$view_name\",
                \"description\": \"Template view with VMs and Dashboard\",
                \"status\": \"Active\",
                \"isTemplate\": true,
                \"defaultTeamId\": \"$admin_team_id\"
            }" > /dev/null 2>&1

        log_success "Applications added to view template"
        return 0
    else
        log_error "Failed to create Player view template"
        return 1
    fi
}

create_player_view_live() {
    local view_name="Proxmox Demo"
    local view_id="${RESOURCE_IDS[player_view_live]}"

    log_step "Creating live Player view: $view_name"

    # Check if exists
    local existing_id=$(resource_exists "player-view" "$view_name")
    if [ -n "$existing_id" ]; then
        log_success "Player view already exists: $existing_id"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create live Player view"
        return 0
    fi

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[player]}")

    # Create view
    local view_response=$(curl -k -s -X POST "$PLAYER_API_URL/views" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$view_id\",
            \"name\": \"$view_name\",
            \"description\": \"Live view with running Proxmox VMs\",
            \"status\": \"Active\"
        }" 2>/dev/null)

    if echo "$view_response" | jq -e '.id' > /dev/null 2>&1; then
        log_success "Live Player view created: $view_id"

        # Get Admin team ID
        local teams=$(curl -k -s -X GET "$PLAYER_API_URL/views/$view_id/teams" \
            -H "Authorization: Bearer $token" 2>/dev/null)
        local admin_team_id=$(echo "$teams" | jq -r '.[] | select(.name == "Admin") | .id' | head -1)

        # Register VMs
        register_player_vms "$admin_team_id" "$token"

        log_success "VMs registered to live view"
        return 0
    else
        log_error "Failed to create live Player view"
        return 1
    fi
}

register_player_vms() {
    local admin_team_id="$1"
    local token="$2"

    log_step "Registering VMs in Player VM API..."

    # Register Puppy VM
    curl -k -s -X POST "$VM_API_URL/vms" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"${RESOURCE_IDS[puppy_vm]}\",
            \"name\": \"puppy-test\",
            \"teamIds\": [\"$admin_team_id\"],
            \"proxmoxVmInfo\": {
                \"id\": $PUPPY_PROXMOX_ID,
                \"node\": \"$PROXMOX_NODE\"
            }
        }" > /dev/null 2>&1

    # Register Alpine VM
    curl -k -s -X POST "$VM_API_URL/vms" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"${RESOURCE_IDS[alpine_vm]}\",
            \"name\": \"alpine-linux-template\",
            \"teamIds\": [\"$admin_team_id\"],
            \"proxmoxVmInfo\": {
                \"id\": $ALPINE_PROXMOX_ID,
                \"node\": \"$PROXMOX_NODE\"
            }
        }" > /dev/null 2>&1

    # Register TinyCore VM
    curl -k -s -X POST "$VM_API_URL/vms" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"${RESOURCE_IDS[tinycore_vm]}\",
            \"name\": \"tinycore-linux-template\",
            \"teamIds\": [\"$admin_team_id\"],
            \"proxmoxVmInfo\": {
                \"id\": $TINYCORE_PROXMOX_ID,
                \"node\": \"$PROXMOX_NODE\"
            }
        }" > /dev/null 2>&1

    log_success "3 VMs registered"
}

# ============================================================
# ALLOY FUNCTIONS
# ============================================================

create_alloy_event_no_caster() {
    local event_name="Alloy Event (No Caster)"
    local event_id="${RESOURCE_IDS[alloy_event_no_caster]}"
    local player_view_id="${RESOURCE_IDS[player_view_template]}"

    log_step "Creating Alloy event (view only): $event_name"

    # Check if exists
    local existing_id=$(resource_exists "alloy-event" "$event_name")
    if [ -n "$existing_id" ]; then
        log_success "Alloy event already exists: $existing_id"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create Alloy event (no Caster)"
        return 0
    fi

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[alloy]}")

    local event_response=$(curl -k -s -X POST "$ALLOY_API_URL/eventtemplates" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$event_id\",
            \"name\": \"$event_name\",
            \"description\": \"Simple event template with Player view only\",
            \"viewId\": \"$player_view_id\",
            \"durationHours\": 4,
            \"useDynamicHost\": false,
            \"isPublished\": true
        }" 2>/dev/null)

    if echo "$event_response" | jq -e '.id' > /dev/null 2>&1; then
        log_success "Alloy event created (no Caster): $event_id"
        return 0
    else
        log_error "Failed to create Alloy event"
        return 1
    fi
}

create_alloy_event_with_caster() {
    local event_name="Proxmox Test Event"
    local event_id="${RESOURCE_IDS[alloy_event_with_caster]}"
    local player_view_id="${RESOURCE_IDS[player_view_template]}"
    local caster_dir_id="${RESOURCE_IDS[caster_project2_dir]}"

    log_step "Creating Alloy event (with Caster): $event_name"

    # Check if exists
    local existing_id=$(resource_exists "alloy-event" "$event_name")
    if [ -n "$existing_id" ]; then
        log_success "Alloy event already exists: $existing_id"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would create Alloy event (with Caster)"
        return 0
    fi

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[alloy]}")

    local event_response=$(curl -k -s -X POST "$ALLOY_API_URL/eventtemplates" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$event_id\",
            \"name\": \"$event_name\",
            \"description\": \"Event template linking Caster directory and Player view\",
            \"directoryId\": \"$caster_dir_id\",
            \"viewId\": \"$player_view_id\",
            \"durationHours\": 4,
            \"useDynamicHost\": false,
            \"isPublished\": true
        }" 2>/dev/null)

    if echo "$event_response" | jq -e '.id' > /dev/null 2>&1; then
        log_success "Alloy event created (with Caster): $event_id"
        return 0
    else
        log_error "Failed to create Alloy event with Caster"
        return 1
    fi
}

# ============================================================
# CLEANUP FUNCTIONS (API-ONLY)
# ============================================================

cleanup_player_resources() {
    log_step "Cleaning Player resources..."

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[player]}")
    if [ -z "$token" ]; then
        log_error "Failed to get Player token"
        return 1
    fi

    # Get all views matching pattern
    local all_views=$(curl -k -s -X GET "$PLAYER_API_URL/views" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")

    local view_ids=$(echo "$all_views" | jq -r '.[] | select(.name | startswith("Proxmox")) | .id')

    local count=0
    for view_id in $view_ids; do
        if [ -n "$view_id" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would delete Player view: $view_id"
            else
                curl -k -s -X DELETE "$PLAYER_API_URL/views/$view_id" \
                    -H "Authorization: Bearer $token" > /dev/null
            fi
            count=$((count + 1))
        fi
    done

    # Get all VMs matching pattern
    local all_vms=$(curl -k -s -X GET "$VM_API_URL/vms" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")

    local vm_ids=$(echo "$all_vms" | jq -r '.[] | select(.name | test("puppy|alpine|tinycore")) | .id')

    for vm_id in $vm_ids; do
        if [ -n "$vm_id" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would delete Player VM: $vm_id"
            else
                curl -k -s -X DELETE "$VM_API_URL/vms/$vm_id" \
                    -H "Authorization: Bearer $token" > /dev/null
            fi
            count=$((count + 1))
        fi
    done

    log_success "Cleaned $count Player resources"
}

cleanup_caster_resources() {
    log_step "Cleaning Caster resources..."

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[caster]}")
    if [ -z "$token" ]; then
        log_error "Failed to get Caster token"
        return 1
    fi

    local all_projects=$(curl -k -s -X GET "$CASTER_API_URL/projects" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")

    local project_ids=$(echo "$all_projects" | jq -r '.[] | select(.name | startswith("Proxmox Test")) | .id')

    local count=0
    for project_id in $project_ids; do
        if [ -n "$project_id" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would delete Caster project: $project_id"
            else
                curl -k -s -X DELETE "$CASTER_API_URL/projects/$project_id" \
                    -H "Authorization: Bearer $token" > /dev/null
            fi
            count=$((count + 1))
        fi
    done

    log_success "Cleaned $count Caster resources"
}

cleanup_alloy_resources() {
    log_step "Cleaning Alloy resources..."

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[alloy]}")
    if [ -z "$token" ]; then
        log_error "Failed to get Alloy token"
        return 1
    fi

    local all_templates=$(curl -k -s -X GET "$ALLOY_API_URL/eventtemplates" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")

    local template_ids=$(echo "$all_templates" | jq -r '.[] | select(.name | test("Proxmox Test Event|Alloy Event")) | .id')

    local count=0
    for template_id in $template_ids; do
        if [ -n "$template_id" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would delete Alloy event: $template_id"
            else
                curl -k -s -X DELETE "$ALLOY_API_URL/eventtemplates/$template_id" \
                    -H "Authorization: Bearer $token" > /dev/null
            fi
            count=$((count + 1))
        fi
    done

    log_success "Cleaned $count Alloy resources"
}

cleanup_topomojo_resources() {
    log_step "Cleaning TopoMojo resources..."

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[topomojo]}")
    if [ -z "$token" ]; then
        log_error "Failed to get TopoMojo token"
        return 1
    fi

    # Delete all workspaces
    local all_workspaces=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/workspaces" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")

    local workspace_ids=$(echo "$all_workspaces" | jq -r '.[] | select(.name | test("Test Workspace|Moodle Test")) | .id')

    local count=0
    for workspace_id in $workspace_ids; do
        if [ -n "$workspace_id" ]; then
            curl -k -s -X DELETE "$TOPOMOJO_API_URL/api/workspace/$workspace_id" \
                -H "Authorization: Bearer $token" > /dev/null 2>&1
            count=$((count + 1))
        fi
    done

    log_info "Deleted $count workspaces"

    # Clean all templates (global and workspace-specific)
    local all_templates=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/templates" \
        -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")

    # Show what templates exist
    local all_template_names=$(echo "$all_templates" | jq -r '.[].name' 2>/dev/null)
    if [ -n "$all_template_names" ]; then
        log_info "Found templates: $(echo "$all_template_names" | tr '\n' ', ' | sed 's/,$//')"
    fi

    local template_ids=$(echo "$all_templates" | jq -r '.[] | select(.name | test("tinycore|alpine|puppy"; "i")) | .id')

    local template_count=0
    for template_id in $template_ids; do
        if [ -n "$template_id" ]; then
            local del_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -X DELETE "$TOPOMOJO_API_URL/api/template/$template_id" \
                -H "Authorization: Bearer $token" 2>&1)
            local del_code=$(echo "$del_response" | grep "HTTP_CODE:" | cut -d: -f2)

            if [ "$del_code" = "204" ] || [ "$del_code" = "200" ]; then
                template_count=$((template_count + 1))
            else
                log_warning "Failed to delete template $template_id (HTTP $del_code)"
            fi
        fi
    done

    log_success "Cleaned $count workspaces and $template_count templates"
}

cleanup_all() {
    print_section "Cleaning All Resources"

    cleanup_alloy_resources || log_warning "Alloy cleanup had errors"
    cleanup_player_resources || log_warning "Player cleanup had errors"
    cleanup_caster_resources || log_warning "Caster cleanup had errors"
    cleanup_topomojo_resources || log_warning "TopoMojo cleanup had errors"

    log_success "All resources cleaned"
}

cleanup_proxmox_vms() {
    print_section "Cleaning Proxmox VMs and Templates"

    if [ -z "$PROXMOX_HOST" ]; then
        log_error "PROXMOX_HOST not set"
        return 1
    fi

    log_step "Stopping and removing all non-template VMs..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << 'CLEANVMS'
set -e

# Stop all running VMs (except those marked as templates)
for vmid in $(qm list | grep running | awk '{print $1}'); do
    echo "Stopping VM $vmid..."
    qm stop $vmid || true
done

# Delete all VMs (except templates)
for vmid in $(qm list | tail -n +2 | awk '{print $1}'); do
    # Check if it's a template
    is_template=$(qm config $vmid | grep -c "^template: 1" || echo "0")
    if [ "$is_template" = "0" ]; then
        echo "Deleting VM $vmid..."
        qm destroy $vmid || true
    else
        echo "Skipping template VM $vmid"
    fi
done
CLEANVMS

    log_step "Removing test VM templates (105, 106, 9001, 9002, 9003)..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << 'CLEANTEMPLATES'
set -e

for vmid in 105 106 9001 9002 9003; do
    if qm status $vmid >/dev/null 2>&1; then
        echo "Removing template VM $vmid..."
        qm destroy $vmid || true
    fi
done
CLEANTEMPLATES

    log_success "Proxmox VMs and templates cleaned"
}

# ============================================================
# PHASE ORCHESTRATION
# ============================================================

phase1_proxmox_infrastructure() {

    print_section "Phase 1/7: Proxmox Infrastructure Setup"

    setup_proxmox_ssh || return 1
    setup_proxmox_nginx || return 1
    setup_proxmox_token || return 1
    setup_proxmox_nfs || return 1
    setup_proxmox_oidc || log_warning "OIDC configuration skipped (see warnings above)"
    toggle_topomojo_hypervisor || return 1

    log_success "Proxmox infrastructure configured"
}

phase2_vm_templates() {

    print_section "Phase 2/7: VM Template Creation"

    create_alpine_template || log_warning "Alpine template creation failed"
    create_tinycore_template || log_warning "TinyCore template creation failed"
    create_puppy_vm || log_warning "Puppy VM creation failed"

    log_success "VM templates created"
}

phase3_wait_aspire() {
    print_section "Phase 3/7: Aspire Service Health Check"

    wait_for_aspire_services || {
        log_error "Services not ready. Ensure Aspire is running: aspire run"
        return 1
    }
}

phase4_topomojo_workspaces() {

    print_section "Phase 4/7: TopoMojo Workspaces"

    create_topomojo_workspace_basic || log_warning "TopoMojo basic workspace creation failed"
    create_topomojo_workspace_with_variants || log_warning "TopoMojo workspace with variants creation failed"

    log_success "TopoMojo workspaces created"
}

phase5_caster_projects() {

    print_section "Phase 5/7: Caster Projects"

    create_caster_project1 || log_warning "Caster project 1 creation failed"
    create_caster_project2 || log_warning "Caster project 2 creation failed"

    log_success "Caster projects created"
}

phase6_player_views() {

    print_section "Phase 6/7: Player Views"

    create_player_view_template || log_warning "Player view template creation failed"
    create_player_view_live || log_warning "Player live view creation failed"

    log_success "Player views created"
}

phase7_alloy_events() {

    print_section "Phase 7/7: Alloy Events"

    create_alloy_event_no_caster || log_warning "Alloy event (no Caster) creation failed"
    create_alloy_event_with_caster || log_warning "Alloy event (with Caster) creation failed"

    log_success "Alloy events created"
}

# ============================================================
# MODE HANDLERS
# ============================================================

mode_setup() {
    print_header "Crucible Proxmox Environment Setup"

    # Load config early to preserve token
    load_config || true

    # Validate PROXMOX_HOST
    if [ -z "$PROXMOX_HOST" ]; then
        log_error "PROXMOX_HOST environment variable not set"
        echo ""
        echo "Usage:"
        echo "  export PROXMOX_HOST='<proxmox-ip>'"
        echo "  $0 setup"
        exit 1
    fi

    log_info "Configuration:"
    echo "  Proxmox Host: $PROXMOX_HOST"
    echo "  Mode: setup"
    echo "  Dry Run: $DRY_RUN"
    echo ""

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    # Run all phases
    phase1_proxmox_infrastructure || exit 1
    phase2_vm_templates || true  # Non-fatal
    phase3_wait_aspire || exit 1
    phase4_topomojo_workspaces || true
    phase5_caster_projects || true
    phase6_player_views || true
    phase7_alloy_events || true

    # Save config
    save_config

    print_header "Setup Complete!"

    log_success "Environment ready for Moodle plugin testing"
    echo ""

    # Count resources
    echo -e "${CYAN}Resources Created:${NC}"

    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[player]}" 2>/dev/null)
    if [ -n "$token" ]; then
        local views=$(curl -k -s -X GET "$PLAYER_API_URL/views" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local view_count=$(echo "$views" | jq -r '.[] | select(.name | startswith("Proxmox")) | .id' | wc -l)
        echo "  Player Views: $view_count"
    fi

    token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[caster]}" 2>/dev/null)
    if [ -n "$token" ]; then
        local projects=$(curl -k -s -X GET "$CASTER_API_URL/projects" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local project_count=$(echo "$projects" | jq -r '.[] | select(.name | startswith("Proxmox Test")) | .id' | wc -l)
        echo "  Caster Projects: $project_count"
    fi

    token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[alloy]}" 2>/dev/null)
    if [ -n "$token" ]; then
        local events=$(curl -k -s -X GET "$ALLOY_API_URL/eventtemplates" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local event_count=$(echo "$events" | jq -r '.[] | select(.name | test("Proxmox|Alloy Event")) | .id' | wc -l)
        echo "  Alloy Events: $event_count"
    fi

    token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[topomojo]}" 2>/dev/null)
    if [ -n "$token" ]; then
        local workspaces=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/workspaces" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local workspace_count=$(echo "$workspaces" | jq -r '.[] | select(.name | test("Test Workspace|Moodle Test")) | .id' | wc -l)
        echo "  TopoMojo Workspaces: $workspace_count"

        local templates=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/templates" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local template_count=$(echo "$templates" | jq -r '.[] | select(.name | test("tinycore-workspace|alpine-workspace|TinyCore-ISO-Stock|Alpine-Disk-Stock|Puppy-Linux"; "i")) | .id' | wc -l)
        echo "  TopoMojo Templates: $template_count"
    fi

    # Count Proxmox VMs
    local vm_list=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" "qm list 2>/dev/null | tail -n +2" 2>/dev/null || echo "")
    local vm_count=$(echo "$vm_list" | wc -l)
    if [ -n "$vm_list" ] && [ "$vm_count" -gt 0 ]; then
        echo "  Proxmox VMs: $vm_count"
    fi

    echo ""
    echo "Access URLs:"
    echo "  • Player UI: http://localhost:4303/views/${RESOURCE_IDS[player_view_template]}"
    echo "  • Alloy UI: http://localhost:4403/templates/${RESOURCE_IDS[alloy_event_with_caster]}"
    echo "  • Caster UI: http://localhost:4310/projects/${RESOURCE_IDS[caster_project1]}"
    echo "  • TopoMojo UI: http://localhost:4201"
    echo ""

    # Configure AppHost to use Proxmox
    local toggle_script="$(dirname "$0")/toggle-topomojo-hypervisor.sh"
    if [ -f "$toggle_script" ]; then
        log_info "Configuring AppHost to use Proxmox..."

        # Load config to get PROXMOX_API_TOKEN if not already set
        if [ -z "$PROXMOX_API_TOKEN" ]; then
            load_config || true
        fi

        if [ -n "$PROXMOX_API_TOKEN" ]; then
            bash "$toggle_script" proxmox --non-interactive
        else
            log_warning "PROXMOX_API_TOKEN not set - AppHost configuration skipped"
            log_warning "Run manually: ./scripts/toggle-topomojo-hypervisor.sh proxmox"
        fi
    else
        log_warning "toggle-topomojo-hypervisor.sh not found - AppHost configuration skipped"
    fi
    echo ""
}

mode_reset() {
    print_header "Crucible Proxmox Environment Reset"

    log_warning "This will delete all resources and recreate them"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Reset cancelled"
        exit 0
    fi

    # Clean then setup
    mode_clean
    mode_setup
}

mode_clean() {
    print_header "Crucible Proxmox Environment Cleanup"

    log_warning "This will delete all Proxmox test resources via APIs (keeps Proxmox VMs)"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi

    cleanup_all

    print_header "Cleanup Complete!"
}

mode_cleanall() {
    print_header "Crucible Proxmox Complete Cleanup"

    log_warning "This will delete ALL resources including Proxmox VMs and templates"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi

    # Load config to get PROXMOX_HOST
    load_config || true

    if [ -z "$PROXMOX_HOST" ]; then
        log_error "PROXMOX_HOST not set. Cannot clean Proxmox VMs."
        exit 1
    fi

    cleanup_all
    cleanup_proxmox_vms

    print_header "Complete Cleanup Done!"
}

mode_status() {
    print_header "Crucible Proxmox Environment Status"

    # Load config
    if ! load_config; then
        log_warning "No saved configuration found"
    fi

    if [ -z "$PROXMOX_HOST" ]; then
        log_error "PROXMOX_HOST not set. Run 'setup' first or export PROXMOX_HOST."
        exit 1
    fi

    echo -e "${CYAN}Proxmox Infrastructure:${NC}"
    echo -n "  Host: $PROXMOX_HOST "
    if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
        log_success "(reachable)"

        # Count VMs on Proxmox
        local vm_list=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" "qm list 2>/dev/null | tail -n +2" 2>/dev/null || echo "")
        local vm_count=$(echo "$vm_list" | wc -l)
        if [ -n "$vm_list" ] && [ "$vm_count" -gt 0 ]; then
            echo "  Proxmox VMs: $vm_count"
            # Show our test VMs specifically
            local test_vms=$(echo "$vm_list" | grep -E "103|105|106" | awk '{print "    VM " $1 ": " $2 " (" $3 ")"}')
            if [ -n "$test_vms" ]; then
                echo "$test_vms"
            fi
        fi
    else
        log_error "(unreachable)"
    fi

    echo ""
    echo -e "${CYAN}Aspire Services:${NC}"

    echo -n "  Player API: "
    if check_service_health "Player" "$PLAYER_API_URL" "/player/ping"; then
        log_success "Healthy"
    else
        log_error "Unavailable"
    fi

    echo -n "  Caster API: "
    if check_service_health "Caster" "$CASTER_API_URL" "/ping"; then
        log_success "Healthy"
    else
        log_error "Unavailable"
    fi

    echo -n "  Alloy API: "
    if check_service_health "Alloy" "$ALLOY_API_URL" "/ping"; then
        log_success "Healthy"
    else
        log_error "Unavailable"
    fi

    echo -n "  TopoMojo API: "
    if check_service_health "TopoMojo" "$TOPOMOJO_API_URL" "/api/doc"; then
        log_success "Healthy"
    else
        log_error "Unavailable"
    fi

    echo ""
    echo -e "${CYAN}Resources:${NC}"

    # Count Player views
    local token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[player]}" 2>/dev/null || echo "")
    if [ -n "$token" ]; then
        local views=$(curl -k -s -X GET "$PLAYER_API_URL/views" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local view_count=$(echo "$views" | jq -r '.[] | select(.name | startswith("Proxmox")) | .id' | wc -l)
        echo "  Player Views: $view_count"
    fi

    # Count Caster projects
    token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[caster]}" 2>/dev/null || echo "")
    if [ -n "$token" ]; then
        local projects=$(curl -k -s -X GET "$CASTER_API_URL/projects" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local project_count=$(echo "$projects" | jq -r '.[] | select(.name | startswith("Proxmox Test")) | .id' | wc -l)
        echo "  Caster Projects: $project_count"
    fi

    # Count Alloy events
    token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[alloy]}" 2>/dev/null || echo "")
    if [ -n "$token" ]; then
        local events=$(curl -k -s -X GET "$ALLOY_API_URL/eventtemplates" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local event_count=$(echo "$events" | jq -r '.[] | select(.name | test("Proxmox|Alloy Event")) | .id' | wc -l)
        echo "  Alloy Events: $event_count"
    fi

    # Count TopoMojo workspaces
    token=$(get_keycloak_token "${KEYCLOAK_CLIENTS[topomojo]}" 2>/dev/null || echo "")
    if [ -n "$token" ]; then
        local workspaces=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/workspaces" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local workspace_count=$(echo "$workspaces" | jq -r '.[] | select(.name | test("Test Workspace|Moodle Test")) | .id' | wc -l)
        echo "  TopoMojo Workspaces: $workspace_count"

        # Count templates
        local templates=$(curl -k -s -X GET "$TOPOMOJO_API_URL/api/templates" -H "Authorization: Bearer $token" 2>/dev/null || echo "[]")
        local template_count=$(echo "$templates" | jq -r '.[] | select(.name | test("tinycore-workspace|alpine-workspace|TinyCore-ISO-Stock|Alpine-Disk-Stock|Puppy-Linux"; "i")) | .id' | wc -l)
        echo "  TopoMojo Templates: $template_count"
    fi

    echo ""
}

mode_fix() {
    print_header "Crucible Proxmox Environment Repair"

    # TODO: Implement fix mode
    log_info "Fix mode not yet implemented"
}

show_usage() {
    cat << EOF
Crucible Proxmox Environment Manager v${VERSION}

Usage: $0 <command> [options]

Commands:
  setup     - Create complete Proxmox test environment
  reset     - Clean all resources and recreate
  clean     - Remove TopoMojo/Player/Caster/Alloy resources (keeps Proxmox VMs)
  cleanall  - Remove ALL resources including Proxmox VMs and templates
  status    - Show current environment state
  fix       - Repair broken state
  help      - Show this help message

Environment Variables:
  PROXMOX_HOST          - Proxmox IP/hostname (required)

Examples:
  # Full setup
  export PROXMOX_HOST='192.168.1.100'
  $0 setup

  # Check current status
  $0 status

  # Reset environment (clean + setup)
  $0 reset

  # Clean all resources
  $0 clean
EOF
}

parse_args() {
    # First argument is the command, skip it
    local cmd="$1"
    shift

    # Parse remaining arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--proxmox-host)
                PROXMOX_HOST="$2"
                shift 2
                ;;
            --keycloak-url)
                KEYCLOAK_URL="$2"
                shift 2
                ;;
            --keycloak-user)
                KEYCLOAK_USER="$2"
                shift 2
                ;;
            --keycloak-password)
                KEYCLOAK_PASSWORD="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Fall back to environment variables if not set via command line
    if [ -z "$PROXMOX_HOST" ]; then
        PROXMOX_HOST="${PROXMOX_HOST:-}"
    fi

    # Check for config file if still no PROXMOX_HOST
    if [ -z "$PROXMOX_HOST" ] && [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# ============================================================
# MAIN ENTRY POINT
# ============================================================

main() {
    # Check for command
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi

    local command="$1"

    # Parse command-line arguments
    parse_args "$@"

    # Try to load config if PROXMOX_HOST not set
    if [ "$command" != "help" ] && [ -z "$PROXMOX_HOST" ]; then
        load_config || true
    fi

    # Validate PROXMOX_HOST for commands that need it
    if [ "$command" != "help" ] && [ -z "$PROXMOX_HOST" ]; then
        log_error "PROXMOX_HOST is required. Use -h or --proxmox-host option or run setup first."
        echo ""
        show_usage
        exit 1
    fi

    # Handle commands
    case "$command" in
        setup)
            mode_setup
            ;;
        reset)
            mode_reset
            ;;
        clean)
            mode_clean
            ;;
        cleanall)
            mode_cleanall
            ;;
        status)
            mode_status
            ;;
        fix)
            mode_fix
            ;;
        help|--help|-h)
            show_usage
            ;;
        version|--version|-v)
            echo "Crucible Proxmox Manager v${VERSION}"
            ;;
        *)
            log_error "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main
main "$@"
