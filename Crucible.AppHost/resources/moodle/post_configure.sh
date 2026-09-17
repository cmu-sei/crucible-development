#!/bin/sh

# Global Variables
STATUS_FILE="/tmp/script_status.log"
LOG_FILE="/tmp/moodle_script.log"
MOODLE_DIR="/var/www/html"
MOODLE_CLI="$MOODLE_DIR/admin/cli"
OAUTH2_ISSUER_ID=""
# Shared by both Moodle instances, so it has to suit both provider plugins.
#
# Claude 3.5 Sonnet v2 (the previous value) is end of life on Bedrock: it still resolves as an
# inference profile but every call returns "This model version has reached the end of its life".
#
# Sonnet 4.5 rather than a Claude 5 model because aiprovider_bedrock on 5.0 hardcodes
# temperature 0.7 in its request body, and Claude 5 rejects temperature outright
# ("`temperature` is deprecated for this model"). modelextraparams can only replace values, not
# remove them, so a Claude 5 model there needs a plugin patch. 5.2's core provider sends no
# temperature and works with either.
#
# Check candidates with `aws bedrock list-inference-profiles` before changing this.
BEDROCK_MODEL_ID="us.anthropic.claude-sonnet-4-5-20250929-v1:0"

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

  KEYCLOAK_URL="https://keycloak.dev.internal:8443/realms/crucible/"
  KEYCLOAK_CLIENTID="moodle-client"
  KEYCLOAK_CLIENTSECRET="super-safe-secret"
  KEYCLOAK_NAME="Crucible Keycloak"
  KEYCLOAK_IMAGE="https://localhost:8443/favicon.svg"
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
      log "OAuth2 provider already exists with ID: $EXISTING_ID. Updating..."
      OAUTH2_ISSUER_ID="$EXISTING_ID"
  else
      log "No existing provider found. Creating a new one..."
  fi

  log "Creating/updating OAuth2 provider..."
  PROVIDER_OUTPUT=$(php /usr/local/bin/setup_environment.php \
    --step=manage_oauth \
    ${EXISTING_ID:+--id="$EXISTING_ID"} \
    --baseurl="$KEYCLOAK_URL" \
    --clientid="$KEYCLOAK_CLIENTID" \
    --clientsecret="$KEYCLOAK_CLIENTSECRET" \
    --loginscopes="$KEYCLOAK_LOGINSCOPES" \
    --loginscopesoffline="$KEYCLOAK_LOGINSCOPESOFFLINE" \
    --name="$KEYCLOAK_NAME" \
    --tokenendpoint="https://keycloak.dev.internal:8443/realms/crucible/protocol/openid-connect/token" \
    --userinfoendpoint="https://keycloak.dev.internal:8443/realms/crucible/protocol/openid-connect/userinfo" \
    --image="$KEYCLOAK_IMAGE" \
    --requireconfirmation=0 \
    --showonloginpage=1 \
    2>&1)
  rc=$?
  log "Provider creation output: $PROVIDER_OUTPUT"
  if [ "$rc" -ne 0 ]; then
    error "$section" "Provider creation failed (rc=$rc)."
  fi

  if [ -n "$EXISTING_ID" ]; then
    log "OAuth2 Provider updated successfully with ID: $EXISTING_ID"
  else
    NEW_ISSUER_ID=$(printf '%s\n' "$PROVIDER_OUTPUT" \
      | awk '/provider with ID[[:space:]][0-9]+/ {print $NF; exit}')
    if [ -z "$NEW_ISSUER_ID" ]; then
      error "$section" "Failed to retrieve the new provider ID; aborting mapping."
    fi
    log "OAuth2 Provider created successfully with ID: $NEW_ISSUER_ID"
    OAUTH2_ISSUER_ID="$NEW_ISSUER_ID"
  fi

  if [ -z "$EXISTING_ID" ]; then
  # ---- User field mappings (only on initial creation) ----
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
  fi

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
  php /var/www/html/admin/cli/cfg.php --component=logstore_xapi --name=mbox --set=0
  php /var/www/html/admin/cli/cfg.php --component=logstore_xapi --name=send_name --set=1
  php /var/www/html/admin/cli/cfg.php --component=logstore_xapi --name=send_user_idnumber --set=1
  php /var/www/html/admin/cli/cfg.php --component=logstore_xapi --name=account_homepage --set=https://keycloak.dev.internal:8443/realms/crucible/
}

configure_lptmanager() {
  echo "Configuring lptmanager LRS integration"
  php /var/www/html/admin/cli/cfg.php --component=tool_lptmanager --name=lrs_endpoint --set=http://host.docker.internal:9274/xapi
  php /var/www/html/admin/cli/cfg.php --component=tool_lptmanager --name=lrs_api_key --set=defaultkey
  php /var/www/html/admin/cli/cfg.php --component=tool_lptmanager --name=lrs_api_secret --set=defaultsecret
  php /var/www/html/admin/cli/cfg.php --component=tool_lptmanager --name=enable_lrs_sync --set=1
  php /var/www/html/admin/cli/cfg.php --component=tool_lptmanager --name=competency_iri_prefix --set=https://niccs.cisa.gov/workforce-development/nice-framework/ksat/
}

configure_session_cookie() {
  echo "Configuring session cookie name"

  # Cookies are scoped by host and ignore the port, so every Moodle instance on
  # localhost shares one jar. Both default to the MoodleSession cookie name, which
  # means signing in to 8082 silently overwrites the 8081 session, and the next
  # click on 8081 fails with a session timeout - in either direction. Give each
  # instance its own cookie name, taken from the port in SITE_URL.
  #
  # The image has no environment variable for this and chmods config.php read-only
  # in its final step, so the value is written here instead.
  config_file="$MOODLE_DIR/config.php"
  cookie_suffix=$(echo "${SITE_URL:-}" | sed 's/.*://; s/[^0-9]//g')

  if [ -z "$cookie_suffix" ]; then
    log "No port found in SITE_URL, leaving the default session cookie name"
    return 0
  fi

  if grep -q 'CFG->sessioncookie' "$config_file"; then
    log "Session cookie name already set, skipping"
    return 0
  fi

  config_mode=$(stat -c %a "$config_file")
  chmod u+w "$config_file"
  # Redirect through cat rather than mv so the original owner and mode survive.
  awk -v line="\$CFG->sessioncookie = '$cookie_suffix';" \
    '/^require_once/ && !inserted { print line; inserted = 1 } { print }' \
    "$config_file" > /tmp/config_with_cookie.php
  cat /tmp/config_with_cookie.php > "$config_file"
  rm -f /tmp/config_with_cookie.php
  chmod "$config_mode" "$config_file"

  log "Session cookie name set to MoodleSession$cookie_suffix"
}

configure_site() {
  echo "Configuring Site"
  php /var/www/html/admin/cli/cfg.php --name=curlsecurityblockedhosts --set='';
  php /var/www/html/admin/cli/cfg.php --name=curlsecurityallowedport --set='';
}

configure_boost_dark_theme() {
  echo "Configuring Boost Union and Boost Dark with the CMU development palette"

  boost_union_scss='/* CMU Boost Dark topbar */
.navbar.fixed-top.bg-primary[data-bs-theme="dark"] {
  background-color: #CC0000 !important;
  --bs-navbar-color: rgba(255, 255, 255, 0.92);
  --bs-navbar-hover-color: #fff;
}

.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .navbar-nav > .nav-item > a.nav-link,
.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .navbar-nav > .nav-item > a.nav-link.active,
.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .navbar-nav > .nav-item > a.nav-link[aria-current="true"],
.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .dropdownmoremenu > a.nav-link {
  color: rgba(255, 255, 255, 0.92) !important;
}

.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .navbar-nav > .nav-item > a.nav-link:hover,
.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .navbar-nav > .nav-item > a.nav-link:focus,
.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .navbar-nav > .nav-item > a.nav-link:focus-visible,
.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .dropdownmoremenu > a.nav-link:hover,
.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .dropdownmoremenu > a.nav-link:focus,
.navbar.bg-primary[data-bs-theme="dark"] .primary-navigation .moremenu .dropdownmoremenu > a.nav-link:focus-visible {
  color: #fff !important;
  background-color: rgba(255, 255, 255, 0.16) !important;
}

/* Moodle aiplacement_courseassist dark-mode compatibility. */
[data-bs-theme="dark"] .ai-drawer {
  background-color: var(--bs-body-bg);
  border-left: 1px solid var(--bs-border-color);
}

/* Moodle tool_lp competency/plan tree dark-mode compatibility.
   tool_lp/styles.css hardcodes the selected-node background to #dfdfdf with no
   text colour, so a highlighted item renders near-white on near-white. */
[data-bs-theme="dark"] .path-admin-tool-lp [data-region="managecompetencies"] ul [aria-selected="true"] > span,
[data-bs-theme="dark"] .path-admin-tool-lp [data-region="plans"] ul [aria-selected="true"] > span,
[data-bs-theme="dark"] .path-admin-tool-lp [data-region="competencylinktree"] ul [aria-selected="true"] > span,
[data-bs-theme="dark"] .path-admin-tool-lp [data-region="competencymovetree"] ul [aria-selected="true"] > span,
[data-bs-theme="dark"] .path-badges [data-region="competencylinktree"] ul [aria-selected="true"] > span {
  background-color: var(--bs-secondary-bg) !important;
  color: var(--bs-emphasis-color) !important;
}

[data-bs-theme="dark"] .path-admin-tool-lp [data-region="managecompetencies"] ul[data-enhance="tree"],
[data-bs-theme="dark"] .path-admin-tool-lp [data-region="plans"] ul[data-enhance="tree"],
[data-bs-theme="dark"] .path-admin-tool-lp [data-region="competencylinktree"] ul[data-enhance="linktree"],
[data-bs-theme="dark"] .path-admin-tool-lp [data-region="competencymovetree"] ul[data-enhance="movetree"],
[data-bs-theme="dark"] .path-badges [data-region="competencylinktree"] ul[data-enhance="linktree"] {
  border-color: var(--bs-border-color) !important;
}

/* local_boost_dark solid-button text colour.
   The plugin sets a blanket "[data-bs-theme=dark] .btn { color: ... }", which
   outranks the Bootstrap rule ".btn { color: var(--bs-btn-color) }" and so
   discards the per-variant text colour. Variants with a light background end up
   near-white on near-white: btn-light at 1.12:1 (core uses it for the datafilter
   "Show all" button, e.g. on the question bank) and btn-warning at 1.64:1.
   No !important needed - this SCSS compiles after the plugin styles at the same
   specificity. Present in plugin 1.3.6 through 1.4.0, unreported upstream. */
[data-bs-theme="dark"] .btn-light {
  color: var(--bs-body-color);
  background-color: var(--bs-tertiary-bg);
  border-color: var(--bs-border-color);
}

[data-bs-theme="dark"] .btn-light:hover,
[data-bs-theme="dark"] .btn-light:focus {
  color: var(--bs-emphasis-color);
  background-color: var(--bs-secondary-bg);
  border-color: var(--bs-border-color);
}

/* The amber btn-warning background is fine in dark mode; only the text colour
   is wrong, so hand it back to Bootstrap, which sets --bs-btn-color to black. */
[data-bs-theme="dark"] .btn-warning {
  color: var(--bs-btn-color);
}

/* Moodle course section header in dark mode.
   1. Core hardcodes ".course-section .sectionname > a { color: #1d2125 }" with no
      dark variant, which is 1.10:1 against the dark page background.
      local_boost_dark only rescues it through an adjacent-sibling selector
      (".btn.icons-collapse-expand + h3 a"), which misses whenever the collapse
      control is not the h3 immediate previous sibling - confirmed on a course
      set to "Show one section per page", where no collapse control is rendered
      and the title is unreadable.
   2. Core styles ".btn-icon.icons-collapse-expand" with the brand colour, which
      here is CMU red at 3.27:1. That rule ties the plugin blanket
      "[data-bs-theme=dark] .btn" on specificity and wins on document order, so
      the collapse chevron next to every section title stays dark red. */
[data-bs-theme="dark"] .course-section .sectionname > a,
[data-bs-theme="dark"] .course-section .sectionname .inplaceeditable > a {
  color: var(--bs-emphasis-color);
}

[data-bs-theme="dark"] .btn-icon.icons-collapse-expand {
  color: var(--bs-body-color);
}

[data-bs-theme="dark"] .btn-icon.icons-collapse-expand:hover,
[data-bs-theme="dark"] .btn-icon.icons-collapse-expand:focus {
  color: var(--bs-emphasis-color);
}

/* local_boost_dark dark/light mode toggle.
   Plugin 1.4.0 turned the bare sun/moon icons into a pill: a rounded border, an
   opaque background, a circular badge behind the icon and a text label, all set
   through inline style attributes on the anchor in templates/dark-icon.mustache.
   Restore the icon-only control, which sits better in the navbar. Inline styles
   outrank every selector, so each property has to be !important, and the icon
   colour is handed to inherit so it picks up the navbar foreground instead of
   the plugin hardcoded blues. */
.kraus-layout-dark .nav-link.dark-mode,
.kraus-layout-dark .nav-link.light-mode {
  gap: 0 !important;
  padding: 5px 8px !important;
  border: 0 !important;
  background: transparent !important;
}

.kraus-layout-dark .nav-link > span[aria-hidden="true"] {
  width: auto !important;
  height: auto !important;
  flex: none !important;
  background: transparent !important;
  color: inherit !important;
}

.kraus-layout-dark .nav-link > span[aria-hidden="true"] + span {
  display: none !important;
}'

  # theme_boost_union renamed the colored navbar options for Moodle 5.2: primarylight and
  # primarydark became coloredlight and coloreddark. The old value is not migrated, and an
  # unrecognised value falls through to the default branch of layout/includes/navbar.php,
  # which emits bg-body instead of bg-primary, so the topbar loses the brand color. Ask the
  # installed theme which spelling it knows rather than keying off the Moodle version. Both
  # values produce the same bg-primary plus data-bs-theme="dark" markup that the custom SCSS
  # below targets.
  boost_union_lib="/var/www/html/theme/boost_union/lib.php"
  if [ -f "/var/www/html/public/theme/boost_union/lib.php" ]; then
    boost_union_lib="/var/www/html/public/theme/boost_union/lib.php"
  fi
  navbarcolor="primarydark"
  if grep -q "THEME_BOOST_UNION_SETTING_NAVBARCOLOR_COLOREDDARK" "$boost_union_lib" 2>/dev/null; then
    navbarcolor="coloreddark"
  fi
  log "Using theme_boost_union navbarcolor=$navbarcolor"

  php /var/www/html/admin/cli/cfg.php --name=theme --set=boost_union
  php /var/www/html/admin/cli/cfg.php --component=theme_boost_union --name=brandcolor --set='#CC0000'
  php /var/www/html/admin/cli/cfg.php --component=theme_boost_union --name=navbarcolor --set="$navbarcolor"
  php /var/www/html/admin/cli/cfg.php --component=theme_boost_union --name=scss --set="$boost_union_scss"

  php /var/www/html/admin/cli/cfg.php --component=local_boost_dark --name=enable --set=1
  php /var/www/html/admin/cli/cfg.php --component=local_boost_dark --name=bs_primary --set='#D9363E'
  php /var/www/html/admin/cli/cfg.php --component=local_boost_dark --name=bs_link_color --set='#FF9FA4'
  php /var/www/html/admin/cli/cfg.php --component=local_boost_dark --name=bs_link_hover_color --set='#FFC2C5'
  php /var/www/html/admin/cli/cfg.php --component=local_boost_dark --name=bs_link_focus_color --set='#FFD9DB'

  php /var/www/html/admin/cli/purge_caches.php --theme
}

configure_cmi5launch() {
  if [ "${CRUCIBLE_CATAPULT_ENABLED:-0}" != "1" ]; then
    log "CATAPULT disabled - skipping mod_cmi5launch configuration"
    return
  fi

  echo "Configuring cmi5launch"
  # CATAPULT player (reached from the Moodle container via host.docker.internal).
  php /var/www/html/admin/cli/cfg.php --component=cmi5launch --name=cmi5launchplayerurl --set=http://host.docker.internal:3398
  php /var/www/html/admin/cli/cfg.php --component=cmi5launch --name=cmi5launchbasicname --set=catapult
  php /var/www/html/admin/cli/cfg.php --component=cmi5launch --name=cmi5launchbasepass --set=catapult-dev-secret

  # LRS — same LRsql instance the rest of Crucible uses (xAPI endpoint requires trailing slash).
  php /var/www/html/admin/cli/cfg.php --component=cmi5launch --name=cmi5launchlrsendpoint --set=http://host.docker.internal:9274/xapi/
  php /var/www/html/admin/cli/cfg.php --component=cmi5launch --name=cmi5launchlrslogin --set=defaultkey
  php /var/www/html/admin/cli/cfg.php --component=cmi5launch --name=cmi5launchlrspass --set=defaultsecret

  # Actor account.homePage must match logstore_xapi's account_homepage so cmi5
  # statements correlate to the same learner as the rest of Moodle's xAPI output.
  # (The actor account.name is set in code to $USER->idnumber to match logstore's
  # send_user_idnumber scheme - see classes/local/cmi5_connectors.php.)
  php /var/www/html/admin/cli/cfg.php --component=cmi5launch --name=cmi5launchcustomacchp --set=https://keycloak.dev.internal:8443/realms/crucible/

  # NOTE: cmi5launchtenanttoken must be generated against the player's tenant
  # (Site administration > Plugins > Activity modules > cmi5launch token setup).
  # It cannot be set statically here because the player issues it at runtime.
  log "mod_cmi5launch configured (tenant token still requires manual setup)"
}

configure_cmi5_activity() {
  if [ "${CRUCIBLE_CATAPULT_ENABLED:-0}" != "1" ]; then
    log "CATAPULT disabled - skipping cmi5 demo activity setup"
    return
  fi

  # Idempotently ensure the Test Course has a working cmi5 activity. The CATAPULT
  # player wipes imported content (var/content) on image rebuild, which 404s any
  # existing Moodle activity; this re-imports the bundled package and rewires the
  # activity when needed. Safe to run every time - it no-ops when already healthy.
  # The package is bind-mounted from the cloned CATAPULT repo (see AppHost.cs).
  PACKAGE="/usr/local/share/cmi5/sample_cmi5.zip"
  if [ ! -f "$PACKAGE" ]; then
    log "cmi5 sample package not mounted at $PACKAGE - skipping demo activity"
    return
  fi

  echo "Ensuring cmi5 demo activity"
  php /usr/local/bin/create_cmi5_activity.php \
    --course="Test Course" \
    --package="$PACKAGE" \
    --name="Geology Intro (cmi5)"
}

configure_groupquiz_activity() {
  echo "Ensuring Group Quiz demo activity"
  php /usr/local/bin/create_groupquiz_activity.php \
    --course="Test Course" \
    --name="Group Quiz (Test)" \
    --grouping="Group Quiz Test Grouping" \
    --group="Group Quiz Test Group"
}

configure_demo_activities() {
  echo "Ensuring demo activities"
  php /usr/local/bin/create_demo_activities.php --course="Test Course"
}

configure_crucible_dashboard_blocks() {
  echo "Ensuring Crucible dashboard blocks"
  php /usr/local/bin/create_crucible_dashboard_blocks.php
}

configure_crucible() {
  echo "Configuring Crucible"
  log "Configuring Crucible block based on enabled services..."

  # Configure mod_crucible
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=issuerid --set=$OAUTH2_ISSUER_ID;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=alloyapiurl --set=http://host.docker.internal:4402/api;
  php /var/www/html/admin/cli/cfg.php --component=crucible --name=alloyapiclienturl --set=http://localhost:4402/api;
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
    php /var/www/html/admin/cli/cfg.php --component=block_crucible --name=casterapiurl --set=http://host.docker.internal:4309/api;
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


configure_ai_placements() {
  # AI placements ship disabled: with no settings.php of their own, the enabled flag is only
  # written when something calls \core\plugininfo\aiplacement::enable_plugin(), which is what
  # the Site administration > AI > AI placements toggles do. Without this the provider is
  # configured but no AI feature appears anywhere in the UI.
  for placement in courseassist editor competency; do
    if [ ! -d "/var/www/html/ai/placement/$placement" ] && \
       [ ! -d "/var/www/html/public/ai/placement/$placement" ]; then
      log "Placement aiplacement_$placement not installed, skipping"
      continue
    fi
    log "Enabling aiplacement_$placement"
    php /var/www/html/admin/cli/cfg.php --component="aiplacement_$placement" --name=enabled --set=1
  done

  # enable_plugin() resets the plugin manager caches after writing the flag; cfg.php does not.
  php /var/www/html/admin/cli/purge_caches.php
}


create_course() {
  echo "Creating course"
  moosh course-list | grep -q 'Test Course' || moosh course-create 'Test Course';
}

# Main execution
log "Starting script..."

# Create STATUS_FILE if it doesn't exist
touch "$STATUS_FILE"

# Bind-mounted plugins (block_crucible, mod_crucible, mod_cmi5launch, tool_lptmanager,
# etc.) put Moodle into an "upgrade pending" state on a fresh container. While pending,
# admin/cli/cfg.php refuses to run and exits non-zero, so any plugin configuration that
# follows is silently skipped. Apply pending upgrades up front so the rest of this
# script can configure those plugins. Idempotent: a no-op ("No upgrade needed") once
# everything is installed. Run unconditionally (not via execute_section) so it always
# clears the pending state regardless of prior status.
log "Applying any pending Moodle/plugin upgrades..."
php /var/www/html/admin/cli/upgrade.php --non-interactive --allow-unstable || \
  log "upgrade.php returned non-zero (continuing)"

# Execute sections based on status
execute_section "Session Cookie Name" configure_session_cookie
execute_section "Site Configuration" configure_site
execute_section "Boost Dark Theme Configuration" configure_boost_dark_theme
configure_oauth2
execute_section "Enable Oauth2 Plugin" enable_oauth2_plugin
execute_section "xAPI Configuration" configure_xapi
execute_section "lptmanager Configuration" configure_lptmanager
execute_section "Crucible Configuration" configure_crucible
execute_section "Crucible Dashboard Blocks v2" configure_crucible_dashboard_blocks
execute_section "cmi5launch Configuration" configure_cmi5launch
execute_section "TopoMojo Configuration" configure_topomojo
execute_section "Course Creation" create_course
execute_section "cmi5 Demo Activity" configure_cmi5_activity
execute_section "Group Quiz Demo Activity" configure_groupquiz_activity
execute_section "Demo Activities" configure_demo_activities

# Only configure AWS Bedrock if credentials are available
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ] && [ -n "$AWS_REGION" ]; then
    log "AWS credentials found, configuring Bedrock AI provider..."
    execute_section "Configure AWS Bedrock AI Provider" configure_ai_bedrock
    # Gated on the same credentials: a placement with no working provider behind it just
    # surfaces AI buttons that fail.
    execute_section "Enable AI Placements" configure_ai_placements
else
    log "AWS credentials not found, skipping Bedrock AI provider configuration"
fi

# On subsequent runs add admin user to the list of site admins
ADMINUSERID=$(moosh user-list | grep admin@localhost | sed -e "s/admin.*(\([0-9]\)),.*/\1/")
if [ -n "$ADMINUSERID" ]; then
    log "Found user admin@localhost with ID: $ADMINUSERID and resetting siteadmins list"
    php admin/cli/cfg.php --name=siteadmins --set="2,$ADMINUSERID"
fi

log "Script completed successfully!"
