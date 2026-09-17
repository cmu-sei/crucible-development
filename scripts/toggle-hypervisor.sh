#!/usr/bin/env bash
# Select a local API profile, or open the guided setup menu.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/api-config.sh"
api_config_main toggle "$@"
