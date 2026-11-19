#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Run against the published RangerAI version with its default local identity:
#   bash tests/rangerai-smoke.sh dev   # RangerAI + Keycloak
#   bash tests/rangerai-smoke.sh prod  # Launch:Prod includes RangerAI
set -euo pipefail

case "${1:-}" in
  dev|prod) mode=$1 ;;
  *) echo "Usage: bash tests/rangerai-smoke.sh dev|prod" >&2; exit 2 ;;
esac

# Exercise client-side routes and the API through the browser-facing ports.
for route in http://localhost:4320/events/harbor-ttx http://localhost:4330/admin; do
  page=$(curl -fsS -H 'Accept: text/html' "$route")
  grep -q '<app-root' <<<"$page"
  if [[ $mode == dev ]]; then
    grep -q '/@vite/client' <<<"$page"
  elif grep -q '/@vite/client' <<<"$page"; then
    echo "Production route $route loaded the Vite development client" >&2
    exit 1
  fi
done

curl -fsS http://localhost:4320/api/chronicles | jq -e 'type == "array"' >/dev/null
curl -fsS http://localhost:4330/api/me | jq -e '.user == "dev" and .admin == true' >/dev/null
curl -fsS http://localhost:4330/api/admin/scenario-types | jq -e 'type == "array"' >/dev/null
echo "RangerAI $mode UI routes, API proxies and default administrator passed."
