#!/bin/bash

# Show git dirty status in zsh prompt
git config devcontainers-theme.show-dirty 1

sudo chown -R $(whoami): /home/vscode/.microsoft
sudo chown -R $(whoami): /mnt/data/
sudo chown -R $(whoami): /home/vscode/.claude

scripts/clone-repos.sh
scripts/add-moodle-mounts.sh

dotnet tool install -g Aspire.Cli
# Install dotnet-ef globally
dotnet tool install --global dotnet-ef --version 10
dotnet dev-certs https --trust

# Generate crucible-dev certificates
CERT_DIR=".devcontainer/dev-certs"
CERT_FILE="${CERT_DIR}/crucible-dev.crt"
KEY_FILE="${CERT_DIR}/crucible-dev.key"

echo "Generating crucible-dev certificates..."
mkdir -p "${CERT_DIR}"

# Remove any existing files
if [ -e "${CERT_FILE}" ]; then
  echo "Overwriting existing certificate at ${CERT_FILE}..."
  rm -rf "${CERT_FILE}"
fi

if [ -e "${KEY_FILE}" ]; then
  echo "Overwriting existing key at ${KEY_FILE}..."
  rm -rf "${KEY_FILE}"
fi

# Generate self-signed certificate (valid for 365 days)
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}" \
  -days 365 \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:crucible,DNS:keycloak,DNS:host.docker.internal,DNS:host.minikube.internal" \
  -addext "basicConstraints=critical,CA:TRUE"

# Set appropriate permissions
chmod 644 "${CERT_FILE}"
chmod 600 "${KEY_FILE}"

# Trust the generated certificate
sudo cp "${CERT_FILE}" /usr/local/share/ca-certificates/custom/crucible-dev.crt
sudo update-ca-certificates

echo "Crucible-dev certificates generated and trusted."

npm config -g set fund false
npm install -g @angular/cli@latest

# Stage custom CA certs so Minikube trusts them
CUSTOM_CERT_SOURCE="/usr/local/share/ca-certificates/custom"
MINIKUBE_CERT_DEST="${HOME}/.minikube/files/etc/ssl/certs/custom"
MOODLE_CERT_DEST="Crucible.AppHost/resources/moodle/certs"
if compgen -G "${CUSTOM_CERT_SOURCE}"'/*.crt' > /dev/null; then
  mkdir -p "${MINIKUBE_CERT_DEST}"
  cp "${CUSTOM_CERT_SOURCE}"/*.crt "${MINIKUBE_CERT_DEST}/"
  echo "Copied custom CA certificates to ${MINIKUBE_CERT_DEST}"
  mkdir -p "${MOODLE_CERT_DEST}"
  cp "${CUSTOM_CERT_SOURCE}"/*.crt "${MOODLE_CERT_DEST}/"
  echo "Copied custom CA certificates to ${MOODLE_CERT_DEST}"
else
  echo "No custom CA certificates found in ${CUSTOM_CERT_SOURCE}; skipping copy."
fi

# Add helm repos
declare -A HELM_REPOS=(
  [cmusei]="https://helm.cmusei.dev/charts"
  [prometheus-community]="https://prometheus-community.github.io/helm-charts"
  [ingress-nginx]="https://kubernetes.github.io/ingress-nginx"
  [kvaps]="https://kvaps.github.io/charts"
  [selfhosters]="https://self-hosters-by-night.github.io/helm-charts"
  [runix]="https://helm.runix.net"
  [grafana]="https://grafana.github.io/helm-charts"
)

for name in "${!HELM_REPOS[@]}"; do
  url="${HELM_REPOS[$name]}"
  helm repo add "$name" "$url"
done
