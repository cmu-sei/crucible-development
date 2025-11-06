#!/bin/bash

# Show git dirty status in zsh prompt
git config devcontainers-theme.show-dirty 1

sudo chown -R $(whoami): /home/vscode/.microsoft
sudo chown -R $(whoami): /mnt/data/

scripts/clone-repos.sh

dotnet tool install -g Aspire.Cli
dotnet dev-certs https --trust

npm config -g set fund false
npm install -g @angular/cli@latest

# Stage custom CA certs so Minikube trusts them
CUSTOM_CERT_SOURCE="/usr/local/share/ca-certificates/custom"
MINIKUBE_CERT_DEST="${HOME}/.minikube/files/etc/ssl/certs/custom"
if compgen -G "${CUSTOM_CERT_SOURCE}"'/*.crt' > /dev/null; then
  mkdir -p "${MINIKUBE_CERT_DEST}"
  cp "${CUSTOM_CERT_SOURCE}"/*.crt "${MINIKUBE_CERT_DEST}/"
  echo "Copied custom CA certificates to ${MINIKUBE_CERT_DEST}"
else
  echo "No custom CA certificates found in ${CUSTOM_CERT_SOURCE}; skipping copy."
fi
