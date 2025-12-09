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
CRUCIBLE_RELEASE=crucible
CRUCIBLE_DOMAIN=${CRUCIBLE_DOMAIN:-crucible}
PGADMIN_EMAIL=${PGADMIN_EMAIL:-pgadmin@crucible.dev}
# Disable Helm 4's server-side apply by default because several upstream charts
# still rely on client-side merge semantics (SSA triggers managedFields errors).
HELM_UPGRADE_FLAGS=${HELM_UPGRADE_FLAGS:---wait --timeout 15m --server-side=false}
MINIKUBE_FLAGS=${MINIKUBE_FLAGS:---mount-string=/mnt/data/terraform/root:/terraform/root --embed-certs --cpus 4 --memory 12000}

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
      kubectl delete pod "$pod_name" -n "$CURRENT_NAMESPACE" --ignore-not-found --force
    fi
  done <<< "$pod_list"

  if ! $deleted; then
    echo "No Completed/Failed pods for release ${release_name}"
  fi
}

delete_pvcs_for_release() {
  local release_name=$1
  local ns="$CURRENT_NAMESPACE"
  # Target PVCs bound to the NFS provisioner and TopoMojo API storage.
  local pvcs=(
    "data-${release_name}-nfs-server-provisioner-0"
    "${release_name}-topomojo-api-nfs"
  )

  for pvc in "${pvcs[@]}"; do
    echo "Deleting PVC ${ns}/${pvc} (if present)"
    kubectl delete pvc "$pvc" -n "$ns" --ignore-not-found

    # Find and delete the PV bound to this PVC to avoid orphaned volumes.
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

ensure_nodehosts_entry() {
  local ingress_service="${INGRESS_SERVICE:-${CRUCIBLE_RELEASE}-ingress-nginx-controller}"
  local ingress_namespace="${INGRESS_NAMESPACE:-$CURRENT_NAMESPACE}"
  local dns_namespace="kube-system"
  local dns_configmap="coredns"

  echo -e "\n${BLUE}${BOLD}# Ensuring NodeHosts contains ${CRUCIBLE_DOMAIN}${RESET}\n"

  local ingress_ip=""
  local waited=0
  while [[ $waited -lt 60 ]]; do
    ingress_ip=$(kubectl -n "$ingress_namespace" get svc "$ingress_service" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
    if [[ -n "$ingress_ip" && "$ingress_ip" != "<no value>" ]]; then
      break
    fi
    waited=$((waited + 1))
    sleep 1
  done

  if [[ -z "$ingress_ip" || "$ingress_ip" == "<no value>" ]]; then
    echo -e "${YELLOW}Unable to determine ClusterIP for ${ingress_service}; skipping NodeHosts update${RESET}"
    return
  fi

  local cm_patch
  cm_patch=$(mktemp)
  cat <<EOF > "$cm_patch"
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${dns_configmap}
  namespace: ${dns_namespace}
data:
  Corefile: |
    .:53 {
        log
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
        cache 30 {
           disable success cluster.local
           disable denial cluster.local
        }
        loop
        reload
        loadbalance
    }
  NodeHosts: |
    ${ingress_ip} ${CRUCIBLE_DOMAIN}
    192.168.49.1 host.minikube.internal
EOF

  kubectl -n "$dns_namespace" patch configmap "$dns_configmap" --type merge --patch-file "$cm_patch"

  local deploy_patch
  deploy_patch=$(mktemp)
  cat <<EOF > "$deploy_patch"
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


print_web_app_urls() {
  echo -e "\n${BLUE}${BOLD}# Web application endpoints${RESET}\n"

  local ingress_json
  if ! ingress_json=$(kubectl get ingress -n "$CURRENT_NAMESPACE" -l "app.kubernetes.io/instance=${CRUCIBLE_RELEASE}" -o json 2>/dev/null); then
    echo "Unable to query ingress resources in namespace ${CURRENT_NAMESPACE}."
    return
  fi

  local urls
  urls=$(echo "$ingress_json" | jq -r '
    [
      .items[]? as $ingress |
      ([$ingress.spec.tls[]?.hosts[]?] | unique) as $tlsHosts |
      $ingress.spec.rules[]? as $rule |
      $rule.http.paths[]? as $path |
      ($path.path // "/") as $rawPath |
      ($rawPath | if startswith("/") then . else "/" + . end) as $normalizedPath |
      {
        scheme: (if ($tlsHosts | index($rule.host)) then "https" else "http" end),
        host: ($rule.host // ""),
        path: $normalizedPath,
        service: ($path.backend.service.name // $ingress.metadata.name)
      }
    ]
    | map(select(.host != ""))
    | map(select((.service // "") | test("(?:-ui|keycloak|pgadmin)$")))
    | sort_by([.scheme, .host, .service])
    | group_by({scheme: .scheme, host: .host, service: .service})
    | map(min_by(.path | length))
    | .[]
    | "- \(.scheme)://\(.host)\(.path) (service: \(.service))"
  ' 2>/dev/null)

  if [[ -z "${urls//[[:space:]]/}" ]]; then
    echo "No ingress endpoints were found for release ${CRUCIBLE_RELEASE}."
    return
  fi

  echo "$urls"
}

print_keycloak_admin_credentials() {
  echo -e "\n${BLUE}${BOLD}# Keycloak master realm credentials${RESET}\n"

  local secret_name="${CRUCIBLE_RELEASE}-keycloak-auth"
  local encoded_password
  if ! encoded_password=$(kubectl get secret "$secret_name" -n "$CURRENT_NAMESPACE" -o jsonpath='{.data.admin-password}' 2>/dev/null); then
    echo "Unable to read secret ${secret_name} in namespace ${CURRENT_NAMESPACE}."
    return
  fi

  if [[ -z "$encoded_password" ]]; then
    echo "Secret ${secret_name} does not contain an admin-password key."
    return
  fi

  local decoded_password
  if ! decoded_password=$(echo "$encoded_password" | base64 --decode 2>/dev/null); then
    echo "Failed to decode the Keycloak admin password from secret ${secret_name}."
    return
  fi

  echo "  Username: keycloak-admin"
  echo "  Password: $decoded_password"
}

print_pgadmin_credentials() {
  echo -e "\n${BLUE}${BOLD}# pgAdmin credentials${RESET}\n"

  local secret_name="crucible-pgadmin"
  local encoded_password
  if ! encoded_password=$(kubectl get secret "$secret_name" -n "$CURRENT_NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null); then
    echo "Unable to read secret ${secret_name} in namespace ${CURRENT_NAMESPACE}."
    return
  fi

  if [[ -z "$encoded_password" ]]; then
    echo "Secret ${secret_name} does not contain a password key."
    return
  fi

  local decoded_password
  if ! decoded_password=$(echo "$encoded_password" | base64 --decode 2>/dev/null); then
    echo "Failed to decode the pgAdmin password from secret ${secret_name}."
    return
  fi

  echo "  Email: ${PGADMIN_EMAIL}"
  echo "  Password: $decoded_password"
}

start_minikube_cluster() {
  stage_custom_ca_certs

  echo -e "\n${BLUE}${BOLD}# Starting minikube cluster${RESET}\n"
  minikube start $MINIKUBE_FLAGS
}

purge_minikube_cluster() {
  echo -e "\n${BLUE}${BOLD}# Purging minikube cluster${RESET}\n"
  echo "Attempting sudo umount of ~/.minikube to release mounts (may prompt for sudo)"
  if ! sudo umount "${HOME}/.minikube"; then
    echo -e "${YELLOW}sudo umount ~/.minikube did not succeed; continuing${RESET}"
  fi
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

  echo -e "\n${BLUE}${BOLD}# Deleting completed/failed pods for ${CRUCIBLE_RELEASE}${RESET}\n"
  delete_finished_pods_for_release "$CRUCIBLE_RELEASE"

  echo -e "\n${BLUE}${BOLD}# Deleting PVCs/PVs for ${CRUCIBLE_RELEASE}${RESET}\n"
  delete_pvcs_for_release "$CRUCIBLE_RELEASE"

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
  if [[ "${chart_path}/Chart.yaml" -nt "${chart_path}/Chart.lock" ]]; then
    return 1
  fi
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
  if helm dependency build "$chart_path"; then
    return
  fi

  echo "Dependency build failed for ${chart_path}; refreshing lockfile and fetching missing charts"
  helm dependency update "$chart_path"
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
    echo -e "\n${BLUE}${BOLD}# Dependencies for ${chart_path} already present, skipping rebuild${RESET}\n"
  else
    echo -e "\n${BLUE}${BOLD}# Dependencies missing for ${chart_path}, rebuilding${RESET}\n"
    build_chart_dependencies "$chart"
  fi
}

# Build dependencies for Helm charts
CHARTS=("crucible")
for chart in "${CHARTS[@]}"; do
  ensure_chart_dependencies "$chart"
done

echo -e "\n${BLUE}${BOLD}# Helm installing ${CHARTS_DIR}/crucible${RESET}\n"
if helm status "$CRUCIBLE_RELEASE" &>/dev/null; then
  echo "Existing release detected; running helm upgrade"
  helm upgrade "$CRUCIBLE_RELEASE" "$CHARTS_DIR/crucible" ${HELM_UPGRADE_FLAGS}
else
  echo "Release not found; running helm install"
  helm install "$CRUCIBLE_RELEASE" "$CHARTS_DIR/crucible" ${HELM_UPGRADE_FLAGS}
fi

ensure_nodehosts_entry

echo -e "\n${BLUE}${BOLD}# Enabling port-forwarding${RESET}\n"
nohup kk port-forward -n default "service/crucible-ingress-nginx-controller" "443:443" > /dev/null 2>&1 &

print_web_app_urls
print_keycloak_admin_credentials
print_pgadmin_credentials

echo -e "\n${GREEN}${BOLD}Crucible has been deployed${RESET}\n"
