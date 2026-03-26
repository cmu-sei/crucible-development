# Player UI Comprehensive Test Plan

## Application Overview

The Player application is the main learning platform in the Crucible ecosystem. It provides users with access to cybersecurity training exercises (Views), virtual machine management, team collaboration, file browsing, and administrative functions. The application uses Keycloak for authentication and authorization, supports role-based permissions, and includes real-time notifications. This test plan covers authentication flows, view management, exercise participation, team operations, administrative functions, and error handling scenarios.

## Test Scenarios

### 1. Authentication and Authorization

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 1.1. Successful Authentication Flow

**File:** `tests/authentication/successful-authentication.spec.ts`

**Steps:**
  1. Navigate to Player UI at http://localhost:4301
    - expect: User is redirected to Keycloak login page at https://localhost:8443
  2. Enter valid username 'admin' in the username field
    - expect: Username field accepts input
  3. Enter valid password 'admin' in the password field
    - expect: Password field accepts input and masks the password
  4. Click the 'Sign In' button
    - expect: User is authenticated and redirected back to Player UI at http://localhost:4301
    - expect: Home page displays with view list
    - expect: User profile/menu is visible in top bar

#### 1.2. Failed Authentication - Invalid Credentials

**File:** `tests/authentication/failed-authentication-invalid-credentials.spec.ts`

**Steps:**
  1. Navigate to Player UI at http://localhost:4301
    - expect: User is redirected to Keycloak login page
  2. Enter invalid username 'wronguser' in the username field
    - expect: Username field accepts input
  3. Enter invalid password 'wrongpass' in the password field
    - expect: Password field accepts input
  4. Click the 'Sign In' button
    - expect: Authentication fails
    - expect: Error message is displayed indicating invalid credentials
    - expect: User remains on Keycloak login page

#### 1.3. Failed Authentication - Empty Credentials

**File:** `tests/authentication/failed-authentication-empty-credentials.spec.ts`

**Steps:**
  1. Navigate to Player UI at http://localhost:4301
    - expect: User is redirected to Keycloak login page
  2. Leave username field empty
    - expect: Username field is empty
  3. Leave password field empty
    - expect: Password field is empty
  4. Click the 'Sign In' button
    - expect: Validation error appears
    - expect: Error message indicates required fields
    - expect: User cannot proceed without credentials

#### 1.4. Session Persistence After Refresh

**File:** `tests/authentication/session-persistence.spec.ts`

**Steps:**
  1. Log in with valid credentials (admin/admin)
    - expect: User is successfully authenticated and viewing Player home page
  2. Refresh the browser page
    - expect: User remains authenticated
    - expect: Home page loads without redirecting to Keycloak
    - expect: User session is maintained

#### 1.5. Logout Functionality

**File:** `tests/authentication/logout.spec.ts`

**Steps:**
  1. Log in with valid credentials (admin/admin)
    - expect: User is successfully authenticated
  2. Click on user profile menu in top bar
    - expect: User menu dropdown opens
  3. Click 'Logout' or 'Sign Out' option
    - expect: User is logged out
    - expect: User is redirected to Keycloak or Player home
    - expect: Authentication session is terminated
  4. Attempt to navigate to Player UI again
    - expect: User is redirected to Keycloak login page
    - expect: User must authenticate again

#### 1.6. Unauthorized Access Protection

**File:** `tests/authentication/unauthorized-access.spec.ts`

**Steps:**
  1. Clear all cookies and local storage to simulate unauthenticated state
    - expect: Session is cleared
  2. Attempt to navigate directly to a protected route (e.g., http://localhost:4301/admin)
    - expect: User is redirected to Keycloak login page
    - expect: Protected route is not accessible without authentication

### 2. Home Page and View List

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 2.1. Home Page Display

**File:** `tests/home/home-page-display.spec.ts`

**Steps:**
  1. Log in and land on home page
    - expect: Home page displays with 'Player' title in top bar
    - expect: View list component is visible
    - expect: Navigation elements are present

#### 2.2. View List Display - With Views

**File:** `tests/home/view-list-with-views.spec.ts`

**Steps:**
  1. Log in as user with access to views
    - expect: View list table displays
    - expect: Table shows columns for 'Name' and 'Description'
    - expect: Active views are visible in the list

#### 2.3. View List Display - Empty State

**File:** `tests/home/view-list-empty-state.spec.ts`

**Steps:**
  1. Log in as user with no views assigned
    - expect: View list is empty or shows 'No views available' message
    - expect: No views are displayed in the table

#### 2.4. View List Search/Filter

**File:** `tests/home/view-list-filter.spec.ts`

**Steps:**
  1. Log in and navigate to home page with multiple views
    - expect: View list displays multiple views
  2. Locate the search/filter input field
    - expect: Search field is visible
  3. Enter a search term that matches at least one view name
    - expect: View list filters to show only matching views
    - expect: Non-matching views are hidden
  4. Clear the search field
    - expect: All views are displayed again

#### 2.5. View List Sorting

**File:** `tests/home/view-list-sorting.spec.ts`

**Steps:**
  1. Log in and navigate to home page with multiple views
    - expect: View list displays multiple views
  2. Click on the 'Name' column header
    - expect: Views are sorted alphabetically by name (ascending)
    - expect: Sort indicator appears on column header
  3. Click on the 'Name' column header again
    - expect: Views are sorted in reverse alphabetical order (descending)
    - expect: Sort indicator updates to show descending order

#### 2.6. Create New View Button - Authorized User

**File:** `tests/home/create-view-authorized.spec.ts`

**Steps:**
  1. Log in as user with 'CreateViews' permission
    - expect: User is on home page
  2. Look for 'Create' or 'New View' button
    - expect: Button to create new view is visible and enabled
  3. Click the create view button
    - expect: Create view dialog opens
    - expect: Dialog prompts for view name

#### 2.7. Create New View - Unauthorized User

**File:** `tests/home/create-view-unauthorized.spec.ts`

**Steps:**
  1. Log in as user without 'CreateViews' permission
    - expect: User is on home page
  2. Look for 'Create' or 'New View' button
    - expect: Button to create new view is not visible or is disabled

#### 2.8. Navigate to View from List

**File:** `tests/home/navigate-to-view.spec.ts`

**Steps:**
  1. Log in and navigate to home page
    - expect: View list displays at least one view
  2. Click on a view row in the list
    - expect: User is navigated to the view player page
    - expect: URL changes to /view/:id format
    - expect: View player interface loads

### 3. View Player Interface

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 3.1. View Player Initial Load

**File:** `tests/view-player/view-player-initial-load.spec.ts`

**Steps:**
  1. Log in and navigate to a specific view (e.g., /view/:id)
    - expect: View player page loads
    - expect: View name displays in top bar
    - expect: Sidebar with applications is visible
    - expect: Main content area displays

#### 3.2. View Player Sidebar - Applications List

**File:** `tests/view-player/applications-list.spec.ts`

**Steps:**
  1. Navigate to view player page
    - expect: Sidebar displays list of applications available in the view
    - expect: Each application shows name/icon

#### 3.3. View Player Sidebar - Collapse/Expand

**File:** `tests/view-player/sidebar-collapse-expand.spec.ts`

**Steps:**
  1. Navigate to view player page with sidebar expanded
    - expect: Sidebar is fully visible with application names
  2. Click the collapse button (chevron-double-left icon)
    - expect: Sidebar collapses to mini mode showing only icons
    - expect: More space is available for main content
  3. Click the expand button (chevron-double-right icon)
    - expect: Sidebar expands back to full width
    - expect: Application names are visible again

#### 3.4. View Player Sidebar - Resize

**File:** `tests/view-player/sidebar-resize.spec.ts`

**Steps:**
  1. Navigate to view player page
    - expect: Sidebar is visible
  2. Hover over the right edge of the sidebar (resize handle)
    - expect: Cursor changes to indicate resize capability
  3. Drag the resize handle to increase sidebar width
    - expect: Sidebar width increases
    - expect: Main content area adjusts accordingly
  4. Drag the resize handle to decrease sidebar width
    - expect: Sidebar width decreases
    - expect: Main content area expands

#### 3.5. Application Selection and Launch

**File:** `tests/view-player/application-launch.spec.ts`

**Steps:**
  1. Navigate to view player page with applications
    - expect: Applications are listed in sidebar
  2. Click on an application in the sidebar
    - expect: Application is selected/highlighted
    - expect: Application opens in the main content area or new window/tab
    - expect: Application interface is functional

#### 3.6. Team Selection

**File:** `tests/view-player/team-selection.spec.ts`

**Steps:**
  1. Navigate to view player page where user belongs to multiple teams
    - expect: View player loads
  2. Click on team selector in top bar
    - expect: Team dropdown menu opens
    - expect: List of available teams is displayed
  3. Select a different team from the dropdown
    - expect: Selected team becomes active
    - expect: Applications refresh to show team-specific content
    - expect: Team name updates in top bar

#### 3.7. Return to Home from View Player

**File:** `tests/view-player/return-to-home.spec.ts`

**Steps:**
  1. Navigate to view player page
    - expect: View player is displayed
  2. Click on Player icon/title in sidebar header
    - expect: User is navigated back to home page
    - expect: View list is displayed

#### 3.8. Notifications Display

**File:** `tests/view-player/notifications-display.spec.ts`

**Steps:**
  1. Navigate to view player page
    - expect: View player loads
    - expect: Notifications component is present at bottom of page
  2. Wait for notifications to load
    - expect: Notifications area displays (may be empty or contain messages)
    - expect: No console errors related to notifications

#### 3.9. View Player - Invalid View ID

**File:** `tests/view-player/invalid-view-id.spec.ts`

**Steps:**
  1. Log in successfully
    - expect: User is authenticated
  2. Navigate to /view/invalid-id-12345
    - expect: Error message is displayed
    - expect: User is notified that view does not exist or is not accessible
    - expect: User can navigate back to home

### 4. File Browser

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 4.1. File Browser Access

**File:** `tests/file-browser/file-browser-access.spec.ts`

**Steps:**
  1. Navigate to file browser route /view/:id/files
    - expect: File browser interface loads
    - expect: File list or directory structure is displayed

#### 4.2. File Browser - Directory Navigation

**File:** `tests/file-browser/directory-navigation.spec.ts`

**Steps:**
  1. Open file browser with nested directories
    - expect: Root directory contents are displayed
  2. Click on a directory/folder
    - expect: Directory opens and shows its contents
    - expect: Breadcrumb or path updates to show current location
  3. Click on parent directory or 'back' button
    - expect: User navigates back to parent directory

#### 4.3. File Browser - File Selection

**File:** `tests/file-browser/file-selection.spec.ts`

**Steps:**
  1. Open file browser with files
    - expect: Files are listed
  2. Click on a file
    - expect: File is selected/highlighted
    - expect: File actions (download, open, etc.) become available

#### 4.4. File Download

**File:** `tests/file-browser/file-download.spec.ts`

**Steps:**
  1. Navigate to file browser and select a file
    - expect: File is selected
  2. Click download button or link
    - expect: File download begins
    - expect: Browser shows download progress
    - expect: File is downloaded successfully

#### 4.5. File Browser - Empty Directory

**File:** `tests/file-browser/empty-directory.spec.ts`

**Steps:**
  1. Navigate to file browser for a directory with no files
    - expect: File browser displays empty state message
    - expect: Message indicates no files are available
    - expect: No errors are displayed

### 5. User Presence

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 5.1. User Presence Page Access

**File:** `tests/user-presence/presence-page-access.spec.ts`

**Steps:**
  1. Navigate to user presence route /view/:id/presence
    - expect: User presence page loads
    - expect: List of users in the view is displayed

#### 5.2. User Presence - Online Status

**File:** `tests/user-presence/online-status.spec.ts`

**Steps:**
  1. Navigate to user presence page
    - expect: User presence list displays
    - expect: Current user appears as online/present
    - expect: Online status indicator is visible

#### 5.3. User Presence - Team Filter

**File:** `tests/user-presence/team-filter.spec.ts`

**Steps:**
  1. Navigate to user presence page in a view with multiple teams
    - expect: User presence page displays
  2. Select a specific team from filter/dropdown
    - expect: User list filters to show only members of selected team
    - expect: Team members' presence status is displayed

### 6. Administration - Views

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 6.1. Admin Page Access - Authorized

**File:** `tests/admin/admin-access-authorized.spec.ts`

**Steps:**
  1. Log in as user with admin permissions
    - expect: User is authenticated
  2. Navigate to /admin route
    - expect: Admin page loads
    - expect: Admin sidebar is visible with sections
    - expect: Administration title displays

#### 6.2. Admin Page Access - Unauthorized

**File:** `tests/admin/admin-access-unauthorized.spec.ts`

**Steps:**
  1. Log in as user without admin permissions
    - expect: User is authenticated
  2. Attempt to navigate to /admin route
    - expect: Access is denied
    - expect: User is redirected or shown error message
    - expect: Admin interface is not accessible

#### 6.3. Admin - Views Section Navigation

**File:** `tests/admin/admin-views-section.spec.ts`

**Steps:**
  1. Navigate to admin page
    - expect: Admin page loads with sidebar
  2. Click on 'Views' section in sidebar
    - expect: Views management section displays
    - expect: List of all views is shown
    - expect: Search and filter options are available

#### 6.4. Admin - Create View

**File:** `tests/admin/admin-create-view.spec.ts`

**Steps:**
  1. Navigate to admin views section
    - expect: Views list is displayed
  2. Click 'Create' or 'Add View' button
    - expect: Create view dialog/form opens
  3. Enter view name 'Test View'
    - expect: Name field accepts input
  4. Enter view description 'Test Description'
    - expect: Description field accepts input
  5. Click 'Save' or 'Create' button
    - expect: View is created successfully
    - expect: Success message is displayed
    - expect: New view appears in views list

#### 6.5. Admin - Edit View

**File:** `tests/admin/admin-edit-view.spec.ts`

**Steps:**
  1. Navigate to admin views section with existing views
    - expect: Views list displays
  2. Click on a view or its edit button
    - expect: View edit dialog/page opens
    - expect: Current view details are populated in form
  3. Modify view name or description
    - expect: Fields accept modifications
  4. Click 'Save' or 'Update' button
    - expect: View is updated successfully
    - expect: Success message is displayed
    - expect: Updated information is reflected in views list

#### 6.6. Admin - Delete View

**File:** `tests/admin/admin-delete-view.spec.ts`

**Steps:**
  1. Navigate to admin views section
    - expect: Views list displays
  2. Click delete button for a test view
    - expect: Confirmation dialog appears
    - expect: Dialog warns about view deletion
  3. Click 'Cancel' in confirmation dialog
    - expect: Dialog closes
    - expect: View is not deleted
  4. Click delete button again
    - expect: Confirmation dialog appears
  5. Click 'Confirm' or 'Delete' in dialog
    - expect: View is deleted successfully
    - expect: Success message is displayed
    - expect: View is removed from list

#### 6.7. Admin - View Search/Filter

**File:** `tests/admin/admin-views-search.spec.ts`

**Steps:**
  1. Navigate to admin views section with multiple views
    - expect: Views list displays multiple views
  2. Enter search term in search field
    - expect: Views list filters to show matching views only
    - expect: Non-matching views are hidden
  3. Clear search field
    - expect: All views are displayed again

#### 6.8. Admin - Export View

**File:** `tests/admin/admin-export-view.spec.ts`

**Steps:**
  1. Navigate to admin views section
    - expect: Views list displays
  2. Click export button for a view
    - expect: Export dialog opens or export begins
    - expect: Export options are presented if applicable
  3. Confirm export action
    - expect: View data is exported
    - expect: Export file is downloaded or save location is prompted

#### 6.9. Admin - Import View

**File:** `tests/admin/admin-import-view.spec.ts`

**Steps:**
  1. Navigate to admin views section
    - expect: Views section displays
  2. Click 'Import' button
    - expect: Import dialog opens
    - expect: File upload interface is presented
  3. Select a valid view export file
    - expect: File is accepted
  4. Click 'Import' or 'Upload' button
    - expect: Import process begins
    - expect: Success message displays upon completion
    - expect: Imported view appears in views list

### 7. Administration - Users

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 7.1. Admin - Users Section Navigation

**File:** `tests/admin/admin-users-section.spec.ts`

**Steps:**
  1. Navigate to admin page
    - expect: Admin page loads
  2. Click on 'Users' section in sidebar
    - expect: Users management section displays
    - expect: List of users is shown
    - expect: Search functionality is available

#### 7.2. Admin - User Search

**File:** `tests/admin/admin-users-search.spec.ts`

**Steps:**
  1. Navigate to admin users section
    - expect: Users list displays
  2. Enter a user name or email in search field
    - expect: Users list filters to show matching users
    - expect: Search results update dynamically

#### 7.3. Admin - Edit User

**File:** `tests/admin/admin-edit-user.spec.ts`

**Steps:**
  1. Navigate to admin users section
    - expect: Users list displays
  2. Click on a user or edit button
    - expect: User edit dialog/page opens
    - expect: User details are displayed in editable form
  3. Modify user details (e.g., name, roles)
    - expect: Fields accept modifications
  4. Click 'Save' button
    - expect: User details are updated
    - expect: Success message is displayed

#### 7.4. Admin - Assign User Roles

**File:** `tests/admin/admin-assign-user-roles.spec.ts`

**Steps:**
  1. Navigate to admin users section and open user edit
    - expect: User edit interface displays
  2. Locate roles or permissions section
    - expect: Role assignment interface is visible
  3. Select or add a role for the user
    - expect: Role is assigned to user
  4. Save changes
    - expect: User roles are updated successfully
    - expect: Success message is displayed

### 8. Administration - Application Templates

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 8.1. Admin - Application Templates Section

**File:** `tests/admin/admin-app-templates-section.spec.ts`

**Steps:**
  1. Navigate to admin page
    - expect: Admin page loads
  2. Click on 'Application Templates' section in sidebar
    - expect: Application templates section displays
    - expect: List of templates is shown

#### 8.2. Admin - Create Application Template

**File:** `tests/admin/admin-create-app-template.spec.ts`

**Steps:**
  1. Navigate to admin application templates section
    - expect: Templates list displays
  2. Click 'Create' button
    - expect: Create template dialog/form opens
  3. Enter template name and required details
    - expect: Form fields accept input
  4. Click 'Save' or 'Create' button
    - expect: Template is created successfully
    - expect: New template appears in list

#### 8.3. Admin - Export Application Template

**File:** `tests/admin/admin-export-app-template.spec.ts`

**Steps:**
  1. Navigate to admin application templates section
    - expect: Templates list displays
  2. Click export button for a template
    - expect: Export process begins
    - expect: Template file is downloaded

#### 8.4. Admin - Import Application Template

**File:** `tests/admin/admin-import-app-template.spec.ts`

**Steps:**
  1. Navigate to admin application templates section
    - expect: Templates section displays
  2. Click 'Import' button
    - expect: Import dialog opens
  3. Select a valid template file
    - expect: File is accepted
  4. Confirm import
    - expect: Template is imported successfully
    - expect: Imported template appears in list

### 9. Administration - Roles and Permissions

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 9.1. Admin - Roles and Permissions Section

**File:** `tests/admin/admin-roles-section.spec.ts`

**Steps:**
  1. Navigate to admin page
    - expect: Admin page loads
  2. Click on 'Roles & Permissions' section in sidebar
    - expect: Roles and permissions management displays
    - expect: List of roles is shown

#### 9.2. Admin - Create Role

**File:** `tests/admin/admin-create-role.spec.ts`

**Steps:**
  1. Navigate to admin roles section
    - expect: Roles list displays
  2. Click 'Create Role' button
    - expect: Create role dialog opens
  3. Enter role name 'TestRole'
    - expect: Role name field accepts input
  4. Click 'Create' button
    - expect: Role is created successfully
    - expect: New role appears in list

#### 9.3. Admin - Assign Permissions to Role

**File:** `tests/admin/admin-assign-permissions.spec.ts`

**Steps:**
  1. Navigate to admin roles section
    - expect: Roles list displays
  2. Click on a role or edit permissions button
    - expect: Permissions assignment interface opens
    - expect: List of available permissions is displayed
  3. Select one or more permissions to assign
    - expect: Permissions are selected
  4. Save changes
    - expect: Permissions are assigned to role successfully
    - expect: Success message is displayed

#### 9.4. Admin - Create Permission

**File:** `tests/admin/admin-create-permission.spec.ts`

**Steps:**
  1. Navigate to admin roles and permissions section
    - expect: Roles/permissions interface displays
  2. Click 'Create Permission' button
    - expect: Create permission dialog opens
  3. Enter permission key and description
    - expect: Form fields accept input
  4. Click 'Create' button
    - expect: Permission is created successfully
    - expect: New permission appears in list

#### 9.5. Admin - Delete Role

**File:** `tests/admin/admin-delete-role.spec.ts`

**Steps:**
  1. Navigate to admin roles section
    - expect: Roles list displays
  2. Click delete button for a test role
    - expect: Confirmation dialog appears
  3. Confirm deletion
    - expect: Role is deleted successfully
    - expect: Role is removed from list

### 10. Administration - Webhook Subscriptions

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 10.1. Admin - Subscriptions Section

**File:** `tests/admin/admin-subscriptions-section.spec.ts`

**Steps:**
  1. Navigate to admin page
    - expect: Admin page loads
  2. Click on 'Subscriptions' or 'Webhooks' section in sidebar
    - expect: Subscriptions management section displays
    - expect: List of webhook subscriptions is shown

#### 10.2. Admin - Create Webhook Subscription

**File:** `tests/admin/admin-create-subscription.spec.ts`

**Steps:**
  1. Navigate to admin subscriptions section
    - expect: Subscriptions list displays
  2. Click 'Create' or 'Add Subscription' button
    - expect: Create subscription dialog/form opens
  3. Enter webhook URL and select event types
    - expect: Form fields accept input
  4. Click 'Create' button
    - expect: Subscription is created successfully
    - expect: New subscription appears in list

#### 10.3. Admin - Edit Webhook Subscription

**File:** `tests/admin/admin-edit-subscription.spec.ts`

**Steps:**
  1. Navigate to admin subscriptions section with existing subscriptions
    - expect: Subscriptions list displays
  2. Click on a subscription or edit button
    - expect: Edit subscription dialog opens
    - expect: Current subscription details are displayed
  3. Modify subscription details
    - expect: Fields accept modifications
  4. Save changes
    - expect: Subscription is updated successfully

#### 10.4. Admin - Delete Webhook Subscription

**File:** `tests/admin/admin-delete-subscription.spec.ts`

**Steps:**
  1. Navigate to admin subscriptions section
    - expect: Subscriptions list displays
  2. Click delete button for a subscription
    - expect: Confirmation dialog appears
  3. Confirm deletion
    - expect: Subscription is deleted successfully
    - expect: Subscription is removed from list

### 11. Navigation and UI Components

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 11.1. Top Bar Navigation

**File:** `tests/navigation/top-bar-navigation.spec.ts`

**Steps:**
  1. Log in and navigate to any page
    - expect: Top bar is visible at the top of the page
    - expect: Top bar contains page title and user menu

#### 11.2. User Menu Access

**File:** `tests/navigation/user-menu-access.spec.ts`

**Steps:**
  1. Log in to Player UI
    - expect: User is authenticated and viewing a page
  2. Click on user icon/name in top bar
    - expect: User menu dropdown opens
    - expect: Menu shows user profile options and logout

#### 11.3. Theme Toggle

**File:** `tests/navigation/theme-toggle.spec.ts`

**Steps:**
  1. Log in to Player UI
    - expect: Application loads with default theme
  2. Open user menu or settings
    - expect: Menu opens
  3. Click theme toggle button (if available)
    - expect: Application theme changes from light to dark or vice versa
    - expect: Theme preference is saved

#### 11.4. Breadcrumb Navigation

**File:** `tests/navigation/breadcrumb-navigation.spec.ts`

**Steps:**
  1. Navigate to a nested page (e.g., admin view edit)
    - expect: Breadcrumb trail is visible showing navigation path
  2. Click on a breadcrumb link
    - expect: User navigates to the selected level in the hierarchy

#### 11.5. Admin Sidebar Navigation

**File:** `tests/navigation/admin-sidebar-navigation.spec.ts`

**Steps:**
  1. Navigate to admin page
    - expect: Admin sidebar is visible with section links
  2. Click on different section links in sidebar
    - expect: Each section loads correctly
    - expect: Active section is highlighted in sidebar

#### 11.6. Responsive Layout - Mobile View

**File:** `tests/navigation/responsive-mobile.spec.ts`

**Steps:**
  1. Resize browser window to mobile width or use mobile device emulation
    - expect: Layout adapts to mobile view
    - expect: Navigation becomes mobile-friendly (e.g., hamburger menu)
  2. Test navigation in mobile view
    - expect: All navigation elements are accessible
    - expect: No elements are cut off or overlapping

### 12. Error Handling and Edge Cases

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 12.1. API Error Handling - Network Failure

**File:** `tests/error-handling/network-failure.spec.ts`

**Steps:**
  1. Log in successfully
    - expect: User is authenticated
  2. Simulate network failure (disconnect or block API calls)
    - expect: Application detects network failure
  3. Attempt to perform an action that requires API call
    - expect: Error message is displayed to user
    - expect: Message indicates network issue
    - expect: Application remains stable

#### 12.2. API Error Handling - Server Error (500)

**File:** `tests/error-handling/server-error.spec.ts`

**Steps:**
  1. Log in successfully
    - expect: User is authenticated
  2. Trigger an API call that returns 500 error (or mock such response)
    - expect: Application handles error gracefully
    - expect: Error message is displayed to user
    - expect: No uncaught exceptions in console

#### 12.3. Form Validation - Required Fields

**File:** `tests/error-handling/form-validation-required.spec.ts`

**Steps:**
  1. Navigate to a form (e.g., create view dialog)
    - expect: Form is displayed
  2. Leave required fields empty
    - expect: Required fields are marked
  3. Attempt to submit form
    - expect: Form validation prevents submission
    - expect: Error messages indicate required fields

#### 12.4. Form Validation - Invalid Input Format

**File:** `tests/error-handling/form-validation-format.spec.ts`

**Steps:**
  1. Navigate to a form with formatted fields (e.g., URL, email)
    - expect: Form is displayed
  2. Enter invalid format (e.g., malformed URL)
    - expect: Field shows validation error
  3. Attempt to submit
    - expect: Form validation prevents submission
    - expect: Specific format error is displayed

#### 12.5. Concurrent User Actions - Race Conditions

**File:** `tests/error-handling/concurrent-actions.spec.ts`

**Steps:**
  1. Open two browser instances with same user logged in
    - expect: Both instances are authenticated
  2. Perform conflicting actions in both instances (e.g., edit same view)
    - expect: Application handles concurrent edits
    - expect: Changes are synchronized or conflict is detected
    - expect: No data corruption occurs

#### 12.6. Session Timeout

**File:** `tests/error-handling/session-timeout.spec.ts`

**Steps:**
  1. Log in successfully
    - expect: User is authenticated
  2. Wait for session to expire (or manually invalidate session)
    - expect: Session expires
  3. Attempt to perform an action
    - expect: User is notified of session expiration
    - expect: User is redirected to login page
    - expect: No data loss occurs

#### 12.7. Browser Back Button Navigation

**File:** `tests/error-handling/back-button-navigation.spec.ts`

**Steps:**
  1. Navigate through multiple pages (home -> view player -> admin)
    - expect: Navigation history is recorded
  2. Click browser back button
    - expect: User navigates back to previous page
    - expect: Page state is preserved or reloaded correctly
    - expect: No errors occur

#### 12.8. Deep Link Access

**File:** `tests/error-handling/deep-link-access.spec.ts`

**Steps:**
  1. Copy a deep link URL (e.g., /view/:id)
    - expect: URL is copied
  2. Log out or open in incognito mode
    - expect: User is not authenticated
  3. Paste and navigate to deep link URL
    - expect: User is redirected to login
    - expect: After login, user is redirected back to intended deep link

#### 12.9. XSS Protection - Script Injection in Forms

**File:** `tests/error-handling/xss-protection.spec.ts`

**Steps:**
  1. Navigate to a form (e.g., create view)
    - expect: Form is displayed
  2. Enter script tags in text fields (e.g., <script>alert('XSS')</script>)
    - expect: Input is accepted
  3. Submit form
    - expect: Script is sanitized and not executed
    - expect: No XSS vulnerability is present
    - expect: Data is stored safely

#### 12.10. SQL Injection Protection - Search Fields

**File:** `tests/error-handling/sql-injection-protection.spec.ts`

**Steps:**
  1. Navigate to a search field (e.g., view list search)
    - expect: Search field is visible
  2. Enter SQL injection attempt (e.g., ' OR '1'='1)
    - expect: Input is accepted
  3. Execute search
    - expect: Application handles input safely
    - expect: No SQL errors occur
    - expect: Search results are appropriate or empty

#### 12.11. Large Data Set Handling - Pagination

**File:** `tests/error-handling/large-dataset-pagination.spec.ts`

**Steps:**
  1. Navigate to a list with many items (e.g., large view list)
    - expect: List loads with pagination or virtual scrolling
  2. Navigate through pages or scroll through list
    - expect: Data loads smoothly without freezing
    - expect: Performance remains acceptable
    - expect: All items are accessible

#### 12.12. File Upload - Invalid File Type

**File:** `tests/error-handling/file-upload-invalid-type.spec.ts`

**Steps:**
  1. Navigate to file upload interface (e.g., import view)
    - expect: Upload interface is displayed
  2. Select a file with invalid type (e.g., .exe instead of .json)
    - expect: File is selected
  3. Attempt to upload
    - expect: Validation error is displayed
    - expect: Error indicates invalid file type
    - expect: Upload is prevented

#### 12.13. File Upload - Oversized File

**File:** `tests/error-handling/file-upload-oversized.spec.ts`

**Steps:**
  1. Navigate to file upload interface
    - expect: Upload interface is displayed
  2. Select a file larger than maximum allowed size
    - expect: File is selected
  3. Attempt to upload
    - expect: Validation error is displayed
    - expect: Error indicates file is too large
    - expect: Upload is prevented or gracefully fails

### 13. Performance and Load Testing

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 13.1. Page Load Performance - Home Page

**File:** `tests/performance/home-page-load-time.spec.ts`

**Steps:**
  1. Measure time from navigation to home page until page is fully loaded
    - expect: Home page loads within acceptable time (e.g., under 3 seconds)
    - expect: No blocking resources delay rendering

#### 13.2. Page Load Performance - View Player

**File:** `tests/performance/view-player-load-time.spec.ts`

**Steps:**
  1. Measure time from navigation to view player until page is interactive
    - expect: View player loads within acceptable time
    - expect: Applications list renders promptly

#### 13.3. API Response Time - View List

**File:** `tests/performance/api-response-view-list.spec.ts`

**Steps:**
  1. Monitor network requests when loading view list
    - expect: API response time is under acceptable threshold (e.g., 1 second)
    - expect: No unnecessary API calls are made

#### 13.4. Memory Usage - Extended Session

**File:** `tests/performance/memory-usage-extended-session.spec.ts`

**Steps:**
  1. Log in and navigate through various pages for extended period
    - expect: Memory usage remains stable
    - expect: No significant memory leaks are detected
    - expect: Application performance does not degrade over time

### 14. Accessibility

**Seed:** `Crucible.AppHost/tests/tests/seed.setup.ts`

#### 14.1. Keyboard Navigation - Tab Order

**File:** `tests/accessibility/keyboard-tab-order.spec.ts`

**Steps:**
  1. Navigate to home page
    - expect: Page is loaded
  2. Press Tab key repeatedly to navigate through interactive elements
    - expect: Focus moves through elements in logical order
    - expect: All interactive elements are reachable
    - expect: Focus indicator is visible

#### 14.2. Keyboard Navigation - Enter Key Submission

**File:** `tests/accessibility/keyboard-enter-submission.spec.ts`

**Steps:**
  1. Navigate to a form (e.g., create view dialog)
    - expect: Form is displayed
  2. Fill in form fields using keyboard only
    - expect: Fields can be filled via keyboard
  3. Press Enter key to submit
    - expect: Form submits successfully without mouse click

#### 14.3. Screen Reader Compatibility - Headings

**File:** `tests/accessibility/screen-reader-headings.spec.ts`

**Steps:**
  1. Navigate to any page and inspect heading structure
    - expect: Headings are properly structured (h1, h2, h3)
    - expect: Page has appropriate ARIA labels
    - expect: Screen reader can navigate by headings

#### 14.4. Screen Reader Compatibility - Form Labels

**File:** `tests/accessibility/screen-reader-form-labels.spec.ts`

**Steps:**
  1. Navigate to a form
    - expect: All form fields have associated labels
    - expect: Labels are programmatically linked to inputs
    - expect: Screen reader announces labels correctly

#### 14.5. Color Contrast Compliance

**File:** `tests/accessibility/color-contrast.spec.ts`

**Steps:**
  1. Run automated accessibility audit on various pages
    - expect: All text meets WCAG color contrast requirements
    - expect: No accessibility violations for contrast are reported

#### 14.6. Focus Management - Modal Dialogs

**File:** `tests/accessibility/focus-management-modals.spec.ts`

**Steps:**
  1. Open a modal dialog (e.g., create view)
    - expect: Focus moves to modal when opened
    - expect: Focus is trapped within modal
    - expect: Background content is not accessible via Tab
  2. Close modal
    - expect: Focus returns to element that triggered modal
