#!/bin/bash

# Show git dirty status in zsh prompt
git config devcontainers-theme.show-dirty 1

sudo chown -R $(whoami): /home/vscode/.microsoft
sudo chown -R $(whoami): /mnt/data/

sudo chmod +x .devcontainer/clone-repos.sh
.devcontainer/clone-repos.sh

dotnet tool install -g Aspire.Cli
dotnet dev-certs https --trust
