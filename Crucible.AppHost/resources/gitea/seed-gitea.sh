#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Seeds the dev Gitea with an admin user, an org and a public copy of the
# local Terraform module catalog, so Caster can read modules over http the
# same way it would from a real git server. Safe to re-run: the push mirrors
# the catalog's current branches and tags.

set -euo pipefail

GITEA_CONTAINER="${GITEA_CONTAINER:-gitea}"
GITEA_URL="${GITEA_URL:-http://localhost:3010}"
GITEA_USER="${GITEA_USER:-crucible-admin}"
GITEA_PASSWORD="${GITEA_PASSWORD:-admin}"
GITEA_ORG="${GITEA_ORG:-crucible}"
CATALOG_PATH="${CATALOG_PATH:-/mnt/data/crucible/crucible-terraform-modules}"
CATALOG_REPO="$(basename "$CATALOG_PATH")"

if ! docker exec -u git "$GITEA_CONTAINER" gitea admin user list --admin | awk '{print $2}' | grep -qx "$GITEA_USER"; then
  docker exec -u git "$GITEA_CONTAINER" gitea admin user create --admin \
    --username "$GITEA_USER" --password "$GITEA_PASSWORD" \
    --email "$GITEA_USER@crucible.local" --must-change-password=false
fi

api() {
  # Prints the status code; 409/422 mean the org or repo already exists.
  curl -s -o /dev/null -w '%{http_code}' -u "$GITEA_USER:$GITEA_PASSWORD" \
    -H 'Content-Type: application/json' -X POST "$GITEA_URL/api/v1/$1" -d "$2"
}

echo "Create org $GITEA_ORG: $(api orgs "{\"username\":\"$GITEA_ORG\",\"visibility\":\"public\"}")"

if [[ ! -d "$CATALOG_PATH/.git" ]]; then
  echo "No git repo at $CATALOG_PATH; skipping catalog push"
  exit 0
fi

echo "Create repo $GITEA_ORG/$CATALOG_REPO: $(api "orgs/$GITEA_ORG/repos" "{\"name\":\"$CATALOG_REPO\",\"private\":false}")"

# Public repo, so Caster and the job pods clone it without credentials.
# credential.helper= stops the VS Code helper from prompting.
git -C "$CATALOG_PATH" -c credential.helper= push --force \
  "http://$GITEA_USER:$GITEA_PASSWORD@${GITEA_URL#http://}/$GITEA_ORG/$CATALOG_REPO.git" \
  'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*'

echo "Catalog at $GITEA_URL/$GITEA_ORG/$CATALOG_REPO"
