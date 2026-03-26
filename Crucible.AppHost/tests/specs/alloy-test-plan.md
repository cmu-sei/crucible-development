# Alloy Application Test Plan

## Application Overview

Alloy is an advanced orchestration application within the Crucible cybersecurity training and simulation platform. It serves as the central coordination layer that orchestrates complex training exercises by integrating Player (learning platform), Caster (infrastructure orchestration), and Steamfitter (scenario execution) services. Alloy manages Event Templates (reusable exercise blueprints) and Events (live exercise instances), handling the complete lifecycle from creation through deployment to teardown.

## Test Scenarios

### 1. Authentication and Authorization

**Seed:** `tests/seed.spec.ts`

#### 1.1. User Login Flow

**File:** `tests/authentication-and-authorization/user-login-flow.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403
    - expect: The application redirects to the Keycloak authentication page at https://localhost:8443/realms/crucible
  2. Enter username 'admin' in the username field
    - expect: The username field accepts input
  3. Enter password 'admin' in the password field
    - expect: The password field accepts input and masks the password
  4. Click the 'Sign In' button
    - expect: The application authenticates successfully
    - expect: The user is redirected back to http://localhost:4403
    - expect: The main application interface loads
    - expect: The topbar displays the username 'admin'

#### 1.2. Unauthorized Access Redirect

**File:** `tests/authentication-and-authorization/unauthorized-access-redirect.spec.ts`

**Steps:**
  1. Clear all browser cookies and local storage
    - expect: All authentication tokens are removed
  2. Navigate to http://localhost:4403/admin
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
    - expect: Authentication tokens are cleared
    - expect: The user is redirected to the Keycloak logout page or login page

#### 1.4. Session Token Renewal

**File:** `tests/authentication-and-authorization/session-token-renewal.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated
  2. Wait for silent token renewal (check console logs for token refresh)
    - expect: The application automatically renews the authentication token using the silent_redirect_uri
    - expect: No user interaction is required for token renewal
    - expect: The user session remains active

### 2. Home Page and Navigation

**Seed:** `tests/seed.spec.ts`

#### 2.1. Home Page Initial Load

**File:** `tests/home-page-and-navigation/home-page-initial-load.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4403
    - expect: The home page loads successfully
    - expect: The topbar is visible with application branding
    - expect: The topbar displays 'Alloy' or configured AppTopBarText
    - expect: The topbar color matches the configured color (#719F94 by default)
    - expect: The user's username is displayed in the topbar
    - expect: The main content area displays event list or welcome content

#### 2.2. Navigation to Admin Section

**File:** `tests/home-page-and-navigation/navigation-to-admin-section.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated on home page
  2. Navigate to http://localhost:4403/admin
    - expect: The admin interface loads
    - expect: A sidebar navigation menu is visible on the left
    - expect: The sidebar contains sections: Event Templates, Events, Roles, Groups, Users
    - expect: The 'Event Templates' section is selected by default

#### 2.3. Sidebar Navigation Toggle

**File:** `tests/home-page-and-navigation/sidebar-navigation-toggle.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403/admin
    - expect: Admin page loads with sidebar visible
  2. Click the sidebar toggle button (if present)
    - expect: The sidebar collapses or expands
    - expect: The main content area adjusts to accommodate the sidebar state
    - expect: The toggle state persists during the session

#### 2.4. Theme Toggle (Light/Dark Mode)

**File:** `tests/home-page-and-navigation/theme-toggle-light-dark-mode.spec.ts`

**Steps:**
  1. Log in and navigate to the home page
    - expect: Application loads with default theme
  2. Locate and click the theme toggle button (typically in topbar)
    - expect: The application theme switches between light and dark mode
    - expect: All components properly render in the new theme
    - expect: Theme preference is saved (check if it persists on page reload)
    - expect: Overlay components (dialogs, dropdowns) also reflect the theme change

#### 2.5. Browser Back and Forward Navigation

**File:** `tests/home-page-and-navigation/browser-back-and-forward-navigation.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403/admin
    - expect: Admin page loads
  2. Click on 'Events' in the sidebar
    - expect: Events section is displayed
    - expect: URL changes to include events section
  3. Click on 'Users' in the sidebar
    - expect: Users section is displayed
    - expect: URL changes accordingly
  4. Click browser back button
    - expect: Application navigates back to Events section
    - expect: Events list is displayed
  5. Click browser forward button
    - expect: Application navigates forward to Users section
    - expect: Users list is displayed

### 3. Event Templates Management

**Seed:** `tests/seed.spec.ts`

#### 3.1. View Event Templates List

**File:** `tests/event-templates-management/view-event-templates-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403/admin
    - expect: Admin page loads with Event Templates section visible
  2. Click on 'Event Templates' in the sidebar
    - expect: Event templates list is displayed
    - expect: Each template shows: name, description, duration, creation date
    - expect: Templates can be sorted and filtered
    - expect: If no templates exist, an appropriate empty state is shown

#### 3.2. Create New Event Template

**File:** `tests/event-templates-management/create-new-event-template.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section
    - expect: Event templates list is visible
  2. Click 'Add' or 'Create Event Template' button
    - expect: An event template creation form is displayed
  3. Enter 'Test Exercise Template' in the Name field
    - expect: The name field accepts input
  4. Enter 'This is a test exercise for validation' in the Description field
    - expect: The description field accepts input
  5. Set Duration Hours to '4'
    - expect: The duration field accepts numeric input
  6. Select a Player View from the dropdown (if available)
    - expect: The View dropdown shows available Player views
    - expect: A view can be selected
  7. Select a Caster Directory from the dropdown (if available)
    - expect: The Directory dropdown shows available Caster directories
    - expect: A directory can be selected
  8. Select a Steamfitter Scenario Template from the dropdown (if available)
    - expect: The Scenario Template dropdown shows available templates
    - expect: A template can be selected
  9. Click 'Save' or 'Create' button
    - expect: The event template is created successfully
    - expect: A success notification is displayed
    - expect: The new template appears in the event templates list
    - expect: The form closes or resets

#### 3.3. Edit Event Template

**File:** `tests/event-templates-management/edit-event-template.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section
    - expect: Event templates list is visible with at least one template
  2. Click on an existing event template or click its edit icon
    - expect: The event template edit form is displayed
    - expect: Form fields are populated with current values
  3. Modify the Description field to 'Updated description for testing'
    - expect: The description field accepts the new value
  4. Change Duration Hours to '6'
    - expect: The duration field accepts the updated value
  5. Click 'Save' button
    - expect: The event template is updated successfully
    - expect: A success notification is displayed
    - expect: The updated values are reflected in the template list
    - expect: The modification timestamp is updated

#### 3.4. Delete Event Template

**File:** `tests/event-templates-management/delete-event-template.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section
    - expect: Event templates list is visible
  2. Click the delete icon for a specific event template
    - expect: A confirmation dialog appears asking to confirm deletion
  3. Click 'Cancel' in the confirmation dialog
    - expect: The dialog closes
    - expect: The template is not deleted
  4. Click the delete icon again
    - expect: Confirmation dialog appears again
  5. Click 'Confirm' or 'Delete' button
    - expect: The event template is deleted successfully
    - expect: A success notification is displayed
    - expect: The template is removed from the list
    - expect: If the template has associated events, an appropriate error message is shown preventing deletion

#### 3.5. Event Template Form Validation

**File:** `tests/event-templates-management/event-template-form-validation.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section and click 'Create Event Template'
    - expect: Event template creation form is displayed
  2. Leave the Name field empty and try to submit the form
    - expect: Validation error is displayed indicating Name is required
    - expect: Form submission is prevented
  3. Enter a name but set Duration Hours to a negative value
    - expect: Validation error indicates duration must be positive
    - expect: Form submission is prevented
  4. Enter Duration Hours as '0'
    - expect: Validation error indicates duration must be greater than zero
    - expect: Form submission is prevented
  5. Enter Duration Hours as non-numeric text
    - expect: The field rejects non-numeric input or shows validation error
  6. Fill all required fields correctly
    - expect: Validation passes
    - expect: Save button becomes enabled
    - expect: Form can be submitted

#### 3.6. View Event Template Details

**File:** `tests/event-templates-management/view-event-template-details.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section
    - expect: Event templates list is visible
  2. Click on an event template name or view button
    - expect: The event template detail view is displayed
    - expect: All template properties are shown: name, description, duration, associated IDs
    - expect: Associated Player View ID, Caster Directory ID, and Steamfitter Scenario Template ID are visible
    - expect: Creation and modification timestamps are displayed
    - expect: Permissions associated with the template are shown

#### 3.7. Search and Filter Event Templates

**File:** `tests/event-templates-management/search-and-filter-event-templates.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section
    - expect: Event templates list is visible with multiple templates
  2. Enter a search term in the search box
    - expect: The list filters to show only templates matching the search term
    - expect: Search works on template name and description
    - expect: Results update in real-time or after pressing enter
  3. Clear the search box
    - expect: All event templates are displayed again
  4. Apply filters (if available) such as 'Published' or 'Duration range'
    - expect: The list filters according to the selected criteria

#### 3.8. Sort Event Templates

**File:** `tests/event-templates-management/sort-event-templates.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section
    - expect: Event templates list is visible
  2. Click on the 'Name' column header
    - expect: Templates are sorted alphabetically by name
    - expect: A sort indicator shows the sort direction
  3. Click on the 'Name' column header again
    - expect: Templates are sorted in reverse alphabetical order
    - expect: Sort indicator shows reverse direction
  4. Click on the 'Date Created' column header
    - expect: Templates are sorted by creation date
    - expect: Newest or oldest first depending on initial sort direction
  5. Click on the 'Duration' column header
    - expect: Templates are sorted by duration hours
    - expect: Shortest to longest or vice versa

#### 3.9. Publish and Unpublish Event Template

**File:** `tests/event-templates-management/publish-and-unpublish-event-template.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section and select an unpublished template
    - expect: Template details show 'isPublished' status as false
  2. Click 'Publish' button or toggle the publish switch
    - expect: The template is marked as published
    - expect: A confirmation message is displayed
    - expect: The template becomes available to non-admin users
  3. Click 'Unpublish' button or toggle the publish switch again
    - expect: The template is marked as unpublished
    - expect: A confirmation message is displayed
    - expect: The template is no longer visible to non-admin users

### 4. Events Management

**Seed:** `tests/seed.spec.ts`

#### 4.1. View Events List

**File:** `tests/events-management/view-events-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403/admin
    - expect: Admin page loads
  2. Click on 'Events' in the sidebar
    - expect: Events list is displayed
    - expect: Each event shows: name, status, template name, creation date, dates
    - expect: Events display their status (Creating, Active, Ended, etc.)
    - expect: If no events exist, an appropriate empty state is shown

#### 4.2. Create Event from Template

**File:** `tests/events-management/create-event-from-template.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section
    - expect: Event templates list is visible
  2. Select an event template and click 'Launch' or 'Create Event' button
    - expect: An event creation form or dialog is displayed
  3. Enter 'My Test Event' in the Name field
    - expect: The name field accepts input
  4. Enter a description for the event
    - expect: The description field accepts input
  5. Click 'Create' or 'Launch' button
    - expect: The event is created with status 'Creating'
    - expect: A success notification is displayed
    - expect: The new event appears in the events list
    - expect: Background tasks begin orchestrating Player, Caster, and Steamfitter components

#### 4.3. View Event Details

**File:** `tests/events-management/view-event-details.spec.ts`

**Steps:**
  1. Navigate to admin Events section
    - expect: Events list is visible
  2. Click on an event name or view button
    - expect: The event detail view is displayed
    - expect: All event properties are shown: name, description, status, dates
    - expect: Associated IDs are visible: viewId, workspaceId, runId, scenarioId
    - expect: Event status and internal status are displayed
    - expect: Launch date, end date, and expiration date are shown if set
    - expect: Share code is displayed if available
    - expect: Event permissions are shown

#### 4.4. Event Lifecycle - Creating to Active

**File:** `tests/events-management/event-lifecycle-creating-to-active.spec.ts`

**Steps:**
  1. Create a new event from a template
    - expect: Event is created with status 'Creating'
  2. Monitor the event status (refresh or use real-time updates)
    - expect: Event status transitions to 'Planning' as Caster run is being planned
    - expect: Event status transitions to 'Applying' as Caster run is being applied
    - expect: Event status transitions to 'Active' once all components are successfully deployed
    - expect: ViewId, WorkspaceId, RunId, and ScenarioId are populated
    - expect: LaunchDate is set to the time when status became Active

#### 4.5. Event Lifecycle - End Event

**File:** `tests/events-management/event-lifecycle-end-event.spec.ts`

**Steps:**
  1. Navigate to admin Events section and select an Active event
    - expect: Event detail view shows status as 'Active'
  2. Click 'End Event' button
    - expect: A confirmation dialog appears asking to confirm ending the event
  3. Click 'Cancel'
    - expect: The dialog closes
    - expect: The event remains Active
  4. Click 'End Event' button again and confirm
    - expect: Event status changes to 'Ending'
    - expect: Background tasks begin tearing down resources
    - expect: Player view is set to Inactive
    - expect: Steamfitter scenario is ended
    - expect: Caster workspace is destroyed
  5. Monitor the event status
    - expect: Event status transitions to 'Ended' once all teardown is complete
    - expect: EndDate is set to the time when status became Ended

#### 4.6. Event Lifecycle - Failed State Handling

**File:** `tests/events-management/event-lifecycle-failed-state-handling.spec.ts`

**Steps:**
  1. Create an event that will fail (e.g., invalid configuration or service unavailable)
    - expect: Event is created with status 'Creating'
  2. Monitor the event status as it attempts to launch
    - expect: If any orchestration step fails, event status changes to 'Failed'
    - expect: Failure count is incremented
    - expect: Internal status shows the specific failure point
    - expect: An error message or log is available describing the failure
  3. Check event details
    - expect: Last launch status and internal status show the failure
    - expect: User can see what went wrong
    - expect: Event can potentially be retried or needs manual intervention

#### 4.7. Edit Event

**File:** `tests/events-management/edit-event.spec.ts`

**Steps:**
  1. Navigate to admin Events section
    - expect: Events list is visible
  2. Click on an event to view its details, then click 'Edit' button
    - expect: Event edit form is displayed
    - expect: Form fields are populated with current values
  3. Modify the Name field to 'Updated Event Name'
    - expect: The name field accepts the new value
  4. Modify the Description field
    - expect: The description field accepts the new value
  5. Click 'Save' button
    - expect: The event is updated successfully
    - expect: A success notification is displayed
    - expect: Updated values are reflected in the event details
    - expect: Modification timestamp is updated

#### 4.8. Delete Event

**File:** `tests/events-management/delete-event.spec.ts`

**Steps:**
  1. Navigate to admin Events section
    - expect: Events list is visible
  2. Click the delete icon for a specific event (preferably in Ended status)
    - expect: A confirmation dialog appears asking to confirm deletion
  3. Click 'Cancel'
    - expect: The dialog closes
    - expect: The event is not deleted
  4. Click the delete icon again and confirm
    - expect: The event is deleted successfully
    - expect: A success notification is displayed
    - expect: The event is removed from the list
    - expect: If event is Active, deletion may be prevented with an appropriate error message

#### 4.9. Search and Filter Events

**File:** `tests/events-management/search-and-filter-events.spec.ts`

**Steps:**
  1. Navigate to admin Events section
    - expect: Events list is visible
  2. Enter a search term in the search box
    - expect: The list filters to show only events matching the search term
    - expect: Search works on event name, description, and username
    - expect: Results update dynamically
  3. Clear the search box
    - expect: All events are displayed again
  4. Apply status filter to show only 'Active' events
    - expect: The list filters to show only Active events
  5. Apply status filter to show only 'Ended' events
    - expect: The list filters to show only Ended events
  6. Clear filters
    - expect: All events are displayed again

#### 4.10. Sort Events

**File:** `tests/events-management/sort-events.spec.ts`

**Steps:**
  1. Navigate to admin Events section
    - expect: Events list is visible
  2. Click on the 'Name' column header
    - expect: Events are sorted alphabetically by name
    - expect: Sort indicator shows the direction
  3. Click on the 'Status' column header
    - expect: Events are sorted by status
  4. Click on the 'Created' column header
    - expect: Events are sorted by creation date
  5. Click on the 'Launch Date' column header
    - expect: Events are sorted by launch date

#### 4.11. View My Events from Home Page

**File:** `tests/events-management/view-my-events-from-home-page.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403 (home page)
    - expect: Home page loads
  2. View the list of events displayed on the home page
    - expect: Only events associated with the current user are shown
    - expect: Each event displays: name, template name, status
    - expect: Events can be clicked to view more details or launch into the exercise

#### 4.12. Join Active Event from Home Page

**File:** `tests/events-management/join-active-event-from-home-page.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403 (home page) with Active events available
    - expect: Home page displays list of user's events
  2. Click on an Active event
    - expect: The application navigates to the event view
    - expect: URL changes to /templates/{templateId}/view/{viewId}
    - expect: Event details are displayed
    - expect: User can access integrated Player, Caster, or Steamfitter interfaces

#### 4.13. Event Share Code Functionality

**File:** `tests/events-management/event-share-code-functionality.spec.ts`

**Steps:**
  1. Navigate to admin Events section and select an Active event
    - expect: Event details are displayed
  2. Locate the Share Code field
    - expect: A share code is displayed if generated
  3. Click 'Copy' button next to the share code
    - expect: The share code is copied to clipboard
    - expect: A notification confirms the copy action
  4. Log out and log in as a different user
    - expect: Authenticated as a different user
  5. Navigate to /enlist/{shareCode} using the copied share code
    - expect: The enlist page loads
    - expect: User can join the event using the share code
    - expect: User is added to the event membership

### 5. Event Template Memberships

**Seed:** `tests/seed.spec.ts`

#### 5.1. View Event Template Memberships

**File:** `tests/event-template-memberships/view-event-template-memberships.spec.ts`

**Steps:**
  1. Navigate to admin Event Templates section
    - expect: Event templates list is visible
  2. Select an event template and navigate to its Memberships tab
    - expect: Memberships page is displayed
    - expect: List of users who have access to this template is shown
    - expect: Each membership shows: username, role, date added

#### 5.2. Add User to Event Template

**File:** `tests/event-template-memberships/add-user-to-event-template.spec.ts`

**Steps:**
  1. Navigate to an event template's Memberships page
    - expect: Memberships list is visible
  2. Click 'Add Member' or 'Add User' button
    - expect: A dialog or form appears to add a new member
  3. Search for and select a user from the user dropdown
    - expect: User dropdown shows available users
    - expect: A user can be selected
  4. Select a role for the user (if applicable)
    - expect: Role dropdown shows available roles
  5. Click 'Add' or 'Save' button
    - expect: The user is added to the event template membership
    - expect: A success notification is displayed
    - expect: The new member appears in the membership list

#### 5.3. Remove User from Event Template

**File:** `tests/event-template-memberships/remove-user-from-event-template.spec.ts`

**Steps:**
  1. Navigate to an event template's Memberships page
    - expect: Memberships list is visible with at least one member
  2. Click the remove or delete icon for a specific member
    - expect: A confirmation dialog appears
  3. Click 'Cancel'
    - expect: The dialog closes
    - expect: The member is not removed
  4. Click the remove icon again and confirm
    - expect: The member is removed from the event template
    - expect: A success notification is displayed
    - expect: The member no longer appears in the list

#### 5.4. View Member Permissions

**File:** `tests/event-template-memberships/view-member-permissions.spec.ts`

**Steps:**
  1. Navigate to an event template's Memberships page
    - expect: Memberships list is visible
  2. Click on a member to view their permissions
    - expect: Member details are displayed
    - expect: Permissions granted to this member are shown
    - expect: Role-based permissions are visible

### 6. Event Memberships

**Seed:** `tests/seed.spec.ts`

#### 6.1. View Event Memberships

**File:** `tests/event-memberships/view-event-memberships.spec.ts`

**Steps:**
  1. Navigate to admin Events section
    - expect: Events list is visible
  2. Select an event and navigate to its Memberships tab
    - expect: Memberships page is displayed
    - expect: List of users who have access to this event is shown
    - expect: Each membership shows: username, role, date added

#### 6.2. Add User to Event

**File:** `tests/event-memberships/add-user-to-event.spec.ts`

**Steps:**
  1. Navigate to an event's Memberships page
    - expect: Memberships list is visible
  2. Click 'Add Member' or 'Add User' button
    - expect: A dialog or form appears to add a new member
  3. Search for and select a user from the user dropdown
    - expect: User dropdown shows available users
    - expect: A user can be selected
  4. Select a role for the user (if applicable)
    - expect: Role dropdown shows available roles
  5. Click 'Add' or 'Save' button
    - expect: The user is added to the event membership
    - expect: A success notification is displayed
    - expect: The new member appears in the membership list
    - expect: The user can now access this event

#### 6.3. Remove User from Event

**File:** `tests/event-memberships/remove-user-from-event.spec.ts`

**Steps:**
  1. Navigate to an event's Memberships page
    - expect: Memberships list is visible with at least one member
  2. Click the remove or delete icon for a specific member
    - expect: A confirmation dialog appears
  3. Click 'Cancel'
    - expect: The dialog closes
    - expect: The member is not removed
  4. Click the remove icon again and confirm
    - expect: The member is removed from the event
    - expect: A success notification is displayed
    - expect: The member no longer appears in the list
    - expect: The user loses access to this event

#### 6.4. Bulk Add Users to Event

**File:** `tests/event-memberships/bulk-add-users-to-event.spec.ts`

**Steps:**
  1. Navigate to an event's Memberships page
    - expect: Memberships list is visible
  2. Click 'Bulk Add' or similar button (if available)
    - expect: A dialog for bulk adding users appears
  3. Select multiple users from the user list or enter multiple usernames
    - expect: Multiple users can be selected
  4. Select a role for all selected users
    - expect: Role dropdown is available
  5. Click 'Add' button
    - expect: All selected users are added to the event membership
    - expect: A success notification is displayed
    - expect: All new members appear in the membership list

### 7. Roles and Permissions Management

**Seed:** `tests/seed.spec.ts`

#### 7.1. View System Roles

**File:** `tests/roles-and-permissions-management/view-system-roles.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403/admin
    - expect: Admin page loads
  2. Click on 'Roles' in the sidebar
    - expect: Roles section is displayed
    - expect: Tabs for 'System Roles', 'Event Template Roles', and 'Event Roles' are visible
    - expect: System Roles tab is selected by default
    - expect: List of system-wide roles is displayed

#### 7.2. Create System Role

**File:** `tests/roles-and-permissions-management/create-system-role.spec.ts`

**Steps:**
  1. Navigate to admin Roles section, System Roles tab
    - expect: System roles list is visible
  2. Click 'Add Role' or 'Create Role' button
    - expect: A role creation form is displayed
  3. Enter 'Test System Role' in the Name field
    - expect: The name field accepts input
  4. Select permissions to assign to this role
    - expect: A list of available permissions is displayed
    - expect: Permissions can be selected
  5. Click 'Save' or 'Create' button
    - expect: The system role is created successfully
    - expect: A success notification is displayed
    - expect: The new role appears in the system roles list

#### 7.3. Edit System Role

**File:** `tests/roles-and-permissions-management/edit-system-role.spec.ts`

**Steps:**
  1. Navigate to admin Roles section, System Roles tab
    - expect: System roles list is visible
  2. Click on an existing role or its edit icon
    - expect: Role edit form is displayed
    - expect: Form is populated with current values
  3. Modify the role name or permissions
    - expect: Changes can be made to the role configuration
  4. Click 'Save' button
    - expect: The role is updated successfully
    - expect: A success notification is displayed
    - expect: Updated values are reflected in the roles list

#### 7.4. Delete System Role

**File:** `tests/roles-and-permissions-management/delete-system-role.spec.ts`

**Steps:**
  1. Navigate to admin Roles section, System Roles tab
    - expect: System roles list is visible
  2. Click the delete icon for a specific role
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Delete'
    - expect: The role is deleted successfully
    - expect: A success notification is displayed
    - expect: The role is removed from the list
    - expect: If users are assigned this role, an error may prevent deletion

#### 7.5. View Event Template Roles

**File:** `tests/roles-and-permissions-management/view-event-template-roles.spec.ts`

**Steps:**
  1. Navigate to admin Roles section
    - expect: Roles section is displayed
  2. Click on 'Event Template Roles' tab
    - expect: Event template roles list is displayed
    - expect: Roles specific to event templates are shown

#### 7.6. View Event Roles

**File:** `tests/roles-and-permissions-management/view-event-roles.spec.ts`

**Steps:**
  1. Navigate to admin Roles section
    - expect: Roles section is displayed
  2. Click on 'Event Roles' tab
    - expect: Event roles list is displayed
    - expect: Roles specific to events are shown

#### 7.7. Assign Role to User

**File:** `tests/roles-and-permissions-management/assign-role-to-user.spec.ts`

**Steps:**
  1. Navigate to admin Users section
    - expect: Users list is visible
  2. Click on a user to view their details
    - expect: User details page is displayed
  3. Navigate to the user's Roles section
    - expect: List of roles assigned to this user is shown
  4. Click 'Add Role' button
    - expect: A dialog to add a role appears
  5. Select a role from the dropdown
    - expect: Available roles are listed
  6. Click 'Add' or 'Save'
    - expect: The role is assigned to the user
    - expect: A success notification is displayed
    - expect: The role appears in the user's roles list

#### 7.8. Remove Role from User

**File:** `tests/roles-and-permissions-management/remove-role-from-user.spec.ts`

**Steps:**
  1. Navigate to a user's details and roles section
    - expect: User's roles are displayed
  2. Click the remove icon for a specific role
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Remove'
    - expect: The role is removed from the user
    - expect: A success notification is displayed
    - expect: The role no longer appears in the user's roles list

### 8. Groups Management

**Seed:** `tests/seed.spec.ts`

#### 8.1. View Groups List

**File:** `tests/groups-management/view-groups-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403/admin
    - expect: Admin page loads
  2. Click on 'Groups' in the sidebar
    - expect: Groups list is displayed
    - expect: Each group shows: name, description, member count
    - expect: If no groups exist, an appropriate empty state is shown

#### 8.2. Create New Group

**File:** `tests/groups-management/create-new-group.spec.ts`

**Steps:**
  1. Navigate to admin Groups section
    - expect: Groups list is visible
  2. Click 'Add Group' or 'Create Group' button
    - expect: A group creation form is displayed
  3. Enter 'Test Training Group' in the Name field
    - expect: The name field accepts input
  4. Enter a description for the group
    - expect: The description field accepts input
  5. Click 'Save' or 'Create' button
    - expect: The group is created successfully
    - expect: A success notification is displayed
    - expect: The new group appears in the groups list

#### 8.3. Edit Group

**File:** `tests/groups-management/edit-group.spec.ts`

**Steps:**
  1. Navigate to admin Groups section
    - expect: Groups list is visible
  2. Click on a group to view its details
    - expect: Group details page is displayed
  3. Click 'Edit' button
    - expect: Group edit form is displayed
  4. Modify the group name or description
    - expect: Changes can be made
  5. Click 'Save' button
    - expect: The group is updated successfully
    - expect: A success notification is displayed
    - expect: Updated values are reflected

#### 8.4. Delete Group

**File:** `tests/groups-management/delete-group.spec.ts`

**Steps:**
  1. Navigate to admin Groups section
    - expect: Groups list is visible
  2. Click the delete icon for a specific group
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Delete'
    - expect: The group is deleted successfully
    - expect: A success notification is displayed
    - expect: The group is removed from the list

#### 8.5. View Group Members

**File:** `tests/groups-management/view-group-members.spec.ts`

**Steps:**
  1. Navigate to admin Groups section
    - expect: Groups list is visible
  2. Click on a group to view its details
    - expect: Group details page is displayed
  3. Navigate to the Members tab
    - expect: List of group members is displayed
    - expect: Each member shows: username, date added

#### 8.6. Add Member to Group

**File:** `tests/groups-management/add-member-to-group.spec.ts`

**Steps:**
  1. Navigate to a group's Members tab
    - expect: Group members list is visible
  2. Click 'Add Member' button
    - expect: A dialog to add a member appears
  3. Search for and select a user from the dropdown
    - expect: User dropdown shows available users
  4. Click 'Add' button
    - expect: The user is added to the group
    - expect: A success notification is displayed
    - expect: The user appears in the group members list

#### 8.7. Remove Member from Group

**File:** `tests/groups-management/remove-member-from-group.spec.ts`

**Steps:**
  1. Navigate to a group's Members tab
    - expect: Group members list is visible
  2. Click the remove icon for a specific member
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Remove'
    - expect: The member is removed from the group
    - expect: A success notification is displayed
    - expect: The member no longer appears in the list

#### 8.8. View Group Memberships (Groups a Group Belongs To)

**File:** `tests/groups-management/view-group-memberships-groups-a-group-belongs-to.spec.ts`

**Steps:**
  1. Navigate to a group's details page
    - expect: Group details are displayed
  2. Navigate to the Memberships tab (if groups can belong to other groups)
    - expect: List of parent groups is displayed
    - expect: Shows which groups this group is a member of

### 9. Users Management

**Seed:** `tests/seed.spec.ts`

#### 9.1. View Users List

**File:** `tests/users-management/view-users-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4403/admin
    - expect: Admin page loads
  2. Click on 'Users' in the sidebar
    - expect: Users list is displayed
    - expect: Each user shows: username, name, email, roles
    - expect: Pagination controls are visible if there are many users

#### 9.2. Search Users

**File:** `tests/users-management/search-users.spec.ts`

**Steps:**
  1. Navigate to admin Users section
    - expect: Users list is visible
  2. Enter a search term (username or name) in the search box
    - expect: The list filters to show only matching users
    - expect: Search works in real-time or after pressing enter
  3. Clear the search box
    - expect: All users are displayed again

#### 9.3. View User Details

**File:** `tests/users-management/view-user-details.spec.ts`

**Steps:**
  1. Navigate to admin Users section
    - expect: Users list is visible
  2. Click on a user name or view button
    - expect: User details page is displayed
    - expect: User information is shown: username, name, email, ID
    - expect: Tabs for Roles, Groups, Permissions may be available

#### 9.4. View User Roles

**File:** `tests/users-management/view-user-roles.spec.ts`

**Steps:**
  1. Navigate to a user's details page
    - expect: User details are displayed
  2. Navigate to the Roles tab
    - expect: List of roles assigned to this user is displayed
    - expect: Each role shows: role name, type (system/event template/event)

#### 9.5. View User Groups

**File:** `tests/users-management/view-user-groups.spec.ts`

**Steps:**
  1. Navigate to a user's details page
    - expect: User details are displayed
  2. Navigate to the Groups tab
    - expect: List of groups this user belongs to is displayed
    - expect: Each group shows: group name, date added

#### 9.6. View User Permissions

**File:** `tests/users-management/view-user-permissions.spec.ts`

**Steps:**
  1. Navigate to a user's details page
    - expect: User details are displayed
  2. Navigate to the Permissions tab
    - expect: List of permissions granted to this user is displayed
    - expect: Permissions may be inherited from roles or directly assigned

#### 9.7. Sort Users

**File:** `tests/users-management/sort-users.spec.ts`

**Steps:**
  1. Navigate to admin Users section
    - expect: Users list is visible
  2. Click on the 'Username' column header
    - expect: Users are sorted alphabetically by username
  3. Click on the 'Name' column header
    - expect: Users are sorted alphabetically by name

### 10. Real-time Updates and SignalR

**Seed:** `tests/seed.spec.ts`

#### 10.1. Real-time Event Status Updates

**File:** `tests/real-time-updates-and-signalr/real-time-event-status-updates.spec.ts`

**Steps:**
  1. Open two browser windows/tabs, both logged in as admin
    - expect: Both windows are authenticated
  2. In window 1, navigate to admin Events section
    - expect: Events list is displayed in window 1
  3. In window 2, create a new event or change an event status
    - expect: Event is created or status is changed in window 2
  4. Observe window 1 without refreshing
    - expect: Window 1 receives real-time update via SignalR
    - expect: Events list in window 1 updates automatically to reflect the change
    - expect: No manual refresh is required

#### 10.2. Real-time Event Template Updates

**File:** `tests/real-time-updates-and-signalr/real-time-event-template-updates.spec.ts`

**Steps:**
  1. Open two browser windows, both logged in and viewing Event Templates
    - expect: Both windows show event templates list
  2. In window 1, create or edit an event template
    - expect: Template is created or updated in window 1
  3. Observe window 2 without refreshing
    - expect: Window 2 receives real-time update
    - expect: Event templates list updates automatically in window 2

#### 10.3. SignalR Connection Establishment

**File:** `tests/real-time-updates-and-signalr/signalr-connection-establishment.spec.ts`

**Steps:**
  1. Open browser developer console
    - expect: Console is open
  2. Log in and navigate to admin section
    - expect: Admin page loads
  3. Check console logs for SignalR connection messages
    - expect: Console shows SignalR connection established
    - expect: No connection errors are displayed
    - expect: Admin hub is joined successfully

#### 10.4. SignalR Reconnection on Network Interruption

**File:** `tests/real-time-updates-and-signalr/signalr-reconnection-on-network-interruption.spec.ts`

**Steps:**
  1. Log in and navigate to admin section with SignalR connected
    - expect: SignalR connection is active
  2. Simulate network disconnection (using browser dev tools or network interruption)
    - expect: Network connection is lost
  3. Restore network connection
    - expect: SignalR automatically attempts to reconnect
    - expect: Console logs show reconnection attempts
    - expect: Real-time updates resume once reconnected

### 11. Error Handling and Validation

**Seed:** `tests/seed.spec.ts`

#### 11.1. API Error Display

**File:** `tests/error-handling-and-validation/api-error-display.spec.ts`

**Steps:**
  1. Trigger an API error (e.g., try to create an event template with invalid data)
    - expect: API returns an error response
  2. Observe the application response
    - expect: An error notification or message is displayed to the user
    - expect: The error message is clear and actionable
    - expect: Form submission is prevented
    - expect: User can correct the error and retry

#### 11.2. Network Error Handling

**File:** `tests/error-handling-and-validation/network-error-handling.spec.ts`

**Steps:**
  1. Disconnect from network while on admin page
    - expect: Network connection is lost
  2. Attempt to perform an action (e.g., create event template)
    - expect: Application detects network error
    - expect: An appropriate error message is displayed (e.g., 'Network error, please check connection')
    - expect: Action fails gracefully without crashing
  3. Restore network connection
    - expect: Application resumes normal operation
    - expect: User can retry the action

#### 11.3. Required Field Validation

**File:** `tests/error-handling-and-validation/required-field-validation.spec.ts`

**Steps:**
  1. Open any form with required fields (e.g., create event template)
    - expect: Form is displayed
  2. Leave required fields empty and attempt to submit
    - expect: Validation errors are displayed for each required field
    - expect: Error messages clearly indicate which fields are required
    - expect: Form submission is prevented
    - expect: Required fields are visually highlighted

#### 11.4. Data Type Validation

**File:** `tests/error-handling-and-validation/data-type-validation.spec.ts`

**Steps:**
  1. Open a form with typed fields (e.g., numeric duration field)
    - expect: Form is displayed
  2. Enter invalid data type (e.g., text in a numeric field)
    - expect: Validation error is displayed
    - expect: Error message indicates the expected data type
    - expect: Form submission is prevented
  3. Enter valid data
    - expect: Validation passes
    - expect: Form can be submitted

#### 11.5. Unauthorized Action Handling

**File:** `tests/error-handling-and-validation/unauthorized-action-handling.spec.ts`

**Steps:**
  1. Log in as a user without admin permissions
    - expect: User is authenticated
  2. Attempt to access /admin or perform an admin action
    - expect: Access is denied
    - expect: An appropriate error message is displayed (e.g., 'You do not have permission')
    - expect: User is redirected to home page or login page

#### 11.6. Duplicate Name Validation

**File:** `tests/error-handling-and-validation/duplicate-name-validation.spec.ts`

**Steps:**
  1. Create an event template with a specific name
    - expect: Template is created successfully
  2. Attempt to create another event template with the same name
    - expect: Validation error is displayed indicating duplicate name
    - expect: Form submission is prevented
    - expect: User is prompted to choose a different name

#### 11.7. Long Input Validation

**File:** `tests/error-handling-and-validation/long-input-validation.spec.ts`

**Steps:**
  1. Open a form with text input fields
    - expect: Form is displayed
  2. Enter a very long string exceeding expected length limits
    - expect: Validation error is displayed if input exceeds max length
    - expect: Or field has a character limit that prevents overly long input
    - expect: Error message indicates the maximum allowed length

### 12. Integration Points

**Seed:** `tests/seed.spec.ts`

#### 12.1. Player Integration - View Selection

**File:** `tests/integration-points/player-integration-view-selection.spec.ts`

**Steps:**
  1. Navigate to create or edit event template form
    - expect: Form is displayed
  2. Check the Player View dropdown
    - expect: Dropdown is populated with views from Player API
    - expect: Only authorized views are shown
    - expect: Views are fetched from http://localhost:4402 API endpoint
  3. Select a Player View
    - expect: View is selected and stored in event template

#### 12.2. Caster Integration - Directory Selection

**File:** `tests/integration-points/caster-integration-directory-selection.spec.ts`

**Steps:**
  1. Navigate to create or edit event template form
    - expect: Form is displayed
  2. Check the Caster Directory dropdown
    - expect: Dropdown is populated with directories from Caster API
    - expect: Only authorized directories are shown
    - expect: Directories are fetched from Caster API
  3. Select a Caster Directory
    - expect: Directory is selected and stored in event template

#### 12.3. Steamfitter Integration - Scenario Template Selection

**File:** `tests/integration-points/steamfitter-integration-scenario-template-selection.spec.ts`

**Steps:**
  1. Navigate to create or edit event template form
    - expect: Form is displayed
  2. Check the Steamfitter Scenario Template dropdown
    - expect: Dropdown is populated with scenario templates from Steamfitter API
    - expect: Only authorized templates are shown
    - expect: Templates are fetched from Steamfitter API
  3. Select a Scenario Template
    - expect: Template is selected and stored in event template

#### 12.4. Event Launch - Player View Cloning

**File:** `tests/integration-points/event-launch-player-view-cloning.spec.ts`

**Steps:**
  1. Create an event from a template that has a Player View configured
    - expect: Event is created
  2. Monitor event status as it launches
    - expect: Alloy calls Player API to create a view from the view template
    - expect: A new viewId is generated and stored in the event
    - expect: Event progresses through Creating status

#### 12.5. Event Launch - Caster Workspace Deployment

**File:** `tests/integration-points/event-launch-caster-workspace-deployment.spec.ts`

**Steps:**
  1. Create an event from a template with Caster Directory configured
    - expect: Event is created
  2. Monitor event status as it launches
    - expect: Alloy calls Caster API to create a workspace from the directory
    - expect: A run is created with status 'Planning'
    - expect: Event status changes to 'Planning'
    - expect: Once planned, the run is applied
    - expect: Event status changes to 'Applying'
    - expect: Once applied, workspaceId and runId are stored in the event
    - expect: Event status changes to 'Active'

#### 12.6. Event Launch - Steamfitter Scenario Creation

**File:** `tests/integration-points/event-launch-steamfitter-scenario-creation.spec.ts`

**Steps:**
  1. Create an event from a template with Steamfitter Scenario Template configured
    - expect: Event is created
  2. Monitor event status as it launches
    - expect: Alloy calls Steamfitter API to create a scenario from the template
    - expect: A new scenarioId is generated and stored in the event
    - expect: Scenario starts execution as part of the event launch

#### 12.7. Event End - Player View Deactivation

**File:** `tests/integration-points/event-end-player-view-deactivation.spec.ts`

**Steps:**
  1. End an Active event that has a Player View
    - expect: Event status changes to 'Ending'
  2. Monitor the teardown process
    - expect: Alloy calls Player API to set the view to Inactive
    - expect: Player view is no longer accessible to users
    - expect: Event continues teardown process

#### 12.8. Event End - Steamfitter Scenario Termination

**File:** `tests/integration-points/event-end-steamfitter-scenario-termination.spec.ts`

**Steps:**
  1. End an Active event that has a Steamfitter Scenario
    - expect: Event status changes to 'Ending'
  2. Monitor the teardown process
    - expect: Alloy calls Steamfitter API to end the scenario
    - expect: Scenario execution stops
    - expect: Event continues teardown process

#### 12.9. Event End - Caster Workspace Destruction

**File:** `tests/integration-points/event-end-caster-workspace-destruction.spec.ts`

**Steps:**
  1. End an Active event that has a Caster Workspace
    - expect: Event status changes to 'Ending'
  2. Monitor the teardown process
    - expect: Alloy calls Caster API to create a destroy run for the workspace
    - expect: Destroy run is planned
    - expect: Destroy run is applied
    - expect: Caster workspace and all resources are destroyed
    - expect: Event status changes to 'Ended'
    - expect: EndDate is set

### 13. Accessibility and Usability

**Seed:** `tests/seed.spec.ts`

#### 13.1. Keyboard Navigation

**File:** `tests/accessibility-and-usability/keyboard-navigation.spec.ts`

**Steps:**
  1. Navigate to the home page
    - expect: Home page is loaded
  2. Use Tab key to navigate through interactive elements
    - expect: Focus moves sequentially through all interactive elements
    - expect: Focus indicator is clearly visible
    - expect: All buttons, links, and form fields are accessible via keyboard
  3. Use Shift+Tab to navigate backwards
    - expect: Focus moves backwards through interactive elements
  4. Use Enter or Space to activate buttons and links
    - expect: Buttons and links respond to keyboard activation

#### 13.2. Screen Reader Compatibility

**File:** `tests/accessibility-and-usability/screen-reader-compatibility.spec.ts`

**Steps:**
  1. Enable a screen reader (e.g., NVDA, JAWS, VoiceOver)
    - expect: Screen reader is active
  2. Navigate through the application
    - expect: Screen reader announces page titles, headings, and landmarks
    - expect: Form labels are properly announced
    - expect: Button purposes are clear
    - expect: Status messages and notifications are announced
    - expect: Images have appropriate alt text

#### 13.3. Color Contrast Compliance

**File:** `tests/accessibility-and-usability/color-contrast-compliance.spec.ts`

**Steps:**
  1. Navigate through different pages and components
    - expect: All pages load successfully
  2. Check text color contrast against backgrounds
    - expect: Text has sufficient contrast ratio (WCAG AA: 4.5:1 for normal text, 3:1 for large text)
    - expect: Both light and dark themes meet contrast requirements
    - expect: Interactive elements have sufficient contrast

#### 13.4. Responsive Layout - Mobile View

**File:** `tests/accessibility-and-usability/responsive-layout-mobile-view.spec.ts`

**Steps:**
  1. Resize browser to mobile viewport (e.g., 375x667)
    - expect: Page layout adapts to mobile view
  2. Navigate through the application
    - expect: All content is accessible
    - expect: Navigation menu adapts (e.g., hamburger menu)
    - expect: Forms and tables are usable on small screens
    - expect: No horizontal scrolling is required
    - expect: Touch targets are appropriately sized (minimum 44x44 pixels)

#### 13.5. Responsive Layout - Tablet View

**File:** `tests/accessibility-and-usability/responsive-layout-tablet-view.spec.ts`

**Steps:**
  1. Resize browser to tablet viewport (e.g., 768x1024)
    - expect: Page layout adapts to tablet view
  2. Navigate through the application
    - expect: Layout makes efficient use of available space
    - expect: All features remain accessible
    - expect: Sidebar and navigation work appropriately

#### 13.6. Responsive Layout - Desktop View

**File:** `tests/accessibility-and-usability/responsive-layout-desktop-view.spec.ts`

**Steps:**
  1. View application in standard desktop resolution (e.g., 1920x1080)
    - expect: Page layout utilizes desktop space effectively
  2. Resize window to various widths
    - expect: Layout adapts smoothly to different window sizes
    - expect: No content is cut off or inaccessible
    - expect: Sidebar and main content adjust appropriately

#### 13.7. Focus Management in Dialogs

**File:** `tests/accessibility-and-usability/focus-management-in-dialogs.spec.ts`

**Steps:**
  1. Open a dialog (e.g., create event template)
    - expect: Dialog opens
  2. Check focus behavior
    - expect: Focus is moved to the dialog when it opens
    - expect: Focus is trapped within the dialog (Tab cycles through dialog elements only)
    - expect: Escape key closes the dialog
    - expect: When dialog closes, focus returns to the triggering element

#### 13.8. Loading States and Feedback

**File:** `tests/accessibility-and-usability/loading-states-and-feedback.spec.ts`

**Steps:**
  1. Trigger an action that takes time (e.g., create event)
    - expect: Action is initiated
  2. Observe the UI during processing
    - expect: A loading indicator (spinner, progress bar) is displayed
    - expect: Submit button is disabled during processing
    - expect: User receives feedback that the action is in progress
    - expect: Loading state is announced to screen readers
  3. Wait for action to complete
    - expect: Loading indicator disappears
    - expect: Success or error message is displayed
    - expect: UI updates to reflect the completed action

### 14. Performance and Optimization

**Seed:** `tests/seed.spec.ts`

#### 14.1. Initial Page Load Time

**File:** `tests/performance-and-optimization/initial-page-load-time.spec.ts`

**Steps:**
  1. Clear browser cache and navigate to http://localhost:4403
    - expect: Application loads from scratch
  2. Measure page load time using browser dev tools (Performance tab)
    - expect: Initial page load completes within acceptable time (e.g., < 3 seconds)
    - expect: Time to First Contentful Paint (FCP) is reasonable
    - expect: Time to Interactive (TTI) is acceptable
    - expect: No unnecessary blocking resources

#### 14.2. Subsequent Page Load Time

**File:** `tests/performance-and-optimization/subsequent-page-load-time.spec.ts`

**Steps:**
  1. After initial load, navigate to different sections of the application
    - expect: Navigation occurs
  2. Measure page transition times
    - expect: Page transitions are fast (< 1 second)
    - expect: Cached resources are utilized
    - expect: Lazy loading is used for components when appropriate

#### 14.3. Large List Performance

**File:** `tests/performance-and-optimization/large-list-performance.spec.ts`

**Steps:**
  1. Navigate to a section with a large list (e.g., Events or Users with 100+ items)
    - expect: List page loads
  2. Scroll through the list
    - expect: Scrolling is smooth without jank
    - expect: Virtual scrolling or pagination is used for very large lists
    - expect: Browser remains responsive
  3. Apply filters or search
    - expect: Filtering/searching is responsive
    - expect: Results update quickly
    - expect: UI does not freeze during filtering

#### 14.4. Memory Leak Detection

**File:** `tests/performance-and-optimization/memory-leak-detection.spec.ts`

**Steps:**
  1. Open browser dev tools and start memory profiling
    - expect: Memory profiler is active
  2. Navigate through various sections of the application multiple times
    - expect: Multiple navigation cycles complete
  3. Check memory usage in dev tools
    - expect: Memory usage stabilizes and does not continuously increase
    - expect: No significant memory leaks are detected
    - expect: Garbage collection occurs appropriately

#### 14.5. API Call Optimization

**File:** `tests/performance-and-optimization/api-call-optimization.spec.ts`

**Steps:**
  1. Open browser dev tools Network tab
    - expect: Network tab is active
  2. Navigate to different sections and perform actions
    - expect: Various API calls are made
  3. Analyze API calls
    - expect: No redundant API calls are made
    - expect: Data is cached appropriately
    - expect: API calls are batched when possible
    - expect: Loading states prevent duplicate requests
