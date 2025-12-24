#!/bin/bash

set -euo pipefail

CRUCIBLE_RELEASE=${CRUCIBLE_RELEASE:-crucible-infra}
CRUCIBLE_NAMESPACE=${CRUCIBLE_NAMESPACE:-default}

echo "Using release '$CRUCIBLE_RELEASE' in namespace '$CRUCIBLE_NAMESPACE'."

# Locate the postgres StatefulSet for this release.
POSTGRES_STS=$(
  kubectl get statefulset -n "$CRUCIBLE_NAMESPACE" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.app\.kubernetes\.io/name}{"\t"}{.metadata.labels.app\.kubernetes\.io/instance}{"\n"}{end}' 2>/dev/null \
    | awk -v rel="$CRUCIBLE_RELEASE" '$3==rel && $1 ~ /postgres/ {print $1; exit}'
)

if [[ -z "$POSTGRES_STS" ]]; then
  echo "No postgres StatefulSet found for release '$CRUCIBLE_RELEASE' in namespace '$CRUCIBLE_NAMESPACE'."
  exit 1
fi

echo "Found postgres StatefulSet: $POSTGRES_STS"

# Gather PVC, PV, and hostPath details before deleting anything.
mapfile -t PVC_INFO < <(
  kubectl get pvc -n "$CRUCIBLE_NAMESPACE" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.volumeName}{"\t"}{range .metadata.ownerReferences[*]}{.kind}{"\t"}{.name}{"\t"}{end}{"\n"}{end}' 2>/dev/null \
    | awk -v sts="$POSTGRES_STS" '
        {
          pvc=$1; pv=$2; owned=0;
          for (i=3; i<=NF; i+=2) {
            kind=$(i); name=$(i+1);
            if (kind=="StatefulSet" && name==sts) { owned=1; }
          }
          if (!owned && pvc ~ ("^data-" sts "-[0-9]+$")) { owned=1; }
          if (owned) { print pvc "|" pv; }
        }
      ' \
    | while IFS="|" read -r pvc pv; do
        hostpath=""
        if [[ -n "$pv" ]]; then
          hostpath=$(kubectl get pv "$pv" -o jsonpath='{.spec.hostPath.path}' 2>/dev/null || true)
        fi
        echo "${pvc}|${pv}|${hostpath}"
      done
)

echo "Deleting StatefulSet $POSTGRES_STS and its pods..."
kubectl delete statefulset "$POSTGRES_STS" -n "$CRUCIBLE_NAMESPACE" --wait=true

# Wait for postgres-labeled pods to disappear; ignore failures if labels differ.
kubectl wait --for=delete pod -n "$CRUCIBLE_NAMESPACE" -l "app.kubernetes.io/instance=${CRUCIBLE_RELEASE},app.kubernetes.io/name=postgres" --timeout=120s 2>/dev/null || true
kubectl wait --for=delete pod -n "$CRUCIBLE_NAMESPACE" -l "app.kubernetes.io/instance=${CRUCIBLE_RELEASE},app.kubernetes.io/name=postgresql" --timeout=120s 2>/dev/null || true

if (( ${#PVC_INFO[@]} == 0 )); then
  echo "No PVCs owned by ${POSTGRES_STS} were found; nothing to remove."
else
  echo "Deleting PVCs and bound PVs for ${POSTGRES_STS}..."
fi

for entry in "${PVC_INFO[@]}"; do
  IFS='|' read -r pvc pv hostpath <<< "$entry"
  echo "Deleting PVC ${pvc}..."
  kubectl delete pvc "$pvc" -n "$CRUCIBLE_NAMESPACE" --ignore-not-found
done

for entry in "${PVC_INFO[@]}"; do
  IFS='|' read -r pvc pv hostpath <<< "$entry"
  [[ -z "$pv" ]] && continue
  echo "Deleting PV ${pv}..."
  kubectl delete pv "$pv" --ignore-not-found
done

# Remove hostPath data on the minikube node when it is safe to do so.
for entry in "${PVC_INFO[@]}"; do
  IFS='|' read -r pvc pv hostpath <<< "$entry"
  [[ -z "$hostpath" ]] && continue

  if [[ "$hostpath" == /tmp/hostpath-provisioner/* ]]; then
    echo "Removing hostPath data from minikube node: $hostpath"
    minikube ssh "sudo rm -rf \"$hostpath\""
  else
    echo "Skipping hostPath cleanup for ${pv:-unknown} (unexpected path: '$hostpath')."
  fi
done

echo "Postgres data removed. Helm will provision fresh storage on the next deployment."
