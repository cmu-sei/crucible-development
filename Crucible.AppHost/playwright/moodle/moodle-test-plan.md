# Moodle LMS Comprehensive Test Plan

## Application Overview

The Moodle application is a Learning Management System (LMS) integration within the Crucible cybersecurity training platform. It provides course management, student enrollment, content delivery, assessment tools, and grading functionality. Running on port 8081, this Moodle instance may include custom plugins for integration with other Crucible services (Player, Gallery, etc.). This test plan covers authentication flows, course administration, student participation, content management, assessment and grading, user management, Crucible-specific integrations, and comprehensive error handling scenarios.

## Test Scenarios

### 1. Authentication and Authorization

**Seed:** `tests/seed.setup.ts`

#### 1.1. Successful Login with Valid Credentials

**File:** `tests/moodle/authentication/successful-login.spec.ts`

**Steps:**
  1. Navigate to Moodle at http://localhost:8081
    - expect: Moodle home page loads successfully
    - expect: Login link or login form is visible
  2. Click on 'Log in' link if present
    - expect: Login form is displayed with username and password fields
  3. Enter valid username 'admin' in the username field
    - expect: Username field accepts input
  4. Enter valid password 'admin' in the password field
    - expect: Password field accepts input and masks the password
  5. Click the 'Log in' button
    - expect: User is authenticated successfully
    - expect: Dashboard or course page is displayed
    - expect: User menu shows logged-in user name
    - expect: Logout option is available

#### 1.2. Failed Login with Invalid Credentials

**File:** `tests/moodle/authentication/failed-login-invalid-credentials.spec.ts`

**Steps:**
  1. Navigate to Moodle at http://localhost:8081
    - expect: Moodle home page loads successfully
  2. Navigate to login page
    - expect: Login form is displayed
  3. Enter invalid username 'wronguser' in the username field
    - expect: Username field accepts input
  4. Enter invalid password 'wrongpass' in the password field
    - expect: Password field accepts input
  5. Click the 'Log in' button
    - expect: Authentication fails
    - expect: Error message is displayed: 'Invalid login, please try again'
    - expect: User remains on login page

#### 1.3. Failed Login with Empty Credentials

**File:** `tests/moodle/authentication/failed-login-empty-credentials.spec.ts`

**Steps:**
  1. Navigate to Moodle login page
    - expect: Login form is displayed
  2. Leave username field empty
    - expect: Username field is empty
  3. Leave password field empty
    - expect: Password field is empty
  4. Click the 'Log in' button
    - expect: Validation error appears
    - expect: Error message indicates required fields
    - expect: User cannot proceed without credentials

#### 1.4. Session Persistence After Refresh

**File:** `tests/moodle/authentication/session-persistence.spec.ts`

**Steps:**
  1. Log in with valid credentials (admin/admin)
    - expect: User is successfully authenticated
    - expect: Dashboard is displayed
  2. Refresh the browser page
    - expect: User remains authenticated
    - expect: Dashboard loads without redirecting to login
    - expect: User session is maintained

#### 1.5. Logout Functionality

**File:** `tests/moodle/authentication/logout.spec.ts`

**Steps:**
  1. Log in with valid credentials (admin/admin)
    - expect: User is successfully authenticated
  2. Click on user menu in top right corner
    - expect: User menu dropdown opens
  3. Click 'Log out' option
    - expect: User is logged out
    - expect: User is redirected to home page or login page
    - expect: Login link is visible again
  4. Attempt to navigate to a protected route (e.g., dashboard)
    - expect: User is redirected to login page
    - expect: Protected content is not accessible

#### 1.6. Role-Based Access Control - Admin

**File:** `tests/moodle/authentication/rbac-admin.spec.ts`

**Steps:**
  1. Log in with admin credentials
    - expect: User is successfully authenticated as admin
  2. Navigate to Site administration
    - expect: Site administration menu is accessible
    - expect: Admin options are visible (Users, Courses, Plugins, etc.)
  3. Verify admin can access user management
    - expect: User management page loads successfully
    - expect: Options to add, edit, delete users are available

#### 1.7. Role-Based Access Control - Teacher

**File:** `tests/moodle/authentication/rbac-teacher.spec.ts`

**Steps:**
  1. Log in with teacher credentials
    - expect: User is successfully authenticated as teacher
  2. Navigate to assigned course
    - expect: Course page loads
    - expect: Edit mode toggle is available
  3. Turn editing on
    - expect: Edit controls appear
    - expect: Options to add activities and resources are visible
  4. Attempt to access site administration
    - expect: Site administration is not accessible
    - expect: Access denied or option not visible

#### 1.8. Role-Based Access Control - Student

**File:** `tests/moodle/authentication/rbac-student.spec.ts`

**Steps:**
  1. Log in with student credentials
    - expect: User is successfully authenticated as student
  2. Navigate to enrolled course
    - expect: Course page loads
    - expect: Course content is visible
    - expect: Edit mode toggle is NOT available
  3. Attempt to access grading area
    - expect: Grading area is not accessible
    - expect: Access denied or option not visible
  4. Verify student can view and submit activities
    - expect: Activities are viewable
    - expect: Submission forms are accessible where appropriate

### 2. Course Management

**Seed:** `tests/seed.setup.ts`

#### 2.1. Create New Course - Basic Information

**File:** `tests/moodle/courses/create-course-basic.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to Site administration > Courses > Add a new course
    - expect: Course creation form is displayed
  3. Enter course full name 'Cybersecurity Fundamentals 101'
    - expect: Full name field accepts input
  4. Enter course short name 'CS101'
    - expect: Short name field accepts input
  5. Select course category
    - expect: Category dropdown shows available categories
  6. Set course start date
    - expect: Date picker allows date selection
  7. Click 'Save and display' button
    - expect: Course is created successfully
    - expect: Confirmation message appears
    - expect: User is redirected to new course page
    - expect: Course name is displayed correctly

#### 2.2. Create New Course - Validation Errors

**File:** `tests/moodle/courses/create-course-validation.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to course creation form
    - expect: Course creation form is displayed
  3. Leave full name field empty
    - expect: Full name field is empty
  4. Leave short name field empty
    - expect: Short name field is empty
  5. Click 'Save and display' button
    - expect: Validation errors appear
    - expect: Error message indicates required fields
    - expect: Course is not created
    - expect: Form remains on same page with error highlights

#### 2.3. Edit Existing Course

**File:** `tests/moodle/courses/edit-course.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to an existing course
    - expect: Course page is displayed
  3. Click on course settings gear icon or 'Edit settings'
    - expect: Course settings form is displayed with current values
  4. Modify course full name to 'Cybersecurity Fundamentals 101 - Updated'
    - expect: Full name field is updated
  5. Modify course description
    - expect: Description editor accepts changes
  6. Click 'Save and display' button
    - expect: Changes are saved successfully
    - expect: Confirmation message appears
    - expect: Course page shows updated information

#### 2.4. Delete Course

**File:** `tests/moodle/courses/delete-course.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to Site administration > Courses > Manage courses and categories
    - expect: Course management page is displayed
  3. Find test course and click delete icon
    - expect: Confirmation dialog appears asking to confirm deletion
  4. Confirm deletion
    - expect: Course is deleted successfully
    - expect: Confirmation message appears
    - expect: Course no longer appears in course list

#### 2.5. Course Categories Management

**File:** `tests/moodle/courses/manage-categories.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to Site administration > Courses > Manage courses and categories
    - expect: Category management interface is displayed
  3. Click 'Create new category'
    - expect: Category creation form appears
  4. Enter category name 'Cybersecurity Training'
    - expect: Category name field accepts input
  5. Save the new category
    - expect: Category is created successfully
    - expect: New category appears in category list
  6. Move an existing course to the new category
    - expect: Course is moved successfully
    - expect: Course appears under the new category

#### 2.6. Course Visibility Settings

**File:** `tests/moodle/courses/course-visibility.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to course settings
    - expect: Course settings form is displayed
  3. Change course visibility to 'Hide'
    - expect: Visibility dropdown shows 'Hide' option
  4. Save settings
    - expect: Course is hidden successfully
    - expect: Course appears dimmed or with hidden indicator in course list
  5. Log out and log in as student
    - expect: Student cannot see the hidden course in their course list

#### 2.7. Bulk Course Operations

**File:** `tests/moodle/courses/bulk-operations.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to course management page
    - expect: Course list is displayed with checkboxes
  3. Select multiple courses using checkboxes
    - expect: Multiple courses are selected
  4. Select bulk action (e.g., Move to category, Change visibility)
    - expect: Bulk action menu appears with options
  5. Execute bulk action
    - expect: Action is applied to all selected courses
    - expect: Confirmation message appears
    - expect: Changes are reflected in course list

### 3. Student Enrollment

**Seed:** `tests/seed.setup.ts`

#### 3.1. Manual Enrollment - Add Student to Course

**File:** `tests/moodle/enrollment/manual-enroll-student.spec.ts`

**Steps:**
  1. Log in as admin or teacher
    - expect: User is successfully authenticated
  2. Navigate to course and click 'Participants'
    - expect: Participants page is displayed
  3. Click 'Enrol users' button
    - expect: Enrollment dialog appears with user search
  4. Search for user by name or email
    - expect: Search results show matching users
  5. Select user and assign 'Student' role
    - expect: User is added to enrollment list with Student role
  6. Click 'Enrol' or save button
    - expect: User is enrolled successfully
    - expect: User appears in participants list
    - expect: Confirmation message appears

#### 3.2. Manual Enrollment - Add Teacher to Course

**File:** `tests/moodle/enrollment/manual-enroll-teacher.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to course participants page
    - expect: Participants page is displayed
  3. Click 'Enrol users' button
    - expect: Enrollment dialog appears
  4. Search for user and select 'Teacher' role
    - expect: User is added with Teacher role
  5. Complete enrollment
    - expect: User is enrolled as teacher
    - expect: User appears in participants list with Teacher badge/label

#### 3.3. Self-Enrollment

**File:** `tests/moodle/enrollment/self-enrollment.spec.ts`

**Steps:**
  1. Log in as admin and enable self-enrollment for a course
    - expect: Self-enrollment plugin is enabled
    - expect: Enrollment key is set (optional)
  2. Log out and log in as student
    - expect: Student is authenticated
  3. Browse to course page
    - expect: Course page shows 'Enrol me' button
  4. Click 'Enrol me' button
    - expect: Enrollment form appears (with enrollment key field if required)
  5. Enter enrollment key if required
    - expect: Enrollment key field accepts input
  6. Submit enrollment
    - expect: Student is enrolled successfully
    - expect: Course content becomes accessible
    - expect: Confirmation message appears

#### 3.4. Unenroll Student from Course

**File:** `tests/moodle/enrollment/unenroll-student.spec.ts`

**Steps:**
  1. Log in as admin or teacher
    - expect: User is successfully authenticated
  2. Navigate to course participants page
    - expect: Participants list is displayed
  3. Find enrolled student in list
    - expect: Student appears in participants list
  4. Click unenroll icon or action for the student
    - expect: Confirmation dialog appears
  5. Confirm unenrollment
    - expect: Student is unenrolled successfully
    - expect: Student is removed from participants list
    - expect: Confirmation message appears

#### 3.5. Change Student Role in Course

**File:** `tests/moodle/enrollment/change-role.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to course participants page
    - expect: Participants list is displayed
  3. Find enrolled student and access role editing
    - expect: Role editing options are available
  4. Change role from 'Student' to 'Teacher'
    - expect: Role dropdown shows available roles
  5. Save role change
    - expect: Role is updated successfully
    - expect: User now shows Teacher role in participants list
    - expect: User gains teacher permissions

#### 3.6. Bulk Enrollment via CSV

**File:** `tests/moodle/enrollment/bulk-enroll-csv.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to Site administration > Users > Upload users
    - expect: Upload users page is displayed
  3. Prepare CSV file with user data (username, email, firstname, lastname, course1)
    - expect: CSV file is formatted correctly
  4. Upload CSV file
    - expect: File upload succeeds
    - expect: Preview of users to be created/enrolled is shown
  5. Confirm upload
    - expect: Users are created/updated successfully
    - expect: Users are enrolled in specified courses
    - expect: Summary report shows successful enrollments

### 4. Content Management - Activities and Resources

**Seed:** `tests/seed.setup.ts`

#### 4.1. Add Assignment Activity

**File:** `tests/moodle/content/add-assignment.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and turn editing on
    - expect: Edit mode is enabled
    - expect: Add activity buttons appear
  3. Click 'Add an activity or resource' in a section
    - expect: Activity chooser dialog appears
  4. Select 'Assignment' activity
    - expect: Assignment configuration form is displayed
  5. Enter assignment name 'Lab 1: Network Security Analysis'
    - expect: Assignment name field accepts input
  6. Enter assignment description in rich text editor
    - expect: Description editor accepts formatted text
  7. Set due date and cut-off date
    - expect: Date fields accept date selections
  8. Configure submission types (File submissions, Online text)
    - expect: Submission type options are selectable
  9. Set maximum grade
    - expect: Grade field accepts numeric input
  10. Save assignment
    - expect: Assignment is created successfully
    - expect: Assignment appears in course section
    - expect: Confirmation message appears

#### 4.2. Add Quiz Activity

**File:** `tests/moodle/content/add-quiz.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Add new Quiz activity
    - expect: Quiz configuration form is displayed
  4. Enter quiz name 'Module 1 Assessment'
    - expect: Quiz name field accepts input
  5. Configure quiz timing (open/close dates, time limit)
    - expect: Timing fields accept date and time selections
  6. Set grade and attempts allowed
    - expect: Grade and attempts fields accept input
  7. Save quiz
    - expect: Quiz is created successfully
    - expect: Quiz appears in course
  8. Click on quiz to add questions
    - expect: Quiz editing interface loads
    - expect: Add question options are available

#### 4.3. Add Forum Activity

**File:** `tests/moodle/content/add-forum.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Add new Forum activity
    - expect: Forum configuration form is displayed
  4. Enter forum name 'General Discussion'
    - expect: Forum name field accepts input
  5. Enter forum description
    - expect: Description editor accepts text
  6. Select forum type (Standard forum, Q&A forum, etc.)
    - expect: Forum type dropdown shows options
  7. Save forum
    - expect: Forum is created successfully
    - expect: Forum appears in course section

#### 4.4. Add File Resource

**File:** `tests/moodle/content/add-file-resource.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Click 'Add an activity or resource'
    - expect: Activity chooser appears
  4. Select 'File' resource
    - expect: File resource configuration form is displayed
  5. Enter file name 'Course Syllabus'
    - expect: Name field accepts input
  6. Click 'Choose a file' to upload
    - expect: File picker dialog appears
  7. Upload a PDF file
    - expect: File uploads successfully
    - expect: File name appears in form
  8. Save resource
    - expect: File resource is created successfully
    - expect: File appears as downloadable resource in course

#### 4.5. Add URL Resource

**File:** `tests/moodle/content/add-url-resource.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Add new URL resource
    - expect: URL resource configuration form is displayed
  4. Enter resource name 'NIST Cybersecurity Framework'
    - expect: Name field accepts input
  5. Enter external URL 'https://www.nist.gov/cyberframework'
    - expect: URL field accepts valid URL
  6. Select display option (Open, Embed, etc.)
    - expect: Display options are selectable
  7. Save resource
    - expect: URL resource is created successfully
    - expect: Resource link appears in course

#### 4.6. Add Page Resource

**File:** `tests/moodle/content/add-page-resource.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Add new Page resource
    - expect: Page resource configuration form is displayed
  4. Enter page name 'Week 1: Introduction'
    - expect: Name field accepts input
  5. Enter page content using rich text editor with formatting (bold, lists, images)
    - expect: Editor accepts formatted content
    - expect: Formatting toolbar works correctly
  6. Save page
    - expect: Page is created successfully
    - expect: Page appears in course with formatted content

#### 4.7. Edit Activity Settings

**File:** `tests/moodle/content/edit-activity.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course with existing activity
    - expect: Course page shows activities
  3. Enable editing mode
    - expect: Edit controls appear next to activities
  4. Click edit icon (gear) for an activity
    - expect: Activity settings form is displayed with current values
  5. Modify activity name and description
    - expect: Fields accept changes
  6. Save changes
    - expect: Changes are saved successfully
    - expect: Updated activity name appears in course
    - expect: Confirmation message appears

#### 4.8. Delete Activity

**File:** `tests/moodle/content/delete-activity.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Click delete icon for an activity
    - expect: Confirmation dialog appears
  4. Confirm deletion
    - expect: Activity is deleted successfully
    - expect: Activity is removed from course
    - expect: Confirmation message appears

#### 4.9. Duplicate Activity

**File:** `tests/moodle/content/duplicate-activity.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Click duplicate icon for an activity
    - expect: Activity is duplicated
    - expect: Copy appears below original with '(copy)' suffix
  4. Edit duplicated activity to modify settings
    - expect: Duplicate can be edited independently
    - expect: Changes don't affect original

#### 4.10. Move Activity Between Sections

**File:** `tests/moodle/content/move-activity.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Drag activity from one section to another
    - expect: Activity moves to new section
    - expect: Drag and drop works smoothly
  4. Alternatively, use move icon to relocate activity
    - expect: Move mode is activated
    - expect: Section indicators show where activity can be moved
  5. Complete move operation
    - expect: Activity appears in new location
    - expect: Course structure is updated

#### 4.11. Hide/Show Activity

**File:** `tests/moodle/content/hide-show-activity.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and enable editing
    - expect: Edit mode is enabled
  3. Click hide/eye icon for an activity
    - expect: Activity is hidden
    - expect: Activity appears dimmed or with hidden indicator
  4. Log in as student and view course
    - expect: Hidden activity is not visible to student
  5. Log back in as teacher and unhide activity
    - expect: Activity becomes visible again

### 5. Assessment and Grading

**Seed:** `tests/seed.setup.ts`

#### 5.1. Student Submits Assignment

**File:** `tests/moodle/grading/student-submit-assignment.spec.ts`

**Steps:**
  1. Log in as student enrolled in course
    - expect: Student is successfully authenticated
  2. Navigate to course and find assignment
    - expect: Assignment is visible in course
  3. Click on assignment
    - expect: Assignment details page loads
    - expect: Submission form is available
    - expect: Due date is displayed
  4. Upload a file for submission
    - expect: File upload field accepts file
    - expect: Uploaded file appears in submission area
  5. Click 'Submit assignment' button
    - expect: Confirmation dialog appears
  6. Confirm submission
    - expect: Assignment is submitted successfully
    - expect: Submission status shows 'Submitted for grading'
    - expect: Submission date/time is displayed
    - expect: Confirmation message appears

#### 5.2. Student Submits Online Text Assignment

**File:** `tests/moodle/grading/student-submit-online-text.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is successfully authenticated
  2. Navigate to assignment with online text submission
    - expect: Assignment details page loads
  3. Enter text response in online text editor
    - expect: Text editor accepts input
    - expect: Formatting tools work
  4. Submit assignment
    - expect: Text submission is saved
    - expect: Submission status updates
    - expect: Confirmation appears

#### 5.3. Teacher Grades Assignment

**File:** `tests/moodle/grading/teacher-grade-assignment.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to assignment activity
    - expect: Assignment page loads
  3. Click 'View all submissions' or grading interface
    - expect: Grading table shows all student submissions
    - expect: Submission status for each student is visible
  4. Click on a student submission to grade
    - expect: Grading panel opens
    - expect: Submitted files/text are viewable
  5. Enter grade value (e.g., 85/100)
    - expect: Grade field accepts numeric input
  6. Enter feedback comments
    - expect: Feedback editor accepts text
  7. Save grade
    - expect: Grade is saved successfully
    - expect: Student submission status updates to 'Graded'
    - expect: Confirmation message appears

#### 5.4. View Gradebook

**File:** `tests/moodle/grading/view-gradebook.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to course and click 'Grades' in navigation or settings
    - expect: Gradebook is displayed
    - expect: Table shows students in rows and grade items in columns
  3. Verify grades are displayed correctly for graded assignments
    - expect: Grades appear in appropriate cells
    - expect: Totals/averages are calculated
  4. Click on a grade cell to edit inline
    - expect: Grade editing is possible
    - expect: Changes save automatically or with save button

#### 5.5. Student Views Their Grades

**File:** `tests/moodle/grading/student-view-grades.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is successfully authenticated
  2. Navigate to course and click 'Grades'
    - expect: Student's grade view is displayed
    - expect: Only student's own grades are visible
  3. Verify graded items appear with scores
    - expect: Grades for completed assignments are shown
    - expect: Course total/percentage is calculated
  4. Click on a graded item to view feedback
    - expect: Feedback comments from teacher are visible

#### 5.6. Export Grades

**File:** `tests/moodle/grading/export-grades.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to gradebook
    - expect: Gradebook is displayed
  3. Click on 'Export' tab or export option
    - expect: Export options are displayed (Excel, CSV, etc.)
  4. Select Excel spreadsheet format
    - expect: Export configuration options appear
  5. Click 'Download' or 'Submit'
    - expect: Excel file downloads successfully
    - expect: File contains grade data with student names and scores

#### 5.7. Quiz - Student Takes Quiz

**File:** `tests/moodle/grading/student-take-quiz.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is successfully authenticated
  2. Navigate to quiz activity
    - expect: Quiz information page is displayed
    - expect: Start attempt button is available
  3. Click 'Attempt quiz now' button
    - expect: Confirmation dialog may appear
    - expect: Quiz begins with first question
  4. Answer multiple choice question
    - expect: Radio buttons or checkboxes are selectable
    - expect: Selected answer is highlighted
  5. Navigate to next question
    - expect: Next question loads
    - expect: Progress indicator updates
  6. Answer all questions and click 'Finish attempt'
    - expect: Summary page shows all answers
  7. Click 'Submit all and finish'
    - expect: Quiz is submitted
    - expect: Grade is calculated and displayed (if immediate feedback)
    - expect: Submission confirmation appears

#### 5.8. Quiz - Review Attempt

**File:** `tests/moodle/grading/quiz-review-attempt.spec.ts`

**Steps:**
  1. Student completes quiz
    - expect: Quiz submission is complete
  2. Click 'Review' or return to quiz page
    - expect: Review page shows all questions with student answers
    - expect: Correct answers are indicated (if enabled)
    - expect: Feedback for each question appears
  3. Navigate through review pages
    - expect: All questions and feedback are accessible

#### 5.9. Quiz - Manual Grading of Essay Questions

**File:** `tests/moodle/grading/quiz-manual-grade-essay.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is successfully authenticated
  2. Navigate to quiz with essay questions
    - expect: Quiz page loads
  3. Click 'Manual grading' or similar option
    - expect: List of students requiring manual grading appears
  4. Select essay question to grade
    - expect: Grading interface shows student essay responses
  5. Enter grade and feedback for each essay
    - expect: Grade and comment fields accept input
  6. Save grades
    - expect: Grades are saved
    - expect: Quiz totals are recalculated
    - expect: Students can see updated grades

### 6. User Management

**Seed:** `tests/seed.setup.ts`

#### 6.1. Create New User Account

**File:** `tests/moodle/users/create-user.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to Site administration > Users > Accounts > Add a new user
    - expect: User creation form is displayed
  3. Enter username 'testuser001'
    - expect: Username field accepts input
  4. Enter password and confirm password
    - expect: Password fields accept input
    - expect: Password strength indicator appears
  5. Enter first name 'Test'
    - expect: First name field accepts input
  6. Enter last name 'User'
    - expect: Last name field accepts input
  7. Enter email address 'testuser001@example.com'
    - expect: Email field accepts valid email format
  8. Click 'Create user' button
    - expect: User is created successfully
    - expect: Confirmation message appears
    - expect: User profile page is displayed

#### 6.2. Create User - Validation Errors

**File:** `tests/moodle/users/create-user-validation.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to user creation form
    - expect: User creation form is displayed
  3. Leave required fields empty (username, password, email)
    - expect: Required fields are empty
  4. Click 'Create user'
    - expect: Validation errors appear
    - expect: Error messages indicate required fields
    - expect: User is not created
  5. Enter invalid email format 'notanemail'
    - expect: Email validation error appears
  6. Enter username that already exists
    - expect: Error message indicates username is already taken

#### 6.3. Edit User Profile

**File:** `tests/moodle/users/edit-user.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to Site administration > Users > Accounts > Browse list of users
    - expect: User list is displayed
  3. Search for and select a user
    - expect: User profile page loads
  4. Click 'Edit profile' icon or button
    - expect: User profile editing form is displayed with current values
  5. Modify user information (email, first name, last name)
    - expect: Fields accept changes
  6. Save changes
    - expect: Changes are saved successfully
    - expect: Updated information appears in profile
    - expect: Confirmation message appears

#### 6.4. Delete User Account

**File:** `tests/moodle/users/delete-user.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to user management page
    - expect: User list is displayed
  3. Find test user and click delete icon
    - expect: Confirmation dialog appears with warning about consequences
  4. Confirm deletion
    - expect: User is deleted successfully
    - expect: User no longer appears in user list
    - expect: Confirmation message appears

#### 6.5. Assign System Role to User

**File:** `tests/moodle/users/assign-system-role.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to Site administration > Users > Permissions > Assign system roles
    - expect: System roles list is displayed
  3. Select a role (e.g., Course Creator)
    - expect: Role assignment page opens showing currently assigned users
  4. Search for and select user to assign role
    - expect: User appears in potential users list
  5. Add user to role
    - expect: User is assigned role successfully
    - expect: User appears in assigned users list
  6. Log in as that user and verify new permissions
    - expect: User can now create courses (or perform role-specific actions)

#### 6.6. Reset User Password

**File:** `tests/moodle/users/reset-password.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to user profile
    - expect: User profile is displayed
  3. Look for password reset or change password option
    - expect: Password change form appears
  4. Enter new password and confirm
    - expect: Password fields accept input
  5. Save new password
    - expect: Password is updated successfully
    - expect: Confirmation message appears
  6. Log out and log in as that user with new password
    - expect: Login succeeds with new password

#### 6.7. Suspend User Account

**File:** `tests/moodle/users/suspend-user.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is successfully authenticated
  2. Navigate to user profile
    - expect: User profile is displayed
  3. Edit user profile to suspend account
    - expect: Suspension option is available
  4. Set account status to suspended
    - expect: Account suspension is saved
  5. Attempt to log in as suspended user
    - expect: Login fails
    - expect: Error message indicates account is suspended

### 7. Crucible Integration Features

**Seed:** `tests/seed.setup.ts`

#### 7.1. Verify Keycloak SSO Integration

**File:** `tests/moodle/integration/keycloak-sso.spec.ts`

**Steps:**
  1. Clear browser cookies and storage
    - expect: Session is cleared
  2. Navigate to Moodle at http://localhost:8081
    - expect: Moodle loads
  3. Click login link if authentication is required
    - expect: User is redirected to Keycloak login at https://localhost:8443
  4. Enter Keycloak credentials
    - expect: Keycloak authentication succeeds
  5. Verify redirect back to Moodle
    - expect: User is redirected back to Moodle
    - expect: User is logged into Moodle automatically
    - expect: User profile shows Keycloak-sourced information

#### 7.2. Verify xAPI/LRS Integration

**File:** `tests/moodle/integration/xapi-lrs.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is authenticated
  2. Complete a trackable activity (view content, submit assignment, complete quiz)
    - expect: Activity is completed successfully
  3. Check LRsql service at http://localhost:9274 for xAPI statements
    - expect: xAPI statements are recorded
    - expect: Statements contain correct actor, verb, and object data
    - expect: Moodle activities generate corresponding xAPI events

#### 7.3. Course Linking with Player Views

**File:** `tests/moodle/integration/player-course-link.spec.ts`

**Steps:**
  1. Log in as admin in Moodle
    - expect: Admin is authenticated
  2. Check if custom Crucible plugins are installed (e.g., mod_crucible or similar)
    - expect: Custom plugins appear in plugin list or activity chooser
  3. Create or edit a course with Crucible-specific settings
    - expect: Crucible integration fields/options are available
  4. Link course to a Player View ID
    - expect: View ID field accepts input
    - expect: Link is saved
  5. As student, access linked course
    - expect: Course content shows integration with Player
    - expect: Links to Player exercises work correctly

#### 7.4. Gallery Content Integration

**File:** `tests/moodle/integration/gallery-content.spec.ts`

**Steps:**
  1. Log in as teacher
    - expect: Teacher is authenticated
  2. Check for Gallery integration plugin or repository
    - expect: Gallery repository appears in file picker or content sources
  3. Add activity that sources content from Gallery
    - expect: Gallery content browser is available
    - expect: Content from Gallery at http://localhost:4723 can be browsed
  4. Select and embed Gallery content in course
    - expect: Content is embedded successfully
    - expect: Students can access Gallery-sourced materials

#### 7.5. Custom Moodle Plugin - Verify Installation

**File:** `tests/moodle/integration/custom-plugin-verify.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is authenticated
  2. Navigate to Site administration > Plugins > Plugins overview
    - expect: Plugin list is displayed
  3. Search for Crucible-specific plugins
    - expect: Custom plugins appear in list with version and status
  4. Verify plugin settings are accessible
    - expect: Plugin configuration pages load
    - expect: Crucible service URLs are configurable

#### 7.6. Debugging and Logging

**File:** `tests/moodle/integration/debug-logging.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is authenticated
  2. Navigate to Site administration > Development > Debugging
    - expect: Debugging settings page is displayed
  3. Verify debug level is set appropriately for development environment
    - expect: Debug messages setting shows 'DEVELOPER' or similar
  4. Generate an error or warning condition
    - expect: Debug messages appear on page or in logs
  5. Check Moodle logs at Site administration > Reports > Logs
    - expect: Activity logs show recent events
    - expect: Logs can be filtered by user, course, activity

### 8. Navigation and UI

**Seed:** `tests/seed.setup.ts`

#### 8.1. Main Navigation Menu

**File:** `tests/moodle/navigation/main-menu.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is authenticated
  2. Verify main navigation menu is visible
    - expect: Navigation drawer or menu shows Dashboard, Site home, My courses
  3. Click on 'Dashboard'
    - expect: Dashboard page loads showing enrolled courses and timeline
  4. Click on 'My courses'
    - expect: Course list or dropdown shows enrolled courses
  5. Click on a course from list
    - expect: Course page loads with course content

#### 8.2. Breadcrumb Navigation

**File:** `tests/moodle/navigation/breadcrumbs.spec.ts`

**Steps:**
  1. Log in and navigate to a course activity
    - expect: Activity page is displayed
  2. Verify breadcrumb trail appears at top of page
    - expect: Breadcrumbs show path: Dashboard > Course > Activity
  3. Click on course name in breadcrumb
    - expect: User is navigated back to course page
  4. Click on Dashboard in breadcrumb
    - expect: User returns to dashboard

#### 8.3. Course Navigation Block

**File:** `tests/moodle/navigation/course-navigation-block.spec.ts`

**Steps:**
  1. Log in and navigate to a course
    - expect: Course page is displayed
  2. Verify course navigation block/drawer is visible
    - expect: Navigation shows course sections and activities
  3. Click on an activity in navigation
    - expect: User is taken directly to that activity
  4. Expand/collapse sections in navigation
    - expect: Sections expand to show activities or collapse to hide them

#### 8.4. User Menu Dropdown

**File:** `tests/moodle/navigation/user-menu.spec.ts`

**Steps:**
  1. Log in as any user
    - expect: User is authenticated
  2. Click on user avatar/name in top right corner
    - expect: User menu dropdown appears
  3. Verify menu options include Profile, Grades, Messages, Preferences, Log out
    - expect: All expected menu items are present
  4. Click on 'Profile'
    - expect: User profile page loads

#### 8.5. Search Functionality

**File:** `tests/moodle/navigation/search.spec.ts`

**Steps:**
  1. Log in as user
    - expect: User is authenticated
  2. Locate search box (typically in navigation or header)
    - expect: Search input field is visible
  3. Enter search term (e.g., course name or activity name)
    - expect: Search field accepts input
  4. Submit search
    - expect: Search results page loads
    - expect: Matching courses, activities, or content are displayed
  5. Click on a search result
    - expect: User is navigated to the selected item

#### 8.6. Mobile Responsive Layout

**File:** `tests/moodle/navigation/mobile-responsive.spec.ts`

**Steps:**
  1. Set browser viewport to mobile size (e.g., 375x667)
    - expect: Viewport is resized
  2. Navigate to Moodle home page
    - expect: Page layout adapts to mobile view
    - expect: Navigation menu becomes hamburger icon
  3. Click hamburger menu
    - expect: Navigation drawer slides in
  4. Navigate to a course
    - expect: Course content is readable and accessible on mobile
    - expect: No horizontal scrolling required

#### 8.7. Notifications Center

**File:** `tests/moodle/navigation/notifications.spec.ts`

**Steps:**
  1. Log in as user
    - expect: User is authenticated
  2. Click on notification bell icon (if present)
    - expect: Notifications popup or page appears
  3. Verify recent notifications are displayed
    - expect: List of notifications shows recent events (graded assignments, forum posts, etc.)
  4. Click on a notification
    - expect: User is navigated to related content
    - expect: Notification is marked as read

### 9. Error Handling and Edge Cases

**Seed:** `tests/seed.setup.ts`

#### 9.1. 404 Error - Invalid Course URL

**File:** `tests/moodle/errors/404-invalid-course.spec.ts`

**Steps:**
  1. Log in as user
    - expect: User is authenticated
  2. Navigate to invalid course URL (e.g., http://localhost:8081/course/view.php?id=99999)
    - expect: 404 error page is displayed
    - expect: Error message indicates course not found
    - expect: Navigation options to return to dashboard or home are available

#### 9.2. 403 Error - Unauthorized Access to Course

**File:** `tests/moodle/errors/403-unauthorized-course.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is authenticated
  2. Attempt to access a course student is not enrolled in
    - expect: Access denied page is displayed
    - expect: Error message indicates enrollment is required
    - expect: Self-enrollment option appears if available

#### 9.3. File Upload - Size Limit Exceeded

**File:** `tests/moodle/errors/file-size-limit.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is authenticated
  2. Navigate to assignment with file upload
    - expect: Assignment submission form is displayed
  3. Attempt to upload file larger than size limit
    - expect: Upload fails
    - expect: Error message indicates file is too large and shows size limit
    - expect: File is not uploaded

#### 9.4. File Upload - Invalid File Type

**File:** `tests/moodle/errors/file-type-invalid.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is authenticated
  2. Navigate to assignment with restricted file types
    - expect: Assignment form specifies allowed file types
  3. Attempt to upload disallowed file type (e.g., .exe when only .pdf allowed)
    - expect: Upload fails or is rejected
    - expect: Error message indicates invalid file type

#### 9.5. Quiz - Time Limit Expiration

**File:** `tests/moodle/errors/quiz-time-limit-expired.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is authenticated
  2. Start quiz with time limit
    - expect: Quiz begins
    - expect: Timer is visible showing remaining time
  3. Wait for time limit to expire (or simulate time passing)
    - expect: Quiz is auto-submitted when time expires
    - expect: Warning message appears before expiration
    - expect: Answers entered before expiration are saved

#### 9.6. Assignment - Submit After Due Date

**File:** `tests/moodle/errors/assignment-late-submission.spec.ts`

**Steps:**
  1. Log in as student
    - expect: Student is authenticated
  2. Navigate to assignment with past due date
    - expect: Assignment shows as overdue
    - expect: Due date is highlighted or marked
  3. Attempt to submit assignment
    - expect: Submission may be blocked OR allowed with late penalty indication
    - expect: Warning message about late submission appears

#### 9.7. Database Connection Error Handling

**File:** `tests/moodle/errors/database-error.spec.ts`

**Steps:**
  1. Simulate database connection issue (requires test environment control)
    - expect: Error page is displayed with user-friendly message
    - expect: Technical details are hidden from non-admin users
    - expect: Admin sees detailed error information

#### 9.8. Session Timeout

**File:** `tests/moodle/errors/session-timeout.spec.ts`

**Steps:**
  1. Log in as user
    - expect: User is authenticated
  2. Wait for session timeout period (or simulate timeout)
    - expect: Session expires
  3. Attempt to perform an action (e.g., submit form)
    - expect: User is redirected to login page
    - expect: Warning message about session expiration appears
    - expect: After re-login, user data is preserved if possible

#### 9.9. Form Validation - Special Characters

**File:** `tests/moodle/errors/form-validation-special-chars.spec.ts`

**Steps:**
  1. Log in as admin
    - expect: Admin is authenticated
  2. Navigate to user creation form
    - expect: Form is displayed
  3. Enter special characters in username field (e.g., <script>alert('xss')</script>)
    - expect: Validation rejects invalid characters OR special characters are properly escaped
    - expect: No script execution occurs
  4. Attempt to create user
    - expect: Security measures prevent XSS or injection
    - expect: Error message appears if invalid characters used

#### 9.10. Concurrent Editing - Course Content

**File:** `tests/moodle/errors/concurrent-editing.spec.ts`

**Steps:**
  1. Open same course in two browser sessions as teacher
    - expect: Both sessions show course editing interface
  2. In session 1, edit an activity and save
    - expect: Changes are saved
  3. In session 2, edit the same activity without refreshing
    - expect: Potential conflict warning appears OR last save wins
    - expect: Data integrity is maintained
