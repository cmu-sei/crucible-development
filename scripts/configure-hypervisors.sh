#!/usr/bin/env bash
# Guided setup or manual initialization of local API profiles.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/api-config.sh"
api_config_main configure "$@"
