#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: build-and-load-image.sh <repo_path> [image_tag]

Builds a Docker image from the given repository path and loads it into minikube.
Arguments:
  repo_path  Path to the source repo that contains a Dockerfile.
  image_tag  Name:tag to apply when building and loading into minikube. Defaults to "<repo_dir_basename>:local-dev".

Environment:
  MINIKUBE_PROFILE  Optional. Defaults to "minikube".
  CA_CERT_PATH      Optional. Path to a custom CA cert (PEM) to trust only for this build. Defaults to /workspaces/crucible-development/.devcontainer/certs/crucible-dev.crt.
EOF
    exit 1
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

REPO_PATH="$1"
PROFILE="${MINIKUBE_PROFILE:-minikube}"
CA_CERT_PATH="${CA_CERT_PATH:-/workspaces/crucible-development/.devcontainer/certs/crucible-dev.crt}"
DOCKERFILE_PATH="$REPO_PATH/Dockerfile"
TEMP_FILES=()

cleanup() {
    for f in "${TEMP_FILES[@]:-}"; do
        [ -n "$f" ] && [ -f "$f" ] && rm -f "$f"
    done
}
trap cleanup EXIT

if [ ! -d "$REPO_PATH" ]; then
    echo "Repository path does not exist: $REPO_PATH" >&2
    exit 1
fi

if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Dockerfile not found at $DOCKERFILE_PATH" >&2
    exit 1
fi

REPO_PATH="$(realpath "$REPO_PATH")"
DOCKERFILE_PATH="$(realpath "$DOCKERFILE_PATH")"
REPO_BASENAME="$(basename "$REPO_PATH")"
DEFAULT_IMAGE_TAG="${REPO_BASENAME}:local-dev"
IMAGE_TAG="${2:-$DEFAULT_IMAGE_TAG}"
BUILD_DOCKERFILE="$DOCKERFILE_PATH"

if [ -n "$CA_CERT_PATH" ]; then
    if [ ! -f "$CA_CERT_PATH" ]; then
        echo "Custom CA certificate not found: $CA_CERT_PATH" >&2
        exit 1
    fi

    # Copy CA into build context and append a one-off trust step without editing the real Dockerfile.
    TEMP_CA_FILE="$(mktemp "$REPO_PATH/.tmp-ca-XXXXXX.crt")"
    cp "$CA_CERT_PATH" "$TEMP_CA_FILE"
    TEMP_FILES+=("$TEMP_CA_FILE")
    CA_BASENAME="$(basename "$TEMP_CA_FILE")"

    TEMP_DOCKERFILE="$(mktemp)"
    cat "$DOCKERFILE_PATH" > "$TEMP_DOCKERFILE"
    cat >> "$TEMP_DOCKERFILE" <<EOF

# Append trust setup just for this build (assumes stages named 'build' and 'prod')
FROM build AS build-with-ca
COPY $CA_BASENAME /usr/local/share/ca-certificates/extra-ca.crt
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

FROM prod AS prod-with-ca
COPY --from=build-with-ca /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build-with-ca /usr/local/share/ca-certificates/extra-ca.crt /usr/local/share/ca-certificates/extra-ca.crt
EOF
    TEMP_FILES+=("$TEMP_DOCKERFILE")
    BUILD_DOCKERFILE="$TEMP_DOCKERFILE"

    echo "Using custom CA cert '$CA_CERT_PATH' for this build (not persisted to Dockerfile)."
fi

echo "Building image '$IMAGE_TAG' from '$REPO_PATH'..."
DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}" docker build -t "$IMAGE_TAG" -f "$BUILD_DOCKERFILE" "$REPO_PATH"

echo "Loading image '$IMAGE_TAG' into minikube profile '$PROFILE'..."
minikube image load "$IMAGE_TAG" --profile "$PROFILE"

IMAGE_REPO="${IMAGE_TAG%:*}"
IMAGE_ONLY_TAG="${IMAGE_TAG##*:}"

cat <<EOF

✅ Image loaded into minikube ($PROFILE).
Copy/paste into your Helm values:

image:
  repository: $IMAGE_REPO
  tag: $IMAGE_ONLY_TAG
  pullPolicy: Never
EOF
