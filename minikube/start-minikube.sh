#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

# Color codes
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

log_header() { echo -e "\n${BLUE}${BOLD}# $1${RESET}\n"; }
log_warn() { echo -e "${YELLOW}$1${RESET}"; }

# -----------------------------------------------------------------------------
# Certificate Handling
# -----------------------------------------------------------------------------

stage_custom_ca_certs() {
  local src="/usr/local/share/ca-certificates/custom"
  local dest="${HOME}/.minikube/files/etc/ssl/certs/custom"

  if compgen -G "${src}"'/*.crt' > /dev/null; then
    log_header "Staging custom CA certificates for minikube"
    mkdir -p "$dest"
    cp "${src}"/*.crt "$dest"/
    echo "Copied custom CA certificates to ${dest}"
  else
    log_warn "No custom CA certificates found in ${src}; skipping copy"
  fi
}

# Find a certificate file in dev-certs first, then legacy certs directory
find_cert_file() {
  local filename=$1
  local cert_dev="${REPO_ROOT}/.devcontainer/dev-certs/${filename}"
  local cert_legacy="${REPO_ROOT}/.devcontainer/certs/${filename}"

  if [[ -f "$cert_dev" ]]; then
    echo "$cert_dev"
  elif [[ -f "$cert_legacy" ]]; then
    echo "$cert_legacy"
  fi
}

setup_tls_and_ca_secrets() {
  local cert_source_legacy="${REPO_ROOT}/.devcontainer/certs"
  local cert_source_dev="${REPO_ROOT}/.devcontainer/dev-certs"
  local tls_secret="crucible-cert"
  local ca_configmap="crucible-ca-cert"

  local ns
  ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)
  ns=${ns:-default}

  # Find TLS certificate and key
  local crucible_dev_crt crucible_dev_key
  crucible_dev_crt=$(find_cert_file "crucible-dev.crt")
  crucible_dev_key=$(find_cert_file "crucible-dev.key")

  # Create TLS secret if both cert and key exist
  if [[ -n "$crucible_dev_crt" && -n "$crucible_dev_key" ]]; then
    echo "Creating TLS secret ${tls_secret} from local certificates..."
    kubectl create secret tls "${tls_secret}" \
      --cert="${crucible_dev_crt}" --key="${crucible_dev_key}" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "TLS secret created/updated successfully"
  else
    log_warn "TLS certificate files not found, skipping TLS secret creation"
  fi

  # Create CA ConfigMap from all available certificates
  local temp_dir
  temp_dir=$(mktemp -d)
  local has_certs=false

  # Copy crucible-dev.crt if found
  [[ -n "$crucible_dev_crt" ]] && cp "$crucible_dev_crt" "${temp_dir}/" && has_certs=true

  # Copy other certificates from both directories
  for dir in "$cert_source_legacy" "$cert_source_dev"; do
    [[ -d "$dir" ]] || continue
    for cert_file in "$dir"/*.crt; do
      [[ -f "$cert_file" ]] || continue
      local basename
      basename=$(basename "$cert_file")
      [[ ! -f "${temp_dir}/${basename}" ]] && cp "$cert_file" "${temp_dir}/" && has_certs=true
    done
  done

  if $has_certs; then
    echo "Creating CA certificates ConfigMap ${ca_configmap}..."
    kubectl create configmap "${ca_configmap}" --from-file="${temp_dir}" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "CA ConfigMap created/updated successfully"
  else
    log_warn "No CA certificate files found, skipping CA ConfigMap creation"
  fi

  rm -rf "${temp_dir}"
}

setup_caster_certs() {
  local certs_dir="${REPO_ROOT}/.devcontainer/certs"
  local dev_cert_dir="/home/vscode/.aspnet/dev-certs/trust"

  echo "Regenerating caster-certs ConfigMap..."

  local cert_args=()
  for dir in "$certs_dir" "$dev_cert_dir"; do
    for f in "$dir"/*.crt "$dir"/*.pem; do
      [ -f "$f" ] && cert_args+=("--from-file=$f")
    done
  done

  if [ ${#cert_args[@]} -gt 0 ]; then
    kubectl create configmap caster-certs "${cert_args[@]}" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "caster-certs ConfigMap created/updated with ${#cert_args[@]} certificate(s)."
  else
    echo "Warning: No certificate files found."
  fi
}

# -----------------------------------------------------------------------------
# Minikube Start
# -----------------------------------------------------------------------------

stage_custom_ca_certs

# -----------------------------------------------------------------------------
# Registry Mirror Configuration
# Pull-through cache containers for minikube image pulls.
# Image blobs are stored under /mnt/data/registry/ on the persistent
# crucible-dev-data volume and survive `minikube delete` (but not --purge).
# Mirror ports: docker.io=5001, ghcr.io=5002, quay.io=5003, registry.k8s.io=5004
# -----------------------------------------------------------------------------

declare -A REGISTRY_MIRRORS=(
  ["docker.io"]="5001:https://registry-1.docker.io"
  ["ghcr.io"]="5002:https://ghcr.io"
  ["quay.io"]="5003:https://quay.io"
  ["registry.k8s.io"]="5004:https://registry.k8s.io"
)

start_registry_mirrors() {
  local mirrors_dir="${HOME}/.minikube/files/etc/containerd/certs.d"
  mkdir -p /mnt/data/registry

  # Mount the devcontainer's CA bundle so registry containers trust any
  # TLS-inspecting proxies when connecting to upstream registries.
  local ca_bundle_mount=()
  if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
    ca_bundle_mount=(-v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro)
  fi

  for registry in "${!REGISTRY_MIRRORS[@]}"; do
    IFS=':' read -r port upstream_host upstream_path <<< "${REGISTRY_MIRRORS[$registry]}"
    local upstream="https:${upstream_path}"
    local container="crucible-registry-${registry//[.\/]/-}"
    local data_dir="/mnt/data/registry/${registry}"
    mkdir -p "${data_dir}"

    # Remove the container if it exists but isn't running (crashed or stopped)
    # so it gets recreated with current config.
    if docker inspect "${container}" &>/dev/null; then
      local state
      state=$(docker inspect --format='{{.State.Status}}' "${container}" 2>/dev/null)
      if [[ "${state}" == "running" ]]; then
        : # already up, nothing to do
      else
        echo "Registry mirror ${registry} is ${state}, recreating..."
        docker rm -f "${container}" 2>/dev/null || true
      fi
    fi

    if ! docker inspect "${container}" &>/dev/null; then
      echo "Starting registry mirror for ${registry} on port ${port}..."
      docker run -d \
        --name "${container}" \
        -p "${port}:5000" \
        -v "${data_dir}:/var/lib/registry" \
        "${ca_bundle_mount[@]}" \
        -e "REGISTRY_PROXY_REMOTEURL=${upstream}" \
        -e "REGISTRY_LOG_LEVEL=warn" \
        -e "REGISTRY_STORAGE_DELETE_ENABLED=true" \
        registry:2
    fi

    # Stage containerd mirror config — injected into the minikube node on start
    local hosts_dir="${mirrors_dir}/${registry}"
    mkdir -p "${hosts_dir}"
    cat > "${hosts_dir}/hosts.toml" <<EOF
server = "${upstream}"

[host."http://host.minikube.internal:${port}"]
  capabilities = ["pull", "resolve"]
EOF
  done
  echo "Registry mirrors ready."
}

start_registry_mirrors

log_header "Checking minikube cluster status"

STATUS=$(minikube status --output json 2>/dev/null || echo '{}')

HOST_STATE=$(echo "$STATUS" | jq -r '.Host // empty')
KUBELET_STATE=$(echo "$STATUS" | jq -r '.Kubelet // empty')
APISERVER_STATE=$(echo "$STATUS" | jq -r '.APIServer // empty')

if [[ "$HOST_STATE" == "Running" && "$KUBELET_STATE" == "Running" && "$APISERVER_STATE" == "Running" ]]; then
    echo "minikube is operational."
else
    echo "minikube is not running. Starting now..."
    minikube start --mount-string="/mnt/data/terraform:/mnt/data/terraform" --embed-certs \
      --container-runtime=containerd

    echo "Configuring kubelet for parallel image pulls..."
    minikube ssh "sudo sed -i 's/serializeImagePulls: true/serializeImagePulls: false/' /var/lib/kubelet/config.yaml || echo 'serializeImagePulls: false' | sudo tee -a /var/lib/kubelet/config.yaml"
    minikube ssh "sudo systemctl restart kubelet"
fi

# Set up certificates and secrets in the cluster
log_header "Setting up TLS secrets and CA certificates"
setup_tls_and_ca_secrets
setup_caster_certs
