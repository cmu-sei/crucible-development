#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Start or stop the desktop-lite VNC/noVNC services on demand.
# Usage: scripts/desktop.sh start|stop|status

ORIGINAL_INIT="/usr/local/share/desktop-init.sh.original"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

is_running() {
  pgrep -x Xtigervnc > /dev/null 2>&1
}

case "${1:-}" in
  start)
    if is_running; then
      echo -e "${GREEN}Desktop services are already running.${NC}"
      echo "  VNC:   localhost:5901"
      echo "  noVNC: http://localhost:6080"
      exit 0
    fi
    if [ ! -f "$ORIGINAL_INIT" ]; then
      echo -e "${RED}Error: desktop-lite does not appear to be installed.${NC}"
      echo "  Expected: $ORIGINAL_INIT"
      exit 1
    fi
    echo "Starting desktop services (Xvfb, TigerVNC, noVNC, fluxbox)..."
    DISPLAY=:0 nohup bash "$ORIGINAL_INIT" > /tmp/desktop-init.log 2>&1 &
    for i in $(seq 1 15); do
      if is_running; then
        echo -e "${GREEN}Desktop services started.${NC}"
        echo "  VNC:   localhost:5901"
        echo "  noVNC: http://localhost:6080"
        echo "  Password: crucible"
        echo ""
        echo "  View at: http://localhost:6080"
        exit 0
      fi
      sleep 1
    done
    echo -e "${RED}Warning: services may not have started. Check /tmp/desktop-init.log${NC}"
    exit 1
    ;;

  stop)
    if ! is_running; then
      echo "Desktop services are not running."
      exit 0
    fi
    echo "Stopping desktop services..."
    pkill -x Xtigervnc 2>/dev/null
    pkill -f "novnc_proxy\|launch.sh.*novnc" 2>/dev/null
    pkill -x fluxbox 2>/dev/null
    sleep 1
    if is_running; then
      pkill -9 -x Xtigervnc 2>/dev/null
    fi
    echo -e "${GREEN}Desktop services stopped.${NC}"
    ;;

  status)
    if is_running; then
      echo -e "${GREEN}Desktop services are RUNNING.${NC}"
      echo "  VNC:   localhost:5901"
      echo "  noVNC: http://localhost:6080"
    else
      echo "Desktop services are STOPPED."
      echo "  Run 'scripts/desktop.sh start' to launch."
    fi
    ;;

  *)
    echo "Usage: scripts/desktop.sh {start|stop|status}"
    exit 1
    ;;
esac
