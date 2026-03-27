#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

log_header() { echo -e "\n${BLUE}${BOLD}# $1${RESET}\n"; }
log_warn() { echo -e "${YELLOW}$1${RESET}"; }
log_error() { echo -e "${RED}$1${RESET}"; }

show_usage() {
  cat <<EOF
Usage: $0 [--delete | --purge]

Options:
  --delete   Deletes and restarts minikube using cached artifacts
  --purge    Deletes and recreates the minikube cluster (removes cache too)

Exactly one option must be specified.
EOF
}

# Parse arguments
MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete) MODE="delete" ;;
    --purge)  MODE="purge" ;;
    -h|--help) show_usage; exit 0 ;;
    *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
  esac
  shift
done

if [[ -z "$MODE" ]]; then
  log_error "Must specify --delete or --purge"
  show_usage
  exit 1
fi

if [[ "$MODE" == "purge" ]]; then
  log_header "Purging minikube cluster"
  echo "Attempting sudo umount of ~/.minikube to release mounts (may prompt for sudo)"
  sudo umount "${HOME}/.minikube" 2>/dev/null || log_warn "sudo umount ~/.minikube did not succeed; continuing"
  minikube delete --all --purge
elif [[ "$MODE" == "delete" ]]; then
  log_header "Deleting minikube cluster (preserving cache)"
  minikube delete --all
fi

# Restart minikube after reset
"${SCRIPT_DIR}/start-minikube.sh"
