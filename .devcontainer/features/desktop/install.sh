#!/bin/bash
set -e

ENTRYPOINT="/usr/local/share/desktop-init.sh"

if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "WSL detected -- skipping VNC/desktop-lite install (using native WSLg display)"
  cat > "$ENTRYPOINT" << 'EOF'
#!/bin/bash
exec "$@"
EOF
  chmod +x "$ENTRYPOINT"
  exit 0
fi

echo "Non-WSL platform -- installing desktop-lite for VNC/noVNC support"

export PASSWORD="${PASSWORD:-crucible}"
export WEBPORT="${WEBPORT:-6080}"
export VNCPORT="${VNCPORT:-5901}"
export USERNAME="${_REMOTE_USER:-vscode}"

curl -fsSL https://raw.githubusercontent.com/devcontainers/features/main/src/desktop-lite/install.sh | bash

if [ -f "$ENTRYPOINT" ]; then
  mv "$ENTRYPOINT" "${ENTRYPOINT}.original"
fi

cat > "$ENTRYPOINT" << 'EOF'
#!/bin/bash
exec "$@"
EOF
chmod +x "$ENTRYPOINT"

echo "Desktop-lite installed. Services disabled by default -- use scripts/desktop.sh start"
