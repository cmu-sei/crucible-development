# Caster Application Comprehensive Test Plan

## Application Overview

Caster is an infrastructure orchestration application within the Crucible cybersecurity training and simulation platform. It provides Terraform-based infrastructure-as-code capabilities, enabling users to manage infrastructure through Directories (templates), Workspaces (isolated environments), Projects (organizational units), and Runs (plan/apply/destroy operations). Caster integrates with other Crucible services, particularly Alloy, to dynamically provision and tear down infrastructure for training exercises.

## Test Scenarios

### 1. Authentication and Authorization

**Seed:** `tests/seed.spec.ts`

#### 1.1. User Login Flow

**File:** `tests/authentication-and-authorization/user-login-flow.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310
    - expect: The application redirects to the Keycloak authentication page at https://localhost:8443/realms/crucible
  2. Enter username 'admin' in the username field
    - expect: The username field accepts input
  3. Enter password 'admin' in the password field
    - expect: The password field accepts input and masks the password
  4. Click the 'Sign In' button
    - expect: The application authenticates successfully
    - expect: The user is redirected back to http://localhost:4310
    - expect: The main application interface loads
    - expect: The topbar displays the username 'admin'

#### 1.2. Unauthorized Access Redirect

**File:** `tests/authentication-and-authorization/unauthorized-access-redirect.spec.ts`

**Steps:**
  1. Clear all browser cookies and local storage
    - expect: All authentication tokens are removed
  2. Navigate to http://localhost:4310/admin
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

#### 1.4. Permission-Based Feature Access

**File:** `tests/authentication-and-authorization/permission-based-feature-access.spec.ts`

**Steps:**
  1. Log in as a user with Content Developer role
    - expect: Successfully authenticated
  2. Navigate to the Projects section
    - expect: Projects list is visible
    - expect: User can view projects they have access to
  3. Attempt to access the Admin section
    - expect: Admin section is not accessible if user lacks System Admin permissions
    - expect: Appropriate access denied message is shown

### 2. Home Page and Navigation

**Seed:** `tests/seed.spec.ts`

#### 2.1. Home Page Initial Load

**File:** `tests/home-page-and-navigation/home-page-initial-load.spec.ts`

**Steps:**
  1. Log in as admin user and navigate to http://localhost:4310
    - expect: The home page loads successfully
    - expect: The topbar is visible with application branding
    - expect: The topbar displays 'Caster' or configured AppTopBarText
    - expect: The user's username is displayed in the topbar
    - expect: The main navigation menu is visible with sections: Projects, Directories, Modules, Pools

#### 2.2. Navigation to Admin Section

**File:** `tests/home-page-and-navigation/navigation-to-admin-section.spec.ts`

**Steps:**
  1. Log in as admin user
    - expect: Successfully authenticated on home page
  2. Navigate to http://localhost:4310/admin
    - expect: The admin interface loads
    - expect: A sidebar navigation menu is visible
    - expect: The sidebar contains sections: Users, Permissions, Host Machines, Projects

#### 2.3. Sidebar Navigation Toggle

**File:** `tests/home-page-and-navigation/sidebar-navigation-toggle.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310
    - expect: Main page loads with sidebar visible
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
  1. Navigate to http://localhost:4310/projects
    - expect: Projects page loads
  2. Click on a specific project
    - expect: Project details page is displayed
    - expect: URL changes to include project ID
  3. Navigate to Directories section
    - expect: Directories page is displayed
    - expect: URL changes accordingly
  4. Click browser back button
    - expect: Application navigates back to project details page
  5. Click browser forward button
    - expect: Application navigates forward to Directories page

### 3. Projects Management

**Seed:** `tests/seed.spec.ts`

#### 3.1. View Projects List

**File:** `tests/projects-management/view-projects-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310/projects
    - expect: Projects page loads successfully
    - expect: Projects list is displayed in a grid or table format
    - expect: Each project shows: name, description, creation date
    - expect: If no projects exist, an appropriate empty state is shown

#### 3.2. Create New Project

**File:** `tests/projects-management/create-new-project.spec.ts`

**Steps:**
  1. Navigate to Projects section
    - expect: Projects list is visible
  2. Click 'Create Project' or 'Add Project' button
    - expect: A project creation dialog is displayed
  3. Enter 'Test Infrastructure Project' in the Name field
    - expect: The name field accepts input
  4. Enter 'This is a test project for infrastructure deployment' in the Description field
    - expect: The description field accepts input
  5. Click 'Save' or 'Create' button
    - expect: The project is created successfully
    - expect: A success notification is displayed
    - expect: The new project appears in the projects list

#### 3.3. Edit Project

**File:** `tests/projects-management/edit-project.spec.ts`

**Steps:**
  1. Navigate to Projects section
    - expect: Projects list is visible with at least one project
  2. Click on an existing project or its edit icon
    - expect: The project edit dialog is displayed
    - expect: Form fields are populated with current values
  3. Modify the Description field to 'Updated description for testing'
    - expect: The description field accepts the new value
  4. Click 'Save' button
    - expect: The project is updated successfully
    - expect: A success notification is displayed
    - expect: The updated values are reflected in the project list

#### 3.4. Delete Project

**File:** `tests/projects-management/delete-project.spec.ts`

**Steps:**
  1. Navigate to Projects section
    - expect: Projects list is visible
  2. Click the delete icon for a specific project
    - expect: A confirmation dialog appears asking to confirm deletion
  3. Click 'Cancel' in the confirmation dialog
    - expect: The dialog closes
    - expect: The project is not deleted
  4. Click the delete icon again
    - expect: Confirmation dialog appears again
  5. Click 'Confirm' or 'Delete' button
    - expect: The project is deleted successfully
    - expect: A success notification is displayed
    - expect: The project is removed from the list
    - expect: If the project has associated workspaces, an appropriate error message is shown preventing deletion

#### 3.5. View Project Details

**File:** `tests/projects-management/view-project-details.spec.ts`

**Steps:**
  1. Navigate to Projects section
    - expect: Projects list is visible
  2. Click on a project name or view button
    - expect: The project detail view is displayed
    - expect: Project properties are shown: name, description, ID
    - expect: Tabs are available for: Workspaces, Directories, Users, Permissions
    - expect: Creation and modification timestamps are displayed

#### 3.6. Search and Filter Projects

**File:** `tests/projects-management/search-and-filter-projects.spec.ts`

**Steps:**
  1. Navigate to Projects section
    - expect: Projects list is visible with multiple projects
  2. Enter a search term in the search box
    - expect: The list filters to show only projects matching the search term
    - expect: Search works on project name and description
    - expect: Results update in real-time or after pressing enter
  3. Clear the search box
    - expect: All projects are displayed again

#### 3.7. Sort Projects

**File:** `tests/projects-management/sort-projects.spec.ts`

**Steps:**
  1. Navigate to Projects section
    - expect: Projects list is visible
  2. Click on the 'Name' column header
    - expect: Projects are sorted alphabetically by name
    - expect: A sort indicator shows the sort direction
  3. Click on the 'Name' column header again
    - expect: Projects are sorted in reverse alphabetical order
    - expect: Sort indicator shows reverse direction
  4. Click on the 'Date Created' column header
    - expect: Projects are sorted by creation date
    - expect: Newest or oldest first depending on initial sort direction

### 4. Directories Management

**Seed:** `tests/seed.spec.ts`

#### 4.1. View Directories List

**File:** `tests/directories-management/view-directories-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310/directories
    - expect: Directories page loads successfully
    - expect: Directories list is displayed
    - expect: Each directory shows: name, description, project name, Terraform version
    - expect: If no directories exist, an appropriate empty state is shown

#### 4.2. Create New Directory

**File:** `tests/directories-management/create-new-directory.spec.ts`

**Steps:**
  1. Navigate to Directories section
    - expect: Directories list is visible
  2. Click 'Create Directory' or 'Add Directory' button
    - expect: A directory creation dialog is displayed
  3. Enter 'Test Infrastructure Directory' in the Name field
    - expect: The name field accepts input
  4. Enter 'This is a test directory containing Terraform configurations' in the Description field
    - expect: The description field accepts input
  5. Select a Project from the dropdown
    - expect: The Project dropdown shows available projects
    - expect: A project can be selected
  6. Select a Terraform Version from the dropdown
    - expect: The Terraform Version dropdown shows available versions
    - expect: A version can be selected
  7. Click 'Save' or 'Create' button
    - expect: The directory is created successfully
    - expect: A success notification is displayed
    - expect: The new directory appears in the directories list

#### 4.3. Edit Directory

**File:** `tests/directories-management/edit-directory.spec.ts`

**Steps:**
  1. Navigate to Directories section
    - expect: Directories list is visible
  2. Click on an existing directory or its edit icon
    - expect: The directory edit dialog is displayed
    - expect: Form fields are populated with current values
  3. Modify the Description field
    - expect: The description field accepts the new value
  4. Change the Terraform Version
    - expect: The version dropdown allows selection of a different version
  5. Click 'Save' button
    - expect: The directory is updated successfully
    - expect: A success notification is displayed
    - expect: The updated values are reflected in the directory list

#### 4.4. Delete Directory

**File:** `tests/directories-management/delete-directory.spec.ts`

**Steps:**
  1. Navigate to Directories section
    - expect: Directories list is visible
  2. Click the delete icon for a specific directory
    - expect: A confirmation dialog appears asking to confirm deletion
  3. Click 'Cancel'
    - expect: The dialog closes
    - expect: The directory is not deleted
  4. Click the delete icon again and confirm
    - expect: The directory is deleted successfully
    - expect: A success notification is displayed
    - expect: The directory is removed from the list
    - expect: If the directory has associated workspaces, an appropriate error message is shown preventing deletion

#### 4.5. View Directory Details and Files

**File:** `tests/directories-management/view-directory-details-and-files.spec.ts`

**Steps:**
  1. Navigate to Directories section
    - expect: Directories list is visible
  2. Click on a directory name or view button
    - expect: The directory detail view is displayed
    - expect: Directory properties are shown: name, description, project, Terraform version
    - expect: A file explorer showing directory structure is visible
    - expect: Terraform files (.tf, .tfvars) are listed

#### 4.6. Upload Files to Directory

**File:** `tests/directories-management/upload-files-to-directory.spec.ts`

**Steps:**
  1. Navigate to a directory's detail view
    - expect: Directory file explorer is visible
  2. Click 'Upload File' or 'Add File' button
    - expect: A file upload dialog is displayed
  3. Select a Terraform file (.tf) from local system
    - expect: The file is selected for upload
  4. Click 'Upload' button
    - expect: The file is uploaded successfully
    - expect: A success notification is displayed
    - expect: The file appears in the directory file list
    - expect: File content can be viewed

#### 4.7. Create New File in Directory

**File:** `tests/directories-management/create-new-file-in-directory.spec.ts`

**Steps:**
  1. Navigate to a directory's detail view
    - expect: Directory file explorer is visible
  2. Click 'New File' or 'Create File' button
    - expect: A file creation dialog is displayed
  3. Enter 'main.tf' as the filename
    - expect: Filename field accepts input
  4. Enter Terraform code in the content editor (e.g., 'resource "null_resource" "example" {}')
    - expect: Code editor accepts Terraform syntax
    - expect: Syntax highlighting is applied
  5. Click 'Save' button
    - expect: The file is created successfully
    - expect: A success notification is displayed
    - expect: The file appears in the directory file list

#### 4.8. Edit File in Directory

**File:** `tests/directories-management/edit-file-in-directory.spec.ts`

**Steps:**
  1. Navigate to a directory's detail view
    - expect: Directory file list is visible
  2. Click on a file to view/edit
    - expect: File content is displayed in an editor
    - expect: Syntax highlighting is applied for Terraform files
  3. Modify the file content
    - expect: Editor allows content modification
    - expect: Changes are tracked
  4. Click 'Save' button
    - expect: The file is saved successfully
    - expect: A success notification is displayed
    - expect: Changes are persisted

#### 4.9. Delete File from Directory

**File:** `tests/directories-management/delete-file-from-directory.spec.ts`

**Steps:**
  1. Navigate to a directory's detail view
    - expect: Directory file list is visible
  2. Select a file and click delete icon
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Delete'
    - expect: The file is deleted successfully
    - expect: A success notification is displayed
    - expect: The file is removed from the list

#### 4.10. Directory Versioning and Cloning

**File:** `tests/directories-management/directory-versioning-and-cloning.spec.ts`

**Steps:**
  1. Navigate to a directory's detail view
    - expect: Directory details are displayed
  2. Click 'Clone' or 'Duplicate' button (if available)
    - expect: A clone dialog appears
    - expect: Fields for new directory name are shown
  3. Enter a new name for the cloned directory
    - expect: Name field accepts input
  4. Click 'Clone' button
    - expect: A new directory is created as a copy
    - expect: The new directory appears in the directories list
    - expect: All files from original directory are copied

### 5. Workspaces Management

**Seed:** `tests/seed.spec.ts`

#### 5.1. View Workspaces List

**File:** `tests/workspaces-management/view-workspaces-list.spec.ts`

**Steps:**
  1. Navigate to a Project detail page
    - expect: Project details are displayed
  2. Click on the 'Workspaces' tab
    - expect: Workspaces list is displayed
    - expect: Each workspace shows: name, directory name, status, last run
    - expect: If no workspaces exist, an appropriate empty state is shown

#### 5.2. Create New Workspace

**File:** `tests/workspaces-management/create-new-workspace.spec.ts`

**Steps:**
  1. Navigate to a Project's Workspaces tab
    - expect: Workspaces list is visible
  2. Click 'Create Workspace' or 'Add Workspace' button
    - expect: A workspace creation dialog is displayed
  3. Enter 'Test Workspace' in the Name field
    - expect: The name field accepts input
  4. Select a Directory from the dropdown
    - expect: The Directory dropdown shows available directories for the project
    - expect: A directory can be selected
  5. Click 'Save' or 'Create' button
    - expect: The workspace is created successfully
    - expect: A success notification is displayed
    - expect: The new workspace appears in the workspaces list
    - expect: Workspace is created with 'Ready' status

#### 5.3. Edit Workspace

**File:** `tests/workspaces-management/edit-workspace.spec.ts`

**Steps:**
  1. Navigate to a Project's Workspaces tab
    - expect: Workspaces list is visible
  2. Click on a workspace or its edit icon
    - expect: The workspace edit dialog is displayed
    - expect: Form fields are populated with current values
  3. Modify the Name field
    - expect: The name field accepts the new value
  4. Click 'Save' button
    - expect: The workspace is updated successfully
    - expect: A success notification is displayed
    - expect: The updated values are reflected in the workspace list

#### 5.4. Delete Workspace

**File:** `tests/workspaces-management/delete-workspace.spec.ts`

**Steps:**
  1. Navigate to a Project's Workspaces tab
    - expect: Workspaces list is visible
  2. Click the delete icon for a specific workspace
    - expect: A confirmation dialog appears
  3. Click 'Cancel'
    - expect: The dialog closes
    - expect: The workspace is not deleted
  4. Click delete icon again and confirm
    - expect: The workspace is deleted successfully
    - expect: A success notification is displayed
    - expect: The workspace is removed from the list
    - expect: If the workspace has active runs, deletion may be prevented with an error message

#### 5.5. View Workspace Details

**File:** `tests/workspaces-management/view-workspace-details.spec.ts`

**Steps:**
  1. Navigate to a Project's Workspaces tab
    - expect: Workspaces list is visible
  2. Click on a workspace name
    - expect: The workspace detail view is displayed
    - expect: Workspace properties are shown: name, directory, status, state
    - expect: Tabs are available for: Runs, Variables, Files, State
    - expect: Current Terraform state information is displayed if available

#### 5.6. View Workspace State

**File:** `tests/workspaces-management/view-workspace-state.spec.ts`

**Steps:**
  1. Navigate to a workspace detail view
    - expect: Workspace details are displayed
  2. Click on the 'State' tab
    - expect: The Terraform state is displayed
    - expect: Resources in the state are listed with their types and names
    - expect: State file details are shown (version, serial, etc.)
    - expect: If no state exists, an appropriate message is displayed

#### 5.7. Lock and Unlock Workspace

**File:** `tests/workspaces-management/lock-and-unlock-workspace.spec.ts`

**Steps:**
  1. Navigate to a workspace detail view
    - expect: Workspace details are displayed
  2. Click 'Lock Workspace' button (if available)
    - expect: The workspace is locked
    - expect: A lock icon or indicator is displayed
    - expect: New runs cannot be created while locked
    - expect: A success notification is displayed
  3. Click 'Unlock Workspace' button
    - expect: The workspace is unlocked
    - expect: Lock indicator is removed
    - expect: Runs can be created again
    - expect: A success notification is displayed

### 6. Runs Management (Plan, Apply, Destroy)

**Seed:** `tests/seed.spec.ts`

#### 6.1. View Runs List

**File:** `tests/runs-management/view-runs-list.spec.ts`

**Steps:**
  1. Navigate to a workspace detail view
    - expect: Workspace details are displayed
  2. Click on the 'Runs' tab
    - expect: Runs list is displayed
    - expect: Each run shows: ID, type (Plan/Apply/Destroy), status, creation time
    - expect: Run statuses include: Queued, Planning, Planned, Applying, Applied, Failed
    - expect: If no runs exist, an appropriate empty state is shown

#### 6.2. Create and Execute Plan Run

**File:** `tests/runs-management/create-and-execute-plan-run.spec.ts`

**Steps:**
  1. Navigate to a workspace's Runs tab
    - expect: Runs list is visible
  2. Click 'Create Run' or 'Plan' button
    - expect: A run creation dialog is displayed
    - expect: Option to select 'Plan' is available
  3. Select 'Plan' as the run type
    - expect: Plan option is selected
  4. Click 'Create' or 'Start' button
    - expect: A new run is created with status 'Queued'
    - expect: The run appears in the runs list
    - expect: Run status transitions to 'Planning'
    - expect: Terraform plan execution begins
  5. Monitor the run status
    - expect: Run status transitions to 'Planned' when complete
    - expect: Plan output is available to view
    - expect: Resources to be created/modified/destroyed are shown

#### 6.3. Create and Execute Apply Run

**File:** `tests/runs-management/create-and-execute-apply-run.spec.ts`

**Steps:**
  1. Navigate to a workspace's Runs tab with a successful Plan
    - expect: Runs list shows a completed Plan run
  2. Click 'Apply' button on the planned run or create a new Apply run
    - expect: A confirmation dialog may appear
    - expect: Apply run is created with status 'Queued'
  3. Confirm the apply operation
    - expect: Run status transitions to 'Applying'
    - expect: Terraform apply execution begins
    - expect: Progress updates are shown
  4. Monitor the run status
    - expect: Run status transitions to 'Applied' when complete
    - expect: Apply output is available to view
    - expect: Resources are created/modified in the target environment
    - expect: Workspace state is updated

#### 6.4. Create and Execute Destroy Run

**File:** `tests/runs-management/create-and-execute-destroy-run.spec.ts`

**Steps:**
  1. Navigate to a workspace's Runs tab
    - expect: Runs list is visible
  2. Click 'Destroy' button
    - expect: A destroy run creation dialog is displayed
    - expect: Warning message about resource destruction is shown
  3. Confirm the destroy operation
    - expect: A destroy run is created
    - expect: Run status is 'Queued' or 'Planning'
    - expect: Destroy plan is generated showing resources to be destroyed
  4. Confirm the destroy apply
    - expect: Run status transitions to 'Applying'
    - expect: Terraform destroy execution begins
    - expect: Resources are destroyed
  5. Monitor the run status
    - expect: Run status transitions to 'Applied' or 'Destroyed' when complete
    - expect: All resources are removed from the target environment
    - expect: Workspace state is updated to reflect empty state

#### 6.5. View Run Details and Output

**File:** `tests/runs-management/view-run-details-and-output.spec.ts`

**Steps:**
  1. Navigate to a workspace's Runs tab
    - expect: Runs list is visible
  2. Click on a run to view its details
    - expect: The run detail view is displayed
    - expect: Run properties are shown: ID, type, status, timestamps
    - expect: Terraform output logs are displayed
    - expect: Plan output shows resources to be changed (if applicable)
    - expect: Apply output shows resources that were changed (if applicable)

#### 6.6. Cancel Running Operation

**File:** `tests/runs-management/cancel-running-operation.spec.ts`

**Steps:**
  1. Create a run that will take time to execute
    - expect: Run is in 'Planning' or 'Applying' status
  2. Click 'Cancel' button on the running operation
    - expect: A confirmation dialog appears
  3. Confirm cancellation
    - expect: The run is cancelled
    - expect: Run status changes to 'Cancelled'
    - expect: Terraform execution is stopped
    - expect: A notification confirms the cancellation

#### 6.7. Run Failure Handling

**File:** `tests/runs-management/run-failure-handling.spec.ts`

**Steps:**
  1. Create a run with invalid Terraform configuration (e.g., syntax error or missing variable)
    - expect: Run is created and begins execution
  2. Monitor the run status
    - expect: Run status transitions to 'Failed'
    - expect: Error message is displayed in the run output
    - expect: Specific error details are shown (e.g., 'variable not defined', 'syntax error')
    - expect: User can view full error log
  3. Click 'Retry' button (if available)
    - expect: Option to retry or create a new run is available
    - expect: User can fix the configuration and retry

#### 6.8. View Run History and Timeline

**File:** `tests/runs-management/view-run-history-and-timeline.spec.ts`

**Steps:**
  1. Navigate to a workspace's Runs tab
    - expect: Runs list shows all historical runs
  2. View the chronological list of runs
    - expect: Runs are sorted by creation time (newest first)
    - expect: Each run shows timestamp, type, and status
    - expect: A visual timeline or history view may be available
  3. Click on an older run to view its details
    - expect: Historical run details are accessible
    - expect: Output and logs from past runs are preserved

### 7. Variables Management

**Seed:** `tests/seed.spec.ts`

#### 7.1. View Workspace Variables

**File:** `tests/variables-management/view-workspace-variables.spec.ts`

**Steps:**
  1. Navigate to a workspace detail view
    - expect: Workspace details are displayed
  2. Click on the 'Variables' tab
    - expect: Variables list is displayed
    - expect: Each variable shows: key, value (masked if sensitive), type
    - expect: Terraform variables and environment variables are shown
    - expect: If no variables exist, an appropriate empty state is shown

#### 7.2. Create New Variable

**File:** `tests/variables-management/create-new-variable.spec.ts`

**Steps:**
  1. Navigate to a workspace's Variables tab
    - expect: Variables list is visible
  2. Click 'Add Variable' or 'Create Variable' button
    - expect: A variable creation dialog is displayed
  3. Enter 'region' in the Key field
    - expect: Key field accepts input
  4. Enter 'us-east-1' in the Value field
    - expect: Value field accepts input
  5. Select 'Terraform Variable' as the type
    - expect: Type selection is available (Terraform Variable or Environment Variable)
  6. Click 'Save' or 'Create' button
    - expect: The variable is created successfully
    - expect: A success notification is displayed
    - expect: The new variable appears in the variables list

#### 7.3. Create Sensitive Variable

**File:** `tests/variables-management/create-sensitive-variable.spec.ts`

**Steps:**
  1. Navigate to a workspace's Variables tab
    - expect: Variables list is visible
  2. Click 'Add Variable' button
    - expect: Variable creation dialog is displayed
  3. Enter 'api_key' in the Key field
    - expect: Key field accepts input
  4. Enter a sensitive value in the Value field
    - expect: Value field accepts input
  5. Check the 'Sensitive' checkbox
    - expect: Sensitive checkbox is checked
    - expect: Value may be masked in the UI
  6. Click 'Save' button
    - expect: The sensitive variable is created
    - expect: Value is masked in the variables list (shown as asterisks or 'sensitive')
    - expect: Variable is marked as sensitive

#### 7.4. Edit Variable

**File:** `tests/variables-management/edit-variable.spec.ts`

**Steps:**
  1. Navigate to a workspace's Variables tab
    - expect: Variables list is visible
  2. Click on a variable or its edit icon
    - expect: Variable edit dialog is displayed
    - expect: Form fields are populated with current values
  3. Modify the Value field
    - expect: Value field accepts the new value
  4. Click 'Save' button
    - expect: The variable is updated successfully
    - expect: A success notification is displayed
    - expect: The updated value is reflected in the variables list

#### 7.5. Delete Variable

**File:** `tests/variables-management/delete-variable.spec.ts`

**Steps:**
  1. Navigate to a workspace's Variables tab
    - expect: Variables list is visible
  2. Click the delete icon for a specific variable
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Delete'
    - expect: The variable is deleted successfully
    - expect: A success notification is displayed
    - expect: The variable is removed from the list

#### 7.6. Variable Validation

**File:** `tests/variables-management/variable-validation.spec.ts`

**Steps:**
  1. Open the variable creation form
    - expect: Form is displayed
  2. Attempt to submit without entering a Key
    - expect: Validation error appears
    - expect: Key field is marked as required
    - expect: Form submission is prevented
  3. Enter a duplicate key that already exists
    - expect: Validation error indicates duplicate key
    - expect: Form submission is prevented
  4. Fill all required fields correctly
    - expect: Validation passes
    - expect: Form can be submitted

#### 7.7. Environment Variables vs Terraform Variables

**File:** `tests/variables-management/environment-vs-terraform-variables.spec.ts`

**Steps:**
  1. Create a Terraform variable
    - expect: Variable is created with type 'Terraform Variable'
  2. Create an Environment variable
    - expect: Variable is created with type 'Environment Variable'
  3. Execute a run
    - expect: Terraform variables are passed as -var flags
    - expect: Environment variables are set in the execution environment
    - expect: Both variable types are correctly applied during run

### 8. Modules Management

**Seed:** `tests/seed.spec.ts`

#### 8.1. View Modules List

**File:** `tests/modules-management/view-modules-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310/modules
    - expect: Modules page loads successfully
    - expect: Modules list is displayed
    - expect: Each module shows: name, description, version
    - expect: If no modules exist, an appropriate empty state is shown

#### 8.2. Create New Module

**File:** `tests/modules-management/create-new-module.spec.ts`

**Steps:**
  1. Navigate to Modules section
    - expect: Modules list is visible
  2. Click 'Create Module' or 'Add Module' button
    - expect: A module creation dialog is displayed
  3. Enter 'Test Module' in the Name field
    - expect: Name field accepts input
  4. Enter module description
    - expect: Description field accepts input
  5. Click 'Save' or 'Create' button
    - expect: The module is created successfully
    - expect: A success notification is displayed
    - expect: The new module appears in the modules list

#### 8.3. View Module Details and Versions

**File:** `tests/modules-management/view-module-details-and-versions.spec.ts`

**Steps:**
  1. Navigate to Modules section
    - expect: Modules list is visible
  2. Click on a module name
    - expect: Module detail view is displayed
    - expect: Module properties are shown: name, description
    - expect: A list of module versions is displayed
    - expect: Each version shows version number and upload date

#### 8.4. Upload Module Version

**File:** `tests/modules-management/upload-module-version.spec.ts`

**Steps:**
  1. Navigate to a module detail view
    - expect: Module details and versions list are visible
  2. Click 'Upload Version' or 'Add Version' button
    - expect: A version upload dialog is displayed
  3. Enter version number (e.g., '1.0.0')
    - expect: Version field accepts input in semantic versioning format
  4. Select a module archive file (.tar.gz or .zip)
    - expect: File selection dialog opens
    - expect: File is selected
  5. Click 'Upload' button
    - expect: Module version is uploaded successfully
    - expect: A success notification is displayed
    - expect: New version appears in the versions list

#### 8.5. Delete Module

**File:** `tests/modules-management/delete-module.spec.ts`

**Steps:**
  1. Navigate to Modules section
    - expect: Modules list is visible
  2. Click delete icon for a specific module
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Delete'
    - expect: The module is deleted successfully
    - expect: A success notification is displayed
    - expect: The module is removed from the list
    - expect: All versions of the module are also deleted

### 9. Designs Management

**Seed:** `tests/seed.spec.ts`

#### 9.1. View Designs List

**File:** `tests/designs-management/view-designs-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310/designs (or admin section)
    - expect: Designs page loads successfully
    - expect: Designs list is displayed
    - expect: Each design shows: name, description
    - expect: If no designs exist, an appropriate empty state is shown

#### 9.2. Create New Design

**File:** `tests/designs-management/create-new-design.spec.ts`

**Steps:**
  1. Navigate to Designs section
    - expect: Designs list is visible
  2. Click 'Create Design' or 'Add Design' button
    - expect: A design creation dialog is displayed
  3. Enter 'Test Design' in the Name field
    - expect: Name field accepts input
  4. Enter design description
    - expect: Description field accepts input
  5. Click 'Save' or 'Create' button
    - expect: The design is created successfully
    - expect: A success notification is displayed
    - expect: The new design appears in the designs list

#### 9.3. Edit Design

**File:** `tests/designs-management/edit-design.spec.ts`

**Steps:**
  1. Navigate to Designs section
    - expect: Designs list is visible
  2. Click on a design or its edit icon
    - expect: Design edit dialog is displayed
    - expect: Form fields are populated with current values
  3. Modify the description
    - expect: Description field accepts new value
  4. Click 'Save' button
    - expect: The design is updated successfully
    - expect: A success notification is displayed
    - expect: Updated values are reflected in the list

#### 9.4. Delete Design

**File:** `tests/designs-management/delete-design.spec.ts`

**Steps:**
  1. Navigate to Designs section
    - expect: Designs list is visible
  2. Click delete icon for a specific design
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Delete'
    - expect: The design is deleted successfully
    - expect: A success notification is displayed
    - expect: The design is removed from the list

### 10. Host Machines Management

**Seed:** `tests/seed.spec.ts`

#### 10.1. View Host Machines List

**File:** `tests/host-machines-management/view-host-machines-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310/admin
    - expect: Admin page loads
  2. Click on 'Host Machines' in the sidebar
    - expect: Host Machines list is displayed
    - expect: Each host shows: name, address, status, max concurrent runs
    - expect: If no hosts exist, an appropriate empty state is shown

#### 10.2. Add New Host Machine

**File:** `tests/host-machines-management/add-new-host-machine.spec.ts`

**Steps:**
  1. Navigate to admin Host Machines section
    - expect: Host Machines list is visible
  2. Click 'Add Host Machine' button
    - expect: A host machine creation dialog is displayed
  3. Enter 'terraform-host-01' in the Name field
    - expect: Name field accepts input
  4. Enter host address or IP
    - expect: Address field accepts input
  5. Set max concurrent runs (e.g., '5')
    - expect: Max runs field accepts numeric input
  6. Click 'Save' or 'Add' button
    - expect: The host machine is added successfully
    - expect: A success notification is displayed
    - expect: The new host appears in the list

#### 10.3. Edit Host Machine

**File:** `tests/host-machines-management/edit-host-machine.spec.ts`

**Steps:**
  1. Navigate to admin Host Machines section
    - expect: Host Machines list is visible
  2. Click on a host machine or its edit icon
    - expect: Host machine edit dialog is displayed
    - expect: Form fields are populated with current values
  3. Modify the max concurrent runs
    - expect: Field accepts new value
  4. Click 'Save' button
    - expect: The host machine is updated successfully
    - expect: A success notification is displayed
    - expect: Updated values are reflected

#### 10.4. Delete Host Machine

**File:** `tests/host-machines-management/delete-host-machine.spec.ts`

**Steps:**
  1. Navigate to admin Host Machines section
    - expect: Host Machines list is visible
  2. Click delete icon for a specific host
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Delete'
    - expect: The host machine is deleted successfully
    - expect: A success notification is displayed
    - expect: The host is removed from the list

### 11. Users and Permissions Management

**Seed:** `tests/seed.spec.ts`

#### 11.1. View Users List

**File:** `tests/users-and-permissions/view-users-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310/admin
    - expect: Admin page loads
  2. Click on 'Users' in the sidebar
    - expect: Users list is displayed
    - expect: Each user shows: username, name, role
    - expect: Pagination controls are visible if there are many users

#### 11.2. Search Users

**File:** `tests/users-and-permissions/search-users.spec.ts`

**Steps:**
  1. Navigate to admin Users section
    - expect: Users list is visible
  2. Enter a search term in the search box
    - expect: The list filters to show only matching users
    - expect: Search works on username and name
  3. Clear the search box
    - expect: All users are displayed again

#### 11.3. View User Details

**File:** `tests/users-and-permissions/view-user-details.spec.ts`

**Steps:**
  1. Navigate to admin Users section
    - expect: Users list is visible
  2. Click on a user name
    - expect: User details page is displayed
    - expect: User information is shown: username, name, email, ID
    - expect: User's permissions and roles are listed

#### 11.4. View Permissions List

**File:** `tests/users-and-permissions/view-permissions-list.spec.ts`

**Steps:**
  1. Navigate to admin section
    - expect: Admin page loads
  2. Click on 'Permissions' in the sidebar
    - expect: Permissions management page is displayed
    - expect: List of all permissions is shown
    - expect: Each permission shows: key, description, users with that permission

#### 11.5. Assign Permission to User

**File:** `tests/users-and-permissions/assign-permission-to-user.spec.ts`

**Steps:**
  1. Navigate to a user's detail page
    - expect: User details and permissions are displayed
  2. Click 'Add Permission' button
    - expect: Permission selection dialog appears
  3. Select a permission from the dropdown
    - expect: Available permissions are listed
    - expect: A permission can be selected
  4. Click 'Add' or 'Save' button
    - expect: The permission is assigned to the user
    - expect: A success notification is displayed
    - expect: The permission appears in the user's permissions list

#### 11.6. Remove Permission from User

**File:** `tests/users-and-permissions/remove-permission-from-user.spec.ts`

**Steps:**
  1. Navigate to a user's permissions section
    - expect: User's permissions are displayed
  2. Click remove icon for a specific permission
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Remove'
    - expect: The permission is removed from the user
    - expect: A success notification is displayed
    - expect: The permission no longer appears in the user's list

#### 11.7. Project-Level User Permissions

**File:** `tests/users-and-permissions/project-level-user-permissions.spec.ts`

**Steps:**
  1. Navigate to a Project detail page
    - expect: Project details are displayed
  2. Click on 'Users' or 'Permissions' tab
    - expect: List of users with access to this project is displayed
    - expect: Each user shows their permissions for this project
  3. Click 'Add User' button
    - expect: User selection dialog appears
  4. Select a user and assign project permissions
    - expect: User is added to project with specified permissions
    - expect: User can now access this project based on permissions

### 12. Pools Management

**Seed:** `tests/seed.spec.ts`

#### 12.1. View Pools List

**File:** `tests/pools-management/view-pools-list.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4310/pools
    - expect: Pools page loads successfully
    - expect: Pools list is displayed
    - expect: Each pool shows: name, description
    - expect: If no pools exist, an appropriate empty state is shown

#### 12.2. Create New Pool

**File:** `tests/pools-management/create-new-pool.spec.ts`

**Steps:**
  1. Navigate to Pools section
    - expect: Pools list is visible
  2. Click 'Create Pool' or 'Add Pool' button
    - expect: A pool creation dialog is displayed
  3. Enter 'Test Pool' in the Name field
    - expect: Name field accepts input
  4. Enter pool description
    - expect: Description field accepts input
  5. Click 'Save' or 'Create' button
    - expect: The pool is created successfully
    - expect: A success notification is displayed
    - expect: The new pool appears in the pools list

#### 12.3. View Pool Details

**File:** `tests/pools-management/view-pool-details.spec.ts`

**Steps:**
  1. Navigate to Pools section
    - expect: Pools list is visible
  2. Click on a pool name
    - expect: Pool detail view is displayed
    - expect: Pool properties are shown: name, description
    - expect: Associated resources or workspaces may be listed

#### 12.4. Delete Pool

**File:** `tests/pools-management/delete-pool.spec.ts`

**Steps:**
  1. Navigate to Pools section
    - expect: Pools list is visible
  2. Click delete icon for a specific pool
    - expect: A confirmation dialog appears
  3. Click 'Confirm' or 'Delete'
    - expect: The pool is deleted successfully
    - expect: A success notification is displayed
    - expect: The pool is removed from the list

### 13. Search and Filtering

**Seed:** `tests/seed.spec.ts`

#### 13.1. Global Search Functionality

**File:** `tests/search-and-filtering/global-search-functionality.spec.ts`

**Steps:**
  1. Locate the global search bar in the topbar
    - expect: Search bar is visible
  2. Enter a search term (e.g., project name or directory name)
    - expect: Search suggestions appear
    - expect: Results show matching projects, directories, workspaces
  3. Select a result from the search suggestions
    - expect: User is navigated to the selected resource detail page

#### 13.2. Filter by Project

**File:** `tests/search-and-filtering/filter-by-project.spec.ts`

**Steps:**
  1. Navigate to Directories or Workspaces section
    - expect: List is displayed
  2. Locate the Project filter dropdown
    - expect: Project filter is available
  3. Select a specific project from the dropdown
    - expect: The list filters to show only items belonging to the selected project
    - expect: Other projects' items are hidden
  4. Clear the filter
    - expect: All items are displayed again

#### 13.3. Filter by Status

**File:** `tests/search-and-filtering/filter-by-status.spec.ts`

**Steps:**
  1. Navigate to Runs list
    - expect: Runs list is displayed with various statuses
  2. Locate the Status filter dropdown
    - expect: Status filter is available
  3. Select 'Applied' status
    - expect: The list filters to show only runs with 'Applied' status
    - expect: Other statuses are hidden
  4. Select 'Failed' status
    - expect: The list filters to show only failed runs
  5. Clear the filter
    - expect: All runs are displayed again

#### 13.4. Advanced Filtering with Multiple Criteria

**File:** `tests/search-and-filtering/advanced-filtering-multiple-criteria.spec.ts`

**Steps:**
  1. Navigate to a list view (e.g., Workspaces)
    - expect: List is displayed
  2. Apply multiple filters (e.g., Project and Status)
    - expect: The list filters to show only items matching all criteria
    - expect: Results are narrowed down by each filter
  3. Clear all filters
    - expect: All items are displayed again

### 14. Real-time Updates and SignalR

**Seed:** `tests/seed.spec.ts`

#### 14.1. Real-time Run Status Updates

**File:** `tests/real-time-updates/real-time-run-status-updates.spec.ts`

**Steps:**
  1. Open two browser windows/tabs, both logged in as admin
    - expect: Both windows are authenticated
  2. In window 1, navigate to a workspace's Runs tab
    - expect: Runs list is displayed in window 1
  3. In window 2, create a new run
    - expect: Run is created in window 2
  4. Observe window 1 without refreshing
    - expect: Window 1 receives real-time update via SignalR
    - expect: Runs list in window 1 updates automatically to show the new run
    - expect: Run status updates are reflected in real-time
    - expect: No manual refresh is required

#### 14.2. Real-time Workspace Updates

**File:** `tests/real-time-updates/real-time-workspace-updates.spec.ts`

**Steps:**
  1. Open two browser windows, both logged in and viewing a project's workspaces
    - expect: Both windows show workspaces list
  2. In window 1, create or edit a workspace
    - expect: Workspace is created or updated in window 1
  3. Observe window 2 without refreshing
    - expect: Window 2 receives real-time update
    - expect: Workspaces list updates automatically in window 2

#### 14.3. SignalR Connection Establishment

**File:** `tests/real-time-updates/signalr-connection-establishment.spec.ts`

**Steps:**
  1. Open browser developer console
    - expect: Console is open
  2. Log in and navigate to main application
    - expect: Application loads
  3. Check console logs for SignalR connection messages
    - expect: Console shows SignalR connection established
    - expect: No connection errors are displayed
    - expect: Relevant hubs are joined successfully

#### 14.4. SignalR Reconnection on Network Interruption

**File:** `tests/real-time-updates/signalr-reconnection-on-network-interruption.spec.ts`

**Steps:**
  1. Log in with SignalR connected
    - expect: SignalR connection is active
  2. Simulate network disconnection (using browser dev tools)
    - expect: Network connection is lost
  3. Restore network connection
    - expect: SignalR automatically attempts to reconnect
    - expect: Console logs show reconnection attempts
    - expect: Real-time updates resume once reconnected

### 15. Error Handling and Validation

**Seed:** `tests/seed.spec.ts`

#### 15.1. API Error Display

**File:** `tests/error-handling/api-error-display.spec.ts`

**Steps:**
  1. Trigger an API error (e.g., try to create a project with invalid data)
    - expect: API returns an error response
  2. Observe the application response
    - expect: An error notification or message is displayed to the user
    - expect: The error message is clear and actionable
    - expect: Form submission is prevented
    - expect: User can correct the error and retry

#### 15.2. Network Error Handling

**File:** `tests/error-handling/network-error-handling.spec.ts`

**Steps:**
  1. Disconnect from network while on application page
    - expect: Network connection is lost
  2. Attempt to perform an action (e.g., create workspace)
    - expect: Application detects network error
    - expect: An appropriate error message is displayed (e.g., 'Network error, please check connection')
    - expect: Action fails gracefully without crashing
  3. Restore network connection
    - expect: Application resumes normal operation
    - expect: User can retry the action

#### 15.3. Required Field Validation

**File:** `tests/error-handling/required-field-validation.spec.ts`

**Steps:**
  1. Open any form with required fields (e.g., create project)
    - expect: Form is displayed
  2. Leave required fields empty and attempt to submit
    - expect: Validation errors are displayed for each required field
    - expect: Error messages clearly indicate which fields are required
    - expect: Form submission is prevented
    - expect: Required fields are visually highlighted

#### 15.4. Terraform Syntax Error Handling

**File:** `tests/error-handling/terraform-syntax-error-handling.spec.ts`

**Steps:**
  1. Create or edit a file in a directory with invalid Terraform syntax
    - expect: File is saved
  2. Create a run for the workspace using this directory
    - expect: Run is created and begins planning
  3. Monitor the run status
    - expect: Run status transitions to 'Failed'
    - expect: Terraform syntax error is displayed in the run output
    - expect: Error message indicates the specific syntax issue
    - expect: Line numbers are shown if available

#### 15.5. Unauthorized Action Handling

**File:** `tests/error-handling/unauthorized-action-handling.spec.ts`

**Steps:**
  1. Log in as a user without System Admin permissions
    - expect: User is authenticated
  2. Attempt to access /admin or perform an admin action
    - expect: Access is denied
    - expect: An appropriate error message is displayed (e.g., 'You do not have permission')
    - expect: User is redirected or action is prevented

#### 15.6. Duplicate Name Validation

**File:** `tests/error-handling/duplicate-name-validation.spec.ts`

**Steps:**
  1. Create a project with a specific name
    - expect: Project is created successfully
  2. Attempt to create another project with the same name
    - expect: Validation error is displayed indicating duplicate name
    - expect: Form submission is prevented
    - expect: User is prompted to choose a different name

#### 15.7. Workspace Lock Enforcement

**File:** `tests/error-handling/workspace-lock-enforcement.spec.ts`

**Steps:**
  1. Lock a workspace
    - expect: Workspace is locked
  2. Attempt to create a new run on the locked workspace
    - expect: An error message is displayed indicating workspace is locked
    - expect: Run creation is prevented
    - expect: User is informed they must unlock the workspace first

### 16. Integration with Alloy

**Seed:** `tests/seed.spec.ts`

#### 16.1. Directory Selection from Alloy

**File:** `tests/integration-alloy/directory-selection-from-alloy.spec.ts`

**Steps:**
  1. Navigate to Alloy application (http://localhost:4403)
    - expect: Alloy application loads
  2. Create or edit an Event Template
    - expect: Event Template form is displayed
  3. Check the Caster Directory dropdown
    - expect: Dropdown is populated with directories from Caster API
    - expect: Directories from all accessible projects are shown
    - expect: Directory names are displayed clearly
  4. Select a Caster Directory
    - expect: Directory is selected
    - expect: Directory ID is stored in the Event Template

#### 16.2. Workspace Creation via Alloy Event Launch

**File:** `tests/integration-alloy/workspace-creation-via-alloy-event-launch.spec.ts`

**Steps:**
  1. In Alloy, create an Event from a template with Caster Directory configured
    - expect: Event is created
  2. Monitor the event status in Alloy
    - expect: Event status changes to 'Planning'
    - expect: Alloy calls Caster API to create a workspace from the configured directory
  3. In Caster, navigate to the project's workspaces
    - expect: A new workspace is created automatically by Alloy
    - expect: Workspace name corresponds to the Alloy event
    - expect: A run is created with status 'Planning'
  4. Monitor the run status
    - expect: Run status transitions to 'Planned' then 'Applying'
    - expect: Infrastructure is provisioned
    - expect: Run status transitions to 'Applied'
    - expect: Event in Alloy transitions to 'Active'

#### 16.3. Workspace Destruction via Alloy Event End

**File:** `tests/integration-alloy/workspace-destruction-via-alloy-event-end.spec.ts`

**Steps:**
  1. In Alloy, end an active event that has a Caster workspace
    - expect: Event status changes to 'Ending'
  2. Monitor the teardown process in Alloy
    - expect: Alloy calls Caster API to destroy the workspace
  3. In Caster, navigate to the workspace's runs
    - expect: A new destroy run is created
    - expect: Destroy run status transitions to 'Planning'
    - expect: Destroy plan shows resources to be destroyed
  4. Monitor the destroy run
    - expect: Run status transitions to 'Applying'
    - expect: Infrastructure resources are destroyed
    - expect: Run status transitions to 'Applied' or 'Destroyed'
    - expect: Event in Alloy transitions to 'Ended'

### 17. Accessibility and Usability

**Seed:** `tests/seed.spec.ts`

#### 17.1. Keyboard Navigation

**File:** `tests/accessibility/keyboard-navigation.spec.ts`

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

#### 17.2. Screen Reader Compatibility

**File:** `tests/accessibility/screen-reader-compatibility.spec.ts`

**Steps:**
  1. Enable a screen reader (e.g., NVDA, JAWS, VoiceOver)
    - expect: Screen reader is active
  2. Navigate through the application
    - expect: Screen reader announces page titles, headings, and landmarks
    - expect: Form labels are properly announced
    - expect: Button purposes are clear
    - expect: Status messages and notifications are announced

#### 17.3. Responsive Layout - Mobile View

**File:** `tests/accessibility/responsive-layout-mobile.spec.ts`

**Steps:**
  1. Resize browser to mobile viewport (e.g., 375x667)
    - expect: Page layout adapts to mobile view
  2. Navigate through the application
    - expect: All content is accessible
    - expect: Navigation menu adapts (e.g., hamburger menu)
    - expect: Forms and tables are usable on small screens
    - expect: No horizontal scrolling is required
    - expect: Touch targets are appropriately sized

#### 17.4. Responsive Layout - Desktop View

**File:** `tests/accessibility/responsive-layout-desktop.spec.ts`

**Steps:**
  1. View application in standard desktop resolution (e.g., 1920x1080)
    - expect: Page layout utilizes desktop space effectively
  2. Resize window to various widths
    - expect: Layout adapts smoothly to different window sizes
    - expect: No content is cut off or inaccessible
    - expect: Sidebar and main content adjust appropriately

#### 17.5. Focus Management in Dialogs

**File:** `tests/accessibility/focus-management-dialogs.spec.ts`

**Steps:**
  1. Open a dialog (e.g., create project)
    - expect: Dialog opens
  2. Check focus behavior
    - expect: Focus is moved to the dialog when it opens
    - expect: Focus is trapped within the dialog (Tab cycles through dialog elements only)
    - expect: Escape key closes the dialog
    - expect: When dialog closes, focus returns to the triggering element

#### 17.6. Loading States and Feedback

**File:** `tests/accessibility/loading-states-feedback.spec.ts`

**Steps:**
  1. Trigger an action that takes time (e.g., create run)
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

### 18. Performance and Optimization

**Seed:** `tests/seed.spec.ts`

#### 18.1. Initial Page Load Time

**File:** `tests/performance/initial-page-load-time.spec.ts`

**Steps:**
  1. Clear browser cache and navigate to http://localhost:4310
    - expect: Application loads from scratch
  2. Measure page load time using browser dev tools (Performance tab)
    - expect: Initial page load completes within acceptable time (e.g., < 3 seconds)
    - expect: Time to First Contentful Paint (FCP) is reasonable
    - expect: Time to Interactive (TTI) is acceptable
    - expect: No unnecessary blocking resources

#### 18.2. Large List Performance

**File:** `tests/performance/large-list-performance.spec.ts`

**Steps:**
  1. Navigate to a section with a large list (e.g., Runs or Files with 100+ items)
    - expect: List page loads
  2. Scroll through the list
    - expect: Scrolling is smooth without jank
    - expect: Virtual scrolling or pagination is used for very large lists
    - expect: Browser remains responsive
  3. Apply filters or search
    - expect: Filtering/searching is responsive
    - expect: Results update quickly
    - expect: UI does not freeze during filtering

#### 18.3. API Call Optimization

**File:** `tests/performance/api-call-optimization.spec.ts`

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

#### 18.4. Long Running Operation Handling

**File:** `tests/performance/long-running-operation-handling.spec.ts`

**Steps:**
  1. Create a run that takes several minutes to complete
    - expect: Run is created and begins execution
  2. Observe the UI during the long-running operation
    - expect: UI remains responsive
    - expect: Status updates are shown periodically
    - expect: User can navigate to other pages while run is in progress
    - expect: Progress indicators show the operation is ongoing
    - expect: Real-time updates continue to work
