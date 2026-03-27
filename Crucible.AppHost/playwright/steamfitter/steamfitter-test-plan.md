# Steamfitter Application Test Plan

## Application Overview

Steamfitter is a scenario execution service within the Crucible cybersecurity training platform. It enables content developers to create and manage scenarios consisting of scheduled tasks, manual tasks, and injects that run against virtual machines during training events. The application integrates with StackStorm for task execution and uses Keycloak for authentication. The UI is built with Angular and provides four major functional sections: Scenario Templates (reusable task groups), Scenarios (live instances of templates), Tasks (ad hoc task execution), and History (task execution results). The application supports role-based access control with system roles (Administrator, Content Developer, Observer) and granular permissions for managing scenario templates, scenarios, users, groups, and roles.

## Test Scenarios

### 1. Authentication and Authorization

**Seed:** `tests/seed.spec.ts`

#### 1.1. User Login Flow

**File:** `tests/steamfitter/authentication-and-authorization/user-login-flow.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4401
    - expect: The application redirects to the Keycloak authentication page at https://localhost:8443/realms/crucible
    - expect: The Keycloak login form is displayed
  2. Enter username 'admin' in the username field
    - expect: The username field accepts input
    - expect: The entered text is visible in the field
  3. Enter password 'admin' in the password field
    - expect: The password field accepts input
    - expect: The password text is masked with dots or asterisks
  4. Click the 'Sign In' button
    - expect: The authentication request is submitted
    - expect: The user is redirected back to http://localhost:4401
    - expect: The main Steamfitter application interface loads
    - expect: The topbar displays the username 'admin'
    - expect: The topbar has the configured red color (#BB0000)
    - expect: The application title 'Steamfitter' is visible in the topbar

#### 1.2. Unauthorized Access Redirect

**File:** `tests/steamfitter/authentication-and-authorization/unauthorized-access-redirect.spec.ts`

**Steps:**
  1. Clear all browser cookies and local storage
    - expect: All authentication tokens and session data are removed
  2. Navigate to http://localhost:4401/admin
    - expect: The application redirects to the Keycloak login page at https://localhost:8443/realms/crucible
    - expect: No Steamfitter application content is displayed before authentication
    - expect: The URL shows the authentication provider

#### 1.3. User Logout Flow

**File:** `tests/steamfitter/authentication-and-authorization/user-logout-flow.spec.ts`

**Steps:**
  1. Log in as admin user and verify home page is loaded
    - expect: Successfully authenticated and viewing the Steamfitter home page
    - expect: The topbar shows the username 'admin'
  2. Click on the user menu in the topbar
    - expect: A dropdown menu appears
    - expect: The menu contains user profile options and a logout option
  3. Click the 'Logout' option
    - expect: The user is logged out of the application
    - expect: Authentication tokens are cleared from browser storage
    - expect: The user is redirected to the Keycloak logout page or login page
    - expect: Attempting to access Steamfitter again requires re-authentication

#### 1.4. Session Token Renewal

**File:** `tests/steamfitter/authentication-and-authorization/session-token-renewal.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated with valid access token
    - expect: The application stores authentication state
  2. Monitor browser console and network activity for silent token renewal
    - expect: The application automatically attempts silent token renewal using the silent_redirect_uri (http://localhost:4401/auth-callback-silent.html)
    - expect: The token refresh happens without user interaction
    - expect: The user session remains active and uninterrupted
    - expect: No visible UI changes occur during token renewal

### 2. Home Page and Navigation

**Seed:** `tests/seed.spec.ts`

#### 2.1. Home Page Initial Load

**File:** `tests/steamfitter/home-page-and-navigation/home-page-initial-load.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4401
    - expect: The home page loads successfully
    - expect: The topbar is visible with the application title 'Steamfitter'
    - expect: The topbar has the configured red background color (#BB0000)
    - expect: The topbar text is white (#FFFFFF)
    - expect: The username 'admin' is displayed in the topbar
    - expect: The main content area is displayed
  2. Observe the home page layout and components
    - expect: The page displays the main application interface
    - expect: Navigation elements are visible and accessible
    - expect: The user interface is responsive and properly rendered

#### 2.2. Navigation to Administration Section

**File:** `tests/steamfitter/home-page-and-navigation/navigation-to-administration-section.spec.ts`

**Steps:**
  1. Log in as admin user on home page
    - expect: Successfully authenticated and viewing home page
  2. Click on the user menu dropdown in the topbar
    - expect: A dropdown menu appears
    - expect: The menu contains an 'Administration' option
  3. Click 'Administration' from the dropdown menu
    - expect: The browser navigates to http://localhost:4401/admin
    - expect: The administration interface loads
    - expect: A sidebar navigation menu is visible on the left side
    - expect: The sidebar contains navigation items for different admin sections

#### 2.3. Administration Section Access via Direct URL

**File:** `tests/steamfitter/home-page-and-navigation/administration-section-direct-url.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated
  2. Navigate directly to http://localhost:4401/admin
    - expect: The administration page loads successfully
    - expect: The sidebar navigation menu is displayed
    - expect: The admin interface is fully functional

#### 2.4. Sidebar Navigation in Admin

**File:** `tests/steamfitter/home-page-and-navigation/sidebar-navigation-in-admin.spec.ts`

**Steps:**
  1. Navigate to admin section at http://localhost:4401/admin
    - expect: The admin interface loads with sidebar visible
  2. Observe the sidebar menu items
    - expect: The sidebar contains navigation items for: Scenario Templates, Scenarios, Roles, Groups, Users
    - expect: Each menu item is clickable and properly labeled
    - expect: The current section is visually indicated (highlighted or selected)
  3. Click on each sidebar menu item in sequence
    - expect: Each click loads the corresponding admin section
    - expect: The URL updates to reflect the selected section (e.g., ?section=scenarios)
    - expect: The main content area updates to show the selected section
    - expect: The sidebar remains visible throughout navigation

### 3. Scenario Templates Management

**Seed:** `tests/seed.spec.ts`

#### 3.1. View Scenario Templates List

**File:** `tests/steamfitter/scenario-templates-management/view-scenario-templates-list.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4401/admin
    - expect: The admin interface loads
  2. Click on 'Scenario Templates' in the sidebar
    - expect: The Scenario Templates section loads
    - expect: A list or grid of existing scenario templates is displayed (if any exist)
    - expect: A button or option to create a new scenario template is visible
    - expect: Each scenario template shows its name and description

#### 3.2. Create New Scenario Template

**File:** `tests/steamfitter/scenario-templates-management/create-new-scenario-template.spec.ts`

**Steps:**
  1. Navigate to Scenario Templates section in admin
    - expect: The Scenario Templates list is displayed
  2. Click the 'Create' or 'Add' button to create a new scenario template
    - expect: A dialog or form appears for creating a new scenario template
    - expect: The form contains fields for: Name, Description, Duration
  3. Enter 'Test Scenario Template' in the Name field
    - expect: The name field accepts the input
  4. Enter 'This is a test scenario template for automated testing' in the Description field
    - expect: The description field accepts the input
  5. Enter '3600' in the Duration field (1 hour in seconds)
    - expect: The duration field accepts numeric input
  6. Click 'Save' or 'Create' button
    - expect: The dialog closes
    - expect: The new scenario template appears in the list
    - expect: The scenario template shows the entered name and description
    - expect: A success message or notification appears (if implemented)

#### 3.3. Edit Scenario Template Details

**File:** `tests/steamfitter/scenario-templates-management/edit-scenario-template-details.spec.ts`

**Steps:**
  1. Navigate to Scenario Templates section and ensure at least one template exists
    - expect: The Scenario Templates list displays existing templates
  2. Click on a scenario template or click its 'Edit' button
    - expect: An edit dialog or form appears
    - expect: The form is pre-populated with the current values: Name, Description, Duration
  3. Modify the Name field to 'Updated Test Scenario Template'
    - expect: The field accepts the new value
  4. Modify the Description field
    - expect: The field accepts the new value
  5. Click 'Save' to apply changes
    - expect: The dialog closes
    - expect: The scenario template list updates to show the new name and description
    - expect: The changes are persisted

#### 3.4. Copy Scenario Template

**File:** `tests/steamfitter/scenario-templates-management/copy-scenario-template.spec.ts`

**Steps:**
  1. Navigate to Scenario Templates section with at least one existing template
    - expect: The Scenario Templates list is displayed
  2. Click the 'Copy' button for an existing scenario template
    - expect: A new scenario template is created as a copy of the original
    - expect: The copy appears in the list with a similar name (e.g., 'Copy of [original name]')
    - expect: The copy contains all the same tasks as the original template

#### 3.5. Delete Scenario Template

**File:** `tests/steamfitter/scenario-templates-management/delete-scenario-template.spec.ts`

**Steps:**
  1. Navigate to Scenario Templates section and create a test template for deletion
    - expect: A test scenario template exists in the list
  2. Click the 'Delete' button for the test scenario template
    - expect: A confirmation dialog appears asking to confirm the deletion
    - expect: The dialog warns about the consequences of deletion
  3. Click 'Confirm' or 'Delete' in the confirmation dialog
    - expect: The dialog closes
    - expect: The scenario template is removed from the list
    - expect: The deletion is permanent

#### 3.6. Cancel Scenario Template Deletion

**File:** `tests/steamfitter/scenario-templates-management/cancel-scenario-template-deletion.spec.ts`

**Steps:**
  1. Navigate to Scenario Templates section
    - expect: Scenario templates are displayed
  2. Click the 'Delete' button for a scenario template
    - expect: A confirmation dialog appears
  3. Click 'Cancel' in the confirmation dialog
    - expect: The dialog closes
    - expect: The scenario template remains in the list unchanged
    - expect: No deletion occurs

### 4. Scenario Template Tasks

**Seed:** `tests/seed.spec.ts`

#### 4.1. View Tasks in Scenario Template

**File:** `tests/steamfitter/scenario-template-tasks/view-tasks-in-scenario-template.spec.ts`

**Steps:**
  1. Navigate to Scenario Templates section and select a scenario template
    - expect: The scenario template detail view opens
    - expect: A list of tasks associated with the template is displayed (if any exist)
    - expect: An option to add new tasks is visible

#### 4.2. Add Task to Scenario Template

**File:** `tests/steamfitter/scenario-template-tasks/add-task-to-scenario-template.spec.ts`

**Steps:**
  1. Navigate to a scenario template detail view
    - expect: The scenario template is loaded
  2. Click the '+' icon or 'Add Task' button
    - expect: A task creation form or dialog appears
    - expect: The form contains fields for: Name, Description, Action selection, Trigger Condition, Expected Output, Delay, Iterations, VM Mask
  3. Enter 'Power On VM' in the Name field
    - expect: The name field accepts the input
  4. Enter task description
    - expect: The description field accepts the input
  5. Select an Action from the dropdown (e.g., 'Power On VM')
    - expect: The action dropdown lists available StackStorm actions
    - expect: The selected action is applied to the task
  6. Select 'Manual' as the Trigger Condition
    - expect: The trigger condition is set to Manual
  7. Enter a VM Mask value (e.g., 'web-server')
    - expect: The VM Mask field accepts the input
  8. Click 'Save' to create the task
    - expect: The task is added to the scenario template
    - expect: The task appears in the task list with the entered name
    - expect: The task can be expanded to view its details

#### 4.3. Edit Task in Scenario Template

**File:** `tests/steamfitter/scenario-template-tasks/edit-task-in-scenario-template.spec.ts`

**Steps:**
  1. Navigate to a scenario template with at least one task
    - expect: The task list is displayed
  2. Click the task menu icon and select 'Edit'
    - expect: The task edit form opens
    - expect: The form is pre-populated with current task values
  3. Modify the task name to 'Updated Power On VM'
    - expect: The name field accepts the new value
  4. Change the Delay value to '60' seconds
    - expect: The delay field accepts the numeric value
  5. Click 'Save' to apply changes
    - expect: The changes are saved
    - expect: The task list updates to show the new name
    - expect: The task details reflect the updated values

#### 4.4. Configure Task Trigger Conditions

**File:** `tests/steamfitter/scenario-template-tasks/configure-task-trigger-conditions.spec.ts`

**Steps:**
  1. Open the task edit form for an existing task
    - expect: The edit form is displayed with Trigger Condition options
  2. Select 'Time' as the Trigger Condition
    - expect: The Trigger Condition is set to Time
    - expect: Additional fields appear for Delay and Iteration settings
  3. Enter '120' in the Delay field (2 minutes)
    - expect: The delay value is accepted
  4. Enter '3' in the Number of Iterations field
    - expect: The iteration count is accepted
  5. Enter '300' in the Interval Between Iterations field (5 minutes)
    - expect: The interval value is accepted
  6. Select 'IterationCount' as the Iteration Termination
    - expect: The termination condition is set
  7. Save the task
    - expect: The task is updated with the Time trigger configuration
    - expect: The task will execute automatically after the specified delay when the scenario runs

#### 4.5. Configure Task Expected Output

**File:** `tests/steamfitter/scenario-template-tasks/configure-task-expected-output.spec.ts`

**Steps:**
  1. Open the task edit form
    - expect: The edit form is displayed
  2. Enter 'success' in the Expected Output field
    - expect: The expected output value is accepted
    - expect: This value will be used to determine task success or failure
  3. Save the task
    - expect: The task is updated with the expected output
    - expect: When executed, the task result will be compared against this expected output

#### 4.6. Configure Task VM Selection with Mask

**File:** `tests/steamfitter/scenario-template-tasks/configure-task-vm-selection-mask.spec.ts`

**Steps:**
  1. Open the task edit form
    - expect: The VM Selection section is visible
  2. Enter 'web-' in the VM Mask field
    - expect: The VM Mask accepts the input
    - expect: This mask will match all VMs whose names contain 'web-'
  3. Save the task
    - expect: The task is updated with the VM mask
    - expect: When executed, the task will run against all VMs matching the mask pattern

#### 4.7. Delete Task from Scenario Template

**File:** `tests/steamfitter/scenario-template-tasks/delete-task-from-scenario-template.spec.ts`

**Steps:**
  1. Navigate to a scenario template with tasks
    - expect: The task list is displayed
  2. Click the task menu icon and select 'Delete'
    - expect: A confirmation dialog appears
  3. Confirm the deletion
    - expect: The task is removed from the scenario template
    - expect: The task no longer appears in the task list

#### 4.8. Copy Task in Scenario Template

**File:** `tests/steamfitter/scenario-template-tasks/copy-task-in-scenario-template.spec.ts`

**Steps:**
  1. Navigate to a scenario template with at least one task
    - expect: The task list is displayed
  2. Click the task menu icon and select 'Copy'
    - expect: The task is copied to clipboard or memory
  3. Click in an empty area or another task menu and select 'Paste'
    - expect: A duplicate of the copied task is created
    - expect: The new task appears in the list with the same configuration as the original

#### 4.9. Create Subtask

**File:** `tests/steamfitter/scenario-template-tasks/create-subtask.spec.ts`

**Steps:**
  1. Navigate to a scenario template with at least one task
    - expect: The task list is displayed
  2. Click the task menu icon for a parent task and select 'New'
    - expect: A new task creation form opens
    - expect: The new task will be created as a subtask of the parent
  3. Configure the subtask with name 'Verify VM Status' and appropriate settings
    - expect: The subtask form accepts all inputs
  4. Select 'Completion' as the Trigger Condition
    - expect: The subtask is configured to run after the parent task completes
  5. Save the subtask
    - expect: The subtask is created and appears nested under the parent task
    - expect: The task hierarchy is visually indicated (indentation or tree structure)
    - expect: The subtask will execute automatically after the parent task

#### 4.10. Configure Task with Points

**File:** `tests/steamfitter/scenario-template-tasks/configure-task-with-points.spec.ts`

**Steps:**
  1. Open the task edit form
    - expect: The edit form displays a Scoring section
  2. Enter '10' in the Points field under Scoring
    - expect: The points value is accepted
    - expect: This task will be worth 10 points when completed successfully
  3. Save the task
    - expect: The task is updated with the points value
    - expect: When displayed in Player view, this task will contribute to the score panel

### 5. Scenarios Management

**Seed:** `tests/seed.spec.ts`

#### 5.1. View Scenarios List

**File:** `tests/steamfitter/scenarios-management/view-scenarios-list.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4401/admin
    - expect: The admin interface loads
  2. Click on 'Scenarios' in the sidebar
    - expect: The Scenarios section loads
    - expect: A list of existing scenarios is displayed (if any exist)
    - expect: Each scenario shows its name, status, and associated view
    - expect: Scenarios are organized by status: Planned, Active, Completed

#### 5.2. Create Scenario from Template

**File:** `tests/steamfitter/scenarios-management/create-scenario-from-template.spec.ts`

**Steps:**
  1. Navigate to Scenario Templates section and select a scenario template
    - expect: The scenario template detail view opens
  2. Click 'Create a Scenario' button
    - expect: A new scenario is created from the template
    - expect: The scenario is named with the format '[template name] - [username]'
    - expect: The scenario inherits all tasks from the template
    - expect: The scenario appears in the Scenarios list

#### 5.3. Edit Scenario Details

**File:** `tests/steamfitter/scenarios-management/edit-scenario-details.spec.ts`

**Steps:**
  1. Navigate to Scenarios section and select a scenario
    - expect: The scenario detail view opens
    - expect: The scenario name, description, and view association are displayed
  2. Edit the scenario Name field to 'Updated Scenario Name'
    - expect: The name field accepts the new value
  3. Edit the Description field
    - expect: The description field accepts the new value
  4. Save the changes
    - expect: The scenario is updated with the new name and description
    - expect: The changes are reflected in the scenarios list

#### 5.4. Associate Scenario with Player View

**File:** `tests/steamfitter/scenarios-management/associate-scenario-with-player-view.spec.ts`

**Steps:**
  1. Navigate to a scenario detail view
    - expect: The scenario details are displayed
    - expect: A 'View' dropdown is visible
  2. Click the 'View' dropdown
    - expect: A list of available Player views is displayed
    - expect: Each view shows its name and ID
  3. Select a Player view from the dropdown
    - expect: The selected view is associated with the scenario
    - expect: The scenario can now be started against the VMs in that view
    - expect: The 'Start Scenario' button becomes enabled

#### 5.5. Configure Scenario Start and End Times

**File:** `tests/steamfitter/scenarios-management/configure-scenario-start-end-times.spec.ts`

**Steps:**
  1. Navigate to a scenario detail view
    - expect: The scenario details include Start and End date/time fields
  2. Click on the Start date/time field and set a future date and time
    - expect: A date/time picker appears
    - expect: The selected start time is accepted
  3. Click on the End date/time field and set a date/time after the start time
    - expect: The end time is accepted
    - expect: The end time is after the start time
  4. Save the changes
    - expect: The scenario is updated with the new start and end times
    - expect: The scenario will automatically start and end at the specified times

#### 5.6. Start Scenario

**File:** `tests/steamfitter/scenarios-management/start-scenario.spec.ts`

**Steps:**
  1. Navigate to a scenario that is associated with a Player view
    - expect: The scenario detail view is displayed
    - expect: The 'Start Scenario' button is enabled
  2. Click the 'Start Scenario' button
    - expect: The scenario status changes to 'Active'
    - expect: The 'Start Scenario' button changes to 'End Scenario Now'
    - expect: An 'Execute' option appears in the task menu for manual tasks
    - expect: Time-based tasks begin executing according to their delay settings

#### 5.7. End Scenario

**File:** `tests/steamfitter/scenarios-management/end-scenario.spec.ts`

**Steps:**
  1. Navigate to an active scenario
    - expect: The scenario status is 'Active'
    - expect: The 'End Scenario Now' button is visible
  2. Click the 'End Scenario Now' button
    - expect: A confirmation dialog appears (if implemented)
    - expect: After confirmation, the scenario status changes to 'Ended' or 'Completed'
    - expect: Tasks stop executing
    - expect: The scenario can no longer execute new tasks

#### 5.8. Execute Manual Task in Active Scenario

**File:** `tests/steamfitter/scenarios-management/execute-manual-task-in-active-scenario.spec.ts`

**Steps:**
  1. Start a scenario and navigate to its detail view
    - expect: The scenario is active
    - expect: Manual tasks are visible with an 'Execute' option in the task menu
  2. Click the task menu icon for a manual task and select 'Execute'
    - expect: The task begins execution
    - expect: A loading or progress indicator appears (if implemented)
    - expect: After execution, the task result is displayed
    - expect: The result shows the output from StackStorm and indicates success or failure
  3. Expand the task to view detailed results
    - expect: The task details show each execution result
    - expect: Each result includes timestamp, status, and output text
    - expect: Multiple executions are listed separately if the task was run multiple times

#### 5.9. View Task Results in Scenario

**File:** `tests/steamfitter/scenarios-management/view-task-results-in-scenario.spec.ts`

**Steps:**
  1. Navigate to a scenario where tasks have been executed
    - expect: The scenario detail view shows the task list
  2. Expand a task that has been executed
    - expect: The task results are displayed
    - expect: Each result shows: execution time, status (success/failure), output text, VM name
    - expect: Results are organized chronologically
  3. Review the task result details
    - expect: The actual output is compared against the expected output (if configured)
    - expect: Success/failure status is clearly indicated
    - expect: The full output text from StackStorm is visible

#### 5.10. Scenario Cannot Start Without View

**File:** `tests/steamfitter/scenarios-management/scenario-cannot-start-without-view.spec.ts`

**Steps:**
  1. Create a new scenario from a template
    - expect: The scenario is created successfully
  2. Navigate to the scenario detail view without associating it with a Player view
    - expect: The 'Start Scenario' button is disabled or grayed out
    - expect: A message or tooltip indicates that a view must be selected before starting
  3. Attempt to click the disabled 'Start Scenario' button
    - expect: The button does not respond
    - expect: The scenario does not start

### 6. Tasks Page for Users

**Seed:** `tests/seed.spec.ts`

#### 6.1. Access Tasks via Scenario ID

**File:** `tests/steamfitter/tasks-page-for-users/access-tasks-via-scenario-id.spec.ts`

**Steps:**
  1. Create and start a scenario with user-executable tasks
    - expect: The scenario is active with at least one user-executable task
  2. Navigate to http://localhost:4401/scenario/[scenarioId] where [scenarioId] is the scenario's ID
    - expect: The manual tasks page loads
    - expect: Only user-executable tasks for the specified scenario are displayed
    - expect: Each task shows its name and status
    - expect: Tasks with points show their point values

#### 6.2. Access Tasks via View ID

**File:** `tests/steamfitter/tasks-page-for-users/access-tasks-via-view-id.spec.ts`

**Steps:**
  1. Create a scenario associated with a Player view and start it
    - expect: The scenario is active and associated with exactly one view
  2. Navigate to http://localhost:4401/view/[viewId] where [viewId] is the Player view ID
    - expect: The manual tasks page loads
    - expect: User-executable tasks for the scenario mapped to that view are displayed
    - expect: The tasks are functional and can be executed

#### 6.3. Error When Multiple Scenarios Share Same View

**File:** `tests/steamfitter/tasks-page-for-users/error-multiple-scenarios-same-view.spec.ts`

**Steps:**
  1. Create two scenarios and associate both with the same Player view
    - expect: Both scenarios are associated with the same view ID
  2. Navigate to http://localhost:4401/view/[viewId]
    - expect: An error message is displayed explaining that multiple scenarios share the same view
    - expect: The error message instructs the user to use the scenario-based URL instead
    - expect: No tasks are displayed due to the ambiguity

#### 6.4. Execute User-Executable Task from Tasks Page

**File:** `tests/steamfitter/tasks-page-for-users/execute-user-executable-task-from-tasks-page.spec.ts`

**Steps:**
  1. Navigate to the tasks page for an active scenario with user-executable tasks
    - expect: The tasks page displays user-executable tasks
  2. Click on a user-executable task
    - expect: The task begins execution
    - expect: A loading indicator or status update appears
    - expect: After execution, the result is displayed
    - expect: The task status updates to show completion

#### 6.5. Execute Repeatable Task Multiple Times

**File:** `tests/steamfitter/tasks-page-for-users/execute-repeatable-task-multiple-times.spec.ts`

**Steps:**
  1. Navigate to the tasks page with a repeatable user-executable task
    - expect: The task is marked as repeatable
  2. Execute the task for the first time
    - expect: The task executes successfully
    - expect: The task remains executable after completion
  3. Execute the same task again
    - expect: The task executes again successfully
    - expect: Multiple execution results are recorded
    - expect: The task can be executed additional times

#### 6.6. Non-Repeatable Task Becomes Unavailable

**File:** `tests/steamfitter/tasks-page-for-users/non-repeatable-task-becomes-unavailable.spec.ts`

**Steps:**
  1. Navigate to the tasks page with a non-repeatable user-executable task
    - expect: The task is not marked as repeatable
  2. Execute the task
    - expect: The task executes successfully
    - expect: After completion, the task becomes disabled or grayed out
    - expect: The task cannot be executed again
  3. Attempt to execute the same task again
    - expect: The task button is disabled or does not respond
    - expect: No new execution occurs

#### 6.7. View Task Points and Score Panel

**File:** `tests/steamfitter/tasks-page-for-users/view-task-points-and-score-panel.spec.ts`

**Steps:**
  1. Create a scenario with multiple tasks assigned different point values
    - expect: Tasks have various point values assigned (e.g., 5, 10, 15 points)
  2. Navigate to the tasks page for this scenario
    - expect: A score panel is displayed showing total possible points
    - expect: Each task displays its point value
    - expect: The current score starts at 0
  3. Execute a task worth 10 points successfully
    - expect: The score panel updates to show 10 points earned
    - expect: The progress bar or score indicator reflects the earned points

#### 6.8. No Score Panel When No Points Assigned

**File:** `tests/steamfitter/tasks-page-for-users/no-score-panel-when-no-points-assigned.spec.ts`

**Steps:**
  1. Create a scenario with tasks that have no points assigned (0 points)
    - expect: All tasks have 0 points
  2. Navigate to the tasks page for this scenario
    - expect: No score panel is displayed
    - expect: Only the list of tasks is shown
    - expect: Tasks can still be executed normally

### 7. History and Results

**Seed:** `tests/seed.spec.ts`

#### 7.1. View History Page Default View

**File:** `tests/steamfitter/history-and-results/view-history-page-default-view.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to the History section
    - expect: The History page loads
    - expect: Task results are displayed in reverse chronological order (most recent first)
    - expect: Results are filtered to show only the current user's task executions
    - expect: Each result shows: task name, execution time, status, VM name, output preview

#### 7.2. Filter History by User

**File:** `tests/steamfitter/history-and-results/filter-history-by-user.spec.ts`

**Steps:**
  1. Navigate to the History page
    - expect: The History page is displayed with filter options
  2. Select 'User' filter option
    - expect: A user selection dropdown or filter appears
  3. Select a specific user from the filter
    - expect: The history results update to show only task executions by the selected user
    - expect: The results are filtered accordingly

#### 7.3. Filter History by View

**File:** `tests/steamfitter/history-and-results/filter-history-by-view.spec.ts`

**Steps:**
  1. Navigate to the History page
    - expect: The History page is displayed
  2. Select 'View' filter option
    - expect: A view selection dropdown appears
  3. Select a specific Player view from the filter
    - expect: The history results update to show only task executions for scenarios associated with that view
    - expect: All results are related to the selected view

#### 7.4. Filter History by VM

**File:** `tests/steamfitter/history-and-results/filter-history-by-vm.spec.ts`

**Steps:**
  1. Navigate to the History page
    - expect: The History page is displayed
  2. Select 'VM' filter option
    - expect: A VM selection dropdown appears
  3. Select a specific VM from the filter
    - expect: The history results update to show only task executions that ran against the selected VM
    - expect: All results are for the specified VM

#### 7.5. Sort History Results

**File:** `tests/steamfitter/history-and-results/sort-history-results.spec.ts`

**Steps:**
  1. Navigate to the History page with multiple results
    - expect: The History page displays multiple task results
    - expect: Column headers are clickable for sorting
  2. Click on a column header (e.g., 'Task Name')
    - expect: The results are sorted by the selected column in ascending order
  3. Click the same column header again
    - expect: The results are sorted in descending order
    - expect: The sort direction indicator updates (arrow icon)

#### 7.6. View Detailed Task Result

**File:** `tests/steamfitter/history-and-results/view-detailed-task-result.spec.ts`

**Steps:**
  1. Navigate to the History page and locate a task result
    - expect: Task results are listed
  2. Click on a task result to expand or view details
    - expect: The full task result details are displayed
    - expect: The details include: full output text, execution time, VM name, status, expected vs actual output comparison

#### 7.7. Search History Results

**File:** `tests/steamfitter/history-and-results/search-history-results.spec.ts`

**Steps:**
  1. Navigate to the History page
    - expect: The History page is displayed with a search field (if implemented)
  2. Enter a search term in the search field (e.g., a task name)
    - expect: The history results are filtered to match the search term
    - expect: Only results containing the search term are displayed
  3. Clear the search field
    - expect: All history results are displayed again

### 8. User Management in Admin

**Seed:** `tests/seed.spec.ts`

#### 8.1. View Users List

**File:** `tests/steamfitter/user-management-in-admin/view-users-list.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4401/admin
    - expect: The admin interface loads
  2. Click on 'Users' in the sidebar
    - expect: The Users section loads
    - expect: A list of all users in the system is displayed
    - expect: Each user entry shows: username, name, email (if available)
    - expect: User role information is visible

#### 8.2. Search Users

**File:** `tests/steamfitter/user-management-in-admin/search-users.spec.ts`

**Steps:**
  1. Navigate to the Users section in admin
    - expect: The Users list is displayed with a search field
  2. Enter 'admin' in the search field
    - expect: The users list is filtered to show only users matching 'admin'
    - expect: The admin user appears in the results
  3. Clear the search field
    - expect: All users are displayed again

#### 8.3. View User Details

**File:** `tests/steamfitter/user-management-in-admin/view-user-details.spec.ts`

**Steps:**
  1. Navigate to the Users section
    - expect: The Users list is displayed
  2. Click on a user in the list
    - expect: The user detail view opens
    - expect: User information is displayed: username, name, email, system role
    - expect: User's group memberships are visible
    - expect: User's scenario template and scenario memberships are visible

#### 8.4. Assign System Role to User

**File:** `tests/steamfitter/user-management-in-admin/assign-system-role-to-user.spec.ts`

**Steps:**
  1. Navigate to the Users section and select a user
    - expect: The user detail view is displayed
  2. Locate the System Role dropdown or assignment control
    - expect: A control for assigning system roles is visible
    - expect: Available system roles are listed: Administrator, Content Developer, Observer
  3. Select 'Content Developer' from the system roles
    - expect: The user is assigned the Content Developer role
    - expect: The user now has permissions: CreateScenarioTemplates, CreateScenarios, ExecuteScenarios, ManageTasks, ViewUsers, ViewGroups
    - expect: The role assignment is saved automatically or after clicking Save

### 9. Group Management in Admin

**Seed:** `tests/seed.spec.ts`

#### 9.1. View Groups List

**File:** `tests/steamfitter/group-management-in-admin/view-groups-list.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4401/admin
    - expect: The admin interface loads
  2. Click on 'Groups' in the sidebar
    - expect: The Groups section loads
    - expect: A list of existing groups is displayed (if any exist)
    - expect: Each group shows its name
    - expect: An option to create a new group is visible

#### 9.2. Create New Group

**File:** `tests/steamfitter/group-management-in-admin/create-new-group.spec.ts`

**Steps:**
  1. Navigate to the Groups section
    - expect: The Groups list is displayed
  2. Click the 'Create' or 'Add Group' button
    - expect: A dialog or form appears for creating a new group
    - expect: The form contains a field for the group name
  3. Enter 'Test Group' in the name field
    - expect: The name field accepts the input
  4. Click 'Save' or 'Create' to create the group
    - expect: The new group is created
    - expect: The group appears in the groups list
    - expect: The group can be selected to manage its members

#### 9.3. Add Members to Group

**File:** `tests/steamfitter/group-management-in-admin/add-members-to-group.spec.ts`

**Steps:**
  1. Navigate to the Groups section and select a group
    - expect: The group detail view opens
    - expect: A list of current group members is displayed (if any)
    - expect: An option to add members is visible
  2. Click 'Add Member' or similar button
    - expect: A user selection dialog appears
    - expect: Available users who are not already members are listed
  3. Select one or more users from the list
    - expect: The selected users are highlighted
  4. Confirm the selection
    - expect: The selected users are added to the group
    - expect: The users appear in the group members list
    - expect: The users now have any permissions assigned to the group

#### 9.4. Remove Member from Group

**File:** `tests/steamfitter/group-management-in-admin/remove-member-from-group.spec.ts`

**Steps:**
  1. Navigate to a group that has at least one member
    - expect: The group members list is displayed
  2. Click the remove or delete icon next to a group member
    - expect: A confirmation dialog appears (if implemented)
  3. Confirm the removal
    - expect: The user is removed from the group
    - expect: The user no longer appears in the group members list
    - expect: The user loses any permissions granted through this group membership

#### 9.5. Delete Group

**File:** `tests/steamfitter/group-management-in-admin/delete-group.spec.ts`

**Steps:**
  1. Navigate to the Groups section
    - expect: The Groups list is displayed
  2. Click the delete icon for a group
    - expect: A confirmation dialog appears
  3. Confirm the deletion
    - expect: The group is deleted
    - expect: The group is removed from the groups list
    - expect: Members of the group lose any permissions granted through this group

### 10. Roles and Permissions Management

**Seed:** `tests/seed.spec.ts`

#### 10.1. View System Roles

**File:** `tests/steamfitter/roles-and-permissions-management/view-system-roles.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4401/admin
    - expect: The admin interface loads
  2. Click on 'Roles' in the sidebar
    - expect: The Roles section loads
    - expect: System roles are displayed: Administrator, Content Developer, Observer
    - expect: Each role can be expanded to view its permissions

#### 10.2. View System Role Permissions

**File:** `tests/steamfitter/roles-and-permissions-management/view-system-role-permissions.spec.ts`

**Steps:**
  1. Navigate to the Roles section
    - expect: The Roles list is displayed
  2. Click on the 'Administrator' system role
    - expect: The role details are displayed
    - expect: All available permissions are listed
    - expect: The Administrator role has all permissions checked/enabled
  3. Click on the 'Content Developer' system role
    - expect: The Content Developer permissions are displayed
    - expect: The role has permissions: CreateScenarioTemplates, CreateScenarios, ExecuteScenarios, ManageTasks, ViewUsers, ViewGroups
    - expect: Other permissions are not granted

#### 10.3. Create Custom System Role

**File:** `tests/steamfitter/roles-and-permissions-management/create-custom-system-role.spec.ts`

**Steps:**
  1. Navigate to the Roles section
    - expect: The Roles section is displayed with an option to create new roles
  2. Click 'Create Role' or similar button
    - expect: A role creation form appears
    - expect: The form includes a name field and a list of available permissions
  3. Enter 'Custom Viewer' as the role name
    - expect: The name field accepts the input
  4. Select permissions: ViewScenarioTemplates, ViewScenarios
    - expect: The selected permissions are checked
  5. Save the new role
    - expect: The custom role is created
    - expect: The role appears in the system roles list
    - expect: The role can be assigned to users

#### 10.4. Edit System Role Permissions

**File:** `tests/steamfitter/roles-and-permissions-management/edit-system-role-permissions.spec.ts`

**Steps:**
  1. Navigate to the Roles section and select a custom role
    - expect: The role details are displayed with its current permissions
  2. Add or remove permissions by checking/unchecking permission checkboxes
    - expect: The permission selections update
  3. Save the changes
    - expect: The role permissions are updated
    - expect: Users with this role immediately receive or lose the modified permissions

#### 10.5. Delete Custom System Role

**File:** `tests/steamfitter/roles-and-permissions-management/delete-custom-system-role.spec.ts`

**Steps:**
  1. Navigate to the Roles section
    - expect: The Roles list includes custom roles
  2. Click the delete icon for a custom role
    - expect: A confirmation dialog appears warning about the deletion
  3. Confirm the deletion
    - expect: The custom role is deleted
    - expect: The role is removed from the roles list
    - expect: Users who had this role lose those permissions

#### 10.6. View Scenario Template Roles

**File:** `tests/steamfitter/roles-and-permissions-management/view-scenario-template-roles.spec.ts`

**Steps:**
  1. Navigate to a Scenario Template detail view
    - expect: The scenario template details are displayed
  2. Navigate to the roles or permissions section for the scenario template
    - expect: A list of users and groups with permissions for this specific scenario template is displayed
    - expect: Permissions are specific to this template: View, Modify, Execute

#### 10.7. Grant Scenario Template Permissions to User

**File:** `tests/steamfitter/roles-and-permissions-management/grant-scenario-template-permissions-to-user.spec.ts`

**Steps:**
  1. Navigate to a Scenario Template and its permissions section
    - expect: The template permissions interface is displayed
  2. Click 'Add User' or similar button
    - expect: A user selection dialog appears
  3. Select a user and grant 'View' and 'Execute' permissions
    - expect: The permissions are assigned
  4. Save the changes
    - expect: The user now has View and Execute permissions for this scenario template
    - expect: The user can view and create scenarios from this template but cannot modify it

### 11. VM Credentials Management

**Seed:** `tests/seed.spec.ts`

#### 11.1. View VM Credentials

**File:** `tests/steamfitter/vm-credentials-management/view-vm-credentials.spec.ts`

**Steps:**
  1. Navigate to a scenario that is associated with a Player view
    - expect: The scenario detail view is displayed
  2. Locate and click on the VM Credentials or VM List section
    - expect: A list of VMs from the associated Player view is displayed
    - expect: Each VM shows its name and credential information (if configured)

#### 11.2. Add VM Credentials

**File:** `tests/steamfitter/vm-credentials-management/add-vm-credentials.spec.ts`

**Steps:**
  1. Navigate to the VM Credentials section for a scenario
    - expect: The VM list is displayed
  2. Click 'Add Credentials' or similar button for a VM
    - expect: A credentials input dialog appears
    - expect: Fields for username and password are displayed
  3. Enter 'testuser' as username and 'testpass' as password
    - expect: The credentials fields accept the input
  4. Save the credentials
    - expect: The credentials are stored for the VM
    - expect: The credentials will be used for task execution against this VM

#### 11.3. Edit VM Credentials

**File:** `tests/steamfitter/vm-credentials-management/edit-vm-credentials.spec.ts`

**Steps:**
  1. Navigate to a VM that has credentials configured
    - expect: The VM credentials are displayed
  2. Click 'Edit' on the VM credentials
    - expect: The credentials edit dialog appears
    - expect: Current credentials are shown (password may be masked)
  3. Update the username or password
    - expect: The new credentials are accepted
  4. Save the changes
    - expect: The credentials are updated
    - expect: Future task executions will use the new credentials

#### 11.4. Delete VM Credentials

**File:** `tests/steamfitter/vm-credentials-management/delete-vm-credentials.spec.ts`

**Steps:**
  1. Navigate to a VM with configured credentials
    - expect: The VM credentials are displayed
  2. Click 'Delete' on the VM credentials
    - expect: A confirmation dialog appears
  3. Confirm the deletion
    - expect: The credentials are removed
    - expect: The VM no longer has stored credentials
    - expect: Tasks requiring credentials for this VM may fail

### 12. Error Handling and Edge Cases

**Seed:** `tests/seed.spec.ts`

#### 12.1. Create Scenario Template with Empty Name

**File:** `tests/steamfitter/error-handling-and-edge-cases/create-scenario-template-with-empty-name.spec.ts`

**Steps:**
  1. Navigate to Scenario Templates section
    - expect: The Scenario Templates list is displayed
  2. Click 'Create' to open the creation dialog
    - expect: The creation form appears
  3. Leave the Name field empty and fill in other required fields
    - expect: The Name field remains empty
  4. Attempt to save the scenario template
    - expect: A validation error message appears indicating that Name is required
    - expect: The scenario template is not created
    - expect: The dialog remains open for correction

#### 12.2. Create Task with Invalid Delay Value

**File:** `tests/steamfitter/error-handling-and-edge-cases/create-task-with-invalid-delay-value.spec.ts`

**Steps:**
  1. Navigate to a scenario template and open the task creation form
    - expect: The task creation form is displayed
  2. Enter '-5' in the Delay field (negative value)
    - expect: The field accepts the input initially
  3. Attempt to save the task
    - expect: A validation error appears indicating that Delay must be a positive number or zero
    - expect: The task is not created

#### 12.3. Create Task with Non-Numeric Duration

**File:** `tests/steamfitter/error-handling-and-edge-cases/create-task-with-non-numeric-duration.spec.ts`

**Steps:**
  1. Navigate to the task creation form
    - expect: The form is displayed
  2. Enter 'abc' in the Duration field
    - expect: The field may reject non-numeric input or show a validation error
  3. Attempt to save the task
    - expect: A validation error appears indicating that Duration must be a number
    - expect: The task is not created

#### 12.4. Execute Task Against Non-Existent VM

**File:** `tests/steamfitter/error-handling-and-edge-cases/execute-task-against-non-existent-vm.spec.ts`

**Steps:**
  1. Create a task with a VM Mask that does not match any VMs in the associated view
    - expect: The task is created with the non-matching VM mask
  2. Start the scenario and attempt to execute the task
    - expect: The task execution completes but reports no VMs found
    - expect: An error or warning message indicates that no VMs matched the mask
    - expect: No results are generated

#### 12.5. Start Scenario with End Time Before Start Time

**File:** `tests/steamfitter/error-handling-and-edge-cases/start-scenario-with-end-time-before-start-time.spec.ts`

**Steps:**
  1. Navigate to a scenario and edit its start and end times
    - expect: The start and end time fields are displayed
  2. Set the end time to be before the start time
    - expect: The time values are entered
  3. Attempt to save or start the scenario
    - expect: A validation error appears indicating that end time must be after start time
    - expect: The scenario cannot be started with invalid times

#### 12.6. Network Error During Task Execution

**File:** `tests/steamfitter/error-handling-and-edge-cases/network-error-during-task-execution.spec.ts`

**Steps:**
  1. Start a scenario and execute a task
    - expect: The task begins execution
  2. Simulate a network interruption (if possible in test environment) or wait for a task that may fail
    - expect: If the network is interrupted, an error message appears
    - expect: The task execution fails gracefully
    - expect: An error result is recorded in the task results
    - expect: The application remains functional after the error

#### 12.7. Access Admin Section Without Permissions

**File:** `tests/steamfitter/error-handling-and-edge-cases/access-admin-section-without-permissions.spec.ts`

**Steps:**
  1. Log in as a user with Observer role (ViewScenarioTemplates and ViewScenarios permissions only)
    - expect: The user is authenticated
  2. Navigate to http://localhost:4401/admin
    - expect: The admin interface loads but only shows sections the user has permissions for
    - expect: The sidebar shows only: Scenario Templates, Scenarios
    - expect: The sidebar does not show: Users, Groups, Roles (no ViewUsers, ManageRoles permissions)
  3. Attempt to create a new scenario template
    - expect: The create button is disabled or not visible
    - expect: The user cannot create scenario templates (no CreateScenarioTemplates permission)

#### 12.8. Delete Scenario Template in Use

**File:** `tests/steamfitter/error-handling-and-edge-cases/delete-scenario-template-in-use.spec.ts`

**Steps:**
  1. Create a scenario template and then create an active scenario from it
    - expect: The scenario template has active scenarios associated with it
  2. Attempt to delete the scenario template
    - expect: A warning or error message appears indicating that the template is in use
    - expect: The deletion may be prevented, or the user is warned about consequences
    - expect: If deletion proceeds, the scenarios may lose their template reference

#### 12.9. Session Expires During Active Work

**File:** `tests/steamfitter/error-handling-and-edge-cases/session-expires-during-active-work.spec.ts`

**Steps:**
  1. Log in and navigate to a form or editing interface
    - expect: The user is authenticated and working in the application
  2. Wait for the session to expire (or simulate token expiration)
    - expect: The application detects the expired session
    - expect: An error message or notification appears informing the user of session expiration
    - expect: The user is redirected to the login page or prompted to re-authenticate
    - expect: Unsaved work is lost (or saved if auto-save is implemented)

#### 12.10. Browser Back Button Navigation

**File:** `tests/steamfitter/error-handling-and-edge-cases/browser-back-button-navigation.spec.ts`

**Steps:**
  1. Navigate through multiple pages in the application (Home -> Admin -> Scenario Templates -> Specific Template)
    - expect: Each page loads correctly
  2. Click the browser back button
    - expect: The application navigates back to the previous page correctly
    - expect: The page state is preserved or reloaded appropriately
    - expect: No errors occur during navigation
  3. Continue clicking back multiple times
    - expect: The application continues to navigate backward correctly through the history
    - expect: Eventually reaches the home page or login page

### 13. UI Responsiveness and Accessibility

**Seed:** `tests/seed.spec.ts`

#### 13.1. Responsive Layout on Mobile Viewport

**File:** `tests/steamfitter/ui-responsiveness-and-accessibility/responsive-layout-on-mobile-viewport.spec.ts`

**Steps:**
  1. Set browser viewport to mobile size (e.g., 375x667 pixels)
    - expect: The viewport is set to mobile size
  2. Navigate to http://localhost:4401 and log in
    - expect: The application loads in mobile view
    - expect: The layout adjusts to fit the smaller screen
    - expect: The topbar remains visible and functional
    - expect: Navigation elements are accessible (may be collapsed into a menu)
  3. Navigate to the admin section
    - expect: The sidebar adapts to mobile view (may be collapsible or overlay)
    - expect: All functionality remains accessible on mobile
    - expect: Tables and lists are scrollable or adapted for mobile viewing

#### 13.2. Responsive Layout on Tablet Viewport

**File:** `tests/steamfitter/ui-responsiveness-and-accessibility/responsive-layout-on-tablet-viewport.spec.ts`

**Steps:**
  1. Set browser viewport to tablet size (e.g., 768x1024 pixels)
    - expect: The viewport is set to tablet size
  2. Navigate through the application
    - expect: The application layout adapts appropriately for tablet view
    - expect: All features are accessible and functional
    - expect: The UI elements are properly sized and spaced for touch interaction

#### 13.3. Keyboard Navigation Through Admin Sidebar

**File:** `tests/steamfitter/ui-responsiveness-and-accessibility/keyboard-navigation-through-admin-sidebar.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4401/admin
    - expect: The admin interface loads with the sidebar visible
  2. Use Tab key to navigate through sidebar items
    - expect: Focus moves through each sidebar menu item
    - expect: The focused item is visually highlighted
    - expect: All interactive elements can be reached via keyboard
  3. Press Enter on a focused sidebar item
    - expect: The corresponding admin section loads
    - expect: Keyboard navigation functions the same as mouse clicking

#### 13.4. Keyboard Navigation in Forms

**File:** `tests/steamfitter/ui-responsiveness-and-accessibility/keyboard-navigation-in-forms.spec.ts`

**Steps:**
  1. Open a form dialog (e.g., Create Scenario Template)
    - expect: The form is displayed
  2. Use Tab key to navigate through form fields
    - expect: Focus moves through each form field in logical order
    - expect: Each focused field is visually highlighted
    - expect: All form controls (inputs, dropdowns, buttons) are accessible via keyboard
  3. Press Enter on the Save button when focused
    - expect: The form is submitted as if clicked with mouse
    - expect: Keyboard submission works correctly
  4. Press Escape key
    - expect: The dialog closes (if supported)
    - expect: Keyboard shortcuts function correctly

#### 13.5. Screen Reader Compatibility

**File:** `tests/steamfitter/ui-responsiveness-and-accessibility/screen-reader-compatibility.spec.ts`

**Steps:**
  1. Enable screen reader testing mode or check for ARIA labels
    - expect: The page is loaded
  2. Navigate through the topbar elements
    - expect: Interactive elements have appropriate ARIA labels
    - expect: The application title, user menu, and navigation elements are properly labeled
    - expect: Screen readers can announce the element purposes
  3. Navigate through a data table or list
    - expect: Table headers are properly labeled with ARIA attributes
    - expect: Row and column information is accessible to screen readers
    - expect: List items have descriptive labels

#### 13.6. Color Contrast and Visibility

**File:** `tests/steamfitter/ui-responsiveness-and-accessibility/color-contrast-and-visibility.spec.ts`

**Steps:**
  1. Navigate to the home page
    - expect: The page is displayed with configured colors
  2. Verify the topbar color contrast (red background #BB0000 with white text #FFFFFF)
    - expect: The text is clearly readable against the background
    - expect: The color contrast meets WCAG accessibility standards (minimum 4.5:1 for normal text)
  3. Check contrast throughout the application
    - expect: All text has sufficient contrast against backgrounds
    - expect: Interactive elements are visually distinguishable
    - expect: Error messages and warnings are clearly visible

#### 13.7. Focus Indicators on Interactive Elements

**File:** `tests/steamfitter/ui-responsiveness-and-accessibility/focus-indicators-on-interactive-elements.spec.ts`

**Steps:**
  1. Navigate the application using Tab key
    - expect: Each interactive element receives focus
  2. Observe focus indicators on buttons, links, form fields
    - expect: A visible focus indicator (outline, border, highlight) appears on focused elements
    - expect: The focus indicator is clearly visible and not removed by CSS
    - expect: The indicator helps keyboard users identify their current position

### 14. Integration with Player and StackStorm

**Seed:** `tests/seed.spec.ts`

#### 14.1. Task Execution Uses StackStorm Actions

**File:** `tests/steamfitter/integration-with-player-and-stackstorm/task-execution-uses-stackstorm-actions.spec.ts`

**Steps:**
  1. Create a task with a StackStorm action (e.g., Power On VM)
    - expect: The action dropdown lists available StackStorm actions
    - expect: The selected action is saved with the task
  2. Start a scenario and execute the task
    - expect: The task is sent to StackStorm for execution
    - expect: StackStorm processes the action against the target VM(s)
    - expect: The result returned from StackStorm is displayed in Steamfitter
    - expect: The integration with StackStorm is seamless and transparent to the user

#### 14.2. Player View Association Enables VM Access

**File:** `tests/steamfitter/integration-with-player-and-stackstorm/player-view-association-enables-vm-access.spec.ts`

**Steps:**
  1. Create a scenario and associate it with a Player view
    - expect: The view dropdown shows Player views
    - expect: The selected view is associated with the scenario
  2. View the VMs available for the scenario
    - expect: The scenario has access to the VMs in the associated Player view
    - expect: VM names from the Player view are displayed
    - expect: Tasks can target these VMs using VM masks

#### 14.3. Task Results Reflect VM Command Output

**File:** `tests/steamfitter/integration-with-player-and-stackstorm/task-results-reflect-vm-command-output.spec.ts`

**Steps:**
  1. Execute a task that runs a command on a VM
    - expect: The task executes via StackStorm
  2. View the task result details
    - expect: The result includes the actual output from the VM command
    - expect: The output text shows what the command returned
    - expect: If the expected output was configured, the result indicates whether it matched
    - expect: The integration correctly captures and displays VM command results
