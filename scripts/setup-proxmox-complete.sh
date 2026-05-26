#!/bin/bash
# Complete Proxmox setup for Crucible/TopoMojo
# Combines SSH setup, nginx proxy, API tokens, and TopoMojo configuration

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROXMOX_HOST="${PROXMOX_HOST}"
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_proxmox}"
SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
TOKEN_NAME="${TOKEN_NAME:-CRUCIBLE}"
SETUP_NFS="${SETUP_NFS:-true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPHOST_FILE="$SCRIPT_DIR/../Crucible.AppHost/AppHost.cs"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Proxmox Setup for Crucible/TopoMojo         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check for required variables
if [ -z "$PROXMOX_HOST" ]; then
  echo -e "${RED}Error: PROXMOX_HOST environment variable not set${NC}"
  echo ""
  echo "Export variable:"
  echo "  export PROXMOX_HOST='your-proxmox-ip'"
  echo ""
  echo "Then run this script:"
  echo "  $0"
  exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Host: $PROXMOX_HOST"
echo "  User: $PROXMOX_USER"
echo "  SSH Key: $SSH_KEY_PATH"
echo "  Token Name: $TOKEN_NAME"
echo "  Setup NFS: $SETUP_NFS"
echo ""

# ============================================================
# Step 1: SSH Key Setup
# ============================================================
echo -e "${BLUE}[1/6] Setting up SSH key authentication${NC}"
echo ""

# Create .ssh directory if it doesn't exist
mkdir -p "$(dirname "$SSH_KEY_PATH")"
chmod 700 "$(dirname "$SSH_KEY_PATH")"

# Generate SSH key pair if it doesn't exist
if [[ -f "$SSH_KEY_PATH" ]]; then
  echo "✓ SSH key already exists: $SSH_KEY_PATH"
else
  echo "Generating SSH key pair..."
  ssh-keygen -t "$SSH_KEY_TYPE" -f "$SSH_KEY_PATH" -N "" -C "crucible-dev@proxmox"
  echo "✓ SSH key generated: $SSH_KEY_PATH"
fi

# Check if we can already connect without password
if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
  echo "✓ Passwordless SSH already configured"
else
  echo "Installing SSH key to Proxmox host..."
  echo "You will be prompted for the Proxmox root password"
  echo ""

  if command -v ssh-copy-id &> /dev/null; then
    ssh-copy-id -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST"
  else
    echo -e "${YELLOW}ssh-copy-id not found, manual key installation required${NC}"
    echo "Copy this public key:"
    cat "${SSH_KEY_PATH}.pub"
    echo ""
    echo "Then SSH to Proxmox and add it to ~/.ssh/authorized_keys"
    exit 1
  fi

  # Test connection
  if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
    echo "✓ Passwordless SSH working"
  else
    echo -e "${RED}✗ SSH key installation failed${NC}"
    exit 1
  fi
fi

echo ""

# ============================================================
# Step 2: Install and configure nginx
# ============================================================
echo -e "${BLUE}[2/6] Installing and configuring nginx reverse proxy${NC}"
echo ""

# We'll set the token placeholder for now, update it after token creation
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

# Enable nginx service
systemctl enable nginx

# Get hostname for upstream
HOSTNAME=$(hostname)

# Create nginx configuration (token will be updated later)
cat > /etc/nginx/sites-available/proxmox-reverse-proxy << 'EOF'
# Proxmox Reverse Proxy for TopoMojo
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

    # VNC WebSocket with API token injection
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

    # All other traffic
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

# Replace hostname
sed -i "s/\$HOSTNAME/$HOSTNAME/g" /etc/nginx/sites-available/proxmox-reverse-proxy

# Remove old configs
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/proxmox-console

# Enable the site
ln -sf /etc/nginx/sites-available/proxmox-reverse-proxy /etc/nginx/sites-enabled/proxmox-reverse-proxy

# Create systemd override for pve-cluster dependency
mkdir -p /etc/systemd/system/nginx.service.d
cat > /etc/systemd/system/nginx.service.d/pve-cluster.conf << 'OVERRIDE'
[Unit]
Requires=pve-cluster.service
After=pve-cluster.service
OVERRIDE

# Reload systemd
systemctl daemon-reload

# Test and restart nginx (will work even with placeholder token)
nginx -t
systemctl restart nginx

echo "✓ nginx configured (token placeholder will be updated)"
ENDSSH

echo "✓ nginx reverse proxy installed"
echo ""

# ============================================================
# Step 3: Create API token
# ============================================================
echo -e "${BLUE}[3/6] Creating Proxmox API token${NC}"
echo ""

TOKEN_OUTPUT=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << TOKENEOF
set -e

if pveum user token list root@pam | grep -q "$TOKEN_NAME"; then
    echo "Removing existing token..."
    pveum user token remove root@pam $TOKEN_NAME
fi

echo "Creating API token..."
pveum user token add root@pam $TOKEN_NAME --privsep 0

TOKENEOF
)

echo "$TOKEN_OUTPUT"

# Extract token value
TOKEN_VALUE=$(echo "$TOKEN_OUTPUT" | grep -E "│ value\s+│" | awk -F'│' '{print $3}' | xargs)

if [ -z "$TOKEN_VALUE" ]; then
    echo -e "${RED}Error: Failed to extract token value${NC}"
    exit 1
fi

# Full token format: root@pam!tokenname=value
FULL_TOKEN="root@pam!${TOKEN_NAME}=${TOKEN_VALUE}"

echo ""
echo -e "${GREEN}✓ API token created${NC}"
echo "  Token: $FULL_TOKEN"
echo ""

# ============================================================
# Step 4: Update nginx with real token
# ============================================================
echo -e "${BLUE}[4/6] Updating nginx configuration with API token${NC}"
echo ""

ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" bash << NGINXEOF
set -e

# Update token in nginx config
sed -i "s|__PROXMOX_TOKEN__|$FULL_TOKEN|g" /etc/nginx/sites-available/proxmox-reverse-proxy

# Test and reload nginx
nginx -t
systemctl reload nginx

echo "✓ nginx configuration updated with API token"
NGINXEOF

echo "✓ nginx updated"
echo ""

# ============================================================
# Step 5: Setup NFS (optional)
# ============================================================
if [ "$SETUP_NFS" = "true" ]; then
    echo -e "${BLUE}[5/6] Setting up NFS export for ISO storage${NC}"
    echo ""

    # Get the network that can reach Proxmox (usually Hyper-V network 172.29.x.x)
    # Extract first 3 octets from PROXMOX_HOST and use /16 to allow entire range
    PROXMOX_NETWORK="${PROXMOX_HOST%.*.*}.0.0/16"

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
    echo "/var/lib/vz/template/iso $PROXMOX_NETWORK(rw,sync,no_subtree_check,no_root_squash,insecure)" >> /etc/exports
    echo "✓ Added NFS export"
else
    echo "✓ NFS export already exists"
fi

# Make ISO directory writable by all users (needed for dev container access)
chmod 777 /var/lib/vz/template/iso

# Export filesystems
exportfs -ra

# Enable and restart NFS
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

echo "✓ NFS server configured"
NFSEOF

    echo "✓ NFS export configured"
    echo ""
else
    echo -e "${BLUE}[5/6] Skipping NFS setup (SETUP_NFS=false)${NC}"
    echo ""
fi

# ============================================================
# Step 6: Update TopoMojo AppHost configuration
# ============================================================
echo -e "${BLUE}[6/6] Updating TopoMojo configuration${NC}"
echo ""

# Run the toggle script to set Proxmox config
cd "$SCRIPT_DIR/.."
./scripts/toggle-topomojo-hypervisor.sh proxmox 2>&1 | grep -E "(✓|Configuration|Type:|URL:|ISO API:)" || true

# Save config to file for other scripts to use
PROXMOX_CONFIG_FILE="$HOME/.crucible-proxmox"
cat > "$PROXMOX_CONFIG_FILE" <<CONFIG_EOF
# Crucible Proxmox Configuration
# Auto-generated by setup-proxmox-complete.sh on $(date)
export PROXMOX_HOST=$PROXMOX_HOST
export PROXMOX_API_TOKEN=$FULL_TOKEN
CONFIG_EOF

chmod 600 "$PROXMOX_CONFIG_FILE"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Proxmox Setup Complete!                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  • SSH key: $SSH_KEY_PATH"
echo "  • API token: root@pam!${TOKEN_NAME}=..."
echo "  • Web UI: https://$PROXMOX_HOST/ (nginx on port 443)"
echo "  • TopoMojo configured to use Proxmox"
echo "  • Config saved to: $PROXMOX_CONFIG_FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Restart TopoMojo: aspire run"
echo "  2. Create VM templates on Proxmox"
echo "  3. Test VM creation in TopoMojo"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  • SSH to Proxmox: ssh -i $SSH_KEY_PATH root@$PROXMOX_HOST"
echo "  • Test API: curl -k -H \"Authorization: PVEAPIToken=$FULL_TOKEN\" https://$PROXMOX_HOST/api2/json/version"
echo ""
