#!/usr/bin/env bash
# Guided setup or manual initialization of local API profiles.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$SCRIPT_DIR/api-config.cjs" configure "$@"
