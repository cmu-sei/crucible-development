#!/bin/bash
# Creates a TopoMojo workspace with multiple variants for testing mod_topomojo
# Each variant has different templates and questions

set -e

# Validation
if [ -z "$TOPOMOJO_API_URL" ]; then
    echo "Error: TOPOMOJO_API_URL is not set"
    echo "Example: export TOPOMOJO_API_URL='http://localhost:5000'"
    exit 1
fi

# Get Keycloak token if not provided
if [ -z "$KEYCLOAK_TOKEN" ]; then
    KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
    KEYCLOAK_USERNAME="${KEYCLOAK_USERNAME:-admin}"
    KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"

    echo "Getting Keycloak token..."
    TOKEN_RESPONSE=$(curl -k -s -X POST "${KEYCLOAK_URL}/realms/crucible/protocol/openid-connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d "client_id=topomojo.ui" \
        -d "grant_type=password" \
        -d "username=${KEYCLOAK_USERNAME}" \
        -d "password=${KEYCLOAK_PASSWORD}" \
        -d "scope=openid profile topomojo")

    KEYCLOAK_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

    if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" = "null" ]; then
        echo "Error: Failed to get Keycloak token"
        echo "Response: $TOKEN_RESPONSE"
        exit 1
    fi

    echo "✓ Token acquired"
fi

# Script parameters
WORKSPACE_NAME="${WORKSPACE_NAME:-Moodle Test Workspace - Variants}"
WORKSPACE_DESCRIPTION="${WORKSPACE_DESCRIPTION:-Test workspace with 3 variants for mod_topomojo testing}"
WORKSPACE_TAGS="${WORKSPACE_TAGS:-test,moodle}"

echo "Creating TopoMojo workspace with variants..."
echo "API URL: $TOPOMOJO_API_URL"
echo "Workspace: $WORKSPACE_NAME"
echo ""

# Check if workspace exists
echo "Checking if workspace exists..."
LIST_RESPONSE=$(curl -k -s -X GET "${TOPOMOJO_API_URL}/api/workspaces" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

WORKSPACE_ID=$(echo "$LIST_RESPONSE" | jq -r ".[] | select(.name == \"${WORKSPACE_NAME}\") | .id" | head -1)

if [ -n "$WORKSPACE_ID" ] && [ "$WORKSPACE_ID" != "null" ]; then
    echo "✓ Workspace already exists: $WORKSPACE_ID"
    echo ""
    echo "Deleting existing workspace to recreate with fresh data..."
    curl -k -s -X DELETE "${TOPOMOJO_API_URL}/api/workspace/${WORKSPACE_ID}" \
      -H "Authorization: Bearer ${KEYCLOAK_TOKEN}"
    echo "✓ Deleted existing workspace"
fi

# Create new workspace
echo "Creating new workspace..."
WORKSPACE_RESPONSE=$(curl -k -s -X POST "${TOPOMOJO_API_URL}/api/workspace" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${WORKSPACE_NAME}\",
    \"description\": \"${WORKSPACE_DESCRIPTION}\",
    \"tags\": \"${WORKSPACE_TAGS}\"
  }")

WORKSPACE_ID=$(echo "$WORKSPACE_RESPONSE" | jq -r '.id')
echo "✓ Workspace created: $WORKSPACE_ID"
echo ""

# Create challenge JSON with 3 variants
# Each variant has 3 questions with different answers
echo "Creating challenge spec with 3 variants..."

CHALLENGE_JSON=$(cat <<'CHALLENGE_EOF'
{
  "text": "# Moodle Test Challenge\n\nThis challenge has 3 variants for testing mod_topomojo random variant assignment.",
  "maxPoints": 0,
  "maxAttempts": 0,
  "transforms": [],
  "variants": [
    {
      "text": "# Variant 1: Linux Basics",
      "sections": [
        {
          "name": "Basic Commands",
          "text": "",
          "preReqTotal": 0,
          "preReqPrevSection": 0,
          "questions": [
            {
              "text": "What is the command to list files in the current directory?",
              "answer": "ls",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            },
            {
              "text": "What is the command to print the current working directory?",
              "answer": "pwd",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            },
            {
              "text": "What is the command to change to the home directory?",
              "answer": "cd ~",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            }
          ]
        }
      ]
    },
    {
      "text": "# Variant 2: Network Tools",
      "sections": [
        {
          "name": "Network Commands",
          "text": "",
          "preReqTotal": 0,
          "preReqPrevSection": 0,
          "questions": [
            {
              "text": "What is the command to display network interfaces?",
              "answer": "ip addr",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            },
            {
              "text": "What is the command to test connectivity to a host?",
              "answer": "ping",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            },
            {
              "text": "What is the command to display routing table?",
              "answer": "ip route",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            }
          ]
        }
      ]
    },
    {
      "text": "# Variant 3: File Operations",
      "sections": [
        {
          "name": "File Management",
          "text": "",
          "preReqTotal": 0,
          "preReqPrevSection": 0,
          "questions": [
            {
              "text": "What is the command to copy a file?",
              "answer": "cp",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            },
            {
              "text": "What is the command to move or rename a file?",
              "answer": "mv",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            },
            {
              "text": "What is the command to remove a file?",
              "answer": "rm",
              "weight": 1.0,
              "penalty": 0,
              "grader": 0,
              "hidden": false
            }
          ]
        }
      ]
    }
  ]
}
CHALLENGE_EOF
)

# Update challenge using dedicated challenge endpoint
HTTP_CODE=$(curl -k -s -w "%{http_code}" -o /dev/null -X PUT "${TOPOMOJO_API_URL}/api/challenge/${WORKSPACE_ID}" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$CHALLENGE_JSON")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
    echo "✓ Challenge spec added with 3 variants (HTTP $HTTP_CODE)"
else
    echo "⚠ Warning: Challenge update failed with HTTP $HTTP_CODE"
fi
echo ""

# Find and link global templates to workspace
echo "Finding global templates and linking to workspace..."

# Get all global templates
ALL_TEMPLATES=$(curl -k -s -X GET "${TOPOMOJO_API_URL}/api/templates" \
  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}")

# Template names we want to use for each variant
TEMPLATE_NAMES=("TinyCore-ISO" "Alpine-Disk" "Puppy-Linux")
TEMPLATE_IDS=()

for i in {0..2}; do
    VARIANT=$((i + 1))
    TEMPLATE_NAME="${TEMPLATE_NAMES[$i]}"

    echo "Finding template ${VARIANT}: ${TEMPLATE_NAME}..."

    # Find template ID by name
    TEMPLATE_ID=$(echo "$ALL_TEMPLATES" | jq -r ".[] | select(.name == \"$TEMPLATE_NAME\") | .id" | head -1)

    if [ -n "$TEMPLATE_ID" ] && [ "$TEMPLATE_ID" != "null" ]; then
        echo "  ✓ Found template: $TEMPLATE_ID"
        TEMPLATE_IDS+=("$TEMPLATE_ID")

        # Link template to workspace
        curl -k -s -X POST "${TOPOMOJO_API_URL}/api/workspace/${WORKSPACE_ID}/template" \
          -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"templateId\": \"${TEMPLATE_ID}\"}" > /dev/null

        echo "  ✓ Template linked to workspace"
    else
        echo "  ⚠ Warning: Template not found: $TEMPLATE_NAME"
        echo "  Make sure to run create-topomojo-workspace-template.sh first to create global templates"
    fi
done

echo ""
echo "==============================================="
echo "SUCCESS!"
echo "==============================================="
echo "Workspace ID: $WORKSPACE_ID"
echo "Workspace Name: $WORKSPACE_NAME"
echo ""
echo "Challenge Structure:"
echo "  Variant 1: Linux Basics (3 questions about basic commands)"
echo "  Variant 2: Network Tools (3 questions about network commands)"
echo "  Variant 3: File Operations (3 questions about file management)"
echo ""
echo "Templates Linked:"
echo "  Variant 1: TinyCore-ISO"
echo "  Variant 2: Alpine-Disk"
echo "  Variant 3: Puppy-Linux"
echo ""
echo "View in TopoMojo UI:"
echo "  ${TOPOMOJO_API_URL}/topo/workspace/${WORKSPACE_ID}"
echo ""
echo "Next steps for Moodle testing:"
echo "  1. In Moodle, create a new TopoMojo activity"
echo "  2. Set Workspace ID to: ${WORKSPACE_ID}"
echo "  3. Enable 'Import challenge questions'"
echo "  4. Set Variant to 'Random' (or specific 1-3 for testing)"
echo "  5. Save and view Questions tab"
echo ""
echo "Testing scenarios:"
echo "  A. Specific variant: Set variant=1, verify only Variant 1 questions import"
echo "  B. Random variant: Set variant=0, verify ALL variants import"
echo "  C. Deploy as student: Verify only deployed variant questions shown"
echo "  D. Auto-import: Delete questions, verify they re-import on deploy"
echo ""
echo "To delete this workspace:"
echo "  curl -k -X DELETE '${TOPOMOJO_API_URL}/api/workspace/${WORKSPACE_ID}' \\"
echo "    -H 'Authorization: Bearer ${KEYCLOAK_TOKEN}'"
