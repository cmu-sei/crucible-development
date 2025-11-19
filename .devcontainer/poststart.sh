#!/bin/bash
set -euo pipefail

# Start minikube
minikube start --mount-string="/mnt/data/terraform/root:/terraform/root" --embed-certs
