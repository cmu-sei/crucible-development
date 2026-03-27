# Gameboard Application Comprehensive Test Plan

## Application Overview

The Gameboard application is a competition and scoring platform within the Crucible cybersecurity training ecosystem. It provides functionality for managing cybersecurity competitions, games, and challenges. The platform supports team-based competition, challenge solving, scoring, leaderboards, and administrative functions for game management. Gameboard integrates with Keycloak for authentication via OpenID Connect and uses TopoMojo for challenge infrastructure. The application supports both individual and team-based competition formats with real-time scoring and progress tracking.

## Test Scenarios

### 1. Authentication and Authorization

**Seed:** `tests/seed.setup.ts`

#### 1.1. Successful Authentication Flow

**File:** `tests/gameboard/authentication/successful-authentication.spec.ts`

**Steps:**
  1. Navigate to Gameboard UI at http://localhost:4202
    - expect: User is redirected to Keycloak login page at https://localhost:8443/realms/crucible
  2. Enter valid username 'admin' in the username field
    - expect: Username field accepts input
  3. Enter valid password 'admin' in the password field
    - expect: Password field accepts input and masks the password
  4. Click the 'Sign In' button
    - expect: User is authenticated and redirected back to Gameboard UI
    - expect: Home page displays with available games/competitions
    - expect: User profile/menu is visible in the top navigation

#### 1.2. Failed Authentication - Invalid Credentials

**File:** `tests/gameboard/authentication/failed-authentication-invalid-credentials.spec.ts`

**Steps:**
  1. Navigate to Gameboard UI at http://localhost:4202
    - expect: User is redirected to Keycloak login page
  2. Enter invalid username 'wronguser' in the username field
    - expect: Username field accepts input
  3. Enter invalid password 'wrongpass' in the password field
    - expect: Password field accepts input
  4. Click the 'Sign In' button
    - expect: Authentication fails
    - expect: Error message is displayed indicating invalid credentials
    - expect: User remains on Keycloak login page

#### 1.3. Session Persistence After Refresh

**File:** `tests/gameboard/authentication/session-persistence.spec.ts`

**Steps:**
  1. Log in with valid credentials (admin/admin)
    - expect: User is successfully authenticated and viewing Gameboard home page
  2. Refresh the browser page
    - expect: User remains authenticated
    - expect: Home page loads without redirecting to Keycloak
    - expect: User session is maintained with automaticSilentRenew

#### 1.4. Logout Functionality

**File:** `tests/gameboard/authentication/logout.spec.ts`

**Steps:**
  1. Log in with valid credentials (admin/admin)
    - expect: User is successfully authenticated
  2. Click on user profile menu in top navigation
    - expect: User menu dropdown opens
  3. Click 'Logout' or 'Sign Out' option
    - expect: User is logged out
    - expect: User is redirected to post_logout_redirect_uri (http://localhost:4202)
    - expect: Authentication session is terminated
  4. Attempt to navigate to Gameboard UI again
    - expect: User is redirected to Keycloak login page
    - expect: User must authenticate again

#### 1.5. OIDC Silent Token Renewal

**File:** `tests/gameboard/authentication/silent-token-renewal.spec.ts`

**Steps:**
  1. Log in with valid credentials
    - expect: User is authenticated with access token
  2. Wait for token expiration time to approach
    - expect: Application detects token near expiration
  3. Monitor silent renewal process
    - expect: Silent iframe redirect to silent_redirect_uri occurs
    - expect: New access token is obtained without user interaction
    - expect: User session continues seamlessly

### 2. Home Page and Game Discovery

**Seed:** `tests/seed.setup.ts`

#### 2.1. Home Page Display

**File:** `tests/gameboard/home/home-page-display.spec.ts`

**Steps:**
  1. Log in and land on home page
    - expect: Home page displays with 'Gameboard' title
    - expect: Navigation menu is visible
    - expect: Main content area shows available games/competitions

#### 2.2. Game List Display - Active Games

**File:** `tests/gameboard/home/game-list-active.spec.ts`

**Steps:**
  1. Navigate to home page while logged in
    - expect: List of active games/competitions is displayed
    - expect: Each game shows title, description, dates, and status
    - expect: Game cards or list items are clickable

#### 2.3. Game List Display - Empty State

**File:** `tests/gameboard/home/game-list-empty.spec.ts`

**Steps:**
  1. Navigate to home page when no games are available
    - expect: Empty state message is displayed
    - expect: Message indicates no active games or competitions
    - expect: No errors are shown

#### 2.4. Game List Filtering - By Status

**File:** `tests/gameboard/home/game-list-filter-status.spec.ts`

**Steps:**
  1. Navigate to home page with multiple games
    - expect: Game list displays all games
  2. Click on status filter (e.g., 'Active', 'Upcoming', 'Completed')
    - expect: Game list filters to show only games matching selected status
    - expect: Filter indicator shows active filter
    - expect: Non-matching games are hidden
  3. Clear filter or select 'All'
    - expect: All games are displayed again

#### 2.5. Game Search Functionality

**File:** `tests/gameboard/home/game-search.spec.ts`

**Steps:**
  1. Navigate to home page with multiple games
    - expect: Game list displays
    - expect: Search field is visible
  2. Enter search term matching a game name
    - expect: Game list filters to show matching games only
    - expect: Search results update as user types
  3. Clear search field
    - expect: All games are displayed again

#### 2.6. Navigate to Game Details

**File:** `tests/gameboard/home/navigate-to-game-details.spec.ts`

**Steps:**
  1. Navigate to home page with games listed
    - expect: Game list is displayed
  2. Click on a game card or list item
    - expect: User is navigated to game details page
    - expect: URL updates to reflect selected game
    - expect: Game details page loads showing game information

### 3. Game Details and Registration

**Seed:** `tests/seed.setup.ts`

#### 3.1. Game Details Page Display

**File:** `tests/gameboard/game-details/details-page-display.spec.ts`

**Steps:**
  1. Navigate to a specific game details page
    - expect: Game details page loads with game title
    - expect: Game description and rules are displayed
    - expect: Competition dates and times are shown
    - expect: Registration status is visible
    - expect: Challenge count and difficulty information is displayed

#### 3.2. Individual Registration

**File:** `tests/gameboard/game-details/individual-registration.spec.ts`

**Steps:**
  1. Navigate to game details page for an open game
    - expect: Game details are displayed
    - expect: Registration button is visible and enabled
  2. Click 'Register' or 'Join Game' button
    - expect: Registration confirmation dialog or form appears
    - expect: User is prompted to confirm registration
  3. Confirm registration
    - expect: User is registered for the game
    - expect: Success message is displayed
    - expect: Registration status updates to 'Registered'
    - expect: User can now access game challenges

#### 3.3. Team Registration - Create New Team

**File:** `tests/gameboard/game-details/team-registration-create.spec.ts`

**Steps:**
  1. Navigate to team-based game details page
    - expect: Game details are displayed
    - expect: Team registration option is visible
  2. Click 'Register as Team' or 'Create Team' button
    - expect: Team creation dialog opens
    - expect: Form fields for team name and details are shown
  3. Enter team name 'Test Team Alpha'
    - expect: Team name field accepts input
  4. Enter team sponsor or organization name (if required)
    - expect: Sponsor field accepts input
  5. Click 'Create Team' button
    - expect: Team is created successfully
    - expect: User is registered as team captain
    - expect: Success message is displayed
    - expect: Team registration is confirmed

#### 3.4. Team Registration - Join Existing Team

**File:** `tests/gameboard/game-details/team-registration-join.spec.ts`

**Steps:**
  1. Navigate to team-based game details page
    - expect: Game details are displayed
  2. Click 'Join Team' button
    - expect: Team search or join interface is displayed
  3. Search for existing team by name or code
    - expect: Search results show matching teams
  4. Click 'Request to Join' for a team
    - expect: Join request is sent to team captain
    - expect: User is notified that request is pending
    - expect: User status shows 'Pending Team Approval'

#### 3.5. Registration - Game Full

**File:** `tests/gameboard/game-details/registration-game-full.spec.ts`

**Steps:**
  1. Navigate to game details page for a game at maximum capacity
    - expect: Game details are displayed
    - expect: Registration button is disabled or shows 'Full'
    - expect: Message indicates game is at capacity
  2. Attempt to click registration button (if enabled)
    - expect: Registration is prevented
    - expect: Error message indicates game is full
    - expect: User is not registered

#### 3.6. Unregister from Game

**File:** `tests/gameboard/game-details/unregister.spec.ts`

**Steps:**
  1. Navigate to game details page for a game user is registered for
    - expect: Game details show 'Registered' status
    - expect: 'Unregister' button is visible
  2. Click 'Unregister' or 'Leave Game' button
    - expect: Confirmation dialog appears warning about unregistering
  3. Confirm unregistration
    - expect: User is unregistered from the game
    - expect: Success message is displayed
    - expect: Registration status updates to 'Not Registered'
    - expect: User loses access to game challenges

### 4. Team Management

**Seed:** `tests/seed.setup.ts`

#### 4.1. View Team Details

**File:** `tests/gameboard/team/view-team-details.spec.ts`

**Steps:**
  1. Log in as user who is part of a team
    - expect: User is authenticated
  2. Navigate to 'My Team' or team details page
    - expect: Team details page displays
    - expect: Team name and information are shown
    - expect: List of team members is displayed
    - expect: Team captain is identified

#### 4.2. Edit Team Details - Team Captain

**File:** `tests/gameboard/team/edit-team-captain.spec.ts`

**Steps:**
  1. Log in as team captain
    - expect: User is authenticated as team captain
  2. Navigate to team details page
    - expect: Team details are displayed
    - expect: 'Edit Team' button is visible
  3. Click 'Edit Team' button
    - expect: Edit team dialog or form opens
    - expect: Team fields are editable
  4. Modify team name or details
    - expect: Fields accept modifications
  5. Click 'Save' button
    - expect: Team details are updated successfully
    - expect: Success message is displayed
    - expect: Updated information is reflected on team page

#### 4.3. Edit Team Details - Team Member (Unauthorized)

**File:** `tests/gameboard/team/edit-team-unauthorized.spec.ts`

**Steps:**
  1. Log in as regular team member (not captain)
    - expect: User is authenticated
  2. Navigate to team details page
    - expect: Team details are displayed
    - expect: 'Edit Team' button is not visible or is disabled
    - expect: User cannot modify team details

#### 4.4. Invite Team Member

**File:** `tests/gameboard/team/invite-member.spec.ts`

**Steps:**
  1. Log in as team captain
    - expect: User is authenticated as team captain
  2. Navigate to team details page
    - expect: Team member list is displayed
    - expect: 'Invite Member' button is visible
  3. Click 'Invite Member' button
    - expect: Invite dialog opens
    - expect: Field to enter user email or username is shown
  4. Enter user email or search for user
    - expect: User search results appear
  5. Select user and send invitation
    - expect: Invitation is sent to user
    - expect: Success message is displayed
    - expect: User appears as 'Pending' in team roster

#### 4.5. Accept Team Invitation

**File:** `tests/gameboard/team/accept-invitation.spec.ts`

**Steps:**
  1. Log in as user who has received team invitation
    - expect: User is authenticated
    - expect: Notification or invitation indicator is visible
  2. Navigate to notifications or invitations page
    - expect: List of pending invitations is displayed
  3. Click 'Accept' on team invitation
    - expect: User joins the team
    - expect: Success message is displayed
    - expect: User is added to team roster
    - expect: User can now participate with team

#### 4.6. Decline Team Invitation

**File:** `tests/gameboard/team/decline-invitation.spec.ts`

**Steps:**
  1. Log in as user with pending invitation
    - expect: User is authenticated
  2. Navigate to invitations page
    - expect: Pending invitations are displayed
  3. Click 'Decline' on team invitation
    - expect: Invitation is declined
    - expect: Invitation is removed from list
    - expect: User is not added to team

#### 4.7. Remove Team Member - Captain

**File:** `tests/gameboard/team/remove-member.spec.ts`

**Steps:**
  1. Log in as team captain
    - expect: User is authenticated as captain
  2. Navigate to team details page
    - expect: Team member list is displayed
  3. Click 'Remove' button next to a team member
    - expect: Confirmation dialog appears
  4. Confirm removal
    - expect: Team member is removed from team
    - expect: Success message is displayed
    - expect: Member no longer appears in team roster

#### 4.8. Leave Team - Team Member

**File:** `tests/gameboard/team/leave-team.spec.ts`

**Steps:**
  1. Log in as regular team member
    - expect: User is authenticated
  2. Navigate to team details page
    - expect: Team details are displayed
    - expect: 'Leave Team' button is visible
  3. Click 'Leave Team' button
    - expect: Confirmation dialog appears warning about leaving team
  4. Confirm leaving team
    - expect: User leaves the team
    - expect: Success message is displayed
    - expect: User is no longer associated with team
    - expect: User may need to join another team or register individually

#### 4.9. Transfer Team Captain Role

**File:** `tests/gameboard/team/transfer-captain.spec.ts`

**Steps:**
  1. Log in as team captain
    - expect: User is authenticated as captain
  2. Navigate to team details page
    - expect: Team member list is displayed
  3. Click 'Promote to Captain' or 'Transfer Leadership' next to a member
    - expect: Confirmation dialog appears
  4. Confirm captain transfer
    - expect: Captain role is transferred to selected member
    - expect: Success message is displayed
    - expect: New captain has full team management permissions
    - expect: Previous captain becomes regular member

### 5. Challenge Board and Gameplay

**Seed:** `tests/seed.setup.ts`

#### 5.1. Challenge Board Display

**File:** `tests/gameboard/challenges/board-display.spec.ts`

**Steps:**
  1. Log in as registered participant and navigate to active game
    - expect: Challenge board page displays
    - expect: List or grid of available challenges is shown
    - expect: Each challenge shows title, points, difficulty, and completion status

#### 5.2. Challenge Filtering - By Category

**File:** `tests/gameboard/challenges/filter-category.spec.ts`

**Steps:**
  1. Navigate to challenge board with multiple challenge categories
    - expect: All challenges are displayed
    - expect: Category filter is visible
  2. Select a specific category from filter
    - expect: Challenge board filters to show only challenges in selected category
    - expect: Other categories' challenges are hidden
  3. Clear category filter
    - expect: All challenges are displayed again

#### 5.3. Challenge Filtering - By Difficulty

**File:** `tests/gameboard/challenges/filter-difficulty.spec.ts`

**Steps:**
  1. Navigate to challenge board
    - expect: Challenges are displayed
    - expect: Difficulty filter is available
  2. Select difficulty level (e.g., 'Easy', 'Medium', 'Hard')
    - expect: Only challenges of selected difficulty are shown
  3. Clear filter
    - expect: All challenges are displayed

#### 5.4. Challenge Filtering - By Completion Status

**File:** `tests/gameboard/challenges/filter-status.spec.ts`

**Steps:**
  1. Navigate to challenge board
    - expect: Challenges are displayed
  2. Select status filter (e.g., 'Completed', 'In Progress', 'Not Started')
    - expect: Challenge board filters to show matching challenges
  3. Clear filter
    - expect: All challenges are displayed

#### 5.5. Open Challenge Details

**File:** `tests/gameboard/challenges/open-details.spec.ts`

**Steps:**
  1. Navigate to challenge board
    - expect: Challenges are listed
  2. Click on a challenge card or title
    - expect: Challenge details page or modal opens
    - expect: Challenge description and objectives are displayed
    - expect: Challenge materials and resources are shown
    - expect: Submit answer interface is visible

#### 5.6. Start Challenge

**File:** `tests/gameboard/challenges/start-challenge.spec.ts`

**Steps:**
  1. Navigate to a challenge that hasn't been started
    - expect: Challenge details are displayed
    - expect: 'Start Challenge' button is visible
  2. Click 'Start Challenge' button
    - expect: Challenge timer starts (if timed)
    - expect: Challenge status updates to 'In Progress'
    - expect: Challenge environment is provisioned (if applicable)
    - expect: User can begin working on challenge

#### 5.7. Submit Challenge Answer - Correct

**File:** `tests/gameboard/challenges/submit-correct.spec.ts`

**Steps:**
  1. Start a challenge and work through it
    - expect: Challenge is active
    - expect: Submit answer field is available
  2. Enter correct answer in submission field
    - expect: Answer field accepts input
  3. Click 'Submit' button
    - expect: Answer is validated as correct
    - expect: Success message is displayed
    - expect: Points are awarded to user/team
    - expect: Challenge is marked as completed
    - expect: Leaderboard is updated

#### 5.8. Submit Challenge Answer - Incorrect

**File:** `tests/gameboard/challenges/submit-incorrect.spec.ts`

**Steps:**
  1. Start a challenge
    - expect: Challenge is active
  2. Enter incorrect answer in submission field
    - expect: Answer field accepts input
  3. Click 'Submit' button
    - expect: Answer is validated as incorrect
    - expect: Error or 'Try Again' message is displayed
    - expect: No points are awarded
    - expect: User can attempt again (if attempts remain)
    - expect: Submission count increments

#### 5.9. Challenge Answer Submission - Max Attempts Reached

**File:** `tests/gameboard/challenges/submit-max-attempts.spec.ts`

**Steps:**
  1. Submit incorrect answers until maximum attempts are reached
    - expect: Each incorrect submission is recorded
  2. Attempt to submit after max attempts
    - expect: Submission is prevented
    - expect: Message indicates maximum attempts reached
    - expect: Challenge may be locked or marked as failed
    - expect: No further submissions are allowed

#### 5.10. Challenge Timer - Time Expiration

**File:** `tests/gameboard/challenges/timer-expiration.spec.ts`

**Steps:**
  1. Start a timed challenge
    - expect: Challenge timer begins counting down
  2. Wait for timer to reach zero
    - expect: Timer expires
    - expect: Challenge is automatically ended
    - expect: User is notified of time expiration
    - expect: Challenge is marked as incomplete or failed
    - expect: Submission interface is disabled

#### 5.11. Challenge with Console Access

**File:** `tests/gameboard/challenges/console-access.spec.ts`

**Steps:**
  1. Start a challenge that includes virtual machine access
    - expect: Challenge details show VM console option
  2. Click 'Open Console' or 'Connect to VM' button
    - expect: Console window opens (VNC or similar)
    - expect: Virtual machine interface is displayed
    - expect: User can interact with VM
    - expect: Console uses console-forge configuration

#### 5.12. Challenge Resources and Materials

**File:** `tests/gameboard/challenges/resources.spec.ts`

**Steps:**
  1. Open a challenge with downloadable resources
    - expect: Challenge details show resources section
  2. Click on a resource file to download
    - expect: File download begins
    - expect: Resource is downloaded successfully

#### 5.13. Challenge Hints

**File:** `tests/gameboard/challenges/hints.spec.ts`

**Steps:**
  1. Open a challenge with hints available
    - expect: Challenge shows 'Hint' button or hint indicator
  2. Click 'Get Hint' button
    - expect: Hint is revealed to user
    - expect: Point penalty may be applied (if configured)
    - expect: Hint content is displayed

### 6. Leaderboard and Scoring

**Seed:** `tests/seed.setup.ts`

#### 6.1. Leaderboard Display - Game Leaderboard

**File:** `tests/gameboard/leaderboard/game-leaderboard.spec.ts`

**Steps:**
  1. Navigate to active game leaderboard page
    - expect: Leaderboard displays with ranking table
    - expect: Table shows rank, team/player name, points, and challenge completion
    - expect: Current user/team position is highlighted
    - expect: Leaderboard updates in real-time or periodically

#### 6.2. Leaderboard Display - Overall Standings

**File:** `tests/gameboard/leaderboard/overall-standings.spec.ts`

**Steps:**
  1. Navigate to overall leaderboard page
    - expect: Overall competition standings are displayed
    - expect: All participating teams/players are ranked
    - expect: Points and completion statistics are shown

#### 6.3. Leaderboard Filtering - By Division

**File:** `tests/gameboard/leaderboard/filter-division.spec.ts`

**Steps:**
  1. Navigate to leaderboard with multiple divisions
    - expect: Leaderboard displays all divisions
  2. Select a specific division from filter
    - expect: Leaderboard filters to show only selected division
    - expect: Rankings are recalculated for division
  3. Clear filter
    - expect: All divisions are displayed

#### 6.4. Leaderboard Search - Find Team/Player

**File:** `tests/gameboard/leaderboard/search-team.spec.ts`

**Steps:**
  1. Navigate to leaderboard page
    - expect: Leaderboard is displayed
    - expect: Search field is available
  2. Enter team or player name in search field
    - expect: Search results highlight matching entries
    - expect: Page scrolls or jumps to matching entry

#### 6.5. Leaderboard Real-time Updates

**File:** `tests/gameboard/leaderboard/realtime-updates.spec.ts`

**Steps:**
  1. Open leaderboard page while game is active
    - expect: Initial leaderboard state is displayed
  2. Have another user/team complete a challenge (simulate or use second session)
    - expect: Leaderboard updates automatically
    - expect: New rankings reflect recent score changes
    - expect: User sees updated positions without manual refresh

#### 6.6. View Team/Player Details from Leaderboard

**File:** `tests/gameboard/leaderboard/view-details.spec.ts`

**Steps:**
  1. Navigate to leaderboard
    - expect: Leaderboard is displayed
  2. Click on a team or player name
    - expect: Team/player profile or details page opens
    - expect: Profile shows completed challenges, points breakdown, and statistics

#### 6.7. Score History and Timeline

**File:** `tests/gameboard/leaderboard/score-history.spec.ts`

**Steps:**
  1. Navigate to team/player profile or score details page
    - expect: Profile page displays
  2. View score history or timeline section
    - expect: Timeline of challenge completions is displayed
    - expect: Each completion shows timestamp and points earned
    - expect: Cumulative score progression is visualized (graph or chart)

### 7. User Profile and Settings

**Seed:** `tests/seed.setup.ts`

#### 7.1. View User Profile

**File:** `tests/gameboard/profile/view-profile.spec.ts`

**Steps:**
  1. Log in and navigate to user profile page
    - expect: Profile page displays user information
    - expect: User name, email, and avatar are shown
    - expect: List of participated games is displayed
    - expect: Overall statistics and achievements are visible

#### 7.2. Edit User Profile

**File:** `tests/gameboard/profile/edit-profile.spec.ts`

**Steps:**
  1. Navigate to user profile page
    - expect: Profile is displayed
    - expect: 'Edit Profile' button is visible
  2. Click 'Edit Profile' button
    - expect: Profile edit form opens
    - expect: Editable fields are displayed
  3. Modify display name or other editable fields
    - expect: Fields accept modifications
  4. Click 'Save' button
    - expect: Profile is updated successfully
    - expect: Success message is displayed
    - expect: Updated information is reflected on profile page

#### 7.3. Upload Profile Avatar

**File:** `tests/gameboard/profile/upload-avatar.spec.ts`

**Steps:**
  1. Navigate to profile edit page
    - expect: Edit interface is displayed
  2. Click 'Upload Avatar' or avatar image area
    - expect: File upload dialog opens
  3. Select a valid image file (PNG or JPEG)
    - expect: File is uploaded successfully
    - expect: New avatar is displayed
  4. Save changes
    - expect: Avatar update is saved
    - expect: New avatar appears on profile

#### 7.4. View Game History

**File:** `tests/gameboard/profile/game-history.spec.ts`

**Steps:**
  1. Navigate to user profile page
    - expect: Profile displays
  2. View 'Game History' or 'Past Competitions' section
    - expect: List of previously participated games is shown
    - expect: Each game shows name, date, and final ranking/score
    - expect: User can click on a game to view detailed results

#### 7.5. View Achievements and Badges

**File:** `tests/gameboard/profile/achievements.spec.ts`

**Steps:**
  1. Navigate to user profile page
    - expect: Profile displays
  2. View 'Achievements' or 'Badges' section
    - expect: Earned achievements and badges are displayed
    - expect: Each badge shows icon, name, and description
    - expect: Locked/unearned achievements may be shown in disabled state

#### 7.6. User Preferences - Notification Settings

**File:** `tests/gameboard/profile/notification-settings.spec.ts`

**Steps:**
  1. Navigate to user settings or preferences page
    - expect: Settings page displays
  2. Locate notification preferences section
    - expect: Notification toggles are displayed
  3. Toggle notification settings (e.g., email notifications, browser notifications)
    - expect: Settings update successfully
    - expect: Changes are saved

#### 7.7. User Preferences - Theme Settings

**File:** `tests/gameboard/profile/theme-settings.spec.ts`

**Steps:**
  1. Navigate to settings page
    - expect: Settings page displays
  2. Select theme preference (e.g., Light, Dark, Auto)
    - expect: Application theme changes to selected preference
    - expect: Theme preference is saved
    - expect: Custom background class is applied (custom-bg-dark-gray)

### 8. Notifications and Real-time Updates

**Seed:** `tests/seed.setup.ts`

#### 8.1. In-App Notifications Display

**File:** `tests/gameboard/notifications/display.spec.ts`

**Steps:**
  1. Log in and navigate to any page
    - expect: Notification icon or indicator is visible in navigation
  2. Click on notification icon
    - expect: Notification panel or dropdown opens
    - expect: List of recent notifications is displayed
    - expect: Unread notifications are highlighted

#### 8.2. Notification - Team Invitation

**File:** `tests/gameboard/notifications/team-invitation.spec.ts`

**Steps:**
  1. Receive team invitation from another user
    - expect: Notification appears in notification center
    - expect: Notification shows team name and inviter
    - expect: Actions to accept or decline are available

#### 8.3. Notification - Game Start Reminder

**File:** `tests/gameboard/notifications/game-start.spec.ts`

**Steps:**
  1. Be registered for a game approaching start time
    - expect: Notification is sent before game start (based on countdown settings)
    - expect: Notification indicates game is starting soon
    - expect: User can click to navigate to game

#### 8.4. Notification - Challenge Update

**File:** `tests/gameboard/notifications/challenge-update.spec.ts`

**Steps:**
  1. Have an active challenge in progress
    - expect: User is working on challenge
  2. Admin updates challenge or posts announcement
    - expect: Notification is received about challenge update
    - expect: User can view updated challenge information

#### 8.5. Browser Push Notifications

**File:** `tests/gameboard/notifications/browser-push.spec.ts`

**Steps:**
  1. Enable browser notifications when prompted
    - expect: Browser notification permission is granted
  2. Trigger notification event (e.g., team invitation, game start)
    - expect: Browser push notification appears
    - expect: Notification shows appropriate message and icon
    - expect: Clicking notification navigates to relevant page

#### 8.6. Mark Notifications as Read

**File:** `tests/gameboard/notifications/mark-read.spec.ts`

**Steps:**
  1. Open notification panel with unread notifications
    - expect: Unread notifications are displayed
  2. Click on a notification or 'Mark as Read' button
    - expect: Notification is marked as read
    - expect: Unread indicator is removed
    - expect: Notification count updates

#### 8.7. Clear All Notifications

**File:** `tests/gameboard/notifications/clear-all.spec.ts`

**Steps:**
  1. Open notification panel with multiple notifications
    - expect: Notifications are displayed
  2. Click 'Clear All' or 'Dismiss All' button
    - expect: All notifications are cleared
    - expect: Notification panel shows empty state
    - expect: Notification counter resets to zero

### 9. Administration - Game Management

**Seed:** `tests/seed.setup.ts`

#### 9.1. Admin Dashboard Access - Authorized

**File:** `tests/gameboard/admin/dashboard-access-authorized.spec.ts`

**Steps:**
  1. Log in as user with admin permissions
    - expect: User is authenticated with admin role
  2. Navigate to /admin or admin dashboard route
    - expect: Admin dashboard loads
    - expect: Admin navigation menu is visible
    - expect: Game management options are displayed

#### 9.2. Admin Dashboard Access - Unauthorized

**File:** `tests/gameboard/admin/dashboard-access-unauthorized.spec.ts`

**Steps:**
  1. Log in as regular user without admin permissions
    - expect: User is authenticated
  2. Attempt to navigate to admin dashboard
    - expect: Access is denied
    - expect: User is shown error message or redirected
    - expect: Admin interface is not accessible

#### 9.3. Create New Game

**File:** `tests/gameboard/admin/create-game.spec.ts`

**Steps:**
  1. Navigate to admin game management section
    - expect: Game list is displayed
    - expect: 'Create Game' button is visible
  2. Click 'Create Game' button
    - expect: Game creation form opens
  3. Enter game name 'Test Competition 2026'
    - expect: Name field accepts input
  4. Enter game description and rules
    - expect: Description fields accept input
  5. Set game start and end dates/times
    - expect: Date/time pickers accept selections
  6. Configure game settings (team-based, max participants, etc.)
    - expect: Settings fields accept configurations
  7. Click 'Create' or 'Save' button
    - expect: Game is created successfully
    - expect: Success message is displayed
    - expect: New game appears in game list
    - expect: Game is in draft or unpublished state

#### 9.4. Edit Game Details

**File:** `tests/gameboard/admin/edit-game.spec.ts`

**Steps:**
  1. Navigate to admin game list
    - expect: Games are displayed
  2. Click 'Edit' button for a game
    - expect: Game edit form opens with current details
  3. Modify game name or description
    - expect: Fields accept modifications
  4. Click 'Save' button
    - expect: Game is updated successfully
    - expect: Success message is displayed
    - expect: Updated information is reflected in game list

#### 9.5. Publish Game

**File:** `tests/gameboard/admin/publish-game.spec.ts`

**Steps:**
  1. Navigate to admin game list with unpublished game
    - expect: Draft game is visible
  2. Click 'Publish' button for the game
    - expect: Confirmation dialog may appear
  3. Confirm publication
    - expect: Game is published successfully
    - expect: Game becomes visible to users
    - expect: Registration opens (if configured)
    - expect: Game status updates to 'Published' or 'Active'

#### 9.6. Unpublish/Archive Game

**File:** `tests/gameboard/admin/unpublish-game.spec.ts`

**Steps:**
  1. Navigate to admin game list with published game
    - expect: Published game is visible
  2. Click 'Unpublish' or 'Archive' button
    - expect: Confirmation dialog appears
  3. Confirm unpublishing
    - expect: Game is unpublished/archived
    - expect: Game is no longer visible to regular users
    - expect: Game status updates accordingly

#### 9.7. Delete Game

**File:** `tests/gameboard/admin/delete-game.spec.ts`

**Steps:**
  1. Navigate to admin game list
    - expect: Games are displayed
  2. Click 'Delete' button for a test game
    - expect: Confirmation dialog appears with warning
  3. Confirm deletion
    - expect: Game is deleted permanently
    - expect: Success message is displayed
    - expect: Game is removed from list
    - expect: Associated data may be removed or archived

#### 9.8. Clone/Duplicate Game

**File:** `tests/gameboard/admin/clone-game.spec.ts`

**Steps:**
  1. Navigate to admin game list
    - expect: Games are displayed
  2. Click 'Clone' or 'Duplicate' button for a game
    - expect: Clone confirmation or naming dialog appears
  3. Enter new game name for clone
    - expect: Name field accepts input
  4. Confirm cloning
    - expect: Game is cloned successfully
    - expect: Cloned game appears in list with new name
    - expect: All challenges and settings are copied

### 10. Administration - Challenge Management

**Seed:** `tests/seed.setup.ts`

#### 10.1. View Challenge List

**File:** `tests/gameboard/admin/challenges-list.spec.ts`

**Steps:**
  1. Navigate to admin challenge management section
    - expect: Challenge list is displayed
    - expect: Challenges show title, category, points, and difficulty
    - expect: Search and filter options are available

#### 10.2. Create New Challenge

**File:** `tests/gameboard/admin/create-challenge.spec.ts`

**Steps:**
  1. Navigate to admin challenges section
    - expect: Challenge list displays
    - expect: 'Create Challenge' button is visible
  2. Click 'Create Challenge' button
    - expect: Challenge creation form opens
  3. Enter challenge title 'SQL Injection Defense'
    - expect: Title field accepts input
  4. Enter challenge description and objectives
    - expect: Description fields accept input
  5. Set challenge category, difficulty, and points value
    - expect: Category and points fields accept values
  6. Configure challenge answer (correct flag or solution)
    - expect: Answer configuration field accepts input
  7. Set maximum attempts and time limit (optional)
    - expect: Constraint fields accept values
  8. Click 'Save' button
    - expect: Challenge is created successfully
    - expect: Success message is displayed
    - expect: New challenge appears in list

#### 10.3. Edit Challenge Details

**File:** `tests/gameboard/admin/edit-challenge.spec.ts`

**Steps:**
  1. Navigate to admin challenges list
    - expect: Challenges are displayed
  2. Click 'Edit' button for a challenge
    - expect: Challenge edit form opens with current details
  3. Modify challenge details (description, points, etc.)
    - expect: Fields accept modifications
  4. Click 'Save' button
    - expect: Challenge is updated successfully
    - expect: Success message is displayed
    - expect: Changes are reflected in challenge list

#### 10.4. Add Challenge to Game

**File:** `tests/gameboard/admin/add-challenge-to-game.spec.ts`

**Steps:**
  1. Navigate to game edit page
    - expect: Game details are displayed
    - expect: 'Add Challenges' section is visible
  2. Click 'Add Challenge' button
    - expect: Challenge selection interface opens
    - expect: Available challenges are listed
  3. Select one or more challenges to add
    - expect: Challenges are selected
  4. Confirm addition
    - expect: Challenges are added to game
    - expect: Success message is displayed
    - expect: Challenges appear in game's challenge board

#### 10.5. Remove Challenge from Game

**File:** `tests/gameboard/admin/remove-challenge-from-game.spec.ts`

**Steps:**
  1. Navigate to game edit page with assigned challenges
    - expect: Game challenges are listed
  2. Click 'Remove' button next to a challenge
    - expect: Confirmation dialog appears
  3. Confirm removal
    - expect: Challenge is removed from game
    - expect: Success message is displayed
    - expect: Challenge no longer appears in game's challenge board

#### 10.6. Delete Challenge

**File:** `tests/gameboard/admin/delete-challenge.spec.ts`

**Steps:**
  1. Navigate to admin challenges list
    - expect: Challenges are displayed
  2. Click 'Delete' button for a test challenge
    - expect: Confirmation dialog appears with warning
  3. Confirm deletion
    - expect: Challenge is deleted permanently
    - expect: Success message is displayed
    - expect: Challenge is removed from list

#### 10.7. Add Challenge Resources

**File:** `tests/gameboard/admin/add-challenge-resources.spec.ts`

**Steps:**
  1. Navigate to challenge edit page
    - expect: Challenge details are displayed
  2. Locate 'Resources' or 'Files' section
    - expect: Resource upload interface is visible
  3. Click 'Upload' button and select files
    - expect: File upload dialog opens
    - expect: Files are selected
  4. Confirm upload
    - expect: Files are uploaded successfully
    - expect: Resources appear in challenge resources list
    - expect: Files will be available to participants

#### 10.8. Configure Challenge Hints

**File:** `tests/gameboard/admin/configure-hints.spec.ts`

**Steps:**
  1. Navigate to challenge edit page
    - expect: Challenge details are displayed
  2. Locate 'Hints' section
    - expect: Hints configuration is visible
  3. Add hint text and configure point penalty
    - expect: Hint fields accept input
  4. Save hint configuration
    - expect: Hint is saved successfully
    - expect: Hint will be available to participants with configured penalty

### 11. Administration - User and Participant Management

**Seed:** `tests/seed.setup.ts`

#### 11.1. View All Participants

**File:** `tests/gameboard/admin/view-participants.spec.ts`

**Steps:**
  1. Navigate to admin user/participant management section
    - expect: List of all registered users/participants is displayed
    - expect: User information includes name, email, and registration status
    - expect: Search and filter options are available

#### 11.2. Search Users

**File:** `tests/gameboard/admin/search-users.spec.ts`

**Steps:**
  1. Navigate to admin users section
    - expect: User list is displayed
    - expect: Search field is visible
  2. Enter user name or email in search field
    - expect: User list filters to show matching users
    - expect: Search results update as user types

#### 11.3. View User Details and Activity

**File:** `tests/gameboard/admin/view-user-details.spec.ts`

**Steps:**
  1. Navigate to admin users section
    - expect: User list is displayed
  2. Click on a user to view details
    - expect: User detail page opens
    - expect: User profile information is displayed
    - expect: Game participation history is shown
    - expect: Challenge completion statistics are visible

#### 11.4. Assign User Roles - Make Admin

**File:** `tests/gameboard/admin/assign-admin-role.spec.ts`

**Steps:**
  1. Navigate to user details page
    - expect: User information is displayed
  2. Click 'Edit Roles' or 'Manage Permissions' button
    - expect: Role management interface opens
  3. Assign 'Administrator' or 'Game Manager' role to user
    - expect: Role is selected
  4. Save role changes
    - expect: User role is updated successfully
    - expect: User gains admin permissions
    - expect: Success message is displayed

#### 11.5. Manually Register User for Game

**File:** `tests/gameboard/admin/manual-registration.spec.ts`

**Steps:**
  1. Navigate to game participants section for a specific game
    - expect: Current participants are listed
  2. Click 'Add Participant' button
    - expect: User search interface opens
  3. Search for and select a user
    - expect: User is found and selected
  4. Confirm registration
    - expect: User is registered for the game
    - expect: User appears in participant list
    - expect: User can now access game challenges

#### 11.6. Remove User from Game

**File:** `tests/gameboard/admin/remove-user-from-game.spec.ts`

**Steps:**
  1. Navigate to game participants list
    - expect: Participants are displayed
  2. Click 'Remove' button next to a participant
    - expect: Confirmation dialog appears
  3. Confirm removal
    - expect: User is removed from game
    - expect: User no longer appears in participant list
    - expect: User loses access to game challenges

#### 11.7. Disqualify Participant

**File:** `tests/gameboard/admin/disqualify-participant.spec.ts`

**Steps:**
  1. Navigate to game participants list
    - expect: Participants are displayed
  2. Click 'Disqualify' button for a participant
    - expect: Disqualification dialog opens
    - expect: Reason field is displayed
  3. Enter disqualification reason
    - expect: Reason field accepts input
  4. Confirm disqualification
    - expect: Participant is disqualified
    - expect: Participant's scores are invalidated or hidden
    - expect: Participant is removed from leaderboard
    - expect: Status updates to 'Disqualified'

#### 11.8. Export Participant Data

**File:** `tests/gameboard/admin/export-participants.spec.ts`

**Steps:**
  1. Navigate to game participants section
    - expect: Participants are displayed
  2. Click 'Export' or 'Download CSV' button
    - expect: Export process begins
    - expect: Participant data is exported to CSV or Excel format
    - expect: File is downloaded successfully

### 12. Administration - Reporting and Analytics

**Seed:** `tests/seed.setup.ts`

#### 12.1. View Game Statistics Dashboard

**File:** `tests/gameboard/admin/game-statistics.spec.ts`

**Steps:**
  1. Navigate to admin reporting section for a specific game
    - expect: Game statistics dashboard is displayed
    - expect: Metrics show total participants, completion rate, average score
    - expect: Charts and graphs visualize participation and performance
    - expect: Challenge completion statistics are shown

#### 12.2. View Challenge Performance Analytics

**File:** `tests/gameboard/admin/challenge-analytics.spec.ts`

**Steps:**
  1. Navigate to challenge analytics page
    - expect: Challenge performance metrics are displayed
    - expect: Each challenge shows completion rate and average attempts
    - expect: Difficulty analysis is provided
    - expect: Challenges can be sorted by completion rate or difficulty

#### 12.3. Export Game Report

**File:** `tests/gameboard/admin/export-game-report.spec.ts`

**Steps:**
  1. Navigate to game reporting section
    - expect: Reporting interface is displayed
  2. Click 'Generate Report' or 'Export Report' button
    - expect: Report generation options are presented
  3. Select report format (PDF, CSV, Excel)
    - expect: Format is selected
  4. Confirm export
    - expect: Report is generated
    - expect: Report file is downloaded successfully
    - expect: Report contains comprehensive game statistics

#### 12.4. View User Activity Logs

**File:** `tests/gameboard/admin/activity-logs.spec.ts`

**Steps:**
  1. Navigate to admin activity logs section
    - expect: Activity log is displayed
    - expect: Logs show user actions with timestamps
    - expect: Filter options for user, action type, and date range are available

#### 12.5. Filter Activity Logs

**File:** `tests/gameboard/admin/filter-activity-logs.spec.ts`

**Steps:**
  1. Navigate to activity logs page
    - expect: Activity logs are displayed
  2. Apply filters (user, date range, action type)
    - expect: Logs filter to show matching entries only
    - expect: Filter criteria are clearly indicated
  3. Clear filters
    - expect: All logs are displayed again

### 13. Error Handling and Edge Cases

**Seed:** `tests/seed.setup.ts`

#### 13.1. API Error Handling - Network Failure

**File:** `tests/gameboard/error-handling/network-failure.spec.ts`

**Steps:**
  1. Log in successfully
    - expect: User is authenticated
  2. Simulate network disconnection or API unavailability
    - expect: Network connection is lost
  3. Attempt to perform an action requiring API call
    - expect: Application detects network failure
    - expect: Error message is displayed to user
    - expect: Message indicates connection issue
    - expect: Application remains stable without crashes

#### 13.2. API Error Handling - Server Error (500)

**File:** `tests/gameboard/error-handling/server-error.spec.ts`

**Steps:**
  1. Log in successfully
    - expect: User is authenticated
  2. Trigger an API call that returns 500 error (mock or actual)
    - expect: Application handles error gracefully
    - expect: User-friendly error message is displayed
    - expect: No uncaught exceptions appear in console
    - expect: User can retry or navigate away

#### 13.3. Form Validation - Required Fields

**File:** `tests/gameboard/error-handling/form-validation-required.spec.ts`

**Steps:**
  1. Navigate to a form (e.g., create team dialog)
    - expect: Form is displayed
  2. Leave required fields empty
    - expect: Required fields are marked with indicators
  3. Attempt to submit form
    - expect: Form validation prevents submission
    - expect: Error messages indicate which fields are required
    - expect: Focus moves to first invalid field

#### 13.4. Form Validation - Invalid Input Format

**File:** `tests/gameboard/error-handling/form-validation-format.spec.ts`

**Steps:**
  1. Navigate to a form with formatted fields (e.g., date/time)
    - expect: Form is displayed
  2. Enter invalid format data (e.g., malformed date)
    - expect: Field shows validation error
  3. Attempt to submit
    - expect: Form validation prevents submission
    - expect: Specific format error is displayed
    - expect: User is guided to correct format

#### 13.5. Session Timeout

**File:** `tests/gameboard/error-handling/session-timeout.spec.ts`

**Steps:**
  1. Log in successfully
    - expect: User is authenticated
  2. Wait for session to expire or manually invalidate token
    - expect: Session expires
  3. Attempt to perform an action
    - expect: User is notified of session expiration
    - expect: User is redirected to login page
    - expect: User can log in again to continue

#### 13.6. Browser Back Button Navigation

**File:** `tests/gameboard/error-handling/back-button.spec.ts`

**Steps:**
  1. Navigate through multiple pages (home -> game -> challenge)
    - expect: Navigation history is recorded
  2. Click browser back button
    - expect: User navigates back to previous page
    - expect: Page state is correctly restored or reloaded
    - expect: No errors occur during back navigation

#### 13.7. Deep Link Access - Unauthenticated

**File:** `tests/gameboard/error-handling/deep-link-unauthenticated.spec.ts`

**Steps:**
  1. Copy deep link URL to specific game or challenge
    - expect: URL is copied
  2. Open link in incognito mode or while logged out
    - expect: User is not authenticated
  3. Navigate to deep link URL
    - expect: User is redirected to login page
    - expect: After successful login, user is redirected to intended deep link destination

#### 13.8. XSS Protection - Script Injection in Forms

**File:** `tests/gameboard/error-handling/xss-protection.spec.ts`

**Steps:**
  1. Navigate to a form (e.g., create game, team name)
    - expect: Form is displayed
  2. Enter script tags in text fields (e.g., <script>alert('XSS')</script>)
    - expect: Input is accepted
  3. Submit form
    - expect: Script is sanitized and not executed
    - expect: No XSS vulnerability is present
    - expect: Data is stored safely without executable code

#### 13.9. Concurrent User Actions - Challenge Submission

**File:** `tests/gameboard/error-handling/concurrent-submissions.spec.ts`

**Steps:**
  1. Open challenge in two browser tabs with same user
    - expect: Challenge is active in both tabs
  2. Submit answer in first tab
    - expect: Answer is submitted and validated
  3. Attempt to submit answer in second tab
    - expect: Application detects duplicate submission or challenge completion
    - expect: User is notified appropriately
    - expect: No duplicate points are awarded

#### 13.10. Large Data Set Handling - Leaderboard Pagination

**File:** `tests/gameboard/error-handling/leaderboard-pagination.spec.ts`

**Steps:**
  1. Navigate to leaderboard with many participants (100+)
    - expect: Leaderboard loads with pagination or infinite scroll
    - expect: Initial page loads quickly
  2. Navigate through pages or scroll through list
    - expect: Data loads smoothly without freezing
    - expect: Performance remains acceptable
    - expect: All participants are accessible

#### 13.11. Invalid Game ID Access

**File:** `tests/gameboard/error-handling/invalid-game-id.spec.ts`

**Steps:**
  1. Log in successfully
    - expect: User is authenticated
  2. Navigate to game URL with non-existent game ID
    - expect: Error page or message is displayed
    - expect: Message indicates game not found
    - expect: User can navigate back to home
    - expect: Application does not crash

#### 13.12. Challenge Answer Case Sensitivity

**File:** `tests/gameboard/error-handling/answer-case-sensitivity.spec.ts`

**Steps:**
  1. Start a challenge with known answer
    - expect: Challenge is active
  2. Submit answer in different case (e.g., lowercase instead of uppercase)
    - expect: Answer validation handles case appropriately based on configuration
    - expect: User is notified if case matters
    - expect: Case-insensitive answers are accepted when configured

### 14. Performance and Accessibility

**Seed:** `tests/seed.setup.ts`

#### 14.1. Page Load Performance - Home Page

**File:** `tests/gameboard/performance/home-page-load.spec.ts`

**Steps:**
  1. Measure time from navigation to home page until fully loaded
    - expect: Home page loads within acceptable time (under 3 seconds)
    - expect: No blocking resources delay rendering
    - expect: Core Web Vitals are within acceptable ranges

#### 14.2. Page Load Performance - Challenge Board

**File:** `tests/gameboard/performance/challenge-board-load.spec.ts`

**Steps:**
  1. Measure time from navigation to challenge board until interactive
    - expect: Challenge board loads within acceptable time
    - expect: Challenges render progressively
    - expect: User can interact without delay

#### 14.3. API Response Time - Leaderboard Updates

**File:** `tests/gameboard/performance/api-response-leaderboard.spec.ts`

**Steps:**
  1. Monitor network requests when loading leaderboard
    - expect: API response time is under acceptable threshold (1-2 seconds)
    - expect: No unnecessary or redundant API calls are made
    - expect: Data is cached appropriately

#### 14.4. Memory Usage - Extended Session

**File:** `tests/gameboard/performance/memory-usage.spec.ts`

**Steps:**
  1. Use application for extended period, navigating through various pages
    - expect: Memory usage remains stable
    - expect: No significant memory leaks are detected
    - expect: Application performance does not degrade over time

#### 14.5. Keyboard Navigation - Tab Order

**File:** `tests/gameboard/accessibility/keyboard-tab-order.spec.ts`

**Steps:**
  1. Navigate to home page
    - expect: Page is loaded
  2. Press Tab key repeatedly to navigate through interactive elements
    - expect: Focus moves through elements in logical order
    - expect: All interactive elements are reachable via keyboard
    - expect: Focus indicator is clearly visible

#### 14.6. Keyboard Navigation - Form Submission

**File:** `tests/gameboard/accessibility/keyboard-form-submission.spec.ts`

**Steps:**
  1. Navigate to a form using keyboard only
    - expect: Form is accessible
  2. Fill form fields using Tab and keyboard input
    - expect: All fields can be filled via keyboard
  3. Press Enter to submit form
    - expect: Form submits successfully without mouse interaction

#### 14.7. Screen Reader Compatibility - ARIA Labels

**File:** `tests/gameboard/accessibility/screen-reader-aria.spec.ts`

**Steps:**
  1. Inspect page structure for ARIA labels and roles
    - expect: All interactive elements have appropriate ARIA labels
    - expect: Headings are properly structured (h1, h2, h3 hierarchy)
    - expect: Screen reader can navigate by landmarks and headings
    - expect: Form fields have associated labels

#### 14.8. Color Contrast Compliance

**File:** `tests/gameboard/accessibility/color-contrast.spec.ts`

**Steps:**
  1. Run automated accessibility audit on various pages
    - expect: All text meets WCAG AA color contrast requirements (4.5:1 for normal text)
    - expect: Important UI elements meet contrast requirements
    - expect: No critical accessibility violations are reported

#### 14.9. Focus Management - Modal Dialogs

**File:** `tests/gameboard/accessibility/focus-management-modals.spec.ts`

**Steps:**
  1. Open a modal dialog (e.g., create team)
    - expect: Focus moves to modal when opened
    - expect: Focus is trapped within modal while open
    - expect: Background content is not accessible via Tab key
  2. Close modal using Escape key or close button
    - expect: Modal closes
    - expect: Focus returns to element that triggered modal

#### 14.10. Responsive Design - Mobile View

**File:** `tests/gameboard/accessibility/responsive-mobile.spec.ts`

**Steps:**
  1. Resize browser to mobile viewport (320x568)
    - expect: Layout adapts to mobile view
    - expect: Navigation becomes mobile-friendly (hamburger menu)
    - expect: All content is accessible and readable
    - expect: No horizontal scrolling is required
    - expect: Touch targets are appropriately sized (minimum 44x44px)

#### 14.11. Responsive Design - Tablet View

**File:** `tests/gameboard/accessibility/responsive-tablet.spec.ts`

**Steps:**
  1. Resize browser to tablet viewport (768x1024)
    - expect: Layout adapts appropriately for tablet
    - expect: Navigation and content are optimized for medium screens
    - expect: All features remain accessible
