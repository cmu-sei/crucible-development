#!/bin/sh

# Global Variables
STATUS_FILE="/tmp/script_status.log"
LOG_FILE="/tmp/moodle_script.log"
MOODLE_DIR="/var/www/html"
MOODLE_CLI="$MOODLE_DIR/admin/cli"
OAUTH2_ISSUER_ID=""
BEDROCK_MODEL_ID="us.anthropic.claude-3-5-sonnet-20241022-v2:0"

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
  log "Configuring Crucible block based on enabled services..."

  # Configure mod_crucible
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=issuerid --set=$OAUTH2_ISSUER_ID;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=alloyapiurl --set=http://host.docker.internal:4402/api;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=playerappurl --set=http://localhost:4301;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=vmappurl --set=http://localhost:4303;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=steamfitterapiurl --set=http://host.docker.internal:4400/api

  # Configure block_crucible - only set URLs for enabled services
  php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=enabled --set=1;
  php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=issuerid --set=$OAUTH2_ISSUER_ID;
  php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showallapps --set=0;
  log "Disabled showallapps - using individual service settings"

  # Keycloak is always available (core dependency)
  php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showkeycloak --set=1;
  php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=keycloakuserurl --set=https://localhost:8443/realms/crucible/account;
  php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=keycloakadminurl --set=https://localhost:8443/admin/master/console/#/crucible;
  log "Keycloak URLs configured"

  # Player
  if [ "${CRUCIBLE_PLAYER_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=playerapiurl --set=http://host.docker.internal:4300/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=playerappurl --set=http://localhost:4301;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showplayer --set=1;
    log "Player enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=playerapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=playerappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showplayer --set=0;
    log "Player disabled"
  fi

  # Blueprint
  if [ "${CRUCIBLE_BLUEPRINT_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=blueprintapiurl --set=http://host.docker.internal:4724/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=blueprintappurl --set=http://localhost:4725;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showblueprint --set=1;
    log "Blueprint enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=blueprintapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=blueprintappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showblueprint --set=0;
    log "Blueprint disabled"
  fi

  # CITE
  if [ "${CRUCIBLE_CITE_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=citeapiurl --set=http://host.docker.internal:4720/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=citeappurl --set=http://localhost:4721;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showcite --set=1;
    log "CITE enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=citeapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=citeappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showcite --set=0;
    log "CITE disabled"
  fi

  # Gallery
  if [ "${CRUCIBLE_GALLERY_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=galleryapiurl --set=http://host.docker.internal:4722/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=galleryappurl --set=http://localhost:4723;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showgallery --set=1;
    log "Gallery enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=galleryapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=galleryappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showgallery --set=0;
    log "Gallery disabled"
  fi

  # Gameboard
  if [ "${CRUCIBLE_GAMEBOARD_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=gameboardapiurl --set=http://host.docker.internal:5002/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=gameboardappurl --set=http://localhost:4202;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showgameboard --set=1;
    log "Gameboard enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=gameboardapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=gameboardappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showgameboard --set=0;
    log "Gameboard disabled"
  fi

  # TopoMojo
  if [ "${CRUCIBLE_TOPOMOJO_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=topomojoapiurl --set=http://host.docker.internal:5000/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=topomojoappurl --set=http://localhost:4201;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showtopomojo --set=1;
    log "TopoMojo enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=topomojoapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=topomojoappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showtopomojo --set=0;
    log "TopoMojo disabled"
  fi

  # Steamfitter
  if [ "${CRUCIBLE_STEAMFITTER_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=steamfitterapiurl --set=http://host.docker.internal:4400/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=steamfitterappurl --set=http://localhost:4401;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showsteamfitter --set=1;
    log "Steamfitter enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=steamfitterapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=steamfitterappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showsteamfitter --set=0;
    log "Steamfitter disabled"
  fi

  # Alloy
  if [ "${CRUCIBLE_ALLOY_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=alloyapiurl --set=http://host.docker.internal:4402/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=alloyappurl --set=http://localhost:4403;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showalloy --set=1;
    log "Alloy enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=alloyapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=alloyappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showalloy --set=0;
    log "Alloy disabled"
  fi

  # Caster
  if [ "${CRUCIBLE_CASTER_ENABLED:-0}" = "1" ]; then
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=casterapiurl --set=http://host.docker.internal:4308/api;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=casterappurl --set=http://localhost:4310;
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showcaster --set=1;
    log "Caster enabled"
  else
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=casterapiurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=casterappurl --set='';
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=showcaster --set=0;
    log "Caster disabled"
  fi

  log "Crucible block configured with enabled services only"
}

configure_topomojo() {
  echo "Configuring TopoMojo"
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enableoauth --set=1;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=issuerid --set=$OAUTH2_ISSUER_ID;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=topomojoapiurl --set=http://host.docker.internal:5000/api;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=topomojobaseurl --set=http://localhost:4201;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enableapikey --set=1;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enablemanagername --set=1;
  php /var/www/html/admin/cli/cfg.php --component=topomojo --name=managername --set='Admin User';
  echo "TopoMojo API KEY needs to be generated and set manually"
  #php /var/www/html/admin/cli/cfg.php --component=topomojo --name=apikey --set=la9_eT_RaK640Pb2WZgdvj84__iXSAC4
}


configure_ai_bedrock() {
  log "Configuring AWS Bedrock AI provider..."
  local out
  if ! out=$(php /usr/local/bin/setup_environment.php \
      --step=configure_ai_bedrock \
      --accesskeyid="$AWS_ACCESS_KEY_ID" \
      --secretaccesskey="$AWS_SECRET_ACCESS_KEY" \
      --sessiontoken="$AWS_SESSION_TOKEN" \
      --region="$AWS_REGION" \
      --modelid="$BEDROCK_MODEL_ID" 2>&1); then
    error "Configure AI Bedrock" "Failed to configure AWS Bedrock AI provider: $out"
    return 1
  fi
  log "$out"
}


create_course() {
  echo "Creating course"
  moosh course-list | grep -q 'Test Course' || moosh course-create 'Test Course';
}

# Main execution
log "Starting script..."

# Create STATUS_FILE if it doesn't exist
touch "$STATUS_FILE"

# Execute sections based on status
execute_section "Site Configuration" configure_site
execute_section "OAuth2 Configuration" configure_oauth2
execute_section "Enable Oauth2 Plugin" enable_oauth2_plugin
execute_section "xAPI Configuration" configure_xapi
execute_section "Crucible Configuration" configure_crucible
execute_section "TopoMojo Configuration" configure_topomojo
execute_section "Course Creation" create_course
execute_section "Configure AWS Bedrock AI Provider" configure_ai_bedrock

# On subsequent runs add admin user to the list of site admins
ADMINUSERID=$(moosh user-list | grep admin@localhost | sed -e "s/admin.*(\([0-9]\)),.*/\1/")
if [ -n "$ADMINUSERID" ]; then
    log "Found user admin@localhost with ID: $ADMINUSERID and resetting siteadmins list"
    php admin/cli/cfg.php --name=siteadmins --set="2,$ADMINUSERID"
fi

log "Script completed successfully!"
