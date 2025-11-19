#!/bin/bash
set -euo pipefail

# Start minikube
minikube start --mount-string="/mnt/data/terraform/root:/terraform/root" --embed-certs

# Paths inside the devcontainer
WORKSPACE="/workspaces/crucible-development"
APPHOST="$WORKSPACE/Crucible.AppHost"
MOODLE_CERT_DIR="$APPHOST/resources/moodle/certs"
ZSCALER_SRC="$WORKSPACE/.devcontainer/certs/ZscalerRootCertificate-2048-SHA256.crt"

if [ -f "$ZSCALER_SRC" ]; then
  echo "Copying Zscaler cert into Moodle resources..."
  mkdir -p "$MOODLE_CERT_DIR"
  cp -f "$ZSCALER_SRC" "$MOODLE_CERT_DIR/"
else
  echo "Zscaler cert not found at $ZSCALER_SRC, skipping Moodle cert copy."
fi
