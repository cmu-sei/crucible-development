#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Match the UI hosting mode and login settings of the running AppHost:
#   bash tests/rangerai-smoke.sh dev           # RangerAI
#   bash tests/rangerai-smoke.sh dev keycloak  # RangerAI + Keycloak
#   bash tests/rangerai-smoke.sh prod          # Launch:Prod includes RangerAI
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || ! $1 =~ ^(dev|prod)$ || ($# == 2 && $2 != keycloak) ]]; then
  echo "Usage: bash tests/rangerai-smoke.sh dev|prod [keycloak]" >&2
  exit 2
fi
mode=$1

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

if [[ ${2:-} == keycloak ]]; then
  for path in localhost:4320/api/chronicles localhost:4330/api/me localhost:4330/api/admin/scenario-types; do
    status=$(curl -sS --output /dev/null --write-out '%{http_code}' "http://$path")
    [[ $status == 401 ]] || { echo "$path returned $status, expected 401" >&2; exit 1; }
  done

  check_login() {
    local port=$1 client=$2 redirect query
    redirect=$(curl -fsS --output /dev/null --write-out '%{redirect_url}' "http://localhost:$port/api/auth/login")
    query="&${redirect#*\?}&"
    if [[ $redirect != https://localhost:8443/realms/crucible/protocol/openid-connect/auth\?* ||
          $query != *"&client_id=$client&"* ]]; then
      echo "Expected the UI on $port to redirect to Keycloak with client $client" >&2
      exit 1
    fi
  }
  check_login 4320 chronicle.ui
  check_login 4330 scenario-builder.ui
  echo "RangerAI $mode UI routes, anonymous access checks and Keycloak login redirects passed."
  exit 0
fi

curl -fsS http://localhost:4320/api/chronicles | jq -e 'type == "array"' >/dev/null
curl -fsS http://localhost:4330/api/me | jq -e '.user == "dev" and .admin == true' >/dev/null
curl -fsS http://localhost:4330/api/admin/scenario-types | jq -e 'type == "array"' >/dev/null
echo "RangerAI $mode UI routes, API proxies and default administrator passed."
