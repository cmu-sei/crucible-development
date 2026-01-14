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
  CA_CERT_PATHS     Optional. Comma-separated paths to custom CA certs (PEM) to trust only for this build.
                    Defaults to checking both .devcontainer/certs and .devcontainer/dev-certs directories.
EOF
    exit 1
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

REPO_PATH="$1"
PROFILE="${MINIKUBE_PROFILE:-minikube}"
DOCKERFILE_PATH="$REPO_PATH/Dockerfile"
TEMP_FILES=()

# Default CA cert paths - check both directories
REPO_ROOT="/workspaces/crucible-development"
DEFAULT_CERT_PATHS=""
if [ -d "${REPO_ROOT}/.devcontainer/dev-certs" ]; then
    for cert in "${REPO_ROOT}/.devcontainer/dev-certs"/*.crt; do
        if [ -f "$cert" ]; then
            DEFAULT_CERT_PATHS="${DEFAULT_CERT_PATHS}${cert},"
        fi
    done
fi
if [ -d "${REPO_ROOT}/.devcontainer/certs" ]; then
    for cert in "${REPO_ROOT}/.devcontainer/certs"/*.crt; do
        if [ -f "$cert" ]; then
            DEFAULT_CERT_PATHS="${DEFAULT_CERT_PATHS}${cert},"
        fi
    done
fi
# Remove trailing comma
DEFAULT_CERT_PATHS="${DEFAULT_CERT_PATHS%,}"

CA_CERT_PATHS="${CA_CERT_PATHS:-$DEFAULT_CERT_PATHS}"

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

if [ -n "$CA_CERT_PATHS" ]; then
    # Split comma-separated paths and copy all certs into build context
    IFS=',' read -ra CERT_ARRAY <<< "$CA_CERT_PATHS"
    CA_BASENAMES=()

    for cert_path in "${CERT_ARRAY[@]}"; do
        if [ ! -f "$cert_path" ]; then
            echo "Custom CA certificate not found: $cert_path" >&2
            continue
        fi

        # Copy CA into build context
        TEMP_CA_FILE="$(mktemp "$REPO_PATH/.tmp-ca-XXXXXX.crt")"
        cp "$cert_path" "$TEMP_CA_FILE"
        TEMP_FILES+=("$TEMP_CA_FILE")
        CA_BASENAMES+=("$(basename "$TEMP_CA_FILE")")
        echo "Including CA cert: $cert_path"
    done

    if [ ${#CA_BASENAMES[@]} -gt 0 ]; then
        # Build Dockerfile with all CA certs
        TEMP_DOCKERFILE="$(mktemp)"
        cat "$DOCKERFILE_PATH" > "$TEMP_DOCKERFILE"
        cat >> "$TEMP_DOCKERFILE" <<'DOCKEREOF'

# Append trust setup just for this build (assumes stages named 'build' and 'prod')
FROM build AS build-with-ca
DOCKEREOF

        # Copy all certs
        for ca_name in "${CA_BASENAMES[@]}"; do
            echo "COPY ${ca_name} /usr/local/share/ca-certificates/${ca_name}" >> "$TEMP_DOCKERFILE"
        done

        cat >> "$TEMP_DOCKERFILE" <<'DOCKEREOF'
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

FROM prod AS prod-with-ca
COPY --from=build-with-ca /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
DOCKEREOF

        # Copy all certs to prod stage
        for ca_name in "${CA_BASENAMES[@]}"; do
            echo "COPY --from=build-with-ca /usr/local/share/ca-certificates/${ca_name} /usr/local/share/ca-certificates/${ca_name}" >> "$TEMP_DOCKERFILE"
        done

        TEMP_FILES+=("$TEMP_DOCKERFILE")
        BUILD_DOCKERFILE="$TEMP_DOCKERFILE"

        echo "Using custom CA certificates for this build (not persisted to Dockerfile)."
    fi
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
