#!/bin/bash
# Setup NGINX reverse proxy on Proxmox for API and VNC WebSocket connections
# Based on TopoMojo Proxmox documentation: topomojo/docs/Proxmox.md

set -e

# Configuration
PROXMOX_HOST="${PROXMOX_HOST}"
PROXMOX_USER="${PROXMOX_USER:-root}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/crucible_proxmox}"
PROXMOX_API_TOKEN="${PROXMOX_API_TOKEN}"

echo "Setting up NGINX proxy on Proxmox (TopoMojo pattern)"
echo ""

# Check for required variables
if [ -z "$PROXMOX_HOST" ]; then
  echo "Error: PROXMOX_HOST environment variable not set"
  echo ""
  echo "Export variables:"
  echo "  export PROXMOX_HOST='your-proxmox-ip'"
  echo "  export PROXMOX_API_TOKEN='root@pam!crucible=your-token-here'"
  echo ""
  echo "Then run this script:"
  echo "  ./scripts/setup-proxmox-nginx.sh"
  exit 1
fi

echo "  Host: $PROXMOX_HOST"
echo ""

# Check for API token
if [ -z "$PROXMOX_API_TOKEN" ]; then
  echo "Error: PROXMOX_API_TOKEN environment variable not set"
  echo ""
  echo "IMPORTANT: Use single quotes to prevent bash ! expansion"
  echo ""
  echo "Export variables:"
  echo "  export PROXMOX_HOST='$PROXMOX_HOST'"
  echo "  export PROXMOX_API_TOKEN='root@pam!crucible=your-token-here'"
  echo ""
  echo "Then run this script:"
  echo "  ./scripts/setup-proxmox-nginx.sh"
  exit 1
fi

# Check SSH connectivity
if ! ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
  echo "Error: Cannot connect to Proxmox host via SSH"
  echo "Run setup-proxmox-ssh.sh first"
  exit 1
fi

echo "Installing and configuring NGINX..."

ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" "bash -s" << ENDSSH
set -e

# Install NGINX
if ! command -v nginx &> /dev/null; then
  echo "Installing NGINX..."
  apt-get update
  apt-get install -y nginx
else
  echo "NGINX already installed"
fi

# Enable nginx service
systemctl enable nginx

# Get the hostname for upstream
HOSTNAME=\$(hostname)

# Create NGINX configuration following TopoMojo pattern
# Note: Using quoted 'EOF' to prevent variable expansion, then manually substitute token
cat > /etc/nginx/sites-available/proxmox-reverse-proxy << 'EOF'
# Proxmox Reverse Proxy
# Based on TopoMojo Proxmox documentation
# Provides API and console access on port 443

upstream proxmox {
    server "\$HOSTNAME";
}

server {
    listen 80 default_server;
    rewrite ^(.*) https://\$host\$1 permanent;
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
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass https://localhost:8006;
        proxy_buffering off;
        client_max_body_size 0;
        proxy_connect_timeout 3600s;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
    }

    # All other traffic (Web UI, API)
    location / {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
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

# Replace hostname and token placeholders
sed -i "s/\\\$HOSTNAME/\$HOSTNAME/g" /etc/nginx/sites-available/proxmox-reverse-proxy
sed -i "s|__PROXMOX_TOKEN__|${PROXMOX_API_TOKEN}|g" /etc/nginx/sites-available/proxmox-reverse-proxy

# Remove old config if it exists
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/proxmox-console

# Enable the site
ln -sf /etc/nginx/sites-available/proxmox-reverse-proxy /etc/nginx/sites-enabled/proxmox-reverse-proxy

# Test nginx configuration
nginx -t

# Modify nginx.service to require pve-cluster
if ! grep -q "Requires=pve-cluster.service" /usr/lib/systemd/system/nginx.service; then
  echo "Updating nginx.service dependencies..."

  # Create override directory
  mkdir -p /etc/systemd/system/nginx.service.d

  # Create override file
  cat > /etc/systemd/system/nginx.service.d/pve-cluster.conf << 'OVERRIDE'
[Unit]
Requires=pve-cluster.service
After=pve-cluster.service
OVERRIDE

  # Reload systemd
  systemctl daemon-reload
fi

# Restart nginx
systemctl restart nginx

echo ""
echo "✓ NGINX proxy configured successfully!"
echo ""
echo "NGINX is listening on ports 80 (HTTP) and 443 (HTTPS)"
echo "All Proxmox access now goes through NGINX on port 443"
ENDSSH

echo ""
echo "✓ NGINX proxy setup complete!"
echo ""
echo "Access Proxmox:"
echo "  Web UI: https://$PROXMOX_HOST/ (NGINX proxies to port 8006)"
echo "  API: https://$PROXMOX_HOST/api2/json/..."
echo "  WebSocket: wss://$PROXMOX_HOST/api2/json/nodes/.../vncwebsocket"
echo ""
echo "Update application configurations:"
echo "  - TopoMojo Pod__Url: https://$PROXMOX_HOST"
echo "  - Player VM API: Use port 443 (or omit port for default HTTPS)"
echo ""
echo "Note: Direct access to Proxmox on port 8006 still works for local access"
