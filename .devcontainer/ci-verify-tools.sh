#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Runs inside the built devcontainer via devcontainers/ci. Asserts each core
# tool is on PATH and can report its version. Exits non-zero on the first
# missing or broken tool.

set -euo pipefail

fail=0

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok    %-12s %s\n' "$name" "$("$@" 2>&1 | head -n1)"
  else
    printf '  FAIL  %-12s (command: %s)\n' "$name" "$*"
    fail=1
  fi
}

echo "Verifying core tools..."
check dotnet     dotnet --version
check aspire     aspire --version
check node       node --version
check npm        npm --version
check gh         gh --version
check kubectl    kubectl version --client=true
check helm       helm version --short
check minikube   minikube version --short
check kubefwd    kubefwd version
check docker     docker --version
check terraform  terraform version
check go         go version
check task       task --version
check aws        aws --version
check vale       vale --version
check playwright playwright-cli --version
check claude     claude --version
check codex      codex --version
check dotnet-ef  dotnet ef --version
check ng         ng --version

if [ "$fail" -ne 0 ]; then
  echo
  echo "One or more tool checks failed."
  exit 1
fi

echo
echo "All tool checks passed."
