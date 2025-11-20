#!/bin/bash

set -euo pipefail

# --- Color codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

CHARTS_DIR=/workspaces/crucible-development/helm-charts
CERT_MANAGER_VERSION=v1.17.2
CRUCIBLE_RELEASE=crucible
INFRA_RELEASE=infra

refresh_current_namespace() {
  CURRENT_NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)
  CURRENT_NAMESPACE=${CURRENT_NAMESPACE:-default}
}

refresh_current_namespace

show_usage() {
  echo "Usage: $0 [--uninstall] [--update-charts] [--purge] [--delete] [--no-install]"
  echo "  --uninstall       Removes the Helm releases and CRDs installed by this script."
  echo "  --update-charts   Forces rebuilding Helm chart dependencies even if they already exist."
  echo "  --purge           Deletes and recreates the local minikube cluster before deploying."
  echo "  --delete          Deletes and restarts minikube using cached artifacts (no purge)."
  echo "  --no-install      Skips the install phase (useful with --purge/--delete for cleanup only)."
}

UNINSTALL=false
UPDATE_CHARTS=false
PURGE_CLUSTER=false
DELETE_CLUSTER=false
NO_INSTALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    --update-charts)
      UPDATE_CHARTS=true
      shift
      ;;
    --purge)
      PURGE_CLUSTER=true
      shift
      ;;
    --delete)
      DELETE_CLUSTER=true
      shift
      ;;
    --no-install)
      NO_INSTALL=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${RESET}"
      show_usage
      exit 1
      ;;
  esac
done

if $PURGE_CLUSTER && $DELETE_CLUSTER; then
  echo -e "${RED}Cannot specify both --purge and --delete.${RESET}"
  exit 1
fi

helm_uninstall_if_exists() {
  local release_name=$1
  if helm status "$release_name" &>/dev/null; then
    echo -e "\n${BLUE}${BOLD}# Uninstalling Helm release ${release_name}${RESET}\n"
    helm uninstall "$release_name" --wait --timeout 300s
  else
    echo "Helm release ${release_name} not found, skipping uninstall"
  fi
}

delete_finished_pods_for_release() {
  local release_name=$1
  local selector="app.kubernetes.io/instance=${release_name}"
  local pod_list
  local deleted=false

  pod_list=$(kubectl get pods -n "$CURRENT_NAMESPACE" -l "$selector" -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}' 2>/dev/null || true)
  if [[ -z "$pod_list" ]]; then
    echo "No pods found for release ${release_name}"
    return
  fi

  while read -r pod_name pod_phase; do
    [[ -z "$pod_name" ]] && continue
    if [[ "$pod_phase" == "Succeeded" || "$pod_phase" == "Failed" ]]; then
      deleted=true
      echo "Deleting pod ${pod_name} (phase: ${pod_phase})"
      kubectl delete pod "$pod_name" -n "$CURRENT_NAMESPACE" --ignore-not-found
    fi
  done <<< "$pod_list"

  if ! $deleted; then
    echo "No Completed/Failed pods for release ${release_name}"
  fi
}

stage_custom_ca_certs() {
  local src="/usr/local/share/ca-certificates/custom"
  local dest="${HOME}/.minikube/files/etc/ssl/certs/custom"

  if compgen -G "${src}"'/*.crt' > /dev/null; then
    echo -e "\n${BLUE}${BOLD}# Staging custom CA certificates for minikube${RESET}\n"
    mkdir -p "$dest"
    cp "${src}"/*.crt "$dest"/
    echo "Copied custom CA certificates to ${dest}"
  else
    echo -e "\n${YELLOW}${BOLD}# No custom CA certificates found in ${src}; skipping copy${RESET}\n"
  fi
}

start_minikube_cluster() {
  stage_custom_ca_certs

  echo -e "\n${BLUE}${BOLD}# Starting minikube cluster${RESET}\n"
  minikube start --mount-string="/mnt/data/terraform/root:/terraform/root" --embed-certs
}

purge_minikube_cluster() {
  echo -e "\n${BLUE}${BOLD}# Purging minikube cluster${RESET}\n"
  minikube delete --all --purge

  start_minikube_cluster
}

delete_minikube_cluster() {
  echo -e "\n${BLUE}${BOLD}# Deleting minikube cluster (preserving cache)${RESET}\n"
  minikube delete --all

  start_minikube_cluster
}

if $PURGE_CLUSTER; then
  purge_minikube_cluster
  refresh_current_namespace
elif $DELETE_CLUSTER; then
  delete_minikube_cluster
  refresh_current_namespace
fi

if $UNINSTALL; then
  helm_uninstall_if_exists "$CRUCIBLE_RELEASE"
  helm_uninstall_if_exists "$INFRA_RELEASE"

  echo -e "\n${BLUE}${BOLD}# Deleting completed/failed pods for ${CRUCIBLE_RELEASE}${RESET}\n"
  delete_finished_pods_for_release "$CRUCIBLE_RELEASE"

  echo -e "\n${BLUE}${BOLD}# Removing cert-manager CRDs${RESET}\n"
  kubectl delete --ignore-not-found=true -f https://github.com/cert-manager/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.crds.yaml

  echo -e "\n${GREEN}${BOLD}# Uninstall complete${RESET}\n"
  exit 0
fi

if $NO_INSTALL; then
  echo -e "\n${YELLOW}${BOLD}# --no-install specified; skipping install phase${RESET}\n"
  exit 0
fi

chart_dependencies_ready() {
  local chart_path=$1
  [[ -f "${chart_path}/Chart.lock" ]] || return 1
  [[ -d "${chart_path}/charts" ]] || return 1
  if helm dependency list "$chart_path" 2>/dev/null | grep -qE '[[:space:]]missing$'; then
    return 1
  fi
  return 0
}

build_chart_dependencies() {
  local chart_name=$1
  local chart_path="${CHARTS_DIR}/${chart_name}"
  echo "Building dependencies for chart ${chart_path}"
  helm dependency build "$chart_path"
}

ensure_chart_dependencies() {
  local chart=$1
  local chart_path="${CHARTS_DIR}/${chart}"

  if $UPDATE_CHARTS; then
    echo "Forcing dependency rebuild for ${chart_path}"
    build_chart_dependencies "$chart"
    return
  fi

  if chart_dependencies_ready "$chart_path"; then
    echo "Dependencies for ${chart_path} already present, skipping rebuild"
  else
    echo "Dependencies missing for ${chart_path}, rebuilding"
    build_chart_dependencies "$chart"
  fi
}

# Build dependencies for Helm charts
CHARTS=("infra" "crucible")
for chart in "${CHARTS[@]}"; do
  ensure_chart_dependencies "$chart"
done

echo -e "\n${BLUE}${BOLD}# Applying yaml for cert-manager${RESET}\n"
kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.crds.yaml

echo -e "\n${BLUE}${BOLD}# Helm installing ${CHARTS_DIR}/infra${RESET}\n"
helm upgrade --install "$INFRA_RELEASE" "$CHARTS_DIR/infra"
timeout --foreground 300 bash -c "while ! kubectl get secret ${INFRA_RELEASE}-ca &>/dev/null; do echo 'Waiting for ${INFRA_RELEASE}-ca secret...'; sleep 5; done"

echo -e "\n${BLUE}${BOLD}# Helm installing ${CHARTS_DIR}/crucible${RESET}\n"
helm upgrade --install "$CRUCIBLE_RELEASE" "$CHARTS_DIR/crucible"

echo -e "\n${BLUE}${BOLD}# Enabling port-forwarding${RESET}\n"
nohup kk port-forward -n default "service/crucible-ingress-nginx-controller" "443:443" > /dev/null 2>&1 &

echo -e "\n${GREEN}${BOLD}Crucible has been deployed${RESET}\n"
