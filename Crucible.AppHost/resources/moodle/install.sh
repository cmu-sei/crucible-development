#!/bin/sh

# Global Variables
STATUS_FILE="/opt/cmu/custom-scripts/script_status.log"
LOG_FILE="/tmp/moodle_script.log"
MOODLE_DIR="/var/www/html"
MOODLE_CLI="$MOODLE_DIR/admin/cli"

# Function to log messages
log() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

# Function to log errors
error() {
    section="$1"
    message="$2"
    echo "[ERROR] $message" | tee -a "$LOG_FILE"
    echo "$section = Failed" >> "$STATUS_FILE"
    exit 1
}

# Function to record status
record_status() {
    section="$1"
    status="$2"
    # Delete existing line for this section
    sed -i "/^$section =/d" "$STATUS_FILE"
    echo "$section = $status" >> "$STATUS_FILE"
}

# Function to check and execute a section
execute_section() {
    section="$1"
    func="$2"
    status=$(grep "^$section =" "$STATUS_FILE" 2>/dev/null | cut -d '=' -f2 | xargs)

    if [ "$status" != "Completed" ]; then
        log "Running section: $section"
        $func
        if [ $? -eq 0 ]; then
            record_status "$section" "Completed"
        else
            record_status "$section" "Failed"
            log "Section $section failed."
        fi
    else
        log "Skipping section: $section (already completed)"
    fi
}

configure_oauth2() {
  section="OAuth2 Configuration"
  log "Configuring OAuth2 settings..."

  KEYCLOAK_URL="https://keycloak.${BASE_DOMAIN}/realms/imcite/"
  KEYCLOAK_CLIENTID="moodle-client"
  KEYCLOAK_CLIENTSECRET="super-safe-secret"
  KEYCLOAK_NAME="Crucible Keycloak"
  KEYCLOAK_IMAGE="https://keycloak.${BASE_DOMAIN}/resources/16d5x/admin/keycloak.v2/favicon.svg"
  KEYCLOAK_LOGINSCOPES="openid basic profile email alloy-api blueprint-api caster-api cite-api gallery-api gameboard-api player-api steamfitter-api topomojo-api vm-api"
  KEYCLOAK_LOGINSCOPESOFFLINE="openid basic profile email offline_access alloy-api blueprint-api caster-api cite-api gallery-api gameboard-api player-api steamfitter-api topomojo-api vm-api"

  # Verify required keys
  REQUIRED_KEYS="KEYCLOAK_URL KEYCLOAK_CLIENTID KEYCLOAK_CLIENTSECRET KEYCLOAK_LOGINSCOPES KEYCLOAK_LOGINSCOPESOFFLINE KEYCLOAK_NAME KEYCLOAK_IMAGE"
  for key in $REQUIRED_KEYS; do
    eval val=\$$key
    if [ -z "$val" ]; then
      error "$section" "Missing required configuration: $key"
    fi
  done

  log "Creating a new OAuth2 provider..."
  PROVIDER_OUTPUT=$(php /opt/cmu/custom-scripts/setup_environment.php \
    --step=manage_oauth \
    --baseurl="$KEYCLOAK_URL" \
    --clientid="$KEYCLOAK_CLIENTID" \
    --clientsecret="$KEYCLOAK_CLIENTSECRET" \
    --loginscopes="$KEYCLOAK_LOGINSCOPES" \
    --loginscopesoffline="$KEYCLOAK_LOGINSCOPESOFFLINE" \
    --name="$KEYCLOAK_NAME" \
    --image="$KEYCLOAK_IMAGE" \
    --requireconfirmation=0 \
    --showonloginpage=1 \
    2>&1)
  rc=$?
  log "Provider creation output: $PROVIDER_OUTPUT"
  if [ "$rc" -ne 0 ]; then
    error "$section" "Provider creation failed (rc=$rc)."
  fi

  # Extract provider ID from "Created provider with ID <num>"
  NEW_ISSUER_ID=$(printf '%s\n' "$PROVIDER_OUTPUT" \
    | awk '/Created provider with ID[[:space:]][0-9]+/ {print $NF; exit}')
  if [ -z "$NEW_ISSUER_ID" ]; then
    error "$section" "Failed to retrieve the new provider ID; aborting mapping."
  fi
  log "OAuth2 Provider created successfully with ID: $NEW_ISSUER_ID"

  # ---- User field mappings ----
  mappings="sub:idnumber"

  for m in $mappings; do
    external=$(printf '%s' "$m" | cut -d':' -f1)
    internal=$(printf '%s' "$m" | cut -d':' -f2)
    json=$(printf '{"externalfieldname":"%s","internalfieldname":"%s"}' "$external" "$internal")

    log "Creating user field mapping ($external -> $internal) for provider ID: $NEW_ISSUER_ID..."
    MAP_OUT=$(php /opt/cmu/custom-scripts/setup_environment.php \
      --step=manage_oauth \
      --create-user-field \
      --id="$NEW_ISSUER_ID" \
      --json="$json" 2>&1)
    rc=$?
    log "User field mapping output: $MAP_OUT"

    if [ "$rc" -ne 0 ]; then
      # Treat "already exists" as non-fatal if your PHP prints that verbiage
      if printf '%s\n' "$MAP_OUT" | grep -qi "already exists"; then
        log "Mapping ($external -> $internal) already exists; continuing."
      else
        error "$section" "Failed to create mapping ($external -> $internal) (rc=$rc)."
      fi
    else
      if printf '%s\n' "$MAP_OUT" | grep -q "User field mapping created"; then
        log "Mapping ($external -> $internal) created successfully."
      else
        log "Mapping ($external -> $internal) returned rc=0 but no success line; continuing."
      fi
    fi
  done

  log "OAuth2 configuration completed successfully."
}

# Enable Oauth2 Plugin
enable_oauth2_plugin() {
  section="Enable OAuth2 Plugin"
  log "Enabling OAuth2 auth plugin..."
  out="$(php /opt/cmu/custom-scripts/setup_environment.php --step=enable_auth_oauth2 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    error "$section" "Failed to enable OAuth2 auth plugin: $out"
    return "$rc"
  fi
  log "$out"
}

# Main execution
log "Starting script..."

# Create STATUS_FILE if it doesn't exist
touch "$STATUS_FILE"

# Execute sections based on status
execute_section "OAuth2 Configuration" configure_oauth2
execute_section "Enable Oauth2 Plugin" enable_oauth2_plugin

log "Script completed successfully!"
