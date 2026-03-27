# Keycloak Identity Provider Tests

Tests for the Keycloak identity provider that handles authentication for all Crucible applications.

## Overview

Keycloak is the central identity and access management solution for the Crucible platform. It provides:

- **Single Sign-On (SSO)** - Users authenticate once across all Crucible apps
- **OpenID Connect (OIDC)** - Standard authentication protocol
- **User Management** - Centralized user accounts and profiles
- **Role-Based Access Control** - Fine-grained permissions
- **Realm Management** - Isolation of Crucible from other tenants
- **Client Configuration** - Each Crucible app registered as a client

## Test Coverage

The Keycloak test plan covers:

1. **Authentication Flows**
   - User login and logout
   - Token management (access, refresh, ID tokens)
   - Session management
   - Token renewal and expiration

2. **User Management**
   - User creation, editing, deletion
   - Password policies and resets
   - Email verification
   - User attributes and profile

3. **Realm Configuration**
   - Crucible realm settings
   - Themes and branding
   - Login page customization
   - Security settings

4. **Client Management**
   - OIDC client registration
   - Client secrets and credentials
   - Redirect URIs
   - Client scopes and roles

5. **Role and Permission Management**
   - Realm roles
   - Client roles
   - Role mappings
   - Composite roles

6. **Integration Testing**
   - SSO across Crucible applications
   - Token validation
   - Logout propagation
   - Session timeout handling

## Service Information

- **Admin Console**: https://localhost:8443/admin
- **Crucible Realm**: https://localhost:8443/realms/crucible
- **Default Admin Credentials**: admin/admin

## Running Keycloak Tests

```bash
# Run all Keycloak tests
./run-tests.sh keycloak

# Run in UI mode
./run-tests.sh ui keycloak

# Run specific test categories
./run-tests.sh keycloak --filter "user management"
./run-tests.sh keycloak --filter "authentication"
```

## Test Organization

```
keycloak/
├── keycloak-test-plan.md          # Comprehensive test plan
├── fixtures.ts                    # Keycloak-specific fixtures
├── README.md                      # This file
└── tests/
    ├── authentication/            # Authentication flow tests
    ├── user-management/           # User CRUD operations
    ├── realm-configuration/       # Realm settings tests
    ├── client-management/         # OIDC client tests
    ├── roles-and-permissions/     # RBAC tests
    └── integration/               # SSO integration tests
```

## Fixtures

### `keycloakAdminPage`

Provides an authenticated session to the Keycloak Admin Console:

```typescript
import { test, expect } from '../fixtures';

test('should access admin console', async ({ keycloakAdminPage }) => {
  // Already authenticated to admin console
  await expect(keycloakAdminPage).toHaveURL(/.*admin\/master\/console.*/);
});
```

### `keycloakCrucibleRealmPage`

Provides an authenticated session with Crucible realm selected:

```typescript
import { test, expect } from '../fixtures';

test('should access crucible realm', async ({ keycloakCrucibleRealmPage }) => {
  // Already authenticated and in Crucible realm
  await expect(keycloakCrucibleRealmPage).toHaveURL(/.*\/realms\/crucible\/.*/);
});
```

## Helper Functions

### `authenticateKeycloakAdmin(page, username?, password?)`

Authenticates to the Keycloak admin console.

### `navigateToCrucibleRealm(page)`

Switches to the Crucible realm in the admin console.

## Important Notes

1. **Self-Signed Certificate** - Keycloak uses HTTPS with a self-signed certificate. Tests are configured to ignore SSL errors.

2. **Crucible Realm** - Most tests should focus on the `crucible` realm, not the `master` realm.

3. **Client IDs** - Each Crucible application has a corresponding client ID in Keycloak:
   - `blueprint-ui`
   - `player-ui`
   - `cite-ui`
   - `gameboard-ui`
   - etc.

4. **Token Lifecycle** - Keycloak tokens have configurable lifetimes. Tests should account for token expiration.

5. **SSO Testing** - Integration tests should verify SSO works across multiple Crucible applications.

## Test Status

| Test Suite | Status |
|------------|--------|
| Authentication Flows | ⚪ Planned |
| User Management | ⚪ Planned |
| Realm Configuration | ⚪ Planned |
| Client Management | ⚪ Planned |
| Roles and Permissions | ⚪ Planned |
| Integration Testing | ⚪ Planned |

## Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Admin API](https://www.keycloak.org/docs-api/latest/rest-api/)
- [OIDC Specification](https://openid.net/connect/)
- [Crucible Realm Config](../../Crucible.AppHost/resources/crucible-realm.json)
