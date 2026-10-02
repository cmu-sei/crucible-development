#!/bin/bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Make crucible-admin usable as the APIs' machine-to-machine identity: every
# ResourceOwnerAuthorization/IdentityClient in AppHost.cs logs in as
# crucible-admin / admin, and the APIs only honor its Administrator realm role.
# crucible-realm.json is imported once, into a Keycloak database that persists, so
# fixing the export alone never reaches an existing environment; this applies
# both settings through the admin API on every launch instead.
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
REALM="crucible"
SERVICE_USER="crucible-admin"
SERVICE_PASSWORD="admin"
SERVICE_ROLE="Administrator"

echo "Waiting for the $REALM realm..." >&2
for _ in $(seq 1 60); do
    curl -ksf -o /dev/null "$KEYCLOAK_URL/realms/$REALM" && break
    sleep 2
done

# KC_BOOTSTRAP_ADMIN_PASSWORD in AppHost.cs; Aspire's default bootstrap username
admin_token=$(curl -ksf "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -d grant_type=password -d client_id=admin-cli -d username=admin -d password=admin \
    | jq -r '.access_token')

kc() {
    curl -ksf -H "Authorization: Bearer $admin_token" -H "Content-Type: application/json" "$@"
}

admin_api="$KEYCLOAK_URL/admin/realms/$REALM"

user_id=$(kc "$admin_api/users?username=$SERVICE_USER&exact=true" | jq -r '.[0].id // empty')
if [ -z "$user_id" ]; then
    echo "User $SERVICE_USER not found in the $REALM realm" >&2
    exit 1
fi

kc -X PUT "$admin_api/users/$user_id/reset-password" \
    -d "$(jq -n --arg value "$SERVICE_PASSWORD" '{type: "password", value: $value, temporary: false}')"
echo "Set $SERVICE_USER password" >&2

# Adding a role the user already holds is a no-op
role=$(kc "$admin_api/roles/$SERVICE_ROLE")
kc -X POST "$admin_api/users/$user_id/role-mappings/realm" -d "[$role]"
echo "Granted $SERVICE_USER the $SERVICE_ROLE realm role" >&2
