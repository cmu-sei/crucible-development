# Blueprint Application Test Plan

## Application Overview

Blueprint is a collaborative MSEL (Master Scenario Events List) creation application within the Crucible cybersecurity training and simulation platform. It enables teams to design, manage, and execute training scenario events through a structured interface. Blueprint integrates with Player, Gallery, CITE, Player-VM, and Steamfitter services to provide comprehensive scenario management. The application supports event creation with customizable data fields, delivery methods, team/organization assignments, and timeline management. It features role-based access control, real-time collaboration, and visual scenario planning with color-coded event types.

## Test Scenarios

### 1. Authentication and Authorization

**Seed:** `tests/seed.spec.ts`

#### 1.1. User Login Flow

**File:** `tests/authentication-and-authorization/user-login-flow.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4725
    - expect: The application redirects to the Keycloak authentication page at https://localhost:8443/realms/crucible
  2. Enter username 'admin' in the username field
    - expect: The username field accepts input
  3. Enter password 'admin' in the password field
    - expect: The password field accepts input and masks the password
  4. Click the 'Sign In' button
    - expect: The application authenticates successfully
    - expect: The user is redirected back to http://localhost:4725
    - expect: The main application interface loads
    - expect: The topbar displays 'Blueprint - Collaborative MSEL Creation'
    - expect: The topbar background color is #2d69b4 with white text
    - expect: The username 'admin' is displayed in the topbar

#### 1.2. Unauthorized Access Redirect

**File:** `tests/authentication-and-authorization/unauthorized-access-redirect.spec.ts`

**Steps:**
  1. Clear all browser cookies and local storage
    - expect: All authentication tokens are removed
  2. Navigate to http://localhost:4725
    - expect: The application redirects to the Keycloak login page
    - expect: No application content is displayed before authentication

#### 1.3. User Logout Flow

**File:** `tests/authentication-and-authorization/user-logout-flow.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated and viewing the home page
  2. Click on the user menu in the topbar
    - expect: A dropdown menu appears with logout option
  3. Click 'Logout' option
    - expect: The user is logged out
    - expect: Authentication tokens are cleared from local storage
    - expect: The user is redirected to the Keycloak logout page or login page

#### 1.4. Session Token Renewal

**File:** `tests/authentication-and-authorization/session-token-renewal.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated
  2. Wait for silent token renewal (automaticSilentRenew is enabled in config)
    - expect: The application automatically renews the authentication token using the silent_redirect_uri (http://localhost:4725/auth-callback-silent.html)
    - expect: No user interaction is required for token renewal
    - expect: The user session remains active
    - expect: Console logs show token refresh activity

#### 1.5. Access Token Expiration Redirect

**File:** `tests/authentication-and-authorization/access-token-expiration-redirect.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated
  2. Wait for token to expire or manually invalidate the token
    - expect: Token expiration occurs
  3. Attempt to perform an authenticated action
    - expect: The application detects expired token (useAccessTokenExpirationRedirect is enabled)
    - expect: User is redirected to Keycloak login page
    - expect: User must re-authenticate to continue

### 2. Home Page and Navigation

**Seed:** `tests/seed.spec.ts`

#### 2.1. Home Page Initial Load

**File:** `tests/home-page-and-navigation/home-page-initial-load.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4725
    - expect: The home page loads successfully
    - expect: The topbar is visible with Blueprint branding
    - expect: The topbar displays 'Blueprint - Collaborative MSEL Creation'
    - expect: The topbar color is #2d69b4 with white text (#FFFFFF)
    - expect: A pencil-ruler icon is displayed in the topbar
    - expect: The user's username is displayed in the topbar
    - expect: The main content area displays MSEL list or dashboard

#### 2.2. Navigation to Admin Section

**File:** `tests/home-page-and-navigation/navigation-to-admin-section.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated on home page
  2. Navigate to admin section (if available via menu or URL)
    - expect: The admin interface loads
    - expect: A navigation menu is visible (sidebar or top navigation)
    - expect: Admin sections are accessible: MSELs, Teams, Users, Data Fields, etc.

#### 2.3. Theme Toggle (Light/Dark Mode)

**File:** `tests/home-page-and-navigation/theme-toggle-light-dark-mode.spec.ts`

**Steps:**
  1. Log in and navigate to the home page
    - expect: Application loads with default theme
  2. Locate and click the theme toggle button (typically in topbar)
    - expect: The application theme switches between light and dark mode
    - expect: Dark theme uses tint value of 0.7 as configured
    - expect: Light theme uses tint value of 0.4 as configured
    - expect: All components properly render in the new theme
    - expect: Theme preference is saved in local storage
    - expect: Overlay components (dialogs, dropdowns) also reflect the theme change
  3. Refresh the page
    - expect: The selected theme persists after page reload

#### 2.4. Browser Back and Forward Navigation

**File:** `tests/home-page-and-navigation/browser-back-and-forward-navigation.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4725 and view the home page
    - expect: Home page loads
  2. Click on a MSEL from the list to view its details
    - expect: MSEL details page is displayed
    - expect: URL changes to include MSEL ID
  3. Navigate to another section (e.g., Teams or Settings)
    - expect: New section is displayed
    - expect: URL changes accordingly
  4. Click browser back button
    - expect: Application navigates back to MSEL details page
    - expect: MSEL details are displayed
  5. Click browser back button again
    - expect: Application navigates back to home page
    - expect: MSEL list is displayed
  6. Click browser forward button
    - expect: Application navigates forward to MSEL details
    - expect: Correct MSEL is displayed

### 3. MSEL Management

**Seed:** `tests/seed.spec.ts`

#### 3.1. View MSELs List

**File:** `tests/msel-management/view-msels-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4725 after logging in
    - expect: MSELs list is displayed on the home page or main dashboard
    - expect: Each MSEL shows: name, description, status, dates, team/organization
    - expect: MSELs can be sorted and filtered
    - expect: If no MSELs exist, an appropriate empty state is shown with option to create new MSEL

#### 3.2. Create New MSEL

**File:** `tests/msel-management/create-new-msel.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is visible
  2. Click 'Create MSEL' or 'Add New' button
    - expect: A MSEL creation form is displayed
  3. Enter 'Cybersecurity Training Exercise 2026' in the Name field
    - expect: The name field accepts input
  4. Enter 'Advanced threat detection and response training scenario' in the Description field
    - expect: The description field accepts input
  5. Set the start date and end date for the MSEL
    - expect: Date picker allows selection of start and end dates
  6. Select or create teams/organizations to participate
    - expect: Teams can be selected from a dropdown or created inline
  7. Click 'Save' or 'Create' button
    - expect: The MSEL is created successfully
    - expect: A success notification is displayed
    - expect: The new MSEL appears in the MSELs list
    - expect: User is redirected to the MSEL details or edit page

#### 3.3. Edit MSEL

**File:** `tests/msel-management/edit-msel.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is visible with at least one MSEL
  2. Click on an existing MSEL or click its edit icon
    - expect: The MSEL edit page is displayed
    - expect: Form fields are populated with current values
  3. Modify the Description field
    - expect: The description field accepts the new value
  4. Change the end date
    - expect: The date field accepts the updated value
  5. Click 'Save' button
    - expect: The MSEL is updated successfully
    - expect: A success notification is displayed
    - expect: Updated values are reflected in the MSEL list
    - expect: Modification timestamp is updated

#### 3.4. Delete MSEL

**File:** `tests/msel-management/delete-msel.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is visible
  2. Click the delete icon for a specific MSEL
    - expect: A confirmation dialog appears asking to confirm deletion
  3. Click 'Cancel' in the confirmation dialog
    - expect: The dialog closes
    - expect: The MSEL is not deleted
  4. Click the delete icon again
    - expect: Confirmation dialog appears again
  5. Click 'Confirm' or 'Delete' button
    - expect: The MSEL is deleted successfully
    - expect: A success notification is displayed
    - expect: The MSEL is removed from the list
    - expect: If MSEL has associated events or data, deletion may be prevented with appropriate error message

#### 3.5. MSEL Form Validation

**File:** `tests/msel-management/msel-form-validation.spec.ts`

**Steps:**
  1. Navigate to MSELs list and click 'Create MSEL'
    - expect: MSEL creation form is displayed
  2. Leave the Name field empty and try to submit the form
    - expect: Validation error is displayed indicating Name is required
    - expect: Form submission is prevented
  3. Enter a name but set end date before start date
    - expect: Validation error indicates end date must be after start date
    - expect: Form submission is prevented
  4. Fill all required fields correctly
    - expect: Validation passes
    - expect: Save button becomes enabled
    - expect: Form can be submitted

#### 3.6. View MSEL Details

**File:** `tests/msel-management/view-msel-details.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is visible
  2. Click on a MSEL name or view button
    - expect: The MSEL detail view is displayed
    - expect: All MSEL properties are shown: name, description, dates, status
    - expect: Teams and organizations associated with the MSEL are visible
    - expect: Scenario events timeline or list is displayed
    - expect: Creation and modification timestamps are shown

#### 3.7. Search and Filter MSELs

**File:** `tests/msel-management/search-and-filter-msels.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is visible with multiple MSELs
  2. Enter a search term in the search box
    - expect: The list filters to show only MSELs matching the search term
    - expect: Search works on MSEL name and description
    - expect: Results update in real-time or after pressing enter
  3. Clear the search box
    - expect: All MSELs are displayed again
  4. Apply filters such as status or date range
    - expect: The list filters according to the selected criteria

#### 3.8. Sort MSELs

**File:** `tests/msel-management/sort-msels.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is visible
  2. Click on the 'Name' column header
    - expect: MSELs are sorted alphabetically by name
    - expect: A sort indicator shows the sort direction
  3. Click on the 'Name' column header again
    - expect: MSELs are sorted in reverse alphabetical order
    - expect: Sort indicator shows reverse direction
  4. Click on the 'Date Created' column header
    - expect: MSELs are sorted by creation date
    - expect: Newest or oldest first depending on initial sort direction

#### 3.9. Clone MSEL

**File:** `tests/msel-management/clone-msel.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is visible
  2. Select a MSEL and click 'Clone' or 'Duplicate' button
    - expect: A clone dialog or form is displayed
  3. Enter a new name for the cloned MSEL
    - expect: Name field accepts input
  4. Click 'Clone' button
    - expect: A copy of the MSEL is created with all scenario events
    - expect: The cloned MSEL appears in the list
    - expect: A success notification is displayed
    - expect: Cloned MSEL has independent data from the original

### 4. Scenario Events Management

**Seed:** `tests/seed.spec.ts`

#### 4.1. View Scenario Events in MSEL

**File:** `tests/scenario-events-management/view-scenario-events-in-msel.spec.ts`

**Steps:**
  1. Navigate to a MSEL details page
    - expect: MSEL details page is displayed
  2. View the scenario events timeline or list
    - expect: Scenario events are displayed in chronological order
    - expect: Each event shows: time, control number, from org, to org, description, details
    - expect: Events are color-coded based on their type (using configured background colors)
    - expect: Timeline view or list view is available for viewing events

#### 4.2. Create Scenario Event

**File:** `tests/scenario-events-management/create-scenario-event.spec.ts`

**Steps:**
  1. Navigate to a MSEL details page
    - expect: MSEL details page is displayed
  2. Click 'Add Event' or 'Create Scenario Event' button
    - expect: A scenario event creation form is displayed
  3. Enter 'CTRL-001' in the Control Number field (default data field)
    - expect: Control Number field accepts input
  4. Select 'Red Team' in the From Org field (Organization data type)
    - expect: From Org dropdown shows available organizations
  5. Select one or more teams in the To Org field (TeamsMultiple data type)
    - expect: To Org field allows multiple team selection
  6. Enter 'Initial phishing campaign' in the Description field
    - expect: Description field accepts input
  7. Enter detailed information in the Details field
    - expect: Details field accepts multi-line text input
  8. Set the event time/date
    - expect: Time picker allows scheduling the event
  9. Select a delivery method from options: Gallery, Email, or Notification
    - expect: Delivery method dropdown shows configured options
  10. Select an event type or category
    - expect: Event type selection assigns a color from configured background colors (10 colors available)
  11. Click 'Save' or 'Create' button
    - expect: The scenario event is created successfully
    - expect: A success notification is displayed
    - expect: The event appears in the timeline/list at the correct time position
    - expect: Event is displayed with its assigned color

#### 4.3. Edit Scenario Event

**File:** `tests/scenario-events-management/edit-scenario-event.spec.ts`

**Steps:**
  1. Navigate to a MSEL with existing scenario events
    - expect: MSEL details page shows scenario events
  2. Click on an event or its edit icon
    - expect: Event edit form is displayed
    - expect: All fields are populated with current values
  3. Modify the Description field
    - expect: Description field accepts new value
  4. Change the event time
    - expect: Time field accepts updated value
  5. Click 'Save' button
    - expect: The event is updated successfully
    - expect: A success notification is displayed
    - expect: Updated values are reflected in the timeline
    - expect: Event is repositioned if time changed

#### 4.4. Delete Scenario Event

**File:** `tests/scenario-events-management/delete-scenario-event.spec.ts`

**Steps:**
  1. Navigate to a MSEL with scenario events
    - expect: MSEL details page shows events
  2. Click the delete icon for a specific event
    - expect: A confirmation dialog appears
  3. Click 'Cancel'
    - expect: Dialog closes
    - expect: Event is not deleted
  4. Click delete icon again and confirm
    - expect: The event is deleted successfully
    - expect: A success notification is displayed
    - expect: Event is removed from the timeline

#### 4.5. Scenario Event Timeline View

**File:** `tests/scenario-events-management/scenario-event-timeline-view.spec.ts`

**Steps:**
  1. Navigate to a MSEL with multiple scenario events
    - expect: MSEL details page is displayed
  2. Switch to timeline view (if not default)
    - expect: Events are displayed on a visual timeline
    - expect: Events are positioned according to their scheduled time
    - expect: Color-coded events are easy to distinguish
    - expect: Timeline shows time markers and scale
  3. Zoom in and out on the timeline
    - expect: Timeline zoom controls allow adjusting the time scale
    - expect: Events remain properly positioned during zoom
  4. Drag an event to a new time (if drag-and-drop is supported)
    - expect: Event can be repositioned by dragging
    - expect: Event time is updated automatically
    - expect: Changes are saved or require confirmation

#### 4.6. Scenario Event Custom Data Fields

**File:** `tests/scenario-events-management/scenario-event-custom-data-fields.spec.ts`

**Steps:**
  1. Navigate to MSEL admin or settings
    - expect: Admin/settings page is accessible
  2. Add a custom data field (beyond the 5 defaults) for scenario events
    - expect: Custom data field form is available
    - expect: Field can be configured with name, data type (String, Organization, Teams, etc.), and display order
  3. Create a new scenario event
    - expect: The custom data field appears in the event creation form
    - expect: Field is positioned according to display order
    - expect: Field validates according to its data type

#### 4.7. Scenario Event Delivery Methods

**File:** `tests/scenario-events-management/scenario-event-delivery-methods.spec.ts`

**Steps:**
  1. Create a scenario event and select 'Gallery' as delivery method
    - expect: Delivery method is saved
    - expect: Integration with Gallery service is configured for this event
  2. Create another event with 'Email' delivery method
    - expect: Email delivery is configured
    - expect: Email integration settings are accessible
  3. Create an event with 'Notification' delivery method
    - expect: Notification delivery is configured
    - expect: Notification integration settings are available

#### 4.8. Bulk Import Scenario Events

**File:** `tests/scenario-events-management/bulk-import-scenario-events.spec.ts`

**Steps:**
  1. Navigate to a MSEL details page
    - expect: MSEL details page is displayed
  2. Click 'Import' or 'Upload Events' button
    - expect: File upload dialog is displayed
  3. Select a CSV or Excel file with scenario events
    - expect: File is uploaded
    - expect: System validates file format and data
  4. Review import preview
    - expect: Preview shows events to be imported with data mapping
    - expect: Errors or warnings are displayed if data is invalid
  5. Confirm import
    - expect: Events are imported into the MSEL
    - expect: A success notification shows number of events imported
    - expect: Imported events appear in the timeline

#### 4.9. Export Scenario Events

**File:** `tests/scenario-events-management/export-scenario-events.spec.ts`

**Steps:**
  1. Navigate to a MSEL with scenario events
    - expect: MSEL details page shows events
  2. Click 'Export' button
    - expect: Export options are displayed (CSV, Excel, PDF, etc.)
  3. Select Excel format
    - expect: File is generated and downloaded
    - expect: Excel file contains all events with data fields
    - expect: Row height is set to 15 (as configured in DefaultXlsxRowHeight)

#### 4.10. Scenario Event Color Coding

**File:** `tests/scenario-events-management/scenario-event-color-coding.spec.ts`

**Steps:**
  1. Create multiple scenario events of different types
    - expect: Events are created with different categories/types
  2. View the events in timeline or list view
    - expect: Each event type is displayed with a distinct background color
    - expect: Colors are from the configured palette: 70,130,255 (blue), 255,69,0 (red-orange), 102,51,153 (purple), etc.
    - expect: Up to 10 different event types can be distinguished by color
    - expect: Colors adapt to theme (DarkThemeTint: 0.7, LightThemeTint: 0.4)

### 5. Teams and Organizations Management

**Seed:** `tests/seed.spec.ts`

#### 5.1. View Teams List

**File:** `tests/teams-and-organizations-management/view-teams-list.spec.ts`

**Steps:**
  1. Navigate to Teams section (via menu or admin)
    - expect: Teams list is displayed
    - expect: Each team shows: name, organization, member count
    - expect: If no teams exist, an appropriate empty state is shown

#### 5.2. Create New Team

**File:** `tests/teams-and-organizations-management/create-new-team.spec.ts`

**Steps:**
  1. Navigate to Teams section
    - expect: Teams list is visible
  2. Click 'Add Team' or 'Create Team' button
    - expect: Team creation form is displayed
  3. Enter 'Blue Team' in the Name field
    - expect: Name field accepts input
  4. Select or create an organization for this team
    - expect: Organization dropdown or creation field is available
  5. Click 'Save' or 'Create' button
    - expect: The team is created successfully
    - expect: A success notification is displayed
    - expect: The new team appears in the teams list

#### 5.3. Edit Team

**File:** `tests/teams-and-organizations-management/edit-team.spec.ts`

**Steps:**
  1. Navigate to Teams section
    - expect: Teams list is visible
  2. Click on a team to view details or edit
    - expect: Team edit form is displayed
    - expect: Fields are populated with current values
  3. Modify the team name or organization
    - expect: Changes can be made
  4. Click 'Save' button
    - expect: Team is updated successfully
    - expect: A success notification is displayed
    - expect: Updated values are reflected in the list

#### 5.4. Delete Team

**File:** `tests/teams-and-organizations-management/delete-team.spec.ts`

**Steps:**
  1. Navigate to Teams section
    - expect: Teams list is visible
  2. Click delete icon for a team
    - expect: Confirmation dialog appears
  3. Confirm deletion
    - expect: Team is deleted successfully
    - expect: A success notification is displayed
    - expect: Team is removed from the list
    - expect: If team is referenced in scenario events, deletion may be prevented

#### 5.5. View Organizations List

**File:** `tests/teams-and-organizations-management/view-organizations-list.spec.ts`

**Steps:**
  1. Navigate to Organizations section
    - expect: Organizations list is displayed
    - expect: Each organization shows: name, description, teams count

#### 5.6. Create Organization

**File:** `tests/teams-and-organizations-management/create-organization.spec.ts`

**Steps:**
  1. Navigate to Organizations section
    - expect: Organizations list is visible
  2. Click 'Add Organization' button
    - expect: Organization creation form is displayed
  3. Enter organization details
    - expect: Name and description fields accept input
  4. Click 'Save'
    - expect: Organization is created successfully
    - expect: New organization appears in the list
    - expect: Can now be assigned to teams and used in scenario events

#### 5.7. Assign Teams to Organization

**File:** `tests/teams-and-organizations-management/assign-teams-to-organization.spec.ts`

**Steps:**
  1. Navigate to an organization's details
    - expect: Organization details page is displayed
  2. View teams assigned to this organization
    - expect: List of teams is shown
  3. Add a new team to the organization
    - expect: Team can be selected and assigned
    - expect: Organization-team relationship is saved

### 6. User and Role Management

**Seed:** `tests/seed.spec.ts`

#### 6.1. View Users List

**File:** `tests/user-and-role-management/view-users-list.spec.ts`

**Steps:**
  1. Navigate to Users section (admin area)
    - expect: Users list is displayed
    - expect: Each user shows: username, name, email, roles
    - expect: Pagination controls are visible if there are many users

#### 6.2. Search Users

**File:** `tests/user-and-role-management/search-users.spec.ts`

**Steps:**
  1. Navigate to Users section
    - expect: Users list is visible
  2. Enter a search term in the search box
    - expect: The list filters to show only matching users
    - expect: Search works on username, name, and email
    - expect: Results update in real-time

#### 6.3. View User Details

**File:** `tests/user-and-role-management/view-user-details.spec.ts`

**Steps:**
  1. Navigate to Users section
    - expect: Users list is visible
  2. Click on a user
    - expect: User details page is displayed
    - expect: Shows user information, roles, and permissions
    - expect: Shows MSELs and teams the user is associated with

#### 6.4. Assign Role to User

**File:** `tests/user-and-role-management/assign-role-to-user.spec.ts`

**Steps:**
  1. Navigate to a user's details page
    - expect: User details are displayed
  2. Click 'Add Role' button
    - expect: Role selection dialog appears
  3. Select a role from available options
    - expect: Role dropdown shows system and MSEL-specific roles
  4. Click 'Add'
    - expect: Role is assigned to the user
    - expect: Success notification is displayed
    - expect: Role appears in user's roles list

#### 6.5. Remove Role from User

**File:** `tests/user-and-role-management/remove-role-from-user.spec.ts`

**Steps:**
  1. Navigate to a user's roles section
    - expect: User's roles are displayed
  2. Click remove icon for a role
    - expect: Confirmation dialog appears
  3. Confirm removal
    - expect: Role is removed from user
    - expect: Success notification is displayed
    - expect: Role no longer appears in list

#### 6.6. View System Roles

**File:** `tests/user-and-role-management/view-system-roles.spec.ts`

**Steps:**
  1. Navigate to Roles section in admin
    - expect: System roles list is displayed
    - expect: Shows roles like: Administrator, MSEL Editor, Viewer, etc.
    - expect: Each role shows associated permissions

#### 6.7. Create Custom Role

**File:** `tests/user-and-role-management/create-custom-role.spec.ts`

**Steps:**
  1. Navigate to Roles section
    - expect: Roles list is visible
  2. Click 'Create Role' button
    - expect: Role creation form is displayed
  3. Enter role name and select permissions
    - expect: Name field accepts input
    - expect: Permissions checkboxes allow selection
  4. Click 'Save'
    - expect: Custom role is created
    - expect: Role appears in roles list
    - expect: Can now be assigned to users

### 7. Integration with Crucible Services

**Seed:** `tests/seed.spec.ts`

#### 7.1. Gallery Integration - Content Selection

**File:** `tests/integration-with-crucible-services/gallery-integration-content-selection.spec.ts`

**Steps:**
  1. Create a scenario event with Gallery delivery method
    - expect: Event creation form shows Gallery integration options
  2. Click 'Select from Gallery' or browse Gallery content
    - expect: Gallery content browser opens
    - expect: Shows available content items from Gallery service (http://localhost:4723)
    - expect: Content can be filtered and searched
  3. Select content item(s) to associate with the event
    - expect: Content is linked to the scenario event
    - expect: Selected content appears in event details

#### 7.2. CITE Integration - Team Collaboration

**File:** `tests/integration-with-crucible-services/cite-integration-team-collaboration.spec.ts`

**Steps:**
  1. Navigate to a MSEL that is linked to a CITE evaluation
    - expect: MSEL details show CITE integration status
  2. Click 'Open in CITE' or similar integration link
    - expect: Navigation to CITE service (http://localhost:4721) occurs
    - expect: CITE shows the associated evaluation for this MSEL
    - expect: Teams and scenario timeline are synchronized

#### 7.3. Player Integration - View Association

**File:** `tests/integration-with-crucible-services/player-integration-view-association.spec.ts`

**Steps:**
  1. Create or edit a MSEL
    - expect: MSEL form is displayed
  2. Associate a Player view with the MSEL
    - expect: Player view selector shows available views from Player service (http://localhost:4301)
    - expect: View can be selected and linked to MSEL
  3. Save and view MSEL details
    - expect: Player view is shown as associated
    - expect: Link to open Player with this view is available

#### 7.4. Player-VM Integration - Virtual Machine Access

**File:** `tests/integration-with-crucible-services/player-vm-integration-virtual-machine-access.spec.ts`

**Steps:**
  1. Navigate to a MSEL with VM requirements
    - expect: MSEL details page is displayed
  2. Configure Player-VM integration settings
    - expect: Player-VM service integration (http://localhost:4303) is configured
    - expect: VMs can be assigned to teams or scenario events
  3. Access VM console from scenario event
    - expect: VM console opens in new window or embedded view
    - expect: Users can interact with assigned VMs during scenario

#### 7.5. Steamfitter Integration - Scenario Automation

**File:** `tests/integration-with-crucible-services/steamfitter-integration-scenario-automation.spec.ts`

**Steps:**
  1. Create or edit a MSEL
    - expect: MSEL form is displayed
  2. Link a Steamfitter scenario to the MSEL
    - expect: Steamfitter scenario selector shows available scenarios from Steamfitter service (http://localhost:4401)
    - expect: Scenario can be selected and associated with MSEL
  3. Configure scenario automation triggers based on MSEL timeline
    - expect: Scenario events can trigger Steamfitter tasks
    - expect: Timeline synchronization is configured

#### 7.6. API Integration - Blueprint API Endpoints

**File:** `tests/integration-with-crucible-services/api-integration-blueprint-api-endpoints.spec.ts`

**Steps:**
  1. Open browser developer tools Network tab
    - expect: Network tab is active
  2. Perform various actions in Blueprint UI (create MSEL, add event, etc.)
    - expect: API calls are made to http://localhost:4724 (Blueprint API)
    - expect: Requests use proper authentication headers
    - expect: Responses are in expected JSON format
    - expect: Error handling works correctly

### 8. Real-time Collaboration and SignalR

**Seed:** `tests/seed.spec.ts`

#### 8.1. Real-time MSEL Updates

**File:** `tests/real-time-collaboration-and-signalr/real-time-msel-updates.spec.ts`

**Steps:**
  1. Open two browser windows, both viewing the same MSEL
    - expect: Both windows display the same MSEL details
  2. In window 1, create a new scenario event
    - expect: Event is created in window 1
  3. Observe window 2 without refreshing
    - expect: Window 2 receives real-time update via SignalR
    - expect: New event appears automatically in window 2
    - expect: No manual refresh is required

#### 8.2. Real-time Scenario Event Updates

**File:** `tests/real-time-collaboration-and-signalr/real-time-scenario-event-updates.spec.ts`

**Steps:**
  1. Open two windows viewing the same MSEL timeline
    - expect: Both windows show the same timeline
  2. In window 1, edit an existing event
    - expect: Event is updated in window 1
  3. Observe window 2
    - expect: Event updates automatically in window 2
    - expect: Changes are reflected in real-time
    - expect: Color or position changes are immediately visible

#### 8.3. Collaborative Editing Conflict Resolution

**File:** `tests/real-time-collaboration-and-signalr/collaborative-editing-conflict-resolution.spec.ts`

**Steps:**
  1. Open two windows, both editing the same scenario event
    - expect: Both windows have the event edit form open
  2. In window 1, modify and save the event
    - expect: Event is saved from window 1
  3. In window 2, make different changes and try to save
    - expect: Conflict detection occurs
    - expect: User is notified that the event was modified by another user
    - expect: Options to reload, merge, or overwrite are presented

#### 8.4. User Presence Indicators

**File:** `tests/real-time-collaboration-and-signalr/user-presence-indicators.spec.ts`

**Steps:**
  1. Open a MSEL with multiple users viewing it
    - expect: MSEL is displayed
  2. Check for user presence indicators
    - expect: Active users viewing the MSEL are shown
    - expect: User avatars or names are displayed
    - expect: Real-time join/leave notifications appear

#### 8.5. SignalR Connection Establishment

**File:** `tests/real-time-collaboration-and-signalr/signalr-connection-establishment.spec.ts`

**Steps:**
  1. Open browser developer console
    - expect: Console is open
  2. Log in and navigate to a MSEL
    - expect: MSEL page loads
  3. Check console logs for SignalR connection messages
    - expect: Console shows SignalR connection established
    - expect: Hub connection is successful
    - expect: No connection errors are displayed

#### 8.6. SignalR Reconnection on Network Interruption

**File:** `tests/real-time-collaboration-and-signalr/signalr-reconnection-on-network-interruption.spec.ts`

**Steps:**
  1. Establish SignalR connection by viewing a MSEL
    - expect: SignalR connection is active
  2. Simulate network disconnection
    - expect: Network connection is lost
  3. Restore network connection
    - expect: SignalR automatically attempts to reconnect
    - expect: Console logs show reconnection attempts
    - expect: Real-time updates resume once reconnected
    - expect: User may see a notification about connection status

### 9. Error Handling and Validation

**Seed:** `tests/seed.spec.ts`

#### 9.1. API Error Display

**File:** `tests/error-handling-and-validation/api-error-display.spec.ts`

**Steps:**
  1. Trigger an API error (e.g., create MSEL with invalid data)
    - expect: API returns error response
  2. Observe application response
    - expect: Error notification or message is displayed
    - expect: Error message is clear and actionable
    - expect: Form submission is prevented
    - expect: User can correct the error and retry

#### 9.2. Network Error Handling

**File:** `tests/error-handling-and-validation/network-error-handling.spec.ts`

**Steps:**
  1. Disconnect from network while using the application
    - expect: Network connection is lost
  2. Attempt to perform an action (e.g., save event)
    - expect: Application detects network error
    - expect: Appropriate error message is displayed
    - expect: Action fails gracefully without crashing
    - expect: Unsaved changes may be preserved locally
  3. Restore network connection
    - expect: Application resumes normal operation
    - expect: User can retry the action

#### 9.3. Required Field Validation

**File:** `tests/error-handling-and-validation/required-field-validation.spec.ts`

**Steps:**
  1. Open any form with required fields
    - expect: Form is displayed with required field indicators
  2. Leave required fields empty and attempt to submit
    - expect: Validation errors are displayed for each required field
    - expect: Error messages clearly indicate which fields are required
    - expect: Form submission is prevented
    - expect: Required fields are visually highlighted

#### 9.4. Data Type Validation

**File:** `tests/error-handling-and-validation/data-type-validation.spec.ts`

**Steps:**
  1. Open a form with typed fields (e.g., date, number, email)
    - expect: Form is displayed
  2. Enter invalid data type
    - expect: Validation error is displayed
    - expect: Error message indicates the expected data type
    - expect: Form submission is prevented
  3. Enter valid data
    - expect: Validation passes
    - expect: Form can be submitted

#### 9.5. Unauthorized Action Handling

**File:** `tests/error-handling-and-validation/unauthorized-action-handling.spec.ts`

**Steps:**
  1. Log in as a user without admin permissions
    - expect: User is authenticated
  2. Attempt to access admin-only features
    - expect: Access is denied
    - expect: Appropriate error message is displayed
    - expect: User is redirected or shown permission error
    - expect: No sensitive data is exposed

#### 9.6. Duplicate Name Validation

**File:** `tests/error-handling-and-validation/duplicate-name-validation.spec.ts`

**Steps:**
  1. Create a MSEL with a specific name
    - expect: MSEL is created successfully
  2. Attempt to create another MSEL with the same name
    - expect: Validation error indicates duplicate name
    - expect: Form submission is prevented
    - expect: User is prompted to choose a different name

#### 9.7. Date Range Validation

**File:** `tests/error-handling-and-validation/date-range-validation.spec.ts`

**Steps:**
  1. Create a MSEL or scenario event
    - expect: Form with date fields is displayed
  2. Set end date before start date
    - expect: Validation error indicates invalid date range
    - expect: Error message explains that end date must be after start date
    - expect: Form submission is prevented
  3. Set valid date range
    - expect: Validation passes
    - expect: Form can be submitted

### 10. Search and Filtering

**Seed:** `tests/seed.spec.ts`

#### 10.1. Global Search Functionality

**File:** `tests/search-and-filtering/global-search-functionality.spec.ts`

**Steps:**
  1. Locate the global search box (typically in topbar)
    - expect: Search box is visible
  2. Enter a search term that matches MSELs, events, teams, or users
    - expect: Search results appear in real-time or after submission
    - expect: Results are categorized by type (MSELs, Events, Teams, etc.)
    - expect: Matching items are highlighted
  3. Click on a search result
    - expect: Navigation to the selected item occurs
    - expect: Item details page is displayed

#### 10.2. MSEL Filtering by Status

**File:** `tests/search-and-filtering/msel-filtering-by-status.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is displayed
  2. Apply status filter (e.g., Draft, Active, Completed)
    - expect: Filter dropdown shows available statuses
    - expect: List updates to show only MSELs matching selected status
  3. Clear filter
    - expect: All MSELs are displayed again

#### 10.3. MSEL Filtering by Date Range

**File:** `tests/search-and-filtering/msel-filtering-by-date-range.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is displayed
  2. Apply date range filter
    - expect: Date picker allows selecting start and end dates
    - expect: List updates to show only MSELs within the selected date range

#### 10.4. Scenario Event Filtering by Organization

**File:** `tests/search-and-filtering/scenario-event-filtering-by-organization.spec.ts`

**Steps:**
  1. Navigate to a MSEL with multiple scenario events
    - expect: Scenario events are displayed
  2. Apply organization filter to show events from specific org
    - expect: Filter shows available organizations
    - expect: Events list updates to show only events from/to selected organization

#### 10.5. Scenario Event Filtering by Event Type

**File:** `tests/search-and-filtering/scenario-event-filtering-by-event-type.spec.ts`

**Steps:**
  1. Navigate to a MSEL timeline view
    - expect: Scenario events are displayed with different colors/types
  2. Apply event type filter
    - expect: Filter shows available event types
    - expect: Timeline updates to show only selected event types
    - expect: Other events are hidden or grayed out

#### 10.6. Advanced Search with Multiple Criteria

**File:** `tests/search-and-filtering/advanced-search-with-multiple-criteria.spec.ts`

**Steps:**
  1. Open advanced search or filter panel
    - expect: Advanced search options are displayed
  2. Apply multiple filters (e.g., status + date range + organization)
    - expect: Multiple filters can be combined
    - expect: Results match all selected criteria (AND logic)
    - expect: Filter summary shows active filters
  3. Clear all filters
    - expect: All filters are removed
    - expect: Full unfiltered list is displayed

### 11. Export and Import

**Seed:** `tests/seed.spec.ts`

#### 11.1. Export MSEL to Excel

**File:** `tests/export-and-import/export-msel-to-excel.spec.ts`

**Steps:**
  1. Navigate to a MSEL details page
    - expect: MSEL with scenario events is displayed
  2. Click 'Export' button and select Excel format
    - expect: File is generated and downloaded
    - expect: Excel file contains MSEL details and all scenario events
    - expect: Data fields are properly formatted in columns
    - expect: Row height is 15 pixels as configured
    - expect: Event colors are preserved or indicated

#### 11.2. Export MSEL to CSV

**File:** `tests/export-and-import/export-msel-to-csv.spec.ts`

**Steps:**
  1. Navigate to a MSEL details page
    - expect: MSEL is displayed
  2. Click 'Export' button and select CSV format
    - expect: CSV file is generated and downloaded
    - expect: CSV contains all scenario events with data fields
    - expect: Data is properly escaped and formatted

#### 11.3. Export MSEL to PDF

**File:** `tests/export-and-import/export-msel-to-pdf.spec.ts`

**Steps:**
  1. Navigate to a MSEL details page
    - expect: MSEL is displayed
  2. Click 'Export' button and select PDF format
    - expect: PDF is generated and downloaded
    - expect: PDF contains MSEL overview and timeline
    - expect: Event colors are visible in PDF
    - expect: Formatting is professional and readable

#### 11.4. Import MSEL from Excel

**File:** `tests/export-and-import/import-msel-from-excel.spec.ts`

**Steps:**
  1. Navigate to MSELs list
    - expect: MSELs list is displayed
  2. Click 'Import' button
    - expect: File upload dialog is displayed
  3. Select a valid Excel file with MSEL data
    - expect: File is uploaded and validated
    - expect: Import preview shows data to be imported
    - expect: Validation errors are highlighted if any
  4. Confirm import
    - expect: MSEL and events are created from Excel data
    - expect: Success notification shows import results
    - expect: New MSEL appears in the list

#### 11.5. Import Scenario Events from CSV

**File:** `tests/export-and-import/import-scenario-events-from-csv.spec.ts`

**Steps:**
  1. Navigate to a MSEL details page
    - expect: MSEL is displayed
  2. Click 'Import Events' button
    - expect: File upload dialog is displayed
  3. Select a CSV file with scenario events
    - expect: File is uploaded and parsed
    - expect: Column mapping interface allows matching CSV columns to data fields
    - expect: Preview shows events to be imported
  4. Confirm import
    - expect: Events are imported into the MSEL
    - expect: Events appear in timeline at correct times
    - expect: Success notification shows number imported

#### 11.6. Export Selected Events Only

**File:** `tests/export-and-import/export-selected-events-only.spec.ts`

**Steps:**
  1. Navigate to a MSEL with scenario events
    - expect: Events are displayed
  2. Select specific events using checkboxes or selection tool
    - expect: Selected events are highlighted
  3. Click 'Export Selected' button
    - expect: Export format selection is displayed
    - expect: Only selected events are included in export
    - expect: File is downloaded

### 12. Accessibility and Usability

**Seed:** `tests/seed.spec.ts`

#### 12.1. Keyboard Navigation

**File:** `tests/accessibility-and-usability/keyboard-navigation.spec.ts`

**Steps:**
  1. Navigate to the home page
    - expect: Home page is loaded
  2. Use Tab key to navigate through interactive elements
    - expect: Focus moves sequentially through all interactive elements
    - expect: Focus indicator is clearly visible
    - expect: All buttons, links, and form fields are accessible via keyboard
  3. Use Shift+Tab to navigate backwards
    - expect: Focus moves backwards through elements
  4. Use Enter or Space to activate buttons and links
    - expect: Buttons and links respond to keyboard activation

#### 12.2. Screen Reader Compatibility

**File:** `tests/accessibility-and-usability/screen-reader-compatibility.spec.ts`

**Steps:**
  1. Enable a screen reader (NVDA, JAWS, or VoiceOver)
    - expect: Screen reader is active
  2. Navigate through the application
    - expect: Screen reader announces page titles and headings
    - expect: Form labels are properly announced
    - expect: Button purposes are clear
    - expect: Status messages and notifications are announced
    - expect: ARIA labels provide context for complex UI elements

#### 12.3. Color Contrast Compliance

**File:** `tests/accessibility-and-usability/color-contrast-compliance.spec.ts`

**Steps:**
  1. Navigate through different pages and components
    - expect: All pages load successfully
  2. Check text color contrast against backgrounds
    - expect: Text has sufficient contrast ratio (WCAG AA: 4.5:1 for normal text, 3:1 for large text)
    - expect: Both light and dark themes meet contrast requirements
    - expect: Topbar with #2d69b4 background and white text meets requirements
    - expect: Event colors remain distinguishable with sufficient contrast

#### 12.4. Responsive Layout - Mobile View

**File:** `tests/accessibility-and-usability/responsive-layout-mobile-view.spec.ts`

**Steps:**
  1. Resize browser to mobile viewport (375x667)
    - expect: Page layout adapts to mobile view
  2. Navigate through the application
    - expect: All content is accessible
    - expect: Navigation menu adapts (hamburger menu)
    - expect: Forms and timeline are usable on small screens
    - expect: No horizontal scrolling is required
    - expect: Touch targets are appropriately sized (minimum 44x44 pixels)

#### 12.5. Responsive Layout - Tablet View

**File:** `tests/accessibility-and-usability/responsive-layout-tablet-view.spec.ts`

**Steps:**
  1. Resize browser to tablet viewport (768x1024)
    - expect: Page layout adapts to tablet view
  2. Navigate through the application
    - expect: Layout makes efficient use of available space
    - expect: All features remain accessible
    - expect: Timeline view is optimized for tablet

#### 12.6. Responsive Layout - Desktop View

**File:** `tests/accessibility-and-usability/responsive-layout-desktop-view.spec.ts`

**Steps:**
  1. View application in desktop resolution (1920x1080)
    - expect: Page layout utilizes desktop space effectively
  2. Resize window to various widths
    - expect: Layout adapts smoothly to different window sizes
    - expect: No content is cut off or inaccessible
    - expect: Timeline scales appropriately

#### 12.7. Focus Management in Dialogs

**File:** `tests/accessibility-and-usability/focus-management-in-dialogs.spec.ts`

**Steps:**
  1. Open a dialog (e.g., create scenario event)
    - expect: Dialog opens
  2. Check focus behavior
    - expect: Focus is moved to the dialog when it opens
    - expect: Focus is trapped within the dialog
    - expect: Escape key closes the dialog
    - expect: When dialog closes, focus returns to the triggering element

#### 12.8. Loading States and Feedback

**File:** `tests/accessibility-and-usability/loading-states-and-feedback.spec.ts`

**Steps:**
  1. Trigger an action that takes time (e.g., import MSEL)
    - expect: Action is initiated
  2. Observe the UI during processing
    - expect: Loading indicator is displayed
    - expect: Submit button is disabled during processing
    - expect: User receives feedback that action is in progress
    - expect: Loading state is announced to screen readers
  3. Wait for action to complete
    - expect: Loading indicator disappears
    - expect: Success or error message is displayed
    - expect: UI updates to reflect completed action

### 13. Performance and Optimization

**Seed:** `tests/seed.spec.ts`

#### 13.1. Initial Page Load Time

**File:** `tests/performance-and-optimization/initial-page-load-time.spec.ts`

**Steps:**
  1. Clear browser cache and navigate to http://localhost:4725
    - expect: Application loads from scratch
  2. Measure page load time using browser Performance tab
    - expect: Initial page load completes within acceptable time (< 3 seconds)
    - expect: Time to First Contentful Paint (FCP) is reasonable
    - expect: Time to Interactive (TTI) is acceptable
    - expect: No unnecessary blocking resources

#### 13.2. Subsequent Page Load Time

**File:** `tests/performance-and-optimization/subsequent-page-load-time.spec.ts`

**Steps:**
  1. After initial load, navigate to different sections
    - expect: Navigation occurs
  2. Measure page transition times
    - expect: Page transitions are fast (< 1 second)
    - expect: Cached resources are utilized
    - expect: Lazy loading is used appropriately

#### 13.3. Large Timeline Performance

**File:** `tests/performance-and-optimization/large-timeline-performance.spec.ts`

**Steps:**
  1. Navigate to a MSEL with 100+ scenario events
    - expect: Timeline loads with many events
  2. Scroll through the timeline
    - expect: Scrolling is smooth without jank
    - expect: Virtual scrolling or pagination is used
    - expect: Browser remains responsive
    - expect: Event rendering is optimized
  3. Apply filters or search
    - expect: Filtering is responsive
    - expect: Results update quickly
    - expect: UI does not freeze

#### 13.4. Memory Leak Detection

**File:** `tests/performance-and-optimization/memory-leak-detection.spec.ts`

**Steps:**
  1. Open browser dev tools and start memory profiling
    - expect: Memory profiler is active
  2. Navigate through various MSELs and sections multiple times
    - expect: Multiple navigation cycles complete
  3. Check memory usage
    - expect: Memory usage stabilizes
    - expect: No continuous increase in memory
    - expect: Garbage collection occurs appropriately

#### 13.5. API Call Optimization

**File:** `tests/performance-and-optimization/api-call-optimization.spec.ts`

**Steps:**
  1. Open browser dev tools Network tab
    - expect: Network tab is active
  2. Navigate and perform actions
    - expect: Various API calls are made
  3. Analyze API calls
    - expect: No redundant API calls are made
    - expect: Data is cached appropriately
    - expect: API calls to http://localhost:4724 are optimized
    - expect: Loading states prevent duplicate requests

#### 13.6. Large Export Performance

**File:** `tests/performance-and-optimization/large-export-performance.spec.ts`

**Steps:**
  1. Export a MSEL with 500+ scenario events to Excel
    - expect: Export is initiated
  2. Monitor export process
    - expect: Progress indicator shows export status
    - expect: UI remains responsive during export
    - expect: Export completes within reasonable time
    - expect: File size is reasonable and opens correctly
