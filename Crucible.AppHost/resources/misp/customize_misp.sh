#!/bin/bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Crucible MISP post-init customization script
# This runs inside the MISP container after the standard configure_misp.sh completes.
# It has full access to the cake CLI, MySQL, filesystem, and localhost API.

set -e

CAKE="/var/www/MISP/app/Console/cake"

# OIDC settings (passed from AppHost environment)
OIDC_PROVIDER_URL="${OIDC_PROVIDER_URL:-}"
OIDC_ISSUER="${OIDC_ISSUER:-}"
OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-}"
OIDC_LOGOUT_URL="${OIDC_LOGOUT_URL:-}"

log() {
    echo "CRUCIBLE | $1"
}

###############################################
# Configure OIDC authentication via Keycloak
###############################################
if [ -n "$OIDC_PROVIDER_URL" ] && [ -n "$OIDC_CLIENT_ID" ]; then
    log "Configuring OIDC authentication (provider: ${OIDC_PROVIDER_URL})..."

    # Start socat to forward localhost:8080 -> keycloak:8080 inside the container.
    # Keycloak's .well-known endpoints return localhost:8080 URLs (due to KC_HOSTNAME=localhost),
    # so the OIDC library needs localhost:8080 to be reachable for token exchange.
    if ! pgrep -f "socat.*TCP-LISTEN:8080" > /dev/null 2>&1; then
        # Extract keycloak host from OIDC_PROVIDER_URL (e.g. http://keycloak:8080/realms/crucible -> keycloak:8080)
        KC_HOST_PORT=$(echo "$OIDC_PROVIDER_URL" | sed -E 's|https?://([^/]+).*|\1|')
        log "  Starting socat forward: localhost:8080 -> ${KC_HOST_PORT}"
        socat TCP-LISTEN:8080,fork,reuseaddr TCP:${KC_HOST_PORT} &
    fi

    # Install required OIDC PHP library
    cd /var/www/MISP/app
    if [ ! -d "Vendor/certmichelin" ]; then
        log "  Installing openid-connect-php library..."
        sudo -u www-data php composer.phar require certmichelin/openid-connect-php:1.3.0 --no-interaction 2>&1 | tail -3
    fi
    cd /

    # The OidcAuth plugin is configured via config.php, not cake CLI settings.
    # bootstrap.php auto-loads it when the OidcAuth key exists in config.
    php -r "
        \$configFile = '/var/www/MISP/app/Config/config.php';
        \$cfg = file_get_contents(\$configFile);

        // 1. Replace or add OidcAuth config block.
        // MISP's init may create an empty OidcAuth block, so we must overwrite it.
        // Note: issuer must match what Keycloak reports in .well-known (its external URL),
        // while provider_url uses the same value via socat forwarding.
        \$oidcBlock = \"'OidcAuth' => [\\n\" .
            \"    'provider_url' => '${OIDC_ISSUER}',\\n\" .
            \"    'issuer' => '${OIDC_ISSUER}',\\n\" .
            \"    'client_id' => '${OIDC_CLIENT_ID}',\\n\" .
            \"    'client_secret' => '${OIDC_CLIENT_SECRET}',\\n\" .
            \"    'role_mapper' => [\\n\" .
            \"        'Administrator' => 1,\\n\" .
            \"        'admin' => 1,\\n\" .
            \"        'orgadmin' => 2,\\n\" .
            \"        'user' => 3,\\n\" .
            \"    ],\\n\" .
            \"    'default_org' => '1',\\n\" .
            \"    'mixedAuth' => true,\\n\" .
            \"    'disable_request_object' => true,\\n\" .
            \"    'scopes' => ['profile', 'email'],\\n\" .
            \"]\";

        if (strpos(\$cfg, \"'OidcAuth'\") !== false) {
            // Replace existing (possibly empty) OidcAuth block
            \$cfg = preg_replace(
                \"/  'OidcAuth'\\s*=>\\s*\\n\\s*array\\s*\\([^)]*\\)/s\",
                \"  \" . \$oidcBlock,
                \$cfg,
                1
            );
            echo 'OidcAuth config block replaced. ';
        } else {
            // Insert new block before closing );
            \$pos = strrpos(\$cfg, ');');
            if (\$pos !== false) {
                \$cfg = substr(\$cfg, 0, \$pos) . \"  \" . \$oidcBlock . \",\\n\" . substr(\$cfg, \$pos);
            }
            echo 'OidcAuth config block added. ';
        }

        // 2. Set Security.auth to use OidcAuth
        if (strpos(\$cfg, \"'OidcAuth.Oidc'\") === false) {
            \$cfg = preg_replace(
                \"/('auth'\\s*=>\\s*\\n\\s*array\\s*\\(\\s*\\))/\",
                \"'auth' => array('OidcAuth.Oidc')\",
                \$cfg,
                1
            );
            echo 'Security.auth set to OidcAuth.Oidc. ';
        } else {
            echo 'Security.auth already configured. ';
        }

        file_put_contents(\$configFile, \$cfg);
        echo 'Done.';
    "

    # Set logout URL so MISP redirects to Keycloak on logout
    sudo -u www-data $CAKE Admin setSetting -q "Plugin.CustomAuth_custom_logout" "${OIDC_LOGOUT_URL}"

    # Disable password confirmation (incompatible with SSO)
    sudo -u www-data $CAKE Admin setSetting -q "Security.require_password_confirmation" false

    log "  OIDC authentication configured"
else
    log "OIDC not configured (OIDC_PROVIDER_URL or OIDC_CLIENT_ID not set)"
fi

log "Crucible MISP customization complete."
