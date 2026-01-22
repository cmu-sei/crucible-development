#!/usr/bin/env bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Builds a Docker image from a repository and loads it into minikube.
# Optionally injects custom CA certificates into the build.

set -euo pipefail

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

SCRIPT_NAME="${0##*/}"
REPO_ROOT="/workspaces/crucible-development"
DEFAULT_PROFILE="minikube"
DEFAULT_TAG_SUFFIX="local-dev"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

log_info()   { echo -e "${BLUE}${BOLD}==>${RESET} $1"; }
log_warn()   { echo -e "${YELLOW}Warning:${RESET} $1" >&2; }
log_error()  { echo -e "${RED}Error:${RESET} $1" >&2; }
log_success() { echo -e "${GREEN}${BOLD}$1${RESET}"; }

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} <repo_path> [image_tag]

Builds a Docker image from the given repository path and loads it into minikube.

Arguments:
  repo_path   Path to the source repository containing a Dockerfile.
  image_tag   Image name:tag for the build. Defaults to "<repo_basename>:${DEFAULT_TAG_SUFFIX}".

Environment Variables:
  MINIKUBE_PROFILE  Minikube profile to use. Default: "${DEFAULT_PROFILE}"
  CA_CERT_PATHS     Comma-separated paths to custom CA certificates (PEM format).
                    Default: All .crt files in .devcontainer/certs and .devcontainer/dev-certs

Examples:
  ${SCRIPT_NAME} /mnt/data/crucible/player-api
  ${SCRIPT_NAME} /mnt/data/crucible/player-api player-api:v1.0.0
  CA_CERT_PATHS=/path/to/cert.crt ${SCRIPT_NAME} /mnt/data/crucible/player-api
EOF
    exit 1
}

# -----------------------------------------------------------------------------
# Cleanup Handler
# -----------------------------------------------------------------------------

TEMP_FILES=()

cleanup() {
    local file
    for file in "${TEMP_FILES[@]:-}"; do
        [[ -n "$file" && -f "$file" ]] && rm -f "$file"
    done
}

trap cleanup EXIT

# -----------------------------------------------------------------------------
# Certificate Discovery Functions
# -----------------------------------------------------------------------------

# Discovers default CA certificate paths from the devcontainer directories.
# Outputs a comma-separated list of certificate paths.
discover_default_cert_paths() {
    local cert_paths=""
    local cert_dirs=(
        "${REPO_ROOT}/.devcontainer/dev-certs"
        "${REPO_ROOT}/.devcontainer/certs"
    )

    for dir in "${cert_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for cert in "$dir"/*.crt; do
            [[ -f "$cert" ]] && cert_paths="${cert_paths}${cert},"
        done
    done

    # Remove trailing comma and output
    echo "${cert_paths%,}"
}

# -----------------------------------------------------------------------------
# Argument Parsing and Validation
# -----------------------------------------------------------------------------

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
fi

# Parse positional arguments
REPO_PATH="$1"
PROFILE="${MINIKUBE_PROFILE:-$DEFAULT_PROFILE}"

# Validate repository path exists
if [[ ! -d "$REPO_PATH" ]]; then
    log_error "Repository path does not exist: $REPO_PATH"
    exit 1
fi

# Resolve to absolute paths
REPO_PATH="$(realpath "$REPO_PATH")"
DOCKERFILE_PATH="${REPO_PATH}/Dockerfile"

# Validate Dockerfile exists
if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    log_error "Dockerfile not found at: $DOCKERFILE_PATH"
    exit 1
fi

# Derive image tag from repo name if not provided
REPO_BASENAME="$(basename "$REPO_PATH")"
IMAGE_TAG="${2:-${REPO_BASENAME}:${DEFAULT_TAG_SUFFIX}}"

# Discover CA certificates (use environment variable or auto-discover)
CA_CERT_PATHS="${CA_CERT_PATHS:-$(discover_default_cert_paths)}"

# Track which Dockerfile to use for the build
BUILD_DOCKERFILE="$DOCKERFILE_PATH"

# -----------------------------------------------------------------------------
# Certificate Injection Functions
# -----------------------------------------------------------------------------

# Copies CA certificates into the build context and returns their basenames.
# Arguments: comma-separated list of certificate paths
# Sets: CA_BASENAMES array with the temporary certificate filenames
stage_certificates_in_build_context() {
    local cert_paths="$1"
    local cert_path

    CA_BASENAMES=()

    # Split comma-separated paths
    IFS=',' read -ra cert_array <<< "$cert_paths"

    for cert_path in "${cert_array[@]}"; do
        # Skip empty entries
        [[ -z "$cert_path" ]] && continue

        if [[ ! -f "$cert_path" ]]; then
            log_warn "CA certificate not found, skipping: $cert_path"
            continue
        fi

        # Copy certificate into build context with a unique temporary name
        local temp_ca_file
        temp_ca_file="$(mktemp "${REPO_PATH}/.tmp-ca-XXXXXX.crt")"
        cp "$cert_path" "$temp_ca_file"
        TEMP_FILES+=("$temp_ca_file")
        CA_BASENAMES+=("$(basename "$temp_ca_file")")
        log_info "Including CA certificate: $cert_path"
    done
}

# Generates a modified Dockerfile that injects CA certificates.
# Assumes the original Dockerfile has stages named 'build' and 'prod'.
# Arguments: original Dockerfile path, array of certificate basenames
# Returns: path to the generated temporary Dockerfile
generate_ca_injected_dockerfile() {
    local original_dockerfile="$1"
    shift
    local ca_names=("$@")

    local temp_dockerfile
    temp_dockerfile="$(mktemp)"

    # Start with the original Dockerfile content
    cat "$original_dockerfile" > "$temp_dockerfile"

    # Append CA injection stages
    cat >> "$temp_dockerfile" <<'DOCKEREOF'

# ============================================================================
# CA Certificate Injection (auto-generated, not persisted)
# Assumes the original Dockerfile has stages named 'build' and 'prod'
# ============================================================================

FROM build AS build-with-ca
DOCKEREOF

    # Add COPY instructions for each certificate
    local ca_name
    for ca_name in "${ca_names[@]}"; do
        echo "COPY ${ca_name} /usr/local/share/ca-certificates/${ca_name}" >> "$temp_dockerfile"
    done

    # Install certificates and update trust store
    cat >> "$temp_dockerfile" <<'DOCKEREOF'
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

FROM prod AS prod-with-ca
COPY --from=build-with-ca /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
DOCKEREOF

    # Copy certificate files to prod stage for runtime trust
    for ca_name in "${ca_names[@]}"; do
        echo "COPY --from=build-with-ca /usr/local/share/ca-certificates/${ca_name} /usr/local/share/ca-certificates/${ca_name}" >> "$temp_dockerfile"
    done

    echo "$temp_dockerfile"
}

# -----------------------------------------------------------------------------
# Docker Build and Load Functions
# -----------------------------------------------------------------------------

build_docker_image() {
    local image_tag="$1"
    local dockerfile="$2"
    local context_path="$3"

    log_info "Building image '${image_tag}' from '${context_path}'..."
    DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}" docker build \
        --tag "$image_tag" \
        --file "$dockerfile" \
        "$context_path"
}

load_image_to_minikube() {
    local image_tag="$1"
    local profile="$2"

    log_info "Loading image '${image_tag}' into minikube profile '${profile}'..."
    minikube image load "$image_tag" --profile "$profile"
}

print_helm_values() {
    local image_tag="$1"
    local profile="$2"

    # Parse image repository and tag
    local image_repo="${image_tag%:*}"
    local image_only_tag="${image_tag##*:}"

    cat <<EOF

$(log_success "Image loaded into minikube (${profile}).")

Copy/paste into your Helm values:

image:
  repository: ${image_repo}
  tag: ${image_only_tag}
  pullPolicy: Never
EOF
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

main() {
    # Handle CA certificate injection if certificates are available
    if [[ -n "$CA_CERT_PATHS" ]]; then
        stage_certificates_in_build_context "$CA_CERT_PATHS"

        if [[ ${#CA_BASENAMES[@]} -gt 0 ]]; then
            log_info "Generating Dockerfile with CA certificate injection..."
            BUILD_DOCKERFILE="$(generate_ca_injected_dockerfile "$DOCKERFILE_PATH" "${CA_BASENAMES[@]}")"
            TEMP_FILES+=("$BUILD_DOCKERFILE")
        fi
    fi

    # Build the Docker image
    build_docker_image "$IMAGE_TAG" "$BUILD_DOCKERFILE" "$REPO_PATH"

    # Load into minikube
    load_image_to_minikube "$IMAGE_TAG" "$PROFILE"

    # Print Helm values for easy copy/paste
    print_helm_values "$IMAGE_TAG" "$PROFILE"
}

main
