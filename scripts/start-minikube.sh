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
