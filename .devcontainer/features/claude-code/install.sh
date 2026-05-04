#!/usr/bin/env bash
set -euo pipefail

su - "${_REMOTE_USER:-vscode}" -c "curl -fsSL https://claude.ai/install.sh | bash"
