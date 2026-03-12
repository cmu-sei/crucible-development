#!/bin/bash

STATUS=$(minikube status --output json)

# Extract specific states using jq
HOST_STATE=$(echo $STATUS | jq -r .Host)
KUBELET_STATE=$(echo $STATUS | jq -r .Kubelet)
APISERVER_STATE=$(echo $STATUS | jq -r .APIServer)

if [[ "$HOST_STATE" == "Running" && "$KUBELET_STATE" == "Running" && "$APISERVER_STATE" == "Running" ]]; then
    echo "minikube is operational."
else
    echo "minikube is not running. Starting now..."
    minikube start --mount-string="/mnt/data/terraform:/mnt/data/terraform" --embed-certs

    echo "Configuring kubelet for parallel image pulls..."
    minikube ssh "sudo sed -i 's/serializeImagePulls: true/serializeImagePulls: false/' /var/lib/kubelet/config.yaml || echo 'serializeImagePulls: false' | sudo tee -a /var/lib/kubelet/config.yaml"
    minikube ssh "sudo systemctl restart kubelet"
fi

# Regenerate caster-certs ConfigMap with all trusted certificates
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/../.devcontainer/certs"
DEV_CERT_DIR="/home/vscode/.aspnet/dev-certs/trust"

echo "Regenerating caster-certs ConfigMap..."

CERT_ARGS=()
for dir in "$CERTS_DIR" "$DEV_CERT_DIR"; do
    for f in "$dir"/*.crt "$dir"/*.pem; do
        [ -f "$f" ] && CERT_ARGS+=("--from-file=$f")
    done
done

if [ ${#CERT_ARGS[@]} -gt 0 ]; then
    kubectl create configmap caster-certs "${CERT_ARGS[@]}" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "caster-certs ConfigMap created/updated with ${#CERT_ARGS[@]} certificate(s)."
else
    echo "Warning: No certificate files found."
fi
