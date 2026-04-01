# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

import os
from flask_appbuilder.security.manager import AUTH_OAUTH

# Superset specific config
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "crucible-dev-superset-secret-key")

# Database
SQLALCHEMY_DATABASE_URI = os.environ.get("SUPERSET_SQLALCHEMY_DATABASE_URI")

# Use simple in-memory cache for dev environment
CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
}

# Keycloak OAuth configuration
# External URL (browser redirects) vs internal URL (server-to-server from inside container)
KEYCLOAK_EXTERNAL_URL = os.environ.get("KEYCLOAK_EXTERNAL_URL", "http://localhost:8080/realms/crucible")
KEYCLOAK_INTERNAL_URL = os.environ.get("KEYCLOAK_INTERNAL_URL", "http://localhost:8080/realms/crucible")

AUTH_TYPE = AUTH_OAUTH
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Admin"

OAUTH_PROVIDERS = [
    {
        "name": "keycloak",
        "icon": "fa-key",
        "token_key": "access_token",
        "remote_app": {
            "client_id": os.environ.get("KEYCLOAK_CLIENT_ID", "superset"),
            "client_secret": os.environ.get("KEYCLOAK_CLIENT_SECRET", "superset-client-secret"),
            "api_base_url": f"{KEYCLOAK_INTERNAL_URL}/protocol/openid-connect",
            "access_token_url": f"{KEYCLOAK_INTERNAL_URL}/protocol/openid-connect/token",
            "authorize_url": f"{KEYCLOAK_EXTERNAL_URL}/protocol/openid-connect/auth",
            "jwks_uri": f"{KEYCLOAK_INTERNAL_URL}/protocol/openid-connect/certs",
            "client_kwargs": {
                "scope": "openid profile email roles",
            },
        },
    }
]

# Map Keycloak user info to Superset user fields
from superset.security import SupersetSecurityManager

class CustomSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == "keycloak":
            me = self.appbuilder.sm.oauth_remotes[provider].get(
                f"{KEYCLOAK_INTERNAL_URL}/protocol/openid-connect/userinfo"
            )
            me.raise_for_status()
            data = me.json()
            return {
                "username": data.get("preferred_username", ""),
                "first_name": data.get("given_name", ""),
                "last_name": data.get("family_name", ""),
                "email": data.get("email", ""),
            }
        return {}

CUSTOM_SECURITY_MANAGER = CustomSecurityManager

# General config
ENABLE_PROXY_FIX = True
SUPERSET_WEBSERVER_PORT = 8088
