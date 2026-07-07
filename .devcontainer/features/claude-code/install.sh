#!/usr/bin/env bash
set -euo pipefail

# Install Claude Code
su - "${_REMOTE_USER:-vscode}" -c "curl -fsSL https://claude.ai/install.sh | bash"

# Install opencode (installer adds PATH to .bashrc; add to .zshrc for zsh shells)
su - "${_REMOTE_USER:-vscode}" -c "curl -fsSL https://opencode.ai/install | bash && echo 'export PATH=/home/vscode/.opencode/bin:\$PATH' >> /home/vscode/.zshrc"
