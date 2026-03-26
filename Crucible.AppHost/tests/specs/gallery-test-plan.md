# Gallery Application Comprehensive Test Plan

## Application Overview

Gallery is a content management application for the Crucible cybersecurity training and simulation platform. It provides a Wall view for displaying content cards, an Archive for managing articles, and administrative capabilities for managing collections, exhibits, cards, articles, teams, users, and permissions. The application uses role-based access control with SystemAdmin, ContentDeveloper, and authenticated user roles.

## Test Scenarios

### 1. Authentication and Authorization

**Seed:** `tests/seed.spec.ts`

#### 1.1. User Login and Session Management

**File:** `tests/authentication/user-login.spec.ts`

**Steps:**
  1. Navigate to http://localhost:4723
    - expect: The application redirects to Keycloak login page or shows the authenticated home page
  2. If redirected, enter valid credentials and click login
    - expect: User is authenticated and redirected to the Gallery home page
    - expect: User's name appears in the top navigation bar
  3. Verify the home page loads successfully
    - expect: The page title shows 'Gallery' or similar
    - expect: Main navigation elements are visible

#### 1.2. Unauthorized Access Prevention

**File:** `tests/authentication/unauthorized-access.spec.ts`

**Steps:**
  1. Without authentication, attempt to access http://localhost:4723/admin
    - expect: The application redirects to login page or shows access denied message
  2. Without authentication, attempt to access http://localhost:4723/wall
    - expect: The application redirects to login page or shows access denied message
  3. Without authentication, attempt to access http://localhost:4723/archive
    - expect: The application redirects to login page or shows access denied message

#### 1.3. Role-Based Access Control

**File:** `tests/authentication/role-based-access.spec.ts`

**Steps:**
  1. Log in as a regular authenticated user (no admin permissions)
    - expect: User successfully logs in and sees the home page
  2. Navigate to the admin section
    - expect: User is denied access to admin features or admin button is not visible
  3. Log out and log in as a SystemAdmin user
    - expect: User successfully logs in with admin privileges
  4. Navigate to the admin section
    - expect: User has access to admin features including user management, collection/exhibit management

#### 1.4. Session Timeout and Logout

**File:** `tests/authentication/session-logout.spec.ts`

**Steps:**
  1. Log in successfully and note the user's session
    - expect: User is logged in and can access authenticated pages
  2. Click the logout button in the navigation
    - expect: User is logged out
    - expect: User is redirected to login page or public landing page
    - expect: Session is terminated
  3. Attempt to access authenticated pages after logout
    - expect: User is redirected to login page

### 2. Wall View Functionality

**Seed:** `tests/seed.spec.ts`

#### 2.1. Wall Page Display and Navigation

**File:** `tests/wall/wall-display.spec.ts`

**Steps:**
  1. Log in and navigate to http://localhost:4723/wall
    - expect: The Wall page loads successfully
    - expect: The page title shows 'Gallery Wall' or similar
    - expect: Cards are displayed in a grid or list format
  2. Observe the displayed cards on the wall
    - expect: Each card shows relevant information (title, status, date posted)
    - expect: Unread counts are displayed if applicable
    - expect: Cards are sorted appropriately
  3. Click on a card to view its details or articles
    - expect: User is navigated to the appropriate view
    - expect: Card details or articles are displayed

#### 2.2. Wall Card Filtering and Status

**File:** `tests/wall/wall-filtering.spec.ts`

**Steps:**
  1. Navigate to the Wall page
    - expect: Wall page loads with all visible cards
  2. Observe cards with different statuses (e.g., Pending, Entered, Approved, Not Applicable)
    - expect: Each card displays its current status
    - expect: Status indicators are clear and distinguishable
  3. Check for cards marked as 'Not Applicable' (Unused status)
    - expect: These cards display 'Not Applicable' status correctly
  4. Verify unread article counts on cards
    - expect: Cards with unread articles show the correct count
    - expect: Count updates when articles are read

#### 2.3. Wall Real-Time Updates

**File:** `tests/wall/wall-updates.spec.ts`

**Steps:**
  1. Open the Wall page in one browser tab/window
    - expect: Wall page displays current cards
  2. In another tab/window (or as another user), post a new article to a card that appears on the wall
    - expect: The wall view updates to reflect the new article
    - expect: The card's date posted and unread count update accordingly
  3. Mark an article as read
    - expect: The unread count on the wall decreases appropriately

#### 2.4. Wall Navigation to Admin and Archive

**File:** `tests/wall/wall-navigation.spec.ts`

**Steps:**
  1. Navigate to the Wall page
    - expect: Wall page loads successfully
  2. If admin button is visible, click it
    - expect: User is navigated to the admin section
  3. Return to Wall and click on a card to go to its archive
    - expect: User is navigated to the archive view filtered by that card

### 3. Archive Functionality

**Seed:** `tests/seed.spec.ts`

#### 3.1. Archive Page Display and Article List

**File:** `tests/archive/archive-display.spec.ts`

**Steps:**
  1. Log in and navigate to http://localhost:4723/archive
    - expect: The Archive page loads successfully
    - expect: A list of articles is displayed
    - expect: Each article shows title, source type, date posted, and status
  2. Observe the article list structure
    - expect: Articles are displayed in a table or list format
    - expect: Source type icons are visible (e.g., Intel, News, Social, Email, etc.)
    - expect: Pagination controls are present if there are many articles
  3. Check the page size and pagination
    - expect: Default page size is set (e.g., 25 articles per page)
    - expect: Pagination controls allow navigation between pages

#### 3.2. Archive Search and Filter

**File:** `tests/archive/archive-search.spec.ts`

**Steps:**
  1. Navigate to the Archive page
    - expect: Archive page loads with all articles
  2. Locate the search/filter input field
    - expect: A search input field is visible
  3. Enter a search term (e.g., article title keyword)
    - expect: The article list filters to show only matching articles
    - expect: Non-matching articles are hidden
  4. Clear the search term
    - expect: All articles are displayed again
  5. Filter by source type (e.g., select 'Intel' or 'News')
    - expect: Only articles of the selected source type are displayed
  6. Filter by card (select a specific card from dropdown)
    - expect: Only articles belonging to the selected card are displayed

#### 3.3. Archive Sorting

**File:** `tests/archive/archive-sorting.spec.ts`

**Steps:**
  1. Navigate to the Archive page
    - expect: Archive page loads with articles sorted by default (date posted descending)
  2. Click on the 'Date Posted' column header to change sort order
    - expect: Articles are re-sorted in ascending order by date posted
  3. Click on the 'Date Posted' column header again
    - expect: Articles return to descending order by date posted
  4. Click on other sortable columns (e.g., 'Name', 'Source Type', 'Status')
    - expect: Articles are sorted by the selected column
    - expect: Sort indicator (arrow) shows current sort direction

#### 3.4. Archive Article Actions

**File:** `tests/archive/archive-article-actions.spec.ts`

**Steps:**
  1. Navigate to the Archive page
    - expect: Archive page loads with article list
  2. Click on an article to view its full details
    - expect: Article detail view opens
    - expect: Full article content is displayed
  3. Locate the 'More' or actions menu for an article
    - expect: An actions menu (three dots or similar) is visible
  4. Click the actions menu and select 'Edit' (if permissions allow)
    - expect: Article edit dialog opens
    - expect: Article fields are editable
  5. Click the actions menu and select 'Share'
    - expect: Article share dialog opens
    - expect: Options to share with teams or users are available
  6. Click the actions menu and select 'Move' (if applicable)
    - expect: Move dialog opens
    - expect: Options to move article to different card or exhibit are shown

#### 3.5. Archive Pagination and Page Size

**File:** `tests/archive/archive-pagination.spec.ts`

**Steps:**
  1. Navigate to the Archive page with more than 25 articles
    - expect: Only the first 25 articles are displayed (default page size)
    - expect: Pagination controls show page 1 of N
  2. Click the 'Next Page' button
    - expect: The next 25 articles are displayed
    - expect: Page indicator updates to page 2
  3. Click the 'Previous Page' button
    - expect: The first 25 articles are displayed again
    - expect: Page indicator returns to page 1
  4. Change the page size selector (e.g., to 50 or 100)
    - expect: The article list updates to show the new page size
    - expect: Pagination controls adjust accordingly

### 4. Article Management

**Seed:** `tests/seed.spec.ts`

#### 4.1. View Article Details

**File:** `tests/articles/view-article.spec.ts`

**Steps:**
  1. Navigate to an exhibit and article URL: http://localhost:4723/exhibit/{exhibitId}/article/{articleId}
    - expect: The article detail page loads successfully
    - expect: Article title, content, source type, and metadata are displayed
  2. Scroll through the article content
    - expect: The full article content is readable
    - expect: Any embedded media (images, links) are functional
  3. Check the article's status and date posted
    - expect: Status is clearly displayed (e.g., Pending, Entered, Approved)
    - expect: Date posted is visible and formatted correctly

#### 4.2. Create New Article

**File:** `tests/articles/create-article.spec.ts`

**Steps:**
  1. Navigate to the Archive or admin section
    - expect: User has access to article creation functionality
  2. Click the 'Create Article' or 'Add Article' button
    - expect: Article creation dialog or form opens
    - expect: Required fields are indicated (Name, Description, Source Type, Card)
  3. Fill in the article name field
    - expect: Text is entered successfully
  4. Fill in the article description/content using the rich text editor
    - expect: Rich text editor allows text formatting
    - expect: Content is entered successfully
  5. Select a source type from the dropdown (e.g., Intel, News, Social, Email, etc.)
    - expect: Source type is selected
  6. Select a card to associate with the article
    - expect: Card dropdown shows available cards
    - expect: Card is selected
  7. Select a date posted (or use default current date)
    - expect: Date picker allows date selection
    - expect: Date is set
  8. Click 'Save' or 'Create' button
    - expect: Article is created successfully
    - expect: Success message appears
    - expect: User is returned to article list or detail view
    - expect: New article appears in the list

#### 4.3. Edit Existing Article

**File:** `tests/articles/edit-article.spec.ts`

**Steps:**
  1. Navigate to the Archive page or admin articles section
    - expect: Article list is displayed
  2. Select an article and open its actions menu
    - expect: Actions menu opens
  3. Click 'Edit' option
    - expect: Article edit dialog opens
    - expect: Current article data is pre-populated in the form
  4. Modify the article name
    - expect: Name field is editable and accepts changes
  5. Modify the article description/content
    - expect: Rich text editor allows content modification
  6. Change the source type
    - expect: Source type dropdown allows selection of a different type
  7. Change the status (e.g., from Pending to Approved)
    - expect: Status dropdown allows selection
  8. Click 'Save' button
    - expect: Article is updated successfully
    - expect: Success message appears
    - expect: Changes are reflected in the article list and detail view

#### 4.4. Delete Article

**File:** `tests/articles/delete-article.spec.ts`

**Steps:**
  1. Navigate to the admin articles section
    - expect: Article list is displayed with admin controls
  2. Select an article and open its actions menu
    - expect: Actions menu opens with delete option
  3. Click 'Delete' option
    - expect: Confirmation dialog appears asking to confirm deletion
  4. Click 'Cancel' in the confirmation dialog
    - expect: Dialog closes
    - expect: Article is not deleted and remains in the list
  5. Open delete dialog again and click 'Confirm' or 'Delete'
    - expect: Article is deleted successfully
    - expect: Success message appears
    - expect: Article is removed from the list
  6. Attempt to access the deleted article directly via URL
    - expect: Error message or 404 page is shown
    - expect: Article is not accessible

#### 4.5. Article Validation and Error Handling

**File:** `tests/articles/article-validation.spec.ts`

**Steps:**
  1. Open the article creation form
    - expect: Form is displayed with empty fields
  2. Attempt to submit the form without filling required fields
    - expect: Validation errors appear
    - expect: Required field indicators are shown
    - expect: Form is not submitted
  3. Fill only the name field and attempt to submit
    - expect: Validation errors appear for other required fields
    - expect: Form is not submitted
  4. Enter invalid data (e.g., excessively long name, invalid characters)
    - expect: Validation error appears
    - expect: Helpful error message is displayed
  5. Fill all required fields correctly and submit
    - expect: Article is created successfully without errors

#### 4.6. Article Status Workflow

**File:** `tests/articles/article-status.spec.ts`

**Steps:**
  1. Create a new article with status 'Pending'
    - expect: Article is created with Pending status
  2. Edit the article and change status to 'Entered'
    - expect: Status is updated to Entered
    - expect: Status change is reflected immediately
  3. Edit the article and change status to 'Approved'
    - expect: Status is updated to Approved
    - expect: Status change is reflected in all views
  4. Verify status transitions are logged or tracked (if applicable)
    - expect: Status history or audit log shows changes

#### 4.7. Article Sharing with Teams

**File:** `tests/articles/article-sharing.spec.ts`

**Steps:**
  1. Navigate to an article in the Archive
    - expect: Article is displayed
  2. Open the article's actions menu and select 'Share'
    - expect: Share dialog opens
    - expect: Team selector is available
  3. Select one or more teams to share the article with
    - expect: Teams are selectable via checkboxes or dropdown
  4. Click 'Share' or 'Save' button
    - expect: Article is shared with selected teams
    - expect: Success message appears
  5. Log in as a user belonging to one of the shared teams
    - expect: User can see the shared article in their view
  6. Log in as a user not in the shared teams
    - expect: User cannot see the shared article

#### 4.8. Article Move Between Cards or Exhibits

**File:** `tests/articles/article-move.spec.ts`

**Steps:**
  1. Navigate to the Archive and select an article
    - expect: Article is displayed
  2. Open the article's actions menu and select 'Move'
    - expect: Move dialog opens
    - expect: Options to select new card or exhibit are available
  3. Select a different card from the dropdown
    - expect: New card is selectable
  4. Click 'Move' or 'Save' button
    - expect: Article is moved to the new card
    - expect: Success message appears
    - expect: Article appears under the new card in the archive
  5. Verify the article no longer appears under the old card
    - expect: Article is not listed under the old card

### 5. Collection Management

**Seed:** `tests/seed.spec.ts`

#### 5.1. View Collections List

**File:** `tests/collections/view-collections.spec.ts`

**Steps:**
  1. Log in as SystemAdmin or ContentDeveloper
    - expect: User is authenticated with appropriate permissions
  2. Navigate to the admin section and select 'Collections'
    - expect: Collections list page loads
    - expect: All collections are displayed in a table or list
  3. Observe collection details (name, description, dates)
    - expect: Each collection shows relevant metadata
    - expect: Collections are sortable by columns

#### 5.2. Create New Collection

**File:** `tests/collections/create-collection.spec.ts`

**Steps:**
  1. Navigate to the admin Collections page
    - expect: Collections list is displayed
  2. Click 'Create Collection' or 'Add Collection' button
    - expect: Collection creation dialog opens
    - expect: Form fields are displayed (Name, Description, etc.)
  3. Enter a collection name
    - expect: Name is entered successfully
  4. Enter a collection description
    - expect: Description is entered successfully
  5. Set additional properties (e.g., dates, visibility)
    - expect: Properties are configurable
  6. Click 'Save' or 'Create' button
    - expect: Collection is created successfully
    - expect: Success message appears
    - expect: New collection appears in the list

#### 5.3. Edit Existing Collection

**File:** `tests/collections/edit-collection.spec.ts`

**Steps:**
  1. Navigate to the admin Collections page
    - expect: Collections list is displayed
  2. Select a collection and click 'Edit' or open its edit dialog
    - expect: Collection edit dialog opens
    - expect: Current collection data is pre-populated
  3. Modify the collection name
    - expect: Name field is editable
  4. Modify the collection description
    - expect: Description field is editable
  5. Update other properties as needed
    - expect: Properties are modifiable
  6. Click 'Save' button
    - expect: Collection is updated successfully
    - expect: Success message appears
    - expect: Changes are reflected in the collection list

#### 5.4. Delete Collection

**File:** `tests/collections/delete-collection.spec.ts`

**Steps:**
  1. Navigate to the admin Collections page
    - expect: Collections list is displayed
  2. Select a collection and click 'Delete' button or option
    - expect: Confirmation dialog appears
  3. Click 'Cancel' in the confirmation dialog
    - expect: Dialog closes
    - expect: Collection is not deleted
  4. Click 'Delete' again and confirm
    - expect: Collection is deleted successfully
    - expect: Success message appears
    - expect: Collection is removed from the list
  5. Verify that deleting a collection with associated exhibits is handled appropriately
    - expect: Warning message appears if exhibits exist
    - expect: User is informed about dependencies

#### 5.5. Collection Permissions and Roles

**File:** `tests/collections/collection-permissions.spec.ts`

**Steps:**
  1. Navigate to a collection's details or edit page
    - expect: Collection details are displayed
  2. Navigate to the 'Permissions' or 'Roles' tab/section
    - expect: Permissions management interface is displayed
  3. Add a user or team to the collection with a specific role
    - expect: Role assignment interface allows selection
    - expect: User/team is added successfully
  4. Verify the added user has the correct permissions
    - expect: User can access collection based on assigned role
  5. Remove the user or team from the collection
    - expect: User/team is removed successfully
    - expect: Permissions are revoked

#### 5.6. Collection Membership Management

**File:** `tests/collections/collection-memberships.spec.ts`

**Steps:**
  1. Navigate to a collection's edit page
    - expect: Collection edit interface is displayed
  2. Navigate to the 'Members' or 'Memberships' section
    - expect: List of members (users or teams) is displayed
  3. Click 'Add Member' button
    - expect: Member selection dialog opens
  4. Select a user or team to add as a member
    - expect: User/team is selectable
  5. Assign a role to the member (e.g., Viewer, Editor, Admin)
    - expect: Role dropdown is available and functional
  6. Click 'Add' or 'Save' button
    - expect: Member is added successfully
    - expect: Member appears in the membership list with assigned role
  7. Remove a member from the collection
    - expect: Member is removed successfully
    - expect: Member no longer has access to the collection

### 6. Exhibit Management

**Seed:** `tests/seed.spec.ts`

#### 6.1. View Exhibits List

**File:** `tests/exhibits/view-exhibits.spec.ts`

**Steps:**
  1. Log in as SystemAdmin or ContentDeveloper
    - expect: User is authenticated with appropriate permissions
  2. Navigate to the admin section and select 'Exhibits'
    - expect: Exhibits list page loads
    - expect: All exhibits are displayed with collection associations
  3. Observe exhibit details (name, description, collection, scenario)
    - expect: Each exhibit shows relevant metadata

#### 6.2. Create New Exhibit

**File:** `tests/exhibits/create-exhibit.spec.ts`

**Steps:**
  1. Navigate to the admin Exhibits page
    - expect: Exhibits list is displayed
  2. Click 'Create Exhibit' or 'Add Exhibit' button
    - expect: Exhibit creation dialog opens
  3. Enter an exhibit name
    - expect: Name is entered successfully
  4. Enter an exhibit description
    - expect: Description is entered successfully
  5. Select a collection to associate the exhibit with
    - expect: Collection dropdown shows available collections
    - expect: Collection is selected
  6. Set scenario ID or other properties (if applicable)
    - expect: Properties are configurable
  7. Click 'Save' or 'Create' button
    - expect: Exhibit is created successfully
    - expect: Success message appears
    - expect: New exhibit appears in the list

#### 6.3. Edit Existing Exhibit

**File:** `tests/exhibits/edit-exhibit.spec.ts`

**Steps:**
  1. Navigate to the admin Exhibits page
    - expect: Exhibits list is displayed
  2. Select an exhibit and click 'Edit' or open its edit dialog
    - expect: Exhibit edit dialog opens
    - expect: Current exhibit data is pre-populated
  3. Modify the exhibit name
    - expect: Name field is editable
  4. Modify the exhibit description
    - expect: Description field is editable
  5. Change the associated collection
    - expect: Collection dropdown allows selection change
  6. Click 'Save' button
    - expect: Exhibit is updated successfully
    - expect: Success message appears
    - expect: Changes are reflected in the exhibit list

#### 6.4. Delete Exhibit

**File:** `tests/exhibits/delete-exhibit.spec.ts`

**Steps:**
  1. Navigate to the admin Exhibits page
    - expect: Exhibits list is displayed
  2. Select an exhibit and click 'Delete' button or option
    - expect: Confirmation dialog appears
  3. Click 'Cancel' in the confirmation dialog
    - expect: Dialog closes
    - expect: Exhibit is not deleted
  4. Click 'Delete' again and confirm
    - expect: Exhibit is deleted successfully
    - expect: Success message appears
    - expect: Exhibit is removed from the list
  5. Verify that deleting an exhibit with associated cards/articles is handled appropriately
    - expect: Warning message appears if dependencies exist
    - expect: User is informed about cascading effects

#### 6.5. Exhibit Article Management

**File:** `tests/exhibits/exhibit-articles.spec.ts`

**Steps:**
  1. Navigate to an exhibit's edit page in the admin section
    - expect: Exhibit edit interface is displayed
  2. Navigate to the 'Articles' tab or section
    - expect: List of articles associated with the exhibit is displayed
  3. Observe article details within the exhibit context
    - expect: Articles show name, card, status, and other metadata
  4. Add a new article to the exhibit
    - expect: Article creation dialog opens within exhibit context
    - expect: Article is created and associated with exhibit

#### 6.6. Exhibit Team Management

**File:** `tests/exhibits/exhibit-teams.spec.ts`

**Steps:**
  1. Navigate to an exhibit's edit page in the admin section
    - expect: Exhibit edit interface is displayed
  2. Navigate to the 'Teams' tab or section
    - expect: List of teams associated with the exhibit is displayed
  3. Click 'Add Team' button
    - expect: Team selection dialog opens
  4. Select a team to add to the exhibit
    - expect: Team is selectable
  5. Click 'Add' or 'Save' button
    - expect: Team is added to the exhibit
    - expect: Team appears in the exhibit teams list
  6. Remove a team from the exhibit
    - expect: Team is removed successfully

#### 6.7. Exhibit Permissions and Roles

**File:** `tests/exhibits/exhibit-permissions.spec.ts`

**Steps:**
  1. Navigate to an exhibit's edit page
    - expect: Exhibit edit interface is displayed
  2. Navigate to the 'Permissions' or 'Roles' section
    - expect: Permissions management interface is displayed
  3. Add a user to the exhibit with a specific role
    - expect: User is added with assigned role
  4. Verify the user has correct permissions for the exhibit
    - expect: User can access exhibit based on role
  5. Remove the user's role
    - expect: User's permissions are revoked

#### 6.8. Exhibit Membership Management

**File:** `tests/exhibits/exhibit-memberships.spec.ts`

**Steps:**
  1. Navigate to an exhibit's edit page
    - expect: Exhibit edit interface is displayed
  2. Navigate to the 'Members' or 'Memberships' section
    - expect: List of members is displayed
  3. Add a new member to the exhibit
    - expect: Member selection dialog opens
    - expect: User or team is added as member
  4. Assign a role to the member
    - expect: Role is assigned successfully
  5. Remove a member from the exhibit
    - expect: Member is removed successfully

### 7. Card Management

**Seed:** `tests/seed.spec.ts`

#### 7.1. View Cards List

**File:** `tests/cards/view-cards.spec.ts`

**Steps:**
  1. Log in as SystemAdmin or ContentDeveloper
    - expect: User is authenticated
  2. Navigate to the admin section and select 'Cards'
    - expect: Cards list page loads
    - expect: All cards are displayed
  3. Observe card details (name, description, exhibit, collection)
    - expect: Each card shows relevant metadata

#### 7.2. Create New Card

**File:** `tests/cards/create-card.spec.ts`

**Steps:**
  1. Navigate to the admin Cards page
    - expect: Cards list is displayed
  2. Click 'Create Card' or 'Add Card' button
    - expect: Card creation dialog opens
  3. Enter a card name
    - expect: Name is entered successfully
  4. Enter a card description
    - expect: Description is entered successfully
  5. Select an exhibit to associate the card with
    - expect: Exhibit dropdown shows available exhibits
    - expect: Exhibit is selected
  6. Set additional properties (e.g., move number, inject number, gallery URL)
    - expect: Properties are configurable
  7. Click 'Save' or 'Create' button
    - expect: Card is created successfully
    - expect: Success message appears
    - expect: New card appears in the list

#### 7.3. Edit Existing Card

**File:** `tests/cards/edit-card.spec.ts`

**Steps:**
  1. Navigate to the admin Cards page
    - expect: Cards list is displayed
  2. Select a card and click 'Edit' or open its edit dialog
    - expect: Card edit dialog opens
    - expect: Current card data is pre-populated
  3. Modify the card name
    - expect: Name field is editable
  4. Modify the card description
    - expect: Description field is editable
  5. Change the associated exhibit
    - expect: Exhibit dropdown allows selection change
  6. Click 'Save' button
    - expect: Card is updated successfully
    - expect: Success message appears
    - expect: Changes are reflected in the card list

#### 7.4. Delete Card

**File:** `tests/cards/delete-card.spec.ts`

**Steps:**
  1. Navigate to the admin Cards page
    - expect: Cards list is displayed
  2. Select a card and click 'Delete' button or option
    - expect: Confirmation dialog appears
  3. Click 'Cancel' in the confirmation dialog
    - expect: Dialog closes
    - expect: Card is not deleted
  4. Click 'Delete' again and confirm
    - expect: Card is deleted successfully
    - expect: Success message appears
    - expect: Card is removed from the list
  5. Verify that deleting a card with associated articles is handled appropriately
    - expect: Warning message appears if articles exist
    - expect: User is informed about dependencies

#### 7.5. Card Validation

**File:** `tests/cards/card-validation.spec.ts`

**Steps:**
  1. Open the card creation form
    - expect: Form is displayed
  2. Attempt to submit without filling required fields
    - expect: Validation errors appear
    - expect: Form is not submitted
  3. Enter invalid data (e.g., excessively long name)
    - expect: Validation error appears with helpful message
  4. Fill all required fields correctly and submit
    - expect: Card is created successfully

### 8. Team Management

**Seed:** `tests/seed.spec.ts`

#### 8.1. View Teams List

**File:** `tests/teams/view-teams.spec.ts`

**Steps:**
  1. Log in as SystemAdmin
    - expect: User is authenticated
  2. Navigate to the admin section and select 'Teams'
    - expect: Teams list page loads
    - expect: All teams are displayed
  3. Observe team details (name, exhibit, users)
    - expect: Each team shows relevant metadata

#### 8.2. Create New Team

**File:** `tests/teams/create-team.spec.ts`

**Steps:**
  1. Navigate to the admin Teams page
    - expect: Teams list is displayed
  2. Click 'Create Team' or 'Add Team' button
    - expect: Team creation dialog opens
  3. Enter a team name
    - expect: Name is entered successfully
  4. Select an exhibit to associate the team with
    - expect: Exhibit dropdown shows available exhibits
    - expect: Exhibit is selected
  5. Click 'Save' or 'Create' button
    - expect: Team is created successfully
    - expect: Success message appears
    - expect: New team appears in the list

#### 8.3. Edit Existing Team

**File:** `tests/teams/edit-team.spec.ts`

**Steps:**
  1. Navigate to the admin Teams page
    - expect: Teams list is displayed
  2. Select a team and click 'Edit' or open its edit dialog
    - expect: Team edit dialog opens
    - expect: Current team data is pre-populated
  3. Modify the team name
    - expect: Name field is editable
  4. Change the associated exhibit
    - expect: Exhibit dropdown allows selection change
  5. Click 'Save' button
    - expect: Team is updated successfully
    - expect: Success message appears
    - expect: Changes are reflected in the team list

#### 8.4. Delete Team

**File:** `tests/teams/delete-team.spec.ts`

**Steps:**
  1. Navigate to the admin Teams page
    - expect: Teams list is displayed
  2. Select a team and click 'Delete' button or option
    - expect: Confirmation dialog appears
  3. Click 'Cancel' in the confirmation dialog
    - expect: Dialog closes
    - expect: Team is not deleted
  4. Click 'Delete' again and confirm
    - expect: Team is deleted successfully
    - expect: Success message appears
    - expect: Team is removed from the list

#### 8.5. Team User Management

**File:** `tests/teams/team-users.spec.ts`

**Steps:**
  1. Navigate to a team's edit page in the admin section
    - expect: Team edit interface is displayed
  2. Navigate to the 'Users' or 'Members' section
    - expect: List of team users is displayed
  3. Click 'Add User' button
    - expect: User selection dialog opens
  4. Select a user to add to the team
    - expect: User is selectable
  5. Click 'Add' or 'Save' button
    - expect: User is added to the team
    - expect: User appears in the team users list
  6. Remove a user from the team
    - expect: User is removed successfully

#### 8.6. Team Card Management

**File:** `tests/teams/team-cards.spec.ts`

**Steps:**
  1. Navigate to a team's edit page in the admin section
    - expect: Team edit interface is displayed
  2. Navigate to the 'Cards' section
    - expect: List of team cards is displayed
  3. Add a card to the team
    - expect: Card selection dialog opens
    - expect: Card is added to team
  4. Toggle 'Show on Wall' setting for a team card
    - expect: Setting is toggled
    - expect: Card visibility on wall changes accordingly
  5. Remove a card from the team
    - expect: Card is removed successfully

#### 8.7. Team Selector Component

**File:** `tests/teams/team-selector.spec.ts`

**Steps:**
  1. Navigate to a page with team selection functionality (e.g., Wall or Archive)
    - expect: Team selector dropdown is visible
  2. Click the team selector dropdown
    - expect: List of available teams is displayed
  3. Select a different team from the dropdown
    - expect: Selected team changes
    - expect: Page content updates to reflect the selected team's data
  4. Verify that the selected team persists across page navigation
    - expect: Selected team remains active when navigating between pages

### 9. User Management

**Seed:** `tests/seed.spec.ts`

#### 9.1. View Users List

**File:** `tests/users/view-users.spec.ts`

**Steps:**
  1. Log in as SystemAdmin
    - expect: User is authenticated
  2. Navigate to the admin section and select 'Users'
    - expect: Users list page loads
    - expect: All users are displayed
  3. Observe user details (name, username, email, roles)
    - expect: Each user shows relevant metadata

#### 9.2. Create New User

**File:** `tests/users/create-user.spec.ts`

**Steps:**
  1. Navigate to the admin Users page
    - expect: Users list is displayed
  2. Click 'Create User' or 'Add User' button
    - expect: User creation dialog opens
  3. Enter user name
    - expect: Name is entered successfully
  4. Enter username (unique identifier)
    - expect: Username is entered successfully
  5. Enter email address
    - expect: Email is entered successfully
  6. Assign system roles (e.g., SystemAdmin, ContentDeveloper)
    - expect: Roles are selectable via checkboxes or dropdown
  7. Click 'Save' or 'Create' button
    - expect: User is created successfully
    - expect: Success message appears
    - expect: New user appears in the list

#### 9.3. Edit Existing User

**File:** `tests/users/edit-user.spec.ts`

**Steps:**
  1. Navigate to the admin Users page
    - expect: Users list is displayed
  2. Select a user and click 'Edit' or open its edit dialog
    - expect: User edit dialog opens
    - expect: Current user data is pre-populated
  3. Modify the user name
    - expect: Name field is editable
  4. Modify the email address
    - expect: Email field is editable
  5. Change assigned system roles
    - expect: Roles can be added or removed
  6. Click 'Save' button
    - expect: User is updated successfully
    - expect: Success message appears
    - expect: Changes are reflected in the user list

#### 9.4. Delete User

**File:** `tests/users/delete-user.spec.ts`

**Steps:**
  1. Navigate to the admin Users page
    - expect: Users list is displayed
  2. Select a user and click 'Delete' button or option
    - expect: Confirmation dialog appears
  3. Click 'Cancel' in the confirmation dialog
    - expect: Dialog closes
    - expect: User is not deleted
  4. Click 'Delete' again and confirm
    - expect: User is deleted successfully
    - expect: Success message appears
    - expect: User is removed from the list

#### 9.5. User Search and Filter

**File:** `tests/users/user-search.spec.ts`

**Steps:**
  1. Navigate to the admin Users page
    - expect: Users list is displayed
  2. Locate the search/filter input field
    - expect: Search input is visible
  3. Enter a search term (e.g., username or name)
    - expect: User list filters to show only matching users
  4. Clear the search term
    - expect: All users are displayed again

#### 9.6. User Validation

**File:** `tests/users/user-validation.spec.ts`

**Steps:**
  1. Open the user creation form
    - expect: Form is displayed
  2. Attempt to submit without filling required fields
    - expect: Validation errors appear
    - expect: Form is not submitted
  3. Enter an invalid email address
    - expect: Email validation error appears
  4. Enter a duplicate username (if uniqueness is enforced)
    - expect: Validation error appears indicating username already exists
  5. Fill all fields correctly and submit
    - expect: User is created successfully

### 10. Group Management

**Seed:** `tests/seed.spec.ts`

#### 10.1. View Groups List

**File:** `tests/groups/view-groups.spec.ts`

**Steps:**
  1. Log in as SystemAdmin
    - expect: User is authenticated
  2. Navigate to the admin section and select 'Groups'
    - expect: Groups list page loads
    - expect: All groups are displayed
  3. Observe group details (name, description, members)
    - expect: Each group shows relevant metadata

#### 10.2. Group Detail and Members

**File:** `tests/groups/group-details.spec.ts`

**Steps:**
  1. Navigate to the admin Groups page
    - expect: Groups list is displayed
  2. Click on a group to view its details
    - expect: Group detail page opens
    - expect: Group name and description are displayed
  3. Navigate to the 'Members' section
    - expect: List of group members is displayed
  4. Add a new member to the group
    - expect: Member selection dialog opens
    - expect: Member is added successfully
  5. Remove a member from the group
    - expect: Member is removed successfully

#### 10.3. Group Membership Management

**File:** `tests/groups/group-memberships.spec.ts`

**Steps:**
  1. Navigate to a group's detail page
    - expect: Group details are displayed
  2. Navigate to the 'Memberships' section (collections/exhibits the group belongs to)
    - expect: List of memberships is displayed
  3. Add the group to a collection or exhibit
    - expect: Membership is added successfully
  4. Remove the group from a collection or exhibit
    - expect: Membership is removed successfully

### 11. Role and Permission Management

**Seed:** `tests/seed.spec.ts`

#### 11.1. System Roles Management

**File:** `tests/roles/system-roles.spec.ts`

**Steps:**
  1. Log in as SystemAdmin
    - expect: User is authenticated
  2. Navigate to the admin section and select 'Roles' or 'Permissions'
    - expect: Roles management page loads
  3. Navigate to the 'System Roles' tab
    - expect: List of system roles is displayed (e.g., SystemAdmin, ContentDeveloper)
  4. Assign a system role to a user
    - expect: User is assigned the role successfully
  5. Remove a system role from a user
    - expect: Role is removed successfully

#### 11.2. Collection Roles Management

**File:** `tests/roles/collection-roles.spec.ts`

**Steps:**
  1. Navigate to the admin Roles page
    - expect: Roles management page is displayed
  2. Navigate to the 'Collection Roles' tab
    - expect: List of collection-specific roles is displayed
  3. Assign a collection role to a user
    - expect: User is assigned the role for the specified collection
  4. Remove a collection role from a user
    - expect: Role is removed successfully
  5. Verify that user permissions are updated based on collection role
    - expect: User has appropriate access to the collection

#### 11.3. Exhibit Roles Management

**File:** `tests/roles/exhibit-roles.spec.ts`

**Steps:**
  1. Navigate to the admin Roles page
    - expect: Roles management page is displayed
  2. Navigate to the 'Exhibit Roles' tab
    - expect: List of exhibit-specific roles is displayed
  3. Assign an exhibit role to a user
    - expect: User is assigned the role for the specified exhibit
  4. Remove an exhibit role from a user
    - expect: Role is removed successfully
  5. Verify that user permissions are updated based on exhibit role
    - expect: User has appropriate access to the exhibit

#### 11.4. Permission Verification

**File:** `tests/roles/permission-verification.spec.ts`

**Steps:**
  1. Log in as a user with only 'ContentDeveloper' permission
    - expect: User is authenticated
  2. Navigate to the admin section
    - expect: User has access to collection and exhibit create/delete operations
  3. Attempt to access user administration
    - expect: User is denied access to user admin features
  4. Log out and log in as 'SystemAdmin'
    - expect: User is authenticated with full admin access
  5. Verify access to all admin features including user admin
    - expect: User can access user management, collections, exhibits, and all other admin features

### 12. User Interface and Navigation

**Seed:** `tests/seed.spec.ts`

#### 12.1. Top Navigation Bar

**File:** `tests/ui/top-navigation.spec.ts`

**Steps:**
  1. Log in and navigate to any authenticated page
    - expect: Top navigation bar is visible
    - expect: Application title is displayed
    - expect: User's name or profile icon is visible
  2. Click on the user's name or profile icon
    - expect: User menu drops down showing options like 'Logout', 'Profile', etc.
  3. Click the application title or home link
    - expect: User is navigated to the home page
  4. Verify navigation links are present (e.g., Wall, Archive, Admin)
    - expect: Navigation links are visible and functional

#### 12.2. Responsive Design and Mobile View

**File:** `tests/ui/responsive-design.spec.ts`

**Steps:**
  1. Resize the browser window to mobile dimensions (e.g., 375x667)
    - expect: Application layout adjusts to mobile view
    - expect: Navigation may collapse into a hamburger menu
  2. Verify that all functionality is accessible on mobile
    - expect: Forms, buttons, and interactive elements are usable
    - expect: Text is readable without horizontal scrolling
  3. Test navigation on mobile view
    - expect: Mobile navigation menu works correctly
    - expect: All pages are accessible
  4. Resize back to desktop dimensions
    - expect: Application returns to desktop layout

#### 12.3. Loading States and Indicators

**File:** `tests/ui/loading-states.spec.ts`

**Steps:**
  1. Navigate to a page that loads data (e.g., Archive, Wall)
    - expect: Loading indicator appears while data is being fetched
    - expect: Loading indicator is visible and clear
  2. Wait for data to load
    - expect: Loading indicator disappears when data is ready
    - expect: Content is displayed
  3. Perform an action that triggers a loading state (e.g., save, delete)
    - expect: Loading indicator appears during the operation
    - expect: UI is disabled or indicates processing

#### 12.4. Error Messages and Notifications

**File:** `tests/ui/error-messages.spec.ts`

**Steps:**
  1. Trigger a validation error (e.g., submit a form with missing fields)
    - expect: Error message appears near the relevant field
    - expect: Message is clear and helpful
  2. Perform a successful action (e.g., create a collection)
    - expect: Success notification appears
    - expect: Message confirms the action was successful
  3. Simulate a server error (if possible) or trigger an error condition
    - expect: Error notification appears
    - expect: Message is user-friendly and provides guidance
  4. Dismiss the notification
    - expect: Notification closes or disappears automatically after a timeout

#### 12.5. System Messages Display

**File:** `tests/ui/system-messages.spec.ts`

**Steps:**
  1. Check if system messages or announcements are displayed on the home page
    - expect: System message component is visible if messages exist
  2. Verify the content and formatting of system messages
    - expect: Messages are clear, readable, and properly formatted
  3. Dismiss a system message (if dismissible)
    - expect: Message is removed from view

#### 12.6. Dialog and Modal Behavior

**File:** `tests/ui/dialog-behavior.spec.ts`

**Steps:**
  1. Open a dialog (e.g., create collection, edit article)
    - expect: Dialog appears as a modal overlay
    - expect: Background is dimmed or blurred
    - expect: Focus is trapped within the dialog
  2. Attempt to click outside the dialog
    - expect: Dialog may close (if configured) or remain open with focus maintained
  3. Press the Escape key
    - expect: Dialog closes
  4. Click the 'Cancel' or 'Close' button
    - expect: Dialog closes without saving changes
  5. Click the 'Save' or 'Submit' button
    - expect: Dialog processes the action and closes
    - expect: Success message appears

#### 12.7. Accessibility Features

**File:** `tests/ui/accessibility.spec.ts`

**Steps:**
  1. Navigate the application using only the keyboard (Tab, Enter, Escape)
    - expect: All interactive elements are reachable via keyboard
    - expect: Focus indicators are visible
    - expect: Actions can be performed without a mouse
  2. Use a screen reader (if available) to navigate the application
    - expect: Screen reader announces page elements, labels, and states correctly
    - expect: ARIA labels are present and accurate
  3. Check color contrast and readability
    - expect: Text has sufficient contrast against backgrounds
    - expect: Content is readable for users with visual impairments
  4. Verify that form inputs have associated labels
    - expect: All form fields have visible or aria-label attributes
    - expect: Error messages are associated with fields

### 13. Integration and External Services

**Seed:** `tests/seed.spec.ts`

#### 13.1. Keycloak Authentication Integration

**File:** `tests/integration/keycloak-auth.spec.ts`

**Steps:**
  1. Navigate to the Gallery application
    - expect: Application redirects to Keycloak login page
  2. Enter valid Keycloak credentials and submit
    - expect: Keycloak authenticates the user
    - expect: User is redirected back to Gallery
    - expect: User is logged in successfully
  3. Check that the authentication token is valid
    - expect: API requests include valid JWT token in headers
    - expect: User can access authenticated resources
  4. Log out from Gallery
    - expect: User is logged out of Gallery
    - expect: Keycloak session is terminated

#### 13.2. Steamfitter Integration

**File:** `tests/integration/steamfitter-integration.spec.ts`

**Steps:**
  1. Create or view an exhibit with a linked Steamfitter scenario
    - expect: Exhibit shows scenario ID or link to Steamfitter
  2. Verify that Gallery can retrieve scenario data from Steamfitter API
    - expect: Scenario information is displayed correctly
    - expect: API calls to Steamfitter are successful
  3. Trigger a scenario-related action (if applicable)
    - expect: Gallery communicates with Steamfitter appropriately
    - expect: Action is reflected in both systems

#### 13.3. xAPI Learning Record Store Integration

**File:** `tests/integration/xapi-integration.spec.ts`

**Steps:**
  1. Perform an action that generates an xAPI statement (e.g., view an article, complete a task)
    - expect: Gallery sends xAPI statement to the LRS
  2. Verify that the xAPI statement is received by the LRS
    - expect: LRS records the statement
    - expect: Statement contains correct actor, verb, and object
  3. Query the LRS (if possible) to retrieve the statement
    - expect: Statement is retrievable and contains accurate data

#### 13.4. API Health Check

**File:** `tests/integration/api-health-check.spec.ts`

**Steps:**
  1. Make a request to the Gallery API health check endpoint (e.g., /api/health)
    - expect: Health check endpoint responds with status 200
    - expect: Response indicates API is healthy
  2. Check for database connectivity status in health check
    - expect: Database status is included and shows as connected
  3. Simulate an API failure (if test environment allows)
    - expect: Gallery UI displays appropriate error message
    - expect: User is informed that the API is unavailable

#### 13.5. Database Operations and Data Persistence

**File:** `tests/integration/database-persistence.spec.ts`

**Steps:**
  1. Create a new entity (e.g., collection, exhibit, article)
    - expect: Entity is saved to the database
  2. Refresh the page or log out and log back in
    - expect: Entity persists and is displayed correctly
  3. Edit the entity
    - expect: Changes are saved to the database
  4. Verify changes persist after refresh
    - expect: Updated data is displayed correctly
  5. Delete the entity
    - expect: Entity is removed from the database
  6. Verify deletion persists
    - expect: Entity no longer appears in the application

### 14. Edge Cases and Negative Testing

**Seed:** `tests/seed.spec.ts`

#### 14.1. Empty States and No Data Scenarios

**File:** `tests/edge-cases/empty-states.spec.ts`

**Steps:**
  1. Navigate to the Wall page with no cards assigned to the team
    - expect: Empty state message is displayed
    - expect: Message is helpful and guides the user on what to do next
  2. Navigate to the Archive page with no articles
    - expect: Empty state message is displayed
    - expect: User is informed that no articles exist
  3. Navigate to admin sections with no entities (e.g., no collections, no users)
    - expect: Empty state messages are displayed for each section

#### 14.2. Concurrent User Actions

**File:** `tests/edge-cases/concurrent-actions.spec.ts`

**Steps:**
  1. Open the same article in two browser windows as different users
    - expect: Both users can view the article
  2. In one window, edit and save the article
    - expect: Article is updated successfully
  3. In the other window, attempt to edit and save the article with different changes
    - expect: Conflict handling is in place (e.g., optimistic locking, warning message)
    - expect: User is informed of the conflict and guided on how to resolve

#### 14.3. Large Data Sets and Performance

**File:** `tests/edge-cases/large-data-sets.spec.ts`

**Steps:**
  1. Navigate to the Archive page with a large number of articles (e.g., 1000+)
    - expect: Page loads within acceptable time
    - expect: Pagination controls are functional
    - expect: Performance remains acceptable
  2. Search and filter a large data set
    - expect: Search and filter operations complete quickly
    - expect: Results are accurate
  3. Sort a large list
    - expect: Sorting completes efficiently
    - expect: UI remains responsive

#### 14.4. Special Characters and Input Sanitization

**File:** `tests/edge-cases/special-characters.spec.ts`

**Steps:**
  1. Create an article with special characters in the name (e.g., <script>, &, ', ")
    - expect: Special characters are handled correctly
    - expect: No XSS vulnerabilities are present
    - expect: Data is properly escaped or sanitized
  2. Enter HTML tags in a text field
    - expect: HTML is escaped or rendered harmless
    - expect: UI is not broken by malicious input
  3. Enter Unicode characters (e.g., emojis, foreign scripts)
    - expect: Unicode characters are stored and displayed correctly

#### 14.5. Invalid or Malformed API Requests

**File:** `tests/edge-cases/invalid-api-requests.spec.ts`

**Steps:**
  1. Manually construct an API request with missing required parameters
    - expect: API returns appropriate error response (e.g., 400 Bad Request)
    - expect: Error message is clear
  2. Attempt to access a resource with an invalid ID (e.g., non-existent article ID)
    - expect: API returns 404 Not Found
    - expect: UI displays appropriate error message
  3. Send a request with malformed JSON
    - expect: API returns 400 Bad Request with error details

#### 14.6. Network Interruption and Offline Behavior

**File:** `tests/edge-cases/network-interruption.spec.ts`

**Steps:**
  1. Load a page successfully
    - expect: Page is displayed
  2. Simulate network interruption (disable network or use dev tools)
    - expect: Application detects network loss
  3. Attempt to perform an action requiring network (e.g., save, load data)
    - expect: Error message appears indicating network issue
    - expect: User is informed to check connection
  4. Restore network connection
    - expect: Application recovers
    - expect: User can retry the action successfully

#### 14.7. Session Expiration and Token Refresh

**File:** `tests/edge-cases/session-expiration.spec.ts`

**Steps:**
  1. Log in and wait for the session to expire (or manually expire the token)
    - expect: Session expires after the configured timeout
  2. Attempt to perform an action after session expiration
    - expect: User is redirected to login page
    - expect: Session expiration message is displayed
  3. Log in again
    - expect: User is authenticated and can resume work

#### 14.8. Permission Changes During Active Session

**File:** `tests/edge-cases/permission-changes.spec.ts`

**Steps:**
  1. Log in as a user with certain permissions
    - expect: User has access to features based on permissions
  2. As an admin, change the user's permissions (e.g., remove SystemAdmin role)
    - expect: Permissions are updated in the database
  3. Without logging out, attempt to access features requiring the removed permission
    - expect: Access is denied (if permissions are checked on each request)
    - expect: Or user is informed to re-login for permission changes to take effect
  4. Log out and log back in
    - expect: Updated permissions are reflected
    - expect: User cannot access features they no longer have permission for

#### 14.9. Boundary Value Testing

**File:** `tests/edge-cases/boundary-values.spec.ts`

**Steps:**
  1. Create an entity with the minimum allowed values (e.g., shortest valid name)
    - expect: Entity is created successfully
  2. Create an entity with the maximum allowed values (e.g., longest valid name)
    - expect: Entity is created successfully
  3. Attempt to create an entity with values exceeding maximum limits
    - expect: Validation error appears
    - expect: Entity is not created
  4. Test date boundaries (e.g., very old dates, future dates)
    - expect: Date handling is correct
    - expect: No errors occur with edge-case dates

### 15. Search and Filtering Functionality

**Seed:** `tests/seed.spec.ts`

#### 15.1. Archive Search Functionality

**File:** `tests/search/archive-search.spec.ts`

**Steps:**
  1. Navigate to the Archive page
    - expect: Archive page loads with article list and search field
  2. Enter a keyword that appears in article titles
    - expect: Only articles with matching titles are displayed
  3. Enter a keyword that appears in article content
    - expect: Articles with matching content are displayed (if content search is supported)
  4. Enter a keyword with no matches
    - expect: No articles are displayed
    - expect: Empty state or 'no results' message appears
  5. Test case-insensitive search
    - expect: Search is case-insensitive
    - expect: Results include matches regardless of case
  6. Test partial word matching
    - expect: Partial matches are included in results (if supported)

#### 15.2. Archive Filter by Card

**File:** `tests/search/archive-filter-card.spec.ts`

**Steps:**
  1. Navigate to the Archive page
    - expect: Archive page loads with filter options
  2. Locate the 'Filter by Card' dropdown
    - expect: Dropdown shows 'All' or list of available cards
  3. Select a specific card from the dropdown
    - expect: Only articles belonging to the selected card are displayed
  4. Change to a different card
    - expect: Article list updates to show only articles from the new card
  5. Select 'All' or clear the filter
    - expect: All articles are displayed again

#### 15.3. Archive Filter by Source Type

**File:** `tests/search/archive-filter-source.spec.ts`

**Steps:**
  1. Navigate to the Archive page
    - expect: Archive page loads
  2. Locate the 'Filter by Source Type' dropdown or filter control
    - expect: Source type filter is available
  3. Select a source type (e.g., 'Intel', 'News', 'Social')
    - expect: Only articles of the selected source type are displayed
  4. Select multiple source types (if multi-select is supported)
    - expect: Articles matching any of the selected source types are displayed
  5. Clear the source type filter
    - expect: All articles are displayed again

#### 15.4. Combined Search and Filters

**File:** `tests/search/combined-search-filters.spec.ts`

**Steps:**
  1. Navigate to the Archive page
    - expect: Archive page loads
  2. Enter a search term and select a card filter
    - expect: Only articles matching both the search term and card filter are displayed
  3. Add a source type filter to the existing search and card filter
    - expect: Article list narrows further to match all criteria
  4. Clear one filter at a time
    - expect: Article list updates to reflect remaining active filters
  5. Clear all filters and search
    - expect: All articles are displayed

#### 15.5. Admin Search Functionality

**File:** `tests/search/admin-search.spec.ts`

**Steps:**
  1. Navigate to various admin sections (e.g., Users, Collections, Exhibits)
    - expect: Each admin section has a search or filter field
  2. Enter a search term in the admin Users page
    - expect: User list filters to show matching users
  3. Enter a search term in the admin Collections page
    - expect: Collection list filters to show matching collections
  4. Verify search works consistently across all admin sections
    - expect: Search functionality is consistent and accurate

### 16. Data Export and Reporting

**Seed:** `tests/seed.spec.ts`

#### 16.1. Export Article Data

**File:** `tests/export/export-articles.spec.ts`

**Steps:**
  1. Navigate to the Archive page
    - expect: Archive page loads with article list
  2. Locate an 'Export' button or option (if available)
    - expect: Export functionality is accessible
  3. Click 'Export' and select a format (e.g., CSV, PDF, JSON)
    - expect: Export dialog opens with format options
  4. Confirm the export
    - expect: File download begins
    - expect: Exported file contains correct article data
  5. Open the exported file and verify its contents
    - expect: Data is accurate and properly formatted

#### 16.2. Generate Reports

**File:** `tests/export/generate-reports.spec.ts`

**Steps:**
  1. Navigate to a reporting or analytics section (if available)
    - expect: Reporting interface is displayed
  2. Select report criteria (e.g., date range, exhibit, team)
    - expect: Criteria selection is functional
  3. Generate the report
    - expect: Report is generated and displayed or downloaded
  4. Verify report accuracy
    - expect: Report data matches expected values
