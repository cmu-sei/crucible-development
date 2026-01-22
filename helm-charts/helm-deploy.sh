#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

set -euo pipefail

# Get script and repo directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Defaults
UNINSTALL=false
UPDATE_CHARTS=false
PURGE_CLUSTER=false
DELETE_CLUSTER=false
NO_INSTALL=false
SELECT_INFRA=false
SELECT_APPS=false
SELECT_MONITORING=false
USE_LOCAL_CHARTS=false

CHARTS_DIR=/mnt/data/crucible/helm-charts/charts
SEI_HELM_REPO_NAME=cmusei
CRUCIBLE_DOMAIN=crucible
PGADMIN_EMAIL=pgadmin@crucible.dev

# Disable Helm 4's server-side apply by default because several upstream charts
# still rely on client-side merge semantics (SSA triggers managedFields errors).
HELM_UPGRADE_FLAGS=${HELM_UPGRADE_FLAGS:---wait --timeout 15m --server-side=false}

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

log_header() { echo -e "\n${BLUE}${BOLD}# $1${RESET}\n"; }
log_warn() { echo -e "${YELLOW}$1${RESET}"; }
log_error() { echo -e "${RED}$1${RESET}"; }

refresh_current_namespace() {
  CURRENT_NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)
  CURRENT_NAMESPACE=${CURRENT_NAMESPACE:-default}
}

show_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --uninstall        Removes the Helm releases installed by this script
  --update-charts    Rebuild local chart dependencies or update remote repo
  --purge            Deletes and recreates the minikube cluster before deploying
  --delete           Deletes and restarts minikube using cached artifacts
  --no-install       Skips the install phase
  --local            Use local chart files instead of the SEI Helm repository
  --infra            Select crucible-infra chart (can be combined)
  --apps             Select crucible (apps) chart (can be combined)
  --monitoring       Select crucible-monitoring chart (can be combined)

Chart deployment order: infra -> apps -> monitoring
By default, all three charts are selected.
Example: --infra --apps selects infra + apps without monitoring.
EOF
}

# -----------------------------------------------------------------------------
# Helm Operations
# -----------------------------------------------------------------------------

helm_uninstall_if_exists() {
  local release=$1
  if helm status "$release" &>/dev/null; then
    log_header "Uninstalling Helm release ${release}"
    helm uninstall "$release" --wait --timeout 300s
  else
    echo "Helm release ${release} not found, skipping uninstall"
  fi
}

helm_deploy() {
  local chart=$1 values_file=$2 chart_ref

  if $USE_LOCAL_CHARTS; then
    chart_ref="${CHARTS_DIR}/${chart}"
  else
    chart_ref="${SEI_HELM_REPO_NAME}/${chart}"
  fi

  local values_flag=""
  [[ -f "$values_file" ]] && values_flag="-f ${values_file}" && echo "Using local values file: ${values_file}"

  if helm status "$chart" &>/dev/null; then
    echo "Existing release detected; running helm upgrade"
    helm upgrade "$chart" "$chart_ref" ${HELM_UPGRADE_FLAGS} ${values_flag}
  else
    echo "Release not found; running helm install"
    helm install "$chart" "$chart_ref" ${HELM_UPGRADE_FLAGS} ${values_flag}
  fi
}

# -----------------------------------------------------------------------------
# Cleanup Functions
# -----------------------------------------------------------------------------

delete_finished_pods_for_release() {
  local release=$1 selector="app.kubernetes.io/instance=${1}"
  local pod_list deleted=false

  pod_list=$(kubectl get pods -n "$CURRENT_NAMESPACE" -l "$selector" \
    -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}' 2>/dev/null || true)

  [[ -z "$pod_list" ]] && { echo "No pods found for release ${release}"; return; }

  while read -r pod_name pod_phase; do
    [[ -z "$pod_name" ]] && continue
    if [[ "$pod_phase" == "Succeeded" || "$pod_phase" == "Failed" ]]; then
      deleted=true
      echo "Deleting pod ${pod_name} (phase: ${pod_phase})"
      kubectl delete pod "$pod_name" -n "$CURRENT_NAMESPACE" --ignore-not-found --force
    fi
  done <<< "$pod_list"

  $deleted || echo "No Completed/Failed pods for release ${release}"
}

delete_pvcs_for_release() {
  local release=$1 ns="$CURRENT_NAMESPACE"
  local pvcs=(
    "data-${release}-nfs-server-provisioner-0"
    "${release}-topomojo-api-nfs"
    "${release}-gameboard-api-nfs"
    "${release}-caster-api-nfs"
  )

  for pvc in "${pvcs[@]}"; do
    echo "Deleting PVC ${ns}/${pvc} (if present)"
    kubectl delete pvc "$pvc" -n "$ns" --ignore-not-found

    # Find and delete the PV bound to this PVC to avoid orphaned volumes
    local pv_name
    pv_name=$(kubectl get pv -o json | jq -r --arg ns "$ns" --arg claim "$pvc" \
      '.items[] | select(.spec.claimRef.namespace==$ns and .spec.claimRef.name==$claim) | .metadata.name' | head -n1)
    if [[ -n "$pv_name" && "$pv_name" != "null" ]]; then
      echo "Deleting PV ${pv_name} bound to ${ns}/${pvc}"
      kubectl delete pv "$pv_name" --ignore-not-found
    else
      echo "No PV found for ${ns}/${pvc}"
    fi
  done
}

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

# -----------------------------------------------------------------------------
# CoreDNS Configuration
# -----------------------------------------------------------------------------

ensure_nodehosts_entry() {
  local ingress_service="${INGRESS_SERVICE:-crucible-infra-ingress-nginx-controller}"
  local ingress_namespace="${INGRESS_NAMESPACE:-$CURRENT_NAMESPACE}"
  local dns_namespace="kube-system"
  local dns_configmap="coredns"

  log_header "Ensuring CoreDNS NodeHosts contains ${CRUCIBLE_DOMAIN}"

  # Wait for ingress controller IP
  local ingress_ip="" waited=0
  while [[ $waited -lt 60 ]]; do
    ingress_ip=$(kubectl -n "$ingress_namespace" get svc "$ingress_service" \
      -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
    [[ -n "$ingress_ip" && "$ingress_ip" != "<no value>" ]] && break
    ((waited++)) && sleep 1
  done

  if [[ -z "$ingress_ip" || "$ingress_ip" == "<no value>" ]]; then
    log_warn "Unable to determine ClusterIP for ${ingress_service}; skipping NodeHosts update"
    return
  fi

  # Patch CoreDNS ConfigMap
  local cm_patch
  cm_patch=$(mktemp)
  cat > "$cm_patch" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${dns_configmap}
  namespace: ${dns_namespace}
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        hosts /etc/coredns/NodeHosts {
           fallthrough
        }
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
  NodeHosts: |
    ${ingress_ip} ${CRUCIBLE_DOMAIN}
    192.168.49.1 host.minikube.internal
EOF

  kubectl -n "$dns_namespace" patch configmap "$dns_configmap" --type merge --patch-file "$cm_patch"

  # Patch deployment to mount NodeHosts
  local deploy_patch
  deploy_patch=$(mktemp)
  cat > "$deploy_patch" <<EOF
spec:
  template:
    spec:
      volumes:
      - name: config-volume
        configMap:
          name: ${dns_configmap}
          items:
          - key: Corefile
            path: Corefile
          - key: NodeHosts
            path: NodeHosts
EOF
  kubectl -n "$dns_namespace" patch deployment coredns --patch-file "$deploy_patch"
  kubectl -n "$dns_namespace" rollout restart deployment/coredns
  kubectl -n "$dns_namespace" rollout status deployment/coredns --timeout=120s || true

  rm -f "$cm_patch" "$deploy_patch"
}

# -----------------------------------------------------------------------------
# Output Functions
# -----------------------------------------------------------------------------

print_web_app_urls() {
  log_header "Web application endpoints"

  local output=""
  local service_filter="-ui|keycloak|pgadmin|grafana|prometheus|moodle"

  while IFS='|' read -r host path service tls_hosts; do
    [[ -z "$host" ]] && continue
    [[ ! "$service" =~ (${service_filter})$ ]] && continue

    local scheme="http"
    [[ "$tls_hosts" == *"$host"* ]] && scheme="https"
    output+="- ${scheme}://${host}${path} (service: ${service})"$'\n'
  done < <(kubectl get ingress -n "$CURRENT_NAMESPACE" -o json 2>/dev/null | jq -r '
    .items[]? | . as $ing |
    ([.spec.tls[]?.hosts[]?] | join(",")) as $tls |
    .spec.rules[]? | .host as $host |
    .http.paths[]? | "\($host)|\(.path // "/")|\(.backend.service.name // $ing.metadata.name)|\($tls)"
  ')

  if [[ -z "$output" ]]; then
    echo "No ingress endpoints were found."
  else
    echo "$output" | sort -u
  fi
}

print_secret_credentials() {
  local header=$1 secret_name=$2 password_key=$3 username=$4

  log_header "$header"

  local encoded_password
  if ! encoded_password=$(kubectl get secret "$secret_name" -n "$CURRENT_NAMESPACE" \
      -o jsonpath="{.data.${password_key}}" 2>/dev/null) || [[ -z "$encoded_password" ]]; then
    echo "Secret ${secret_name} not found or missing ${password_key} key."
    return
  fi

  local decoded_password
  if ! decoded_password=$(echo "$encoded_password" | base64 --decode 2>/dev/null); then
    echo "Failed to decode password from secret ${secret_name}."
    return
  fi

  echo "  Username: $username"
  echo "  Password: $decoded_password"
}

# -----------------------------------------------------------------------------
# Minikube Cluster Management
# -----------------------------------------------------------------------------

start_minikube_cluster() {
  stage_custom_ca_certs
  log_header "Checking minikube cluster status"
  "${REPO_ROOT}/scripts/start-minikube.sh"
}

purge_minikube_cluster() {
  log_header "Purging minikube cluster"
  echo "Attempting sudo umount of ~/.minikube to release mounts (may prompt for sudo)"
  sudo umount "${HOME}/.minikube" 2>/dev/null || log_warn "sudo umount ~/.minikube did not succeed; continuing"
  minikube delete --all --purge
  start_minikube_cluster
}

delete_minikube_cluster() {
  log_header "Deleting minikube cluster (preserving cache)"
  minikube delete --all
  start_minikube_cluster
}

# -----------------------------------------------------------------------------
# Chart Dependency Management
# -----------------------------------------------------------------------------

chart_dependencies_ready() {
  local chart_path=$1
  [[ -f "${chart_path}/Chart.lock" ]] || return 1
  [[ "${chart_path}/Chart.yaml" -nt "${chart_path}/Chart.lock" ]] && return 1
  [[ -d "${chart_path}/charts" ]] || return 1
  helm dependency list "$chart_path" 2>/dev/null | grep -qE '[[:space:]]missing$' && return 1
  return 0
}

build_chart_dependencies() {
  local chart_path="${CHARTS_DIR}/${1}"
  echo "Building dependencies for chart ${chart_path}"
  if ! helm dependency build "$chart_path"; then
    echo "Dependency build failed; refreshing lockfile and fetching missing charts"
    helm dependency update "$chart_path"
    helm dependency build "$chart_path"
  fi
}

ensure_chart_dependencies() {
  local chart=$1 chart_path="${CHARTS_DIR}/${1}"

  if $UPDATE_CHARTS; then
    log_header "Forcing dependency rebuild for ${chart_path}"
    build_chart_dependencies "$chart"
  elif chart_dependencies_ready "$chart_path"; then
    log_header "Dependencies for ${chart_path} already present, skipping rebuild"
  else
    log_header "Dependencies missing for ${chart_path}, rebuilding"
    build_chart_dependencies "$chart"
  fi
}

# -----------------------------------------------------------------------------
# Chart-Specific Deployment Logic
# -----------------------------------------------------------------------------

deploy_infra_chart() {
  log_header "Deploying crucible-infra chart"

  setup_tls_and_ca_secrets
  helm_deploy "crucible-infra" "${SCRIPT_DIR}/crucible-infra.values.yaml"

  # Configure CoreDNS immediately after infra deployment
  log_header "Updating CoreDNS with current ingress controller IP"
  ensure_nodehosts_entry

  # Create PostgreSQL credentials secret for the crucible chart
  log_header "Creating PostgreSQL credentials secret for crucible chart"
  local postgres_secret="crucible-infra-postgresql"
  local infra_postgres_password
  infra_postgres_password=$(kubectl get secret "${postgres_secret}" -n "$CURRENT_NAMESPACE" \
    -o jsonpath='{.data.postgres-password}' 2>/dev/null | base64 --decode || echo "")

  if [[ -z "$infra_postgres_password" ]]; then
    log_warn "Could not retrieve PostgreSQL password from ${postgres_secret} secret"
    echo "Ensure the infra chart has deployed successfully before continuing."
  else
    kubectl create secret generic "$postgres_secret" \
      --from-literal=username=postgres \
      --from-literal=postgres-password="$infra_postgres_password" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "PostgreSQL credentials secret created/updated successfully"

    # Ensure PostgreSQL user password is set correctly in the database
    echo "Ensuring PostgreSQL user password is set correctly..."
    if kubectl exec -n "$CURRENT_NAMESPACE" "statefulset/crucible-infra-postgresql" -- \
        sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -c "ALTER USER postgres WITH PASSWORD '\''$POSTGRES_PASSWORD'\'';"' &>/dev/null; then
      echo "PostgreSQL user password verified/updated successfully"
    else
      log_warn "Could not update PostgreSQL password - database may not be ready yet"
    fi
  fi
}

deploy_apps_chart() {
  log_header "Deploying crucible (apps) chart"

  # Create Keycloak realm import ConfigMap if realm file exists
  local realm_file="${SCRIPT_DIR}/files/crucible-realm.json"
  local realm_configmap="crucible-keycloak-config-cli"

  if [[ -f "$realm_file" ]]; then
    echo "Creating Keycloak realm import ConfigMap ${realm_configmap}..."
    kubectl create configmap "${realm_configmap}" --from-file=realm.json="${realm_file}" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "Keycloak realm ConfigMap created/updated successfully"
  else
    log_warn "Keycloak realm file not found at ${realm_file}, skipping realm import ConfigMap creation"
  fi

  helm_deploy "crucible" "${SCRIPT_DIR}/crucible.values.yaml"
}

deploy_monitoring_chart() {
  log_header "Deploying crucible-monitoring chart"
  helm_deploy "crucible-monitoring" "${SCRIPT_DIR}/crucible-monitoring.values.yaml"
}

# -----------------------------------------------------------------------------
# Uninstall Logic
# -----------------------------------------------------------------------------

uninstall_charts() {
  # Uninstall in reverse order: monitoring -> apps -> infra
  for ((i=${#CHARTS[@]}-1; i>=0; i--)); do
    helm_uninstall_if_exists "${CHARTS[i]}"
  done

  log_header "Deleting completed/failed pods"
  for ((i=${#CHARTS[@]}-1; i>=0; i--)); do
    delete_finished_pods_for_release "${CHARTS[i]}"
  done

  log_header "Deleting PVCs/PVs"
  for ((i=${#CHARTS[@]}-1; i>=0; i--)); do
    delete_pvcs_for_release "${CHARTS[i]}"
  done

  # Clean up manually created secrets and configmaps
  for ((i=${#CHARTS[@]}-1; i>=0; i--)); do
    case "${CHARTS[i]}" in
      "crucible-infra")
        log_header "Deleting secrets and ConfigMaps created by deployment script (infra)"
        kubectl delete secret crucible-cert -n "$CURRENT_NAMESPACE" --ignore-not-found
        kubectl delete configmap crucible-ca-cert -n "$CURRENT_NAMESPACE" --ignore-not-found
        kubectl delete secret crucible-infra-postgresql -n "$CURRENT_NAMESPACE" --ignore-not-found
        ;;
      "crucible")
        log_header "Deleting secrets and ConfigMaps created by deployment script (apps)"
        kubectl delete configmap crucible-keycloak-config-cli -n "$CURRENT_NAMESPACE" --ignore-not-found
        ;;
    esac
  done

  echo -e "\n${GREEN}${BOLD}# Uninstall complete${RESET}\n"
}

# =============================================================================
# Main Script
# =============================================================================

refresh_current_namespace

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)       UNINSTALL=true ;;
    --update-charts)   UPDATE_CHARTS=true ;;
    --purge)           PURGE_CLUSTER=true ;;
    --delete)          DELETE_CLUSTER=true ;;
    --no-install)      NO_INSTALL=true ;;
    --local)           USE_LOCAL_CHARTS=true ;;
    --infra)           SELECT_INFRA=true ;;
    --apps)            SELECT_APPS=true ;;
    --monitoring)      SELECT_MONITORING=true ;;
    --infra-only)      log_warn "Deprecated: use --infra instead of --infra-only."; SELECT_INFRA=true ;;
    --apps-only)       log_warn "Deprecated: use --apps instead of --apps-only."; SELECT_APPS=true ;;
    --monitoring-only) log_warn "Deprecated: use --monitoring instead of --monitoring-only."; SELECT_MONITORING=true ;;
    -h|--help)         show_usage; exit 0 ;;
    *)                 log_error "Unknown option: $1"; show_usage; exit 1 ;;
  esac
  shift
done

# Validate options
if $PURGE_CLUSTER && $DELETE_CLUSTER; then
  log_error "Cannot specify both --purge and --delete."
  exit 1
fi

# Determine which charts to operate on
CHARTS=()
if $SELECT_INFRA || $SELECT_APPS || $SELECT_MONITORING; then
  $SELECT_INFRA && CHARTS+=("crucible-infra")
  $SELECT_APPS && CHARTS+=("crucible")
  $SELECT_MONITORING && CHARTS+=("crucible-monitoring")
else
  CHARTS=("crucible-infra" "crucible" "crucible-monitoring")
fi

# Handle cluster operations
if $PURGE_CLUSTER; then
  purge_minikube_cluster
  refresh_current_namespace
elif $DELETE_CLUSTER; then
  delete_minikube_cluster
  refresh_current_namespace
fi

# Handle uninstall
if $UNINSTALL; then
  uninstall_charts
  exit 0
fi

# Handle no-install
if $NO_INSTALL; then
  log_warn "--no-install specified; skipping install phase"
  exit 0
fi

# Prepare chart sources
if $USE_LOCAL_CHARTS; then
  log_header "Using local chart files from ${CHARTS_DIR}"
  for chart in "${CHARTS[@]}"; do
    ensure_chart_dependencies "$chart"
  done
elif $UPDATE_CHARTS; then
  log_header "Updating Helm repositories"
  helm repo update
fi

# Ensure minikube cluster is running
log_header "Ensuring minikube cluster is running"
start_minikube_cluster

# Deploy charts in order: infra -> apps -> monitoring
for chart in "${CHARTS[@]}"; do
  case "$chart" in
    "crucible-infra")      deploy_infra_chart ;;
    "crucible")            deploy_apps_chart ;;
    "crucible-monitoring") deploy_monitoring_chart ;;
  esac
done

# Ensure CoreDNS is configured (fallback for non-infra deployments)
if [[ ! " ${CHARTS[*]} " =~ " crucible-infra " ]]; then
  log_header "Ensuring CoreDNS has correct ingress controller IP"
  ensure_nodehosts_entry
fi

# Enable K8s port forwarding to allow connection to web apps from host
log_header "Enabling port-forwarding"
pkill -f "port-forward.*443:443" 2>/dev/null || true
nohup kk port-forward -n default "service/crucible-infra-ingress-nginx-controller" "443:443" > /dev/null 2>&1 &

# Print URLs and credentials
print_web_app_urls
print_secret_credentials "Keycloak admin credentials" "crucible-keycloak-auth" "admin-password" "keycloak-admin"
print_secret_credentials "pgAdmin credentials" "crucible-infra-pgadmin" "password" "${PGADMIN_EMAIL}"

echo -e "\n${GREEN}${BOLD}Crucible deployment complete${RESET}\n"
