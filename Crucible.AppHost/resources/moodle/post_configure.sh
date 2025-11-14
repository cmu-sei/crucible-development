#!/bin/sh

# Global Variables
STATUS_FILE="/tmp/script_status.log"
LOG_FILE="/tmp/moodle_script.log"
MOODLE_DIR="/var/www/html"
MOODLE_CLI="$MOODLE_DIR/admin/cli"
OAUTH2_ISSUER_ID=""

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

  KEYCLOAK_URL="https://keycloak:8443/realms/crucible/"
  KEYCLOAK_CLIENTID="moodle-client"
  KEYCLOAK_CLIENTSECRET="super-safe-secret"
  KEYCLOAK_NAME="Crucible Keycloak"
  KEYCLOAK_IMAGE="https://keycloak:8443/favicon.svg"
  KEYCLOAK_LOGINSCOPES="openid profile email player player-vm alloy steamfitter caster"
  KEYCLOAK_LOGINSCOPESOFFLINE="openid profile email offline_access player player-vm alloy steamfitter caster"

  # Verify required keys
  REQUIRED_KEYS="KEYCLOAK_URL KEYCLOAK_CLIENTID KEYCLOAK_CLIENTSECRET KEYCLOAK_LOGINSCOPES KEYCLOAK_LOGINSCOPESOFFLINE KEYCLOAK_NAME KEYCLOAK_IMAGE"
  for key in $REQUIRED_KEYS; do
    eval val=\$$key
    if [ -z "$val" ]; then
      error "$section" "Missing required configuration: $key"
    fi
  done

  # Check if issuer already exists
  log "Checking for existing OAuth2 provider named '$KEYCLOAK_NAME'..."

  EXISTING_JSON=$(php /usr/local/bin/setup_environment.php \
      --step=manage_oauth \
      --list \
      --json=1 2>/dev/null)

  EXISTING_ID=$(printf '%s\n' "$EXISTING_JSON" | php -r '
    $name = "'"$KEYCLOAK_NAME"'";
    $data = json_decode(stream_get_contents(STDIN), true);
    if (!empty($data["data"])) {
        foreach ($data["data"] as $issuer) {
            if (isset($issuer["name"]) && $issuer["name"] === $name) {
                echo $issuer["id"];
                exit(0);
            }
        }
    }
    exit(1);
  ')

  if [ -n "$EXISTING_ID" ]; then
      log "OAuth2 provider already exists with ID: $EXISTING_ID"
      OAUTH2_ISSUER_ID="$EXISTING_ID"
      return 0
  fi

  log "No existing provider found. Creating a new one..."


  log "Creating a new OAuth2 provider..."
  PROVIDER_OUTPUT=$(php /usr/local/bin/setup_environment.php \
    --step=manage_oauth \
    --baseurl="$KEYCLOAK_URL" \
    --clientid="$KEYCLOAK_CLIENTID" \
    --clientsecret="$KEYCLOAK_CLIENTSECRET" \
    --loginscopes="$KEYCLOAK_LOGINSCOPES" \
    --loginscopesoffline="$KEYCLOAK_LOGINSCOPESOFFLINE" \
    --name="$KEYCLOAK_NAME" \
    --tokenendpoint="https://keycloak:8443/realms/crucible/protocol/openid-connect/token" \
    --userinfoendpoint="https://keycloak:8443/realms/crucible/protocol/openid-connect/userinfo" \
    --image="$KEYCLOAK_IMAGE" \
    --requireconfirmation=0 \
    --showonloginpage=1 \
    2>&1)
  rc=$?
  log "Provider creation output: $PROVIDER_OUTPUT"
  if [ "$rc" -ne 0 ]; then
    error "$section" "Provider creation failed (rc=$rc)."
  fi

  NEW_ISSUER_ID=$(printf '%s\n' "$PROVIDER_OUTPUT" \
    | awk '/Created provider with ID[[:space:]][0-9]+/ {print $NF; exit}')
  if [ -z "$NEW_ISSUER_ID" ]; then
    error "$section" "Failed to retrieve the new provider ID; aborting mapping."
  fi
  log "OAuth2 Provider created successfully with ID: $NEW_ISSUER_ID"
  OAUTH2_ISSUER_ID="$NEW_ISSUER_ID"

  # ---- User field mappings ----
  mappings="sub:idnumber"

  for m in $mappings; do
    external=$(printf '%s' "$m" | cut -d':' -f1)
    internal=$(printf '%s' "$m" | cut -d':' -f2)
    json=$(printf '{"externalfieldname":"%s","internalfieldname":"%s"}' "$external" "$internal")

    log "Creating user field mapping ($external -> $internal) for provider ID: $NEW_ISSUER_ID..."
    MAP_OUT=$(php /usr/local/bin/setup_environment.php \
      --step=manage_oauth \
      --create-user-field \
      --id="$NEW_ISSUER_ID" \
      --json="$json" 2>&1)
    rc=$?
    log "User field mapping output: $MAP_OUT"

    if [ "$rc" -ne 0 ]; then
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
  out="$(php /usr/local/bin/setup_environment.php --step=enable_auth_oauth2 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    error "$section" "Failed to enable OAuth2 auth plugin: $out"
    return "$rc"
  fi
  log "$out"
}

configure_xapi() {
  # TODO: configure lrsql before configuring issuerid and auth values below
  echo "Configuring xAPI"
  log "Enabling Logstore XAPI Plugin"
  php /var/www/html/admin/cli/cfg.php --component=tool_log --name=enabled_stores  --set=logstore_standard,logstore_xapi
  php /var/www/html/admin/cli/cfg.php --component=logstore_xapi --name=endpoint --set=http://host.docker.internal:9274/xapi
  php /var/www/html/admin/cli/cfg.php --component=logstore_xapi --name=username --set=defaultkey
  php /var/www/html/admin/cli/cfg.php --component=logstore_xapi --name=password --set=defaultsecret
  php /var/www/html/admin/cli/cfg.php --component=logstore_xapi --name=mbox --set=1
}

configure_site() {
  echo "Configuring Site"
  php /var/www/html/admin/cli/cfg.php --name=curlsecurityblockedhosts --set='';
  php /var/www/html/admin/cli/cfg.php --name=curlsecurityallowedport --set='';
}

configure_crucible() {
  echo "Configuring Crucible"
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=issuerid --set=$OAUTH2_ISSUER_ID;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=alloyapiurl --set=http://localhost:4402/api;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=playerappurl --set=http://localhost:4301;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=vmappurl --set=http://localhost:4303;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=steamfitterapiurl --set=http://localhost:4400/api
}

configure_topomojo() {
  echo "Configuring TopoMojo"
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enableoauth --set=1;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=issuerid --set=$OAUTH2_ISSUER_ID;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=topomojoapiurl --set=http://localhost:5000/api;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=topomojobaseurl --set=http://localhost:4201;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enableapikey --set=1;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=apikey --set=la9_eT_RaK640Pb2WZgdvj84__iXSAC4
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enablemanagername --set=1;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=managername --set='Admin User';
}

create_course() {
  echo "Creating course"
  moosh course-list | grep -q 'Test Course' || moosh course-create 'Test Course';
  #moosh-new plugin-list;
  #moosh plugin-install --release 2025070100 tool_userdebug
}

# Main execution
log "Starting script..."

# Create STATUS_FILE if it doesn't exist
touch "$STATUS_FILE"

# Execute sections based on status
execute_section "OAuth2 Configuration" configure_oauth2
execute_section "Enable Oauth2 Plugin" enable_oauth2_plugin
execute_section "xAPI Configuration" configure_xapi
execute_section "Site Configuration" configure_site
execute_section "Crucible Configuration" configure_crucible
execute_section "TopoMojo Configuration" configure_topomojo
execute_section "Course Creation" create_course

log "Script completed successfully!"
