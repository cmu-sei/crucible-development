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
UPDATE_CHARTS=false
PURGE_CLUSTER=false
DELETE_CLUSTER=false
SELECT_OPERATORS=false
SELECT_INFRA=false
SELECT_APPS=false
SELECT_MONITORING=false
USE_LOCAL_CHARTS=false

CHARTS_DIR=/mnt/data/crucible/helm-charts/charts
SEI_HELM_REPO_NAME=cmusei
CRUCIBLE_DOMAIN=crucible

# Disable Helm 4's server-side apply by default because several upstream charts
# still rely on client-side merge semantics (SSA triggers managedFields errors).
HELM_DEPLOY_FLAGS=${HELM_DEPLOY_FLAGS:---server-side=false}

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
  --update-charts    Rebuild local chart dependencies or update remote repo
  --purge            Deletes and recreates the minikube cluster before deploying
  --delete           Deletes and restarts minikube using cached artifacts
  --local            Use local chart files instead of the SEI Helm repository
  --operators        Select crucible-operators chart (can be combined)
  --infra            Select crucible-infra chart (can be combined)
  --apps             Select crucible (apps) chart (can be combined)
  --monitoring       Select crucible-monitoring chart (can be combined)

Chart deployment order: operators -> infra -> apps -> monitoring
By default, all four charts are selected.
Example: --infra --apps selects infra + apps without operators or monitoring.
EOF
}

# -----------------------------------------------------------------------------
# Helm Operations
# -----------------------------------------------------------------------------

helm_deploy() {
  local chart=$1 values_file=$2 chart_ref timeout=${3:-15m}

  if $USE_LOCAL_CHARTS; then
    chart_ref="${CHARTS_DIR}/${chart}"
  else
    chart_ref="${SEI_HELM_REPO_NAME}/${chart}"
  fi

  local values_flag=""
  [[ -f "$values_file" ]] && values_flag="-f ${values_file}" && echo "Using local values file: ${values_file}"

  helm upgrade --install "$chart" "$chart_ref" \
    --wait --timeout "$timeout" ${HELM_DEPLOY_FLAGS} ${values_flag}
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
  local service_filter="-ui|keycloak|keycloak-service|pgadmin|grafana|prometheus|moodle"

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

  local display_username="$username"
  if [[ "$username" == "AUTO" ]]; then
    local encoded_username
    if encoded_username=$(kubectl get secret "$secret_name" -n "$CURRENT_NAMESPACE" \
        -o jsonpath='{.data.username}' 2>/dev/null) && [[ -n "$encoded_username" ]]; then
      display_username=$(echo "$encoded_username" | base64 --decode 2>/dev/null || echo "$username")
    fi
  fi

  echo "  Username: $display_username"
  echo "  Password: $decoded_password"
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
  if ! helm dependency build "$chart_path" 2>/dev/null; then
    echo "Dependency build failed; running helm dependency update (refreshes lock + downloads)"
    helm dependency update "$chart_path"
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

# =============================================================================
# Main Script
# =============================================================================

refresh_current_namespace

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --update-charts)   UPDATE_CHARTS=true ;;
    --purge)           PURGE_CLUSTER=true ;;
    --delete)          DELETE_CLUSTER=true ;;
    --local)           USE_LOCAL_CHARTS=true ;;
    --operators)       SELECT_OPERATORS=true ;;
    --infra)           SELECT_INFRA=true ;;
    --apps)            SELECT_APPS=true ;;
    --monitoring)      SELECT_MONITORING=true ;;
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
if $SELECT_OPERATORS || $SELECT_INFRA || $SELECT_APPS || $SELECT_MONITORING; then
  $SELECT_OPERATORS && CHARTS+=("crucible-operators")
  $SELECT_INFRA && CHARTS+=("crucible-infra")
  $SELECT_APPS && CHARTS+=("crucible-apps")
  $SELECT_MONITORING && CHARTS+=("crucible-monitoring")
else
  CHARTS=("crucible-operators" "crucible-infra" "crucible-apps" "crucible-monitoring")
fi

# Handle cluster reset operations
if $PURGE_CLUSTER; then
  "${SCRIPT_DIR}/reset-minikube.sh" --purge
  refresh_current_namespace
elif $DELETE_CLUSTER; then
  "${SCRIPT_DIR}/reset-minikube.sh" --delete
  refresh_current_namespace
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

# Ensure minikube cluster is running (also handles certificates)
"${SCRIPT_DIR}/start-minikube.sh"
refresh_current_namespace

# Deploy charts in order: operators -> infra -> apps -> monitoring
for chart in "${CHARTS[@]}"; do
  log_header "Deploying ${chart} chart"

  case "$chart" in
    "crucible-operators")
      helm_deploy "$chart" "${SCRIPT_DIR}/${chart}.values.yaml" 5m

      echo "Waiting for Keycloak Operator to be ready..."
      kubectl wait deployment keycloak-operator \
        --for=condition=Available --timeout=120s 2>/dev/null || \
        log_warn "Keycloak Operator deployment not found or not ready yet"
      ;;

    "crucible-infra")
      # Infra chart skips --wait: Helm can't track CNPG Cluster readiness.
      # We handle readiness explicitly with kubectl wait below.
      helm_deploy "$chart" "${SCRIPT_DIR}/${chart}.values.yaml" 5m

      log_header "Waiting for CNPG PostgreSQL cluster to be ready"
      if kubectl get cluster crucible-infra-postgresql -n "$CURRENT_NAMESPACE" &>/dev/null; then
        kubectl wait cluster/crucible-infra-postgresql -n "$CURRENT_NAMESPACE" \
          --for=condition=Ready --timeout=300s || \
          log_warn "CNPG Cluster not ready within timeout — apps may fail to connect"
      else
        log_warn "CNPG Cluster resource not found — ensure the CNPG operator is installed"
      fi

      log_header "Updating CoreDNS with current ingress controller IP"
      ensure_nodehosts_entry
      ;;

    *)
      helm_deploy "$chart" "${SCRIPT_DIR}/${chart}.values.yaml"
      ;;
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
nohup kubectl port-forward -n default "service/crucible-infra-ingress-nginx-controller" "443:443" > /dev/null 2>&1 &

# Print URLs and credentials
print_web_app_urls
print_secret_credentials "Keycloak admin credentials" "crucible-apps-keycloak-initial-admin" "password" "AUTO"
print_secret_credentials "Crucible realm admin credentials" "crucible-oidc-client-secrets" "realm-admin-password" "admin"
print_secret_credentials "pgAdmin credentials" "crucible-infra-pgadmin" "password" "admin@crucible.local"

echo -e "\n${GREEN}${BOLD}Crucible deployment complete${RESET}\n"
