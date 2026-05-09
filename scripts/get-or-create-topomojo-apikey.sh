#!/bin/bash
set -e

# Wait for TopoMojo API to be ready
echo "Waiting for TopoMojo API..." >&2
until curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/user/ticket | grep -qE "200|401"; do
    sleep 2
done
echo "TopoMojo API is ready" >&2

# Get database connection details
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="topomojo"
DB_USER="postgres"
# Get password from the postgres container environment
DB_PASS=$(docker exec crucible-postgres printenv POSTGRES_PASSWORD)

# Check if API key already exists
echo "Checking for existing API key..." >&2
EXISTING_KEY=$(docker exec -e PGPASSWORD=$DB_PASS crucible-postgres psql -U $DB_USER -d $DB_NAME -tAc "
    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM \"ApiKeys\" ak
        JOIN \"Users\" u ON ak.\"UserId\" = u.\"Id\"
        WHERE u.\"ServiceAccountClientId\" = 'moodle-service-account' AND ak.\"Name\" = 'Moodle Integration'
    ) THEN 'exists' ELSE 'none' END;
")

if [ "$EXISTING_KEY" = "exists" ]; then
    echo "API key already exists, retrieving placeholder..." >&2
    # We can't retrieve the actual key since it's hashed
    # Output a marker that Moodle will need manual configuration
    echo "EXISTING_KEY_NEEDS_MANUAL_CONFIG"
    exit 0
fi

# Generate new API key
echo "Generating new API key..." >&2
API_KEY=$(openssl rand -base64 24 | tr '/' '_' | tr '+' '_')
API_KEY_HASH=$(echo -n "$API_KEY" | sha256sum | awk '{print $1}')
# Generate UUIDs using /proc/sys/kernel/random/uuid
USER_ID=$(cat /proc/sys/kernel/random/uuid | tr -d '-')
APIKEY_ID=$(cat /proc/sys/kernel/random/uuid | tr -d '-')

# Insert user and API key into database
docker exec -i -e PGPASSWORD=$DB_PASS crucible-postgres psql -U $DB_USER -d $DB_NAME <<EOF >&2
-- Insert service account user if not exists
INSERT INTO "Users" ("Id", "ServiceAccountClientId", "Name", "Role", "WhenCreated", "WorkspaceLimit", "GamespaceLimit", "GamespaceMaxMinutes", "GamespaceCleanupGraceMinutes")
VALUES ('$USER_ID', 'moodle-service-account', 'Moodle Service Account', 3, NOW(), 0, 0, 0, 0)
ON CONFLICT ("ServiceAccountClientId") DO NOTHING;

-- Get the user ID (in case it already existed)
DO \$\$
DECLARE
    existing_user_id TEXT;
BEGIN
    SELECT "Id" INTO existing_user_id FROM "Users" WHERE "ServiceAccountClientId" = 'moodle-service-account';

    -- Insert API key
    INSERT INTO "ApiKeys" ("Id", "UserId", "Name", "Hash", "WhenCreated")
    VALUES ('$APIKEY_ID', existing_user_id, 'Moodle Integration', '$API_KEY_HASH', NOW());
END \$\$;
EOF

echo "API key created successfully" >&2

# Write API key to a file that Moodle can read
mkdir -p /tmp/crucible
echo "$API_KEY" > /tmp/crucible/topomojo-apikey.txt
chmod 644 /tmp/crucible/topomojo-apikey.txt

echo "API key written to /tmp/crucible/topomojo-apikey.txt" >&2
# Also output to stdout
echo "$API_KEY"
