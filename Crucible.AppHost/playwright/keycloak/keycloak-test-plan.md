# Keycloak Identity Provider Test Plan

## Application Overview

Keycloak is the centralized OpenID Connect identity provider for the Crucible platform, managing authentication and authorization for 30+ microservices. The instance runs at https://localhost:8443 with a self-signed certificate (expected in dev environment). The 'crucible' realm contains multiple users (admin, contentdev, rangetech, etc.), 40+ OAuth2 clients for various Crucible services (player.ui, caster.api, etc.), and role-based access control with roles including Administrator, Content Developer, and Rangetech Admin. This test plan covers the Keycloak Admin Console functionality, user management, realm configuration, client management, authentication flows, and security controls.

## Test Scenarios

### 1. Admin Console Access

**Seed:** `tests/seed.setup.ts`

#### 1.1. Admin console login with valid credentials

**File:** `tests/keycloak-admin-console/admin-console-login.spec.ts`

**Steps:**
  1. Navigate to https://localhost:8443
    - expect: Keycloak welcome page loads successfully
    - expect: Page displays 'Welcome to Keycloak' or administration console link
    - expect: SSL certificate warning may appear (expected for self-signed cert)
  2. Click on 'Administration Console' link
    - expect: Login page loads with username and password fields
    - expect: Sign In button is visible
    - expect: Page title indicates Keycloak admin login
  3. Enter username 'admin' in the username field
    - expect: Username field accepts input
    - expect: Text is visible in the field
  4. Enter password 'admin' in the password field
    - expect: Password field accepts input
    - expect: Text is masked/hidden
  5. Click the 'Sign In' button
    - expect: Login succeeds and redirects to admin console dashboard
    - expect: Keycloak admin console displays with realm selector
    - expect: Master realm or Crucible realm is visible in navigation
    - expect: User menu with 'admin' username appears in top right

#### 1.2. Admin console login with invalid credentials

**File:** `tests/keycloak-admin-console/admin-console-login-invalid.spec.ts`

**Steps:**
  1. Navigate to https://localhost:8443/admin
    - expect: Admin login page loads
  2. Enter username 'admin' in the username field
    - expect: Username field accepts input
  3. Enter incorrect password 'wrongpassword' in the password field
    - expect: Password field accepts input
  4. Click the 'Sign In' button
    - expect: Login fails with error message
    - expect: Error message displays 'Invalid username or password' or similar
    - expect: User remains on login page
    - expect: Username and password fields are still visible

#### 1.3. Admin console login with empty credentials

**File:** `tests/keycloak-admin-console/admin-console-login-empty.spec.ts`

**Steps:**
  1. Navigate to https://localhost:8443/admin
    - expect: Admin login page loads
  2. Leave username field empty
    - expect: Field remains empty
  3. Leave password field empty
    - expect: Field remains empty
  4. Click the 'Sign In' button
    - expect: Validation error appears
    - expect: Error indicates required fields
    - expect: Sign In button may be disabled or form shows validation errors

#### 1.4. Admin console logout

**File:** `tests/keycloak-admin-console/admin-console-logout.spec.ts`

**Steps:**
  1. Log in to admin console with valid credentials (admin/admin)
    - expect: Successfully logged into admin console
  2. Click on the user menu in the top right corner (showing 'admin')
    - expect: Dropdown menu appears with options including 'Sign out' or 'Logout'
  3. Click 'Sign out' or 'Logout' option
    - expect: User is logged out
    - expect: Redirected to login page or welcome page
    - expect: User menu no longer visible
    - expect: Attempting to access admin console requires login again

#### 1.5. Realm switching in admin console

**File:** `tests/keycloak-admin-console/realm-switching.spec.ts`

**Steps:**
  1. Log in to admin console as admin
    - expect: Admin console loads successfully
  2. Locate the realm selector dropdown (typically shows 'master' or current realm)
    - expect: Realm selector is visible in the left navigation or top of page
  3. Click on the realm selector dropdown
    - expect: Dropdown expands showing available realms
    - expect: At minimum 'master' and 'crucible' realms should be visible
  4. Select 'crucible' realm from the dropdown
    - expect: Page reloads or updates to show crucible realm
    - expect: Realm selector now displays 'crucible'
    - expect: Left navigation updates with realm-specific options
    - expect: Dashboard shows crucible realm statistics and information

### 2. User Management

**Seed:** `tests/seed.setup.ts`

#### 2.1. View existing users list

**File:** `tests/keycloak-user-management/view-users-list.spec.ts`

**Steps:**
  1. Log in to admin console and switch to 'crucible' realm
    - expect: Admin console shows crucible realm
  2. Click on 'Users' in the left navigation menu
    - expect: Users list page loads
    - expect: Users table or search interface is visible
  3. Click 'View all users' or search with empty criteria to list all users
    - expect: List displays existing users
    - expect: Users should include: admin, OGadmin, contentdev, crucible-admin, demo-user, rangetech, readonly, user1, user2
    - expect: Each user row shows username, email (if set), and enabled status
    - expect: Table includes action buttons like 'Edit' or 'Delete'

#### 2.2. Search for specific user

**File:** `tests/keycloak-user-management/search-user.spec.ts`

**Steps:**
  1. Navigate to Users section in crucible realm
    - expect: Users page is displayed
  2. Enter 'admin' in the search field
    - expect: Search field accepts input
  3. Click search button or press Enter
    - expect: Search results display users matching 'admin'
    - expect: Results should include 'admin', 'crucible-admin', 'OGadmin'
    - expect: Other users not matching the search are filtered out

#### 2.3. Create new user with basic information

**File:** `tests/keycloak-user-management/create-user-basic.spec.ts`

**Steps:**
  1. Navigate to Users section in crucible realm
    - expect: Users page is displayed
  2. Click 'Add user' or 'Create new user' button
    - expect: User creation form appears
    - expect: Form includes fields for Username, Email, First Name, Last Name, and Enabled toggle
  3. Enter 'testuser-' + timestamp in Username field
    - expect: Username field accepts input
  4. Enter 'testuser@example.com' in Email field
    - expect: Email field accepts input
  5. Enter 'Test' in First Name field
    - expect: First Name field accepts input
  6. Enter 'User' in Last Name field
    - expect: Last Name field accepts input
  7. Ensure 'Enabled' toggle is ON
    - expect: Toggle shows enabled state
  8. Click 'Create' or 'Save' button
    - expect: User is created successfully
    - expect: Success message appears
    - expect: Redirected to user details page or back to users list
    - expect: New user appears in users list when searching

#### 2.4. Create user with duplicate username

**File:** `tests/keycloak-user-management/create-user-duplicate.spec.ts`

**Steps:**
  1. Navigate to Users section in crucible realm
    - expect: Users page is displayed
  2. Click 'Add user' button
    - expect: User creation form appears
  3. Enter existing username 'admin' in Username field
    - expect: Username field accepts input
  4. Fill other required fields with valid data
    - expect: Form fields accept input
  5. Click 'Create' or 'Save' button
    - expect: User creation fails
    - expect: Error message indicates username already exists
    - expect: Form remains displayed with entered data
    - expect: User is not created

#### 2.5. Edit existing user information

**File:** `tests/keycloak-user-management/edit-user.spec.ts`

**Steps:**
  1. Navigate to Users section and search for 'demo-user'
    - expect: demo-user appears in search results
  2. Click on 'demo-user' or click 'Edit' button for that user
    - expect: User edit form loads
    - expect: Form is pre-populated with existing user data
    - expect: Fields include Username, Email, First Name, Last Name, Enabled status
  3. Change Email to 'demo-updated@example.com'
    - expect: Email field updates with new value
  4. Change First Name to 'Demo Updated'
    - expect: First Name field updates
  5. Click 'Save' button
    - expect: User information is updated successfully
    - expect: Success message appears
    - expect: Updated information is retained when viewing user again
    - expect: Changes are reflected in users list

#### 2.6. Disable user account

**File:** `tests/keycloak-user-management/disable-user.spec.ts`

**Steps:**
  1. Create or identify a test user account
    - expect: Test user exists and is enabled
  2. Navigate to the user's edit page
    - expect: User edit form is displayed
  3. Toggle the 'Enabled' switch to OFF/disabled state
    - expect: Toggle switches to disabled state
  4. Click 'Save' button
    - expect: User is disabled successfully
    - expect: Success message appears
    - expect: Enabled toggle remains in OFF state
    - expect: User appears as disabled in users list

#### 2.7. Set user password

**File:** `tests/keycloak-user-management/set-user-password.spec.ts`

**Steps:**
  1. Navigate to a test user's details page
    - expect: User details page is displayed
  2. Click on 'Credentials' tab
    - expect: Credentials management interface appears
    - expect: Option to set/reset password is visible
  3. Click 'Set Password' or 'Reset Password' button
    - expect: Password form appears
    - expect: Form includes New Password and Password Confirmation fields
    - expect: Temporary password toggle option may be present
  4. Enter 'NewPassword123!' in New Password field
    - expect: Password field accepts input and masks it
  5. Enter 'NewPassword123!' in Password Confirmation field
    - expect: Confirmation field accepts input and masks it
  6. Set 'Temporary' toggle to OFF (permanent password)
    - expect: Temporary toggle is in OFF state
  7. Click 'Set Password' or 'Save' button
    - expect: Password is set successfully
    - expect: Confirmation message appears
    - expect: Password can be used for authentication

#### 2.8. Assign role to user

**File:** `tests/keycloak-user-management/assign-user-role.spec.ts`

**Steps:**
  1. Navigate to a test user's details page
    - expect: User details page is displayed
  2. Click on 'Role Mappings' or 'Role mapping' tab
    - expect: Role mapping interface appears
    - expect: Shows 'Available Roles' and 'Assigned Roles' sections
  3. Locate 'Content Developer' role in Available Roles list
    - expect: Content Developer role is visible in available roles
  4. Select 'Content Developer' role and click 'Add selected' or assign button
    - expect: Role moves from Available to Assigned
    - expect: Content Developer appears in Assigned Roles list
    - expect: Success message may appear
  5. Save changes if required
    - expect: Role assignment is persisted
    - expect: User now has Content Developer role
    - expect: Role appears when viewing user's roles again

#### 2.9. Delete user account

**File:** `tests/keycloak-user-management/delete-user.spec.ts`

**Steps:**
  1. Create a test user for deletion
    - expect: Test user exists in the system
  2. Navigate to the test user's details page
    - expect: User details page is displayed
  3. Click 'Delete' button (typically in top right or actions menu)
    - expect: Confirmation dialog appears
    - expect: Dialog warns about permanent deletion
    - expect: Dialog has 'Delete' and 'Cancel' options
  4. Click 'Delete' in the confirmation dialog
    - expect: User is deleted successfully
    - expect: Success message appears
    - expect: Redirected to users list
    - expect: Deleted user no longer appears in users search

### 3. Realm Configuration

**Seed:** `tests/seed.setup.ts`

#### 3.1. View realm general settings

**File:** `tests/keycloak-realm-config/view-realm-settings.spec.ts`

**Steps:**
  1. Log in to admin console and switch to 'crucible' realm
    - expect: Crucible realm is active
  2. Click 'Realm Settings' in the left navigation menu
    - expect: Realm Settings page loads
    - expect: General tab is displayed by default
    - expect: Shows Realm ID, Display name, HTML Display name, Frontend URL, Require SSL, User managed access, Endpoints link
  3. Verify 'Require SSL' setting
    - expect: SSL setting shows 'external' or similar (matches realm config)
    - expect: Setting indicates SSL is required for external connections
  4. Click on 'Endpoints' link or view OpenID Endpoint Configuration
    - expect: Endpoints information appears or opens in new tab
    - expect: Shows various OAuth2/OIDC endpoints like token_endpoint, authorization_endpoint, userinfo_endpoint

#### 3.2. View realm login settings

**File:** `tests/keycloak-realm-config/view-login-settings.spec.ts`

**Steps:**
  1. Navigate to Realm Settings for crucible realm
    - expect: Realm Settings page is displayed
  2. Click on 'Login' tab
    - expect: Login settings tab loads
    - expect: Shows settings like User registration, Email as username, Forgot password, Remember me, Verify email, Login with email
  3. Verify 'User registration' setting
    - expect: User registration should be OFF/disabled (per realm config registrationAllowed: false)
  4. Verify 'Login with email' setting
    - expect: Login with email should be ON/enabled (per realm config loginWithEmailAllowed: true)
  5. Verify 'Forgot password' setting
    - expect: Forgot password should be OFF/disabled (per realm config resetPasswordAllowed: false)

#### 3.3. View realm token settings

**File:** `tests/keycloak-realm-config/view-token-settings.spec.ts`

**Steps:**
  1. Navigate to Realm Settings for crucible realm
    - expect: Realm Settings page is displayed
  2. Click on 'Tokens' tab
    - expect: Token settings tab loads
    - expect: Shows settings for token lifespans including: Default Signature Algorithm, Access Token Lifespan, Access Token Lifespan For Implicit Flow, Client login timeout, etc.
  3. Verify 'Access Token Lifespan' value
    - expect: Value should be 5 minutes or 300 seconds (per realm config accessTokenLifespan: 300)
  4. Verify 'SSO Session Idle' timeout
    - expect: Value should be 30 minutes or 1800 seconds (per realm config ssoSessionIdleTimeout: 1800)
  5. Verify 'SSO Session Max' lifespan
    - expect: Value should be 10 hours or 36000 seconds (per realm config ssoSessionMaxLifespan: 36000)

#### 3.4. View realm security defenses

**File:** `tests/keycloak-realm-config/view-security-defenses.spec.ts`

**Steps:**
  1. Navigate to Realm Settings for crucible realm
    - expect: Realm Settings page is displayed
  2. Click on 'Security Defenses' tab
    - expect: Security Defenses settings tab loads
    - expect: Shows settings for Headers, Brute Force Detection
  3. Click on 'Brute Force Detection' sub-tab if present
    - expect: Brute force settings are displayed
    - expect: Shows Enabled toggle, failure factors, wait times, lockout settings
  4. Verify Brute Force Detection status
    - expect: Should be OFF/disabled (per realm config bruteForceProtected: false)
    - expect: Settings show failure thresholds and timing parameters

#### 3.5. View realm themes

**File:** `tests/keycloak-realm-config/view-themes.spec.ts`

**Steps:**
  1. Navigate to Realm Settings for crucible realm
    - expect: Realm Settings page is displayed
  2. Click on 'Themes' tab
    - expect: Themes settings tab loads
    - expect: Shows dropdowns for Login theme, Account theme, Admin Console theme, Email theme
  3. Verify available theme options in Login theme dropdown
    - expect: Dropdown includes options like 'keycloak' or custom themes
    - expect: Selected theme is displayed

#### 3.6. View realm email settings

**File:** `tests/keycloak-realm-config/view-email-settings.spec.ts`

**Steps:**
  1. Navigate to Realm Settings for crucible realm
    - expect: Realm Settings page is displayed
  2. Click on 'Email' tab
    - expect: Email settings tab loads
    - expect: Shows fields for From, From Display Name, Reply To, Reply To Display Name, Envelope From, Host, Port, Authentication settings
  3. Verify email configuration presence
    - expect: Form displays email server configuration fields
    - expect: May be empty or configured depending on environment

#### 3.7. View realm localization

**File:** `tests/keycloak-realm-config/view-localization.spec.ts`

**Steps:**
  1. Navigate to Realm Settings for crucible realm
    - expect: Realm Settings page is displayed
  2. Click on 'Localization' tab
    - expect: Localization settings tab loads
    - expect: Shows Internationalization enabled toggle, Supported locales, Default locale
  3. Verify supported locales
    - expect: Displays list of supported languages/locales
    - expect: Default locale is specified

### 4. Client Management

**Seed:** `tests/seed.setup.ts`

#### 4.1. View clients list

**File:** `tests/keycloak-client-management/view-clients-list.spec.ts`

**Steps:**
  1. Log in to admin console and switch to 'crucible' realm
    - expect: Crucible realm is active
  2. Click 'Clients' in the left navigation menu
    - expect: Clients list page loads
    - expect: Table or list displays existing clients
    - expect: Clients include: player.ui, player.api, caster.ui, caster.api, alloy.ui, alloy.api, gameboard.ui, gameboard.api, topomojo.ui, topomojo.api, blueprint, cite, gallery, steamfitter clients, moodle-client, etc.
    - expect: Each client row shows Client ID, Name, Base URL, and Enabled status

#### 4.2. Search for specific client

**File:** `tests/keycloak-client-management/search-client.spec.ts`

**Steps:**
  1. Navigate to Clients page in crucible realm
    - expect: Clients page is displayed
  2. Enter 'player.ui' in the search field
    - expect: Search field accepts input
  3. Search is triggered (automatically or by clicking search button)
    - expect: Search results display clients matching 'player.ui'
    - expect: player.ui client appears in results
    - expect: player.vm.ui and player.vm.console.ui may also appear
    - expect: Other non-matching clients are filtered out

#### 4.3. View client details and settings

**File:** `tests/keycloak-client-management/view-client-details.spec.ts`

**Steps:**
  1. Navigate to Clients page and search for 'player.ui'
    - expect: player.ui client appears in results
  2. Click on 'player.ui' client or click 'Edit' button
    - expect: Client details page loads
    - expect: Settings tab is displayed
    - expect: Shows Client ID, Name, Description, Enabled toggle, Consent Required, Client Protocol, Access Type, Standard Flow Enabled, Direct Access Grants Enabled, Root URL, Valid Redirect URIs, Base URL, Admin URL, Web Origins
  3. Verify Client Protocol
    - expect: Should show 'openid-connect' as the protocol
  4. Verify Valid Redirect URIs
    - expect: Should include redirect URIs for the player UI application
    - expect: URLs should reference localhost:4301 or configured player UI host

#### 4.4. View client credentials

**File:** `tests/keycloak-client-management/view-client-credentials.spec.ts`

**Steps:**
  1. Navigate to Clients page and open 'player.api' client
    - expect: player.api client details page loads
  2. Click on 'Credentials' tab
    - expect: Credentials tab loads
    - expect: Shows Client Authenticator dropdown
    - expect: Displays Secret field (if client uses secret authentication)
    - expect: May show 'Regenerate Secret' button
  3. Verify client secret is displayed or masked
    - expect: Secret is shown with option to reveal/copy
    - expect: Secret format matches OAuth2 client secret pattern

#### 4.5. View client roles

**File:** `tests/keycloak-client-management/view-client-roles.spec.ts`

**Steps:**
  1. Navigate to Clients page and open any API client (e.g., 'player.api')
    - expect: Client details page loads
  2. Click on 'Roles' tab
    - expect: Roles tab loads
    - expect: Shows list of roles defined for this client
    - expect: Option to 'Add Role' is visible
    - expect: Each role shows Role Name and Description
  3. Verify roles are listed
    - expect: Any client-specific roles are displayed
    - expect: List may be empty if no custom roles defined

#### 4.6. View client scopes

**File:** `tests/keycloak-client-management/view-client-scopes.spec.ts`

**Steps:**
  1. Navigate to Clients page and open 'player.ui' client
    - expect: Client details page loads
  2. Click on 'Client Scopes' tab
    - expect: Client Scopes tab loads
    - expect: Shows 'Setup' sub-tab by default
    - expect: Displays Default Client Scopes and Optional Client Scopes
    - expect: Common scopes include: email, profile, roles, web-origins
  3. Verify default scopes include standard OpenID Connect scopes
    - expect: Default scopes include 'email', 'profile', 'roles'
    - expect: Scopes match expected OAuth2/OIDC configuration

#### 4.7. View client mappers

**File:** `tests/keycloak-client-management/view-client-mappers.spec.ts`

**Steps:**
  1. Navigate to Clients page and open 'player.ui' client
    - expect: Client details page loads
  2. Click on 'Mappers' tab
    - expect: Mappers tab loads
    - expect: Shows list of protocol mappers
    - expect: Mappers control what claims are included in tokens
    - expect: Each mapper shows Name, Category, Type, Priority
  3. Verify standard mappers are present
    - expect: Mappers for email, username, roles, etc. are visible
    - expect: Mappers show their configuration types (e.g., 'User Property', 'User Attribute')

#### 4.8. Create new client

**File:** `tests/keycloak-client-management/create-client.spec.ts`

**Steps:**
  1. Navigate to Clients page in crucible realm
    - expect: Clients page is displayed
  2. Click 'Create' or 'Create client' button
    - expect: Client creation wizard or form appears
    - expect: Shows Client ID field
    - expect: Shows Client Protocol selection (openid-connect, saml)
  3. Enter 'test-client-' + timestamp as Client ID
    - expect: Client ID field accepts input
  4. Select 'openid-connect' as Client Protocol
    - expect: Protocol is selected
  5. Click 'Next' or 'Save' to proceed
    - expect: Wizard advances to next step or client is created
    - expect: If multi-step wizard, shows capability config (Standard flow, Direct access grants, etc.)
  6. Configure capabilities if prompted (enable Standard Flow, Direct Access Grants)
    - expect: Capability toggles are set
  7. Click 'Next' or proceed to settings
    - expect: Settings page appears or wizard continues
  8. Enter valid redirect URI (e.g., 'http://localhost:8888/*')
    - expect: Redirect URI field accepts input
  9. Click 'Save' to create the client
    - expect: Client is created successfully
    - expect: Success message appears
    - expect: Redirected to client details page
    - expect: New client appears in clients list

#### 4.9. Delete client

**File:** `tests/keycloak-client-management/delete-client.spec.ts`

**Steps:**
  1. Create a test client for deletion
    - expect: Test client exists in clients list
  2. Navigate to the test client's details page
    - expect: Client details page is displayed
  3. Click 'Delete' button (typically in actions dropdown or top of page)
    - expect: Confirmation dialog appears
    - expect: Dialog warns about permanent deletion and impact on applications
    - expect: Dialog has 'Delete' and 'Cancel' options
  4. Click 'Delete' in the confirmation dialog
    - expect: Client is deleted successfully
    - expect: Success message appears
    - expect: Redirected to clients list
    - expect: Deleted client no longer appears in clients search

### 5. Roles Management

**Seed:** `tests/seed.setup.ts`

#### 5.1. View realm roles list

**File:** `tests/keycloak-roles-management/view-realm-roles.spec.ts`

**Steps:**
  1. Log in to admin console and switch to 'crucible' realm
    - expect: Crucible realm is active
  2. Click 'Realm roles' or 'Roles' in the left navigation menu
    - expect: Realm roles page loads
    - expect: List displays existing realm roles
    - expect: Roles should include: Administrator, Content Developer, Rangetech Admin, offline_access, uma_authorization, default-roles-crucible
  3. Verify role details are visible in list
    - expect: Each role shows Role Name
    - expect: Description may be visible
    - expect: Action buttons for Edit/Delete are present

#### 5.2. View realm role details

**File:** `tests/keycloak-roles-management/view-role-details.spec.ts`

**Steps:**
  1. Navigate to Realm roles page
    - expect: Realm roles list is displayed
  2. Click on 'Administrator' role
    - expect: Role details page loads
    - expect: Shows role name, description
    - expect: Tabs for Details, Associated roles, Users in role, Attributes
  3. Verify role information
    - expect: Role name shows 'Administrator'
    - expect: Composite Role toggle indicates if role combines other roles
    - expect: Description field may be present

#### 5.3. Create new realm role

**File:** `tests/keycloak-roles-management/create-realm-role.spec.ts`

**Steps:**
  1. Navigate to Realm roles page
    - expect: Realm roles list is displayed
  2. Click 'Create role' or 'Add role' button
    - expect: Role creation form appears
    - expect: Form includes Role name, Description, Composite Role toggle
  3. Enter 'test-role-' + timestamp in Role name field
    - expect: Role name field accepts input
  4. Enter 'Test role for automated testing' in Description field
    - expect: Description field accepts input
  5. Leave Composite Role toggle OFF
    - expect: Toggle is in OFF state
  6. Click 'Save' button
    - expect: Role is created successfully
    - expect: Success message appears
    - expect: Redirected to role details page or back to roles list
    - expect: New role appears in realm roles list

#### 5.4. Create composite realm role

**File:** `tests/keycloak-roles-management/create-composite-role.spec.ts`

**Steps:**
  1. Navigate to Realm roles page
    - expect: Realm roles list is displayed
  2. Click 'Create role' button
    - expect: Role creation form appears
  3. Enter 'test-composite-role-' + timestamp in Role name field
    - expect: Role name field accepts input
  4. Toggle Composite Role to ON
    - expect: Toggle switches to ON
    - expect: Additional section appears for selecting associated roles
  5. Select 'Content Developer' from available realm roles
    - expect: Content Developer role is added to associated roles
  6. Click 'Save' button
    - expect: Composite role is created successfully
    - expect: Success message appears
    - expect: Role includes Content Developer as associated role
    - expect: Role appears in realm roles list

#### 5.5. Delete realm role

**File:** `tests/keycloak-roles-management/delete-realm-role.spec.ts`

**Steps:**
  1. Create a test role for deletion
    - expect: Test role exists in realm roles list
  2. Navigate to the test role's details page
    - expect: Role details page is displayed
  3. Click 'Delete' button
    - expect: Confirmation dialog appears
    - expect: Dialog warns about permanent deletion and impact on users with this role
    - expect: Dialog has 'Delete' and 'Cancel' options
  4. Click 'Delete' in the confirmation dialog
    - expect: Role is deleted successfully
    - expect: Success message appears
    - expect: Redirected to realm roles list
    - expect: Deleted role no longer appears in roles list

### 6. Authentication Flows

**Seed:** `tests/seed.setup.ts`

#### 6.1. View authentication flows

**File:** `tests/keycloak-authentication/view-auth-flows.spec.ts`

**Steps:**
  1. Log in to admin console and switch to 'crucible' realm
    - expect: Crucible realm is active
  2. Click 'Authentication' in the left navigation menu
    - expect: Authentication page loads
    - expect: Shows tabs for Flows, Required Actions, Policies, Password Policy
  3. Verify Flows tab is selected
    - expect: Flows tab displays authentication flows list
    - expect: Default flows include: browser, direct grant, registration, reset credentials, docker auth, client authentication
  4. Select 'browser' flow from dropdown or list
    - expect: Browser flow details are displayed
    - expect: Shows flow steps like Cookie, Kerberos, Identity Provider Redirector, Forms
    - expect: Each step shows authentication type and requirement (Required, Alternative, Disabled)

#### 6.2. View required actions

**File:** `tests/keycloak-authentication/view-required-actions.spec.ts`

**Steps:**
  1. Navigate to Authentication page
    - expect: Authentication page is displayed
  2. Click on 'Required Actions' tab
    - expect: Required Actions tab loads
    - expect: Shows list of required actions that can be enabled
    - expect: Actions include: Verify Email, Update Password, Update Profile, Configure OTP, Terms and Conditions, Update User Locale, Webauthn Register
  3. Verify enabled status of required actions
    - expect: Each action shows Enabled and Default Action toggles
    - expect: Enabled actions can be triggered for users
    - expect: Default actions are automatically required for new users

#### 6.3. View password policy

**File:** `tests/keycloak-authentication/view-password-policy.spec.ts`

**Steps:**
  1. Navigate to Authentication page
    - expect: Authentication page is displayed
  2. Click on 'Policies' tab and select 'Password Policy' if needed
    - expect: Password Policy configuration is displayed
    - expect: Shows dropdown to add policy rules
    - expect: Active policies are listed with their parameters (e.g., Minimum Length: 8, Special Characters, Uppercase Characters)
  3. Verify current password policies
    - expect: Lists all active password requirements
    - expect: Each policy shows its configuration value
    - expect: May be empty if no password policies configured

#### 6.4. Test standard browser authentication flow

**File:** `tests/keycloak-authentication/test-browser-flow.spec.ts`

**Steps:**
  1. Open new incognito/private browser window
    - expect: Clean browser session with no cached credentials
  2. Navigate to a Crucible service that requires authentication (e.g., http://localhost:4301 for Player UI)
    - expect: Browser redirects to Keycloak login page at https://localhost:8443
    - expect: Login page displays with username and password fields
    - expect: Page shows Keycloak branding and crucible realm
  3. Enter valid username 'demo-user' and corresponding password
    - expect: Fields accept input
  4. Click 'Sign In' button
    - expect: Authentication succeeds
    - expect: Browser redirects back to Player UI at localhost:4301
    - expect: User is logged into the application
    - expect: OAuth2 tokens are issued and stored

#### 6.5. Test authentication with invalid credentials

**File:** `tests/keycloak-authentication/test-invalid-credentials.spec.ts`

**Steps:**
  1. Navigate to a Crucible service that triggers Keycloak login
    - expect: Redirected to Keycloak login page
  2. Enter valid username 'admin' but wrong password 'wrongpassword'
    - expect: Fields accept input
  3. Click 'Sign In' button
    - expect: Authentication fails
    - expect: Error message displays 'Invalid username or password'
    - expect: User remains on login page
    - expect: No redirect to application occurs

#### 6.6. Test authentication with disabled user

**File:** `tests/keycloak-authentication/test-disabled-user.spec.ts`

**Steps:**
  1. Create or identify a test user and disable the account via admin console
    - expect: Test user exists and is disabled
  2. Navigate to a Crucible service that triggers Keycloak login
    - expect: Redirected to Keycloak login page
  3. Enter disabled user's username and correct password
    - expect: Fields accept input
  4. Click 'Sign In' button
    - expect: Authentication fails
    - expect: Error message indicates account is disabled or invalid credentials
    - expect: User cannot log in
    - expect: No access token is issued

### 7. Sessions Management

**Seed:** `tests/seed.setup.ts`

#### 7.1. View active sessions

**File:** `tests/keycloak-sessions/view-active-sessions.spec.ts`

**Steps:**
  1. Log in to admin console and switch to 'crucible' realm
    - expect: Crucible realm is active
  2. Click 'Sessions' in the left navigation menu
    - expect: Sessions page loads
    - expect: Shows tabs for 'Realm sessions' or similar
  3. View active sessions list
    - expect: List displays currently active user sessions
    - expect: Each session shows Username, IP Address, Started time, Last Access time
    - expect: Action buttons to view details or revoke session

#### 7.2. View user session details

**File:** `tests/keycloak-sessions/view-session-details.spec.ts`

**Steps:**
  1. Log in as a test user to create an active session
    - expect: Test user has active session
  2. In admin console, navigate to Sessions page
    - expect: Sessions page displays active sessions
  3. Locate the test user's session in the list
    - expect: Test user session is visible
  4. Click on the session or 'Show session details' button
    - expect: Session details appear
    - expect: Shows Session ID, User, IP Address, Started time, Last Access, Clients involved in the session

#### 7.3. Revoke user session

**File:** `tests/keycloak-sessions/revoke-session.spec.ts`

**Steps:**
  1. Log in as a test user to create an active session
    - expect: Test user has active session
  2. In admin console, navigate to Sessions page
    - expect: Sessions page displays active sessions
  3. Locate the test user's session
    - expect: Session is visible in the list
  4. Click 'Logout' or 'Sign out' button for the session
    - expect: Confirmation may appear
  5. Confirm session revocation if prompted
    - expect: Session is revoked successfully
    - expect: Session disappears from active sessions list
    - expect: User is logged out from all applications using that session
    - expect: Test user must re-authenticate to access applications

#### 7.4. Revoke all sessions for realm

**File:** `tests/keycloak-sessions/revoke-all-sessions.spec.ts`

**Steps:**
  1. Ensure multiple users have active sessions (including admin)
    - expect: Multiple active sessions exist
  2. Navigate to Sessions page
    - expect: Sessions page is displayed
  3. Click 'Logout all' or 'Revoke all' button
    - expect: Confirmation dialog appears warning about logging out all users
  4. Confirm the action
    - expect: All user sessions are revoked
    - expect: Success message appears
    - expect: Active sessions list becomes empty or shows only new admin session
    - expect: All users are logged out and must re-authenticate

### 8. Events and Logs

**Seed:** `tests/seed.setup.ts`

#### 8.1. View login events

**File:** `tests/keycloak-events/view-login-events.spec.ts`

**Steps:**
  1. Log in to admin console and switch to 'crucible' realm
    - expect: Crucible realm is active
  2. Click 'Events' in the left navigation menu
    - expect: Events page loads
    - expect: Shows tabs for 'Login events' and 'Admin events'
  3. Ensure 'Login events' tab is selected
    - expect: Login events list is displayed
    - expect: Events show Type (LOGIN, LOGIN_ERROR, LOGOUT, etc.), Date, User, IP Address, Client
  4. Locate recent login event
    - expect: Recent successful or failed login attempts are visible
    - expect: Events are sorted by date/time, most recent first

#### 8.2. Filter login events by user

**File:** `tests/keycloak-events/filter-events-by-user.spec.ts`

**Steps:**
  1. Navigate to Events > Login events
    - expect: Login events page is displayed
  2. Enter 'admin' in the User filter field
    - expect: Filter field accepts input
  3. Click 'Search' or apply filter
    - expect: Events list updates to show only events for user 'admin'
    - expect: Other users' events are filtered out
    - expect: Event count reflects filtered results

#### 8.3. Filter login events by event type

**File:** `tests/keycloak-events/filter-events-by-type.spec.ts`

**Steps:**
  1. Navigate to Events > Login events
    - expect: Login events page is displayed
  2. Select 'LOGIN_ERROR' from the Event Type filter dropdown
    - expect: Event type is selected
  3. Click 'Search' or apply filter
    - expect: Events list updates to show only LOGIN_ERROR events
    - expect: Failed login attempts are displayed
    - expect: Successful logins are filtered out

#### 8.4. View admin events

**File:** `tests/keycloak-events/view-admin-events.spec.ts`

**Steps:**
  1. Navigate to Events page
    - expect: Events page is displayed
  2. Click on 'Admin events' tab
    - expect: Admin events list is displayed
    - expect: Events show administrative actions like CREATE, UPDATE, DELETE
    - expect: Each event shows Date, Operation Type, Resource Type, Admin user who performed action
  3. Locate recent admin action (e.g., user creation, role assignment)
    - expect: Admin events are listed chronologically
    - expect: Events provide audit trail of administrative changes

#### 8.5. View admin event details

**File:** `tests/keycloak-events/view-admin-event-details.spec.ts`

**Steps:**
  1. Navigate to Events > Admin events
    - expect: Admin events list is displayed
  2. Click on a specific admin event to view details
    - expect: Event details appear or expand
    - expect: Shows full event information including Resource Path, Representation (JSON data of change), Admin user, IP Address, Timestamp

#### 8.6. Configure events settings

**File:** `tests/keycloak-events/configure-events-settings.spec.ts`

**Steps:**
  1. Navigate to Events page
    - expect: Events page is displayed
  2. Click on 'Config' or 'Event Listeners' tab
    - expect: Event configuration page loads
    - expect: Shows settings for Save Events, Event Expiration, Saved Types, Event Listeners
  3. Verify 'Save Events' toggle status
    - expect: Toggle indicates whether login events are being saved
    - expect: If ON, events are stored for viewing
  4. Verify Event Listeners list
    - expect: Lists active event listeners (e.g., jboss-logging)
    - expect: Listeners determine where events are sent

### 9. Security and Error Handling

**Seed:** `tests/seed.setup.ts`

#### 9.1. Handle SSL certificate warning

**File:** `tests/keycloak-security/handle-ssl-warning.spec.ts`

**Steps:**
  1. Navigate to https://localhost:8443 in a fresh browser session
    - expect: Browser displays SSL certificate warning
    - expect: Warning indicates self-signed certificate
    - expect: Options to proceed or go back are present
  2. Accept the certificate risk and proceed (browser-specific steps)
    - expect: Browser allows connection to proceed
    - expect: Keycloak welcome page or admin console login loads
    - expect: Address bar may show 'Not Secure' indicator

#### 9.2. Verify HTTPS enforcement

**File:** `tests/keycloak-security/verify-https-enforcement.spec.ts`

**Steps:**
  1. Attempt to navigate to http://localhost:8080 (non-HTTPS Keycloak port)
    - expect: Connection succeeds to port 8080
    - expect: Note: Keycloak may serve on both 8080 (HTTP) and 8443 (HTTPS) in dev mode
  2. Verify that sensitive operations require SSL
    - expect: Realm settings show 'Require SSL' is set to 'external' or 'all'
    - expect: External connections enforce HTTPS
    - expect: Admin console and authentication endpoints use HTTPS

#### 9.3. Test session timeout

**File:** `tests/keycloak-security/test-session-timeout.spec.ts`

**Steps:**
  1. Log in to admin console
    - expect: Admin console loads successfully
  2. Note the SSO Session Idle timeout setting (default 30 minutes per realm config)
    - expect: Session timeout is configured
  3. Remain idle for the configured idle timeout period (or reduce timeout in realm settings for testing)
    - expect: Session expires after idle timeout
  4. Attempt to perform an admin action after timeout
    - expect: Action fails or redirects to login page
    - expect: Error indicates session expired
    - expect: User must re-authenticate

#### 9.4. Test CORS handling

**File:** `tests/keycloak-security/test-cors-handling.spec.ts`

**Steps:**
  1. Open browser developer tools and navigate to Network tab
    - expect: Developer tools are open
  2. Navigate to a Crucible service (e.g., Player UI) that makes cross-origin requests to Keycloak
    - expect: Application loads and authenticates
  3. Observe network requests to Keycloak endpoints (token endpoint, userinfo endpoint)
    - expect: Requests include appropriate CORS headers
    - expect: Keycloak responses include Access-Control-Allow-Origin headers
    - expect: No CORS errors in console
    - expect: Requests from allowed origins succeed

#### 9.5. Test malformed authentication request

**File:** `tests/keycloak-security/test-malformed-request.spec.ts`

**Steps:**
  1. Craft a malformed OAuth2 authentication request (missing required parameters like client_id or redirect_uri)
    - expect: Malformed request prepared
  2. Send the malformed request to Keycloak authorization endpoint
    - expect: Keycloak returns error response
    - expect: Error indicates invalid request, missing parameters, or bad client ID
    - expect: No server error or crash occurs
    - expect: Error is handled gracefully

#### 9.6. Verify rate limiting on login attempts

**File:** `tests/keycloak-security/verify-rate-limiting.spec.ts`

**Steps:**
  1. Navigate to Keycloak login page
    - expect: Login page loads
  2. Attempt multiple failed login attempts rapidly (10-15 times with wrong password)
    - expect: Each attempt fails with invalid credentials error
  3. Observe behavior after multiple failures
    - expect: If brute force detection enabled, account may be temporarily locked or rate limited
    - expect: If brute force detection disabled (per realm config), all attempts fail but no lockout occurs
    - expect: Behavior matches realm's bruteForceProtected setting (false in crucible realm)

#### 9.7. Test access to admin console without authentication

**File:** `tests/keycloak-security/test-unauthenticated-admin-access.spec.ts`

**Steps:**
  1. Open incognito/private browser window
    - expect: Clean session with no cookies
  2. Attempt to navigate directly to admin console URL (https://localhost:8443/admin/crucible/console)
    - expect: Access is denied or redirected to login page
    - expect: Admin console does not load without authentication
    - expect: Login page appears requiring credentials

#### 9.8. Test token expiration and refresh

**File:** `tests/keycloak-security/test-token-expiration.spec.ts`

**Steps:**
  1. Authenticate with a Crucible service and obtain access token
    - expect: Access token is issued with 5-minute lifespan (per realm config)
  2. Observe or simulate token expiration (wait 5+ minutes or manipulate token expiry)
    - expect: Access token expires after configured lifespan
  3. Attempt to use expired token to access protected resource
    - expect: Request fails with 401 Unauthorized
    - expect: Error indicates token expired
  4. Use refresh token to obtain new access token
    - expect: Refresh token request succeeds
    - expect: New access token is issued
    - expect: Application can continue accessing protected resources
