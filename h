[33mcommit 9b904f04a21c478c6c4f5ea8c2c19f9ebe9a6735[m[33m ([m[1;36mHEAD[m[33m -> [m[1;32mfeature/proxmox-vm-automation[m[33m)[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri Jun 5 01:16:57 2026 +0000

    Verify saved Proxmox API token before recreating
    
    - Check TopoMojo and AppHost configs for existing token
    - Test token against Proxmox API before use
    - Only regenerate if token validation fails (HTTP != 200)
    - Prevents unnecessary token churn that breaks running services
    
    Also update PowerShell script for stable Internal Switch networking:
    - Create "Crucible Internal" switch with NAT
    - Use static IPs (10.0.100.1 gateway, 10.0.100.2 Proxmox)
    - Clean up old port proxy rules automatically
    - IPs stable across Windows reboots
    
    Update Terraform to create live Player view:
    - Two teams (Red Team, Blue Team) with separate VMs
    - View template gets puppy VM for Alloy
    - Use crucible_player_view resource for proper team_ids

[33mcommit 4586e0f79ab1482c33e65cdce68d8e10f502bec4[m
Merge: a8cae99 697ddd7
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Tue Jun 2 20:19:07 2026 +0000

    Merge remote-tracking branch 'origin/main' into feature/proxmox-vm-automation

[33mcommit a8cae9994557c15271f5ef396e7f414aabf8b4bf[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 23:33:50 2026 +0000

    Improve workspace deletion UX when resources are deployed
    
    - Check for deployed resources before allowing delete
    - Show 'Cannot Delete Workspace' dialog when resources exist
    - Hide cancel button in error-only dialogs
    - Add snackbar notification for 409 errors as fallback
    - Update workspace service to return Observable for error handling
    - Refactor deleteWorkspace to use RxJS pipe operators instead of nested subscribes

[33mcommit c7133ff11c22f870ab9e04a8897ba5358cc2ac84[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 21:31:50 2026 +0000

    Re-add dashboard application to Player view template
    
    Dashboard app template a4c361cc-b43f-4c44-99a7-7e2e2b3a9f88 has URL configured in database. Alloy dynamically populates event-specific URLs when creating views.

[33mcommit 1fb475b5cf78eae4fa2d3638fcd8252802aa17d0[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 21:30:16 2026 +0000

    Remove dashboard application from Player view template
    
    Match legacy script behavior - only include VM application, not dashboard. Dashboard app template was not part of original setup.

[33mcommit a1c5bbaf350af71f4ff8a5c1d95c4978206d5717[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 21:16:07 2026 +0000

    Add Crucible Terraform provider to register VMs in Player
    
    Include cmu-sei/crucible provider v2.5 alongside proxmox provider. Creates crucible_player_virtual_machine resources to register Proxmox VMs in Player VM API. Adds all required Crucible provider variables and credentials to tfvars.

[33mcommit d9308e6689c8cf20dfe3d5109490ae0e646362f2[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 21:03:58 2026 +0000

    Add applications to Admin team in Player view template
    
    After creating view applications, explicitly add them to the Admin team so they're visible to team members.

[33mcommit 94092b2db2fdd9babd9dbf69e8b2e76e434ff8ca[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 20:46:02 2026 +0000

    Fix Alloy event to delete all duplicates by name, not just by ID
    
    Find all events with target name, check their directoryId. Keep one with correct directory, delete all others. Prevents duplicate events with same name.

[33mcommit 9b4f122250e294bb7e063a22b20180a4578de92e[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 20:44:20 2026 +0000

    Add fallback to create Alloy event without ID if API rejects it
    
    Try creating with specified ID first. If that fails, retry without ID and let API generate one. Show error response for debugging.

[33mcommit 6448fada49d889328820c8e10e9d4a6507b0bdaf[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 20:43:25 2026 +0000

    Fix Alloy event check to use expected ID instead of name lookup
    
    Check for event by exact ID, not by name. Prevents issues when event ID doesn't match expected RESOURCE_IDS value.

[33mcommit 2fc9919c0c01fad3b34859494426be588bf7f664[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 20:42:27 2026 +0000

    Fix Alloy event to verify and update directory ID if incorrect
    
    When Alloy event exists, check if directoryId matches expected value. If wrong, delete and recreate the event with correct Caster directory.

[33mcommit 790a7e541fc615d0d88bc31b5e3c3bfe43c0dc97[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 17:28:11 2026 +0000

    Add Terraform file upload when directory exists but files are missing
    
    Check for existing files in directory. If none exist, upload main.tf, variables.tf, and terraform.tfvars even when directory already exists.

[33mcommit 5cab4bc332ef72c3a76da7e1267630136e85164e[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 17:25:37 2026 +0000

    Fix directory existence check to look for specific directory ID
    
    Check for the exact directory ID we're trying to create, not just any directory for the project. Prevents false positives from orphaned directories with different IDs.

[33mcommit 448eaa62ec1767a62a04ea223ae8bb115094ab1f[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon Jun 1 17:13:57 2026 +0000

    Fix Caster directory creation to work when project already exists
    
    Check for existing directory when project exists. If directory missing, fall through to create it. Refresh token before directory creation in both paths (new project and existing project).

[33mcommit 697ddd7f92eb0d8e0b0903d47c990aa6fe6046c6[m[33m ([m[1;32mmain[m[33m, [m[1;32mfix/cite-no-results-position[m[33m)[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Sat May 30 21:52:11 2026 -0400

    Use kubefwd instead of kubectl port-forward (#90)

[33mcommit 25d9c0a166c1e375cd0bffaeb51edbd49d38a840[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 22:53:05 2026 +0000

    Remove unnecessary sleep after project creation
    
    Project creation is now immediate - no need to wait for DB commit

[33mcommit 4440981068d826193e61040a7cbfafaa884802f1[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 22:12:44 2026 +0000

    Add debug logging for Caster directory creation payload
    
    Show projectId being sent to help diagnose why API returns 'Project does not exist'

[33mcommit b6d616b3306ba2c96cfb20052641f5e6f084ce0a[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:47:13 2026 +0000

    Add 2s delay after token refresh before directory creation
    
    Directory creation validates project exists in DB. Even with fresh token, need brief wait for transaction commit.

[33mcommit 91a55de6be583c1d93449daf5c782566404f728e[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:46:03 2026 +0000

    Fix Caster directory creation by refreshing token after project creation
    
    Token claims are cached and don't include newly created project. Get fresh token after POST /projects so directory creation has proper project permissions.

[33mcommit 110039488e0ba65a76aaa44d124ec30628ade978[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:37:13 2026 +0000

    Simplify Caster project creation - use 3s sleep instead of verification loop
    
    GET /projects/{id} fails due to partition isolation. List endpoint works but individual GET returns 404 even though project exists in partition. Just wait 3s for DB commit.

[33mcommit 42fbebdf1cc92d4b00e02c6c12008614b06a4d5d[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:35:44 2026 +0000

    Add retry loop to verify Caster project exists before directory creation
    
    Poll GET /projects/{id} up to 10 times with 1s sleep to confirm project is queryable before attempting directory creation

[33mcommit 54eaf7c746375e6356fd92e2197924f8d5c4cb05[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:32:27 2026 +0000

    Add 2s delay after Caster project creation before directory creation
    
    Fixes race condition where directory creation API call fails with 'Project does not exist' because project hasn't been committed to database yet

[33mcommit b00b760451ad844bb7067b07575e14b6de401df0[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:22:58 2026 +0000

    Add detailed error logging for Caster directory creation failures
    
    Show actual error message from API response instead of generic 'Failed to create directory'

[33mcommit 3bd95db0beecf2559dafe19b2324ee80b272e922[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:16:57 2026 +0000

    Add debug output to show template names and isPublished values during query

[33mcommit a4b55e1121744933fee31f72c9213531c05e696d[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:16:40 2026 +0000

    Fix jq error - handle missing isPublished field and suppress jq errors

[33mcommit db23864de1cef353635ce37ad1578bdf3399924b[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:14:01 2026 +0000

    Fix bash comparison error - use wc -l for proper integer count

[33mcommit db0eefce18843244dff98dc71a585dd59a26077c[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:12:09 2026 +0000

    Fix idempotency: skip creation if exactly ONE template exists
    
    - Count existing workspace templates (unpublished only, excludes stock)
    - If exactly 1 exists: skip creation entirely (already correct)
    - If 0 exist: create new one
    - If >1 exist: delete all duplicates, then create one
    
    This prevents deleting correct templates and creating duplicates.

[33mcommit 50c81338ebc81c9795917b247fdccbc521bb4a85[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:08:31 2026 +0000

    Fix template query to use /api/templates instead of workspace-specific endpoint
    
    The workspace endpoint was returning 0 templates, causing duplicates.
    Query all templates globally and filter by name pattern to catch orphaned templates.

[33mcommit 2d47f8913c237953859e9d1ef2751470a6661dd8[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:06:54 2026 +0000

    Add debug logging to show template count found in workspace

[33mcommit aefcc81d66947d148c91e98d5f8dacee70776037[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:05:53 2026 +0000

    Add proper error checking and logging to template deletion
    
    - Log HTTP status codes from DELETE operations
    - Count successful deletions
    - Wait 2 seconds after deletion before creating new templates
    - Report failures instead of silently ignoring them

[33mcommit 9c6f197b0bb7f1746f69b5b078ca4f2012180846[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:04:30 2026 +0000

    Fix syntax errors from if/elif/else restructuring - remove extra fi statements

[33mcommit 8ecf05138954a99ff36b8442802e34da398f3288[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 21:03:24 2026 +0000

    Make template creation truly idempotent - delete all existing before creating
    
    - Always delete ALL existing templates of the target type before creating
    - No more 'already exists, skipping' logic that leaves duplicates
    - Ensures exactly ONE template per workspace no matter how many times setup runs
    - Fixes puppy-workspace-210 and puppy-workspace-624 duplicate issue

[33mcommit bcb98bb317b34b5d75677cb8cca7d5ec630b0c2f[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 20:51:36 2026 +0000

    Reduce TinyCore stock template to 1GB RAM and 1 CPU to minimize memory usage

[33mcommit 97293ec10d1d4b6413bcbe0f28bbf4b917c89108[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 20:49:11 2026 +0000

    Fix TinyCore RAM: change from 0.25GB to 1GB (TopoMojo requires integers)

[33mcommit fbd2efe37842e532a6086fd5383d44669561c62b[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 20:47:17 2026 +0000

    Add Puppy Linux stock template creation
    
    Create three stock templates (published, global):
    - TinyCore-ISO-Stock
    - Alpine-Disk-Stock
    - Puppy-Linux-Stock (1GB RAM)

[33mcommit bc99bb5410681ac98715b3ad13739fe3ce3398b0[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 20:44:12 2026 +0000

    Add cleanall command and SSH config auto-setup
    
    - cleanall: Removes ALL resources including Proxmox VMs and templates
    - clean: Only removes TopoMojo/Player/Caster/Alloy resources (keeps VMs)
    - setup: Auto-configures ~/.ssh/config for passwordless 'ssh proxmox' access
    - Stops all running VMs before deleting
    - Preserves template VMs 105, 106, 9001-9003 during normal clean

[33mcommit 0962db8c63d5316d2df3c5bfa7f48e7ca9eb89a9[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 20:36:05 2026 +0000

    Configure workspaces with correct VMs: Basic=Puppy, Variants=TinyCore
    
    - Basic workspace (no variants) uses Puppy Linux template
    - Variants workspace uses TinyCore (256MB) template
    - Duplicate template cleanup ensures only ONE template per workspace

[33mcommit 2b3dbc62d642da69dd2d47c3df40aeb10a6afd88[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 20:23:47 2026 +0000

    Reduce TinyCore RAM from 512MB to 256MB to minimize memory usage
    
    TinyCore Linux can run on 256MB, reducing per-VM memory footprint
    to help with Proxmox memory exhaustion issues.

[33mcommit b12ded5f54b1de8bc0688512965bf4c33ffcf6b6[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 20:22:12 2026 +0000

    Use TinyCore template for all workspaces to reduce memory usage
    
    Changed from Puppy (1GB RAM) to TinyCore (512MB RAM) for Variants workspace
    to minimize memory pressure on Proxmox VM.

[33mcommit 4d0a4693e449836982cec5579960e2a8ec032c42[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 20:16:39 2026 +0000

    Improve duplicate template prevention in setup script
    
    - Refresh template list on each check (not just once at start)
    - Remove duplicate templates at beginning of template creation
    - Keeps only first occurrence of each template name pattern

[33mcommit 495c29b9e489ee6a67bb81ede44578276b7b8e32[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 19:58:08 2026 +0000

    Update Moodle and TopoMojo configuration
    
    - Enable TopoMojo Console Forge (usingconsoleforge=1)
    - Update TopoMojo API key configuration
    - Revert KC_HOSTNAME to localhost for OAuth compatibility

[33mcommit 56984979a04bbe9075b97e08e8b788e1a8563525[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 19:50:49 2026 +0000

    Revert OAuth user enrollment - users don't exist until first login
    
    OAuth users are auto-created on first login, so enrollment must be done manually
    after users authenticate.

[33mcommit 32e20fce31716a1819f2fab92b7cbafb3e653ec0[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 19:50:19 2026 +0000

    Enroll demo-user (student) and contentdev (teacher) in Test Course
    
    Automatically enroll demo-user as student (role 5) and contentdev as teacher (role 3)
    in the Test Course during Moodle post-configuration.

[33mcommit 2e5b3a56740607cbece2379c9ac8a97e5d523219[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 19:47:33 2026 +0000

    Enable TopoMojo Console Forge in Moodle configuration
    
    Set usingconsoleforge=1 in mod_topomojo plugin configuration.

[33mcommit 5609f367ee5246c51efbef8680f5d531c4ff46bc[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 19:23:08 2026 +0000

    Revert "Add Proxmox hypervisor configuration to base appsettings.json"
    
    This reverts commit 3e49570e7805658783aeb0836b0621909ab5d4a3.

[33mcommit 3e49570e7805658783aeb0836b0621909ab5d4a3[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 19:22:01 2026 +0000

    Add Proxmox hypervisor configuration to base appsettings.json
    
    Configuration was in gitignored appsettings.Development.json and not being loaded.
    Moved to base appsettings.json so TopoMojo can access Proxmox.

[33mcommit 1b675e6f17d2c5f28b2f7c0938729bacfbe15ea0[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 18:39:59 2026 +0000

    Auto-configure TopoMojo API key from file created by AppHost script

[33mcommit 080fdea572e429cebd1862515c7670af7e2a3d4e[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 18:32:09 2026 +0000

    Add KC_HOSTNAME_STRICT_BACKCHANNEL=false to fix token issuer validation

[33mcommit df4c36a12716e4e71da1e389e9ae9e5479439cc5[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 18:31:29 2026 +0000

    Revert Keycloak config to match main: restore KC_HOSTNAME and KC_HTTPS_PORT

[33mcommit 7e4e0a148f1c45a5c5be8c3cb13d9c92bf8cc1cc[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 18:25:40 2026 +0000

    Fix KEYCLOAK_URL: use keycloak.dev.internal for Moodle backend discovery

[33mcommit 072878ef859c58ddee0329cf808d1595ea4665e8[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 18:15:45 2026 +0000

    Fix OAuth endpoints: use keycloak.dev.internal for backend token/userinfo calls

[33mcommit f7a06b0e56819a6303c3062c99d681cbfe9bdc59[m
Merge: 7bf6617 4e482c2
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 17:45:06 2026 +0000

    Merge main into feature/proxmox-vm-automation

[33mcommit 7bf661791880ef5c364d032988ea5667fa3f2d77[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 17:44:56 2026 +0000

    Fix Moodle OAuth: use localhost:8443 for browser accessibility from Windows host

[33mcommit 3847d2d048ac8d8b61469e700a25dfbc50bc88a4[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 17:43:56 2026 +0000

    Revert Moodle OAuth to HTTPS port 8443 (original working config)

[33mcommit 94d427cefd8eaf3c4697cae29c08ae0825477f1a[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 17:37:58 2026 +0000

    Fix Moodle OAuth: use HTTP port 8080 instead of HTTPS port 8443

[33mcommit bff21e279b9d5a18c5b9c0f8178d53031af4a9ea[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 17:36:34 2026 +0000

    Revert Keycloak URL: use keycloak.dev.internal for internal container networking

[33mcommit d9feaf47d794026f11122b00a94c52a844da1b1f[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 17:27:54 2026 +0000

    Fix Moodle OAuth: use http://localhost:8080 instead of https://keycloak.dev.internal:8443

[33mcommit d6a8d60e6a1dff6f6157320ec68072ac7e17cf0a[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 17:25:02 2026 +0000

    Fix Moodle OAuth redirect URI: add port 8081

[33mcommit ccb430dbb74fd2b6de35f1218ae938fcfb8054d6[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:48:39 2026 +0000

    Remove debug logging - templates working correctly now

[33mcommit 5a47b639aee0e297bc48dfc9331b2c75282deebe[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:47:01 2026 +0000

    Fix Puppy template RAM: use 1 GB (integer) not 0.5 (float)

[33mcommit 26b2923e4815d29b8c3e72b51ee358f0c92259bf[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:37:17 2026 +0000

    Add debug logging for Puppy template request payload

[33mcommit cd3d3bb4dc0161b3f8e9198aff09fc2bd728c3e7[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:36:05 2026 +0000

    Fix template checks and Puppy template reference
    
    - Check for template names with suffixes (e.g., tinycore-workspace-377)
    - Use Puppy-Linux (VM 9003) instead of puppy-test (VM 103 is not a template)

[33mcommit 5fa9843899b836474dd02ad5cef47437deab67e1[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:34:28 2026 +0000

    Fix template type in existing workspace path (puppy not alpine)

[33mcommit 45797f0610c2b86ece1802bd2f03aabaed126f14[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:33:45 2026 +0000

    Fix Puppy template reference: use puppy-test (VM 103) not Puppy-Linux

[33mcommit a6e53702232ae0d29be8aba4184e22d24b902949[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:31:04 2026 +0000

    Use Puppy Linux template for Variants workspace instead of Alpine

[33mcommit 678929b70812e5b9c6c287f25ed98105e88146c4[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:29:20 2026 +0000

    Add debug logging for Alpine template creation failure

[33mcommit cd75d4a3812833e87cde20dbfaa833958d425e66[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:26:51 2026 +0000

    Fix challenge variant count parsing and improve Alpine error logging
    
    - Parse challenge as JSON string then extract variants
    - Show raw response body if jq parsing fails
    - Increase error message length to 500 chars

[33mcommit ed263aeb7a27d22f5c84c6cfb34cd04715300dcc[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:26:00 2026 +0000

    Fix challenge field: API expects JSON string, not object

[33mcommit 7e53caac990cf7c554f77418cfc65023db0e0c0d[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:25:09 2026 +0000

    Show validation errors when workspace creation fails

[33mcommit 43cb18676ae822aa34abcd5a7e3cdb31338a2b51[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:24:00 2026 +0000

    Add template cleanup logging to show what's being deleted

[33mcommit 71a9fc22aeb2e9e1159be88adec464354e1ed2d5[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:23:01 2026 +0000

    Fix workspace challenge creation and template cleanup
    
    - Include challenge JSON in initial POST instead of PUT update (API doesn't support PUT)
    - Check for existing workspace and skip if already created
    - Make template cleanup regex case-insensitive to catch all variants
    - Add HTTP status codes to all error messages

[33mcommit ea106d51b6aada18aebe70ff2d0f160252031534[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:22:04 2026 +0000

    Fix template counter regex to match actual template names

[33mcommit 7b9a57fbe229b4365d1512182871b46c52a8aaa9[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:05:35 2026 +0000

    Add detailed HTTP status and error logging for template creation and linking
    
    - Capture HTTP response codes for all API calls
    - Log template creation failures with actual error messages
    - Log template linking failures separately from creation failures
    - Show full error response when challenge variant update fails

[33mcommit 75124c1a95762b8c738cc5546e1c831f85cd9feb[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 16:02:35 2026 +0000

    Improve error reporting for template creation and challenge variant updates

[33mcommit 163d0d7fba94e9e6cdcbfdb55ec6930019c45c96[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:59:10 2026 +0000

    Fix template assignments: Basic workspace uses TinyCore, Variants uses Alpine
    
    - Modified create_topomojo_templates() to accept template_type parameter
    - Basic workspace now creates tinycore-workspace template (VM 9001)
    - Variants workspace now creates alpine-workspace template (VM 9002)
    - Removed all old duplicate template linking code

[33mcommit f648cc4ed5fe086723a7f7b0e3125a671900e0d1[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:48:18 2026 +0000

    Simplify template names (remove workspace GUID suffix)
    
    - TinyCore-Workspace-{guid} -> tinycore-workspace
    - Template names are now simple and consistent

[33mcommit ae897ed2c887d2dff514885217989c5e5d7bdd33[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:45:34 2026 +0000

    Fix syntax error in Puppy template creation
    
    - Added missing closing braces for if statements
    - Script now passes bash syntax check

[33mcommit 50eb64a941909791ca894d5664ae7d92b90e4ba1[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:44:29 2026 +0000

    Add proper hardcoded GUIDs for all resources
    
    - Workspaces: 2 real GUIDs
    - Stock templates: 2 real GUIDs (TinyCore, Alpine)
    - Linked templates: 2 real GUIDs (basic workspace links to stock)
    - Workspace-specific: 1 real GUID (Puppy in variants workspace only)
    - All GUIDs are properly formatted UUIDs

[33mcommit d29bce27878ad2c61e5cc1b6dd256fc190611d5e[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:42:38 2026 +0000

    Add hardcoded IDs for 2 stock templates
    
    - TinyCore-ISO-Stock: b0000000-0000-0000-0000-000000000001
    - Alpine-Disk-Stock: b0000000-0000-0000-0000-000000000002
    - Pass IDs during template creation

[33mcommit d2530afd05edf2d38f98325e34c20e7a7675095d[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:42:01 2026 +0000

    Add hardcoded workspace GUIDs (API may ignore them)
    
    - WORKSPACE_BASIC_ID: a0000000-0000-0000-0000-000000000001
    - WORKSPACE_VARIANTS_ID: a0000000-0000-0000-0000-000000000002
    - Pass IDs during creation (API may still generate its own)

[33mcommit 84713989db2f5741866383965f2cf7bcc9c39801[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:40:44 2026 +0000

    Make clean actually delete everything
    
    - Delete workspaces completely (not just empty them)
    - Delete all templates
    - Clean means clean - remove everything

[33mcommit 83acf91fc426fb40fccc09821e2dedb1dafdfff3[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:34:51 2026 +0000

    Fix cleanup and revert hardcoded IDs (API doesn't support them)
    
    - TopoMojo API ignores custom IDs, generates its own
    - Cleanup now properly deletes all templates (global and workspace-specific)
    - Cleanup preserves workspaces for consistent GUIDs (setup reuses existing)
    - Removed hardcoded ID constants (don't work with API)

[33mcommit 7aa3314b4771ec6122b698b14244fd4e082a1022[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:33:15 2026 +0000

    Fix cleanup to actually delete workspaces and templates
    
    - Previously only unlinked templates (kept workspaces)
    - Now deletes workspaces completely
    - Setup will recreate with hardcoded GUIDs for consistency

[33mcommit b47fb545d8f684a05021300ce4910a833b3718dc[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:31:35 2026 +0000

    Skip VM creation if VMs already exist
    
    - Check if VMs 103, 105, 106 exist before creating
    - Prevents recreating existing VMs on multiple setup runs
    - Makes VM creation idempotent

[33mcommit 6fabaaf6ae83267ea86510959a8eca3afa6ea0d8[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:30:37 2026 +0000

    Add hardcoded resource IDs for consistency across runs
    
    - Added readonly constants for all resource IDs at top of script
    - TopoMojo workspaces use consistent GUIDs
    - Caster projects, Player views, Alloy events use fixed IDs
    - Resources will have same ID every time (even after cleanup)

[33mcommit dd66c70779e0b48ec8ea1cb4d772a2e9a3b696d8[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:29:27 2026 +0000

    Only add challenge variants if they don't exist
    
    - Check workspace for existing variants before updating
    - Skip challenge update if workspace already has 3 variants
    - Prevents overwriting or duplicating challenge spec

[33mcommit f089da6ae08afe334b0025fbe391053d139d08ff[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:29:03 2026 +0000

    Only create templates that don't already exist in workspace
    
    - Check each template individually before creating
    - Skip template if it already exists (no duplicates)
    - Allows partial template creation (some exist, some don't)

[33mcommit b0191c238fdd80b53e716cb2c3e7cd86525841d1[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:27:36 2026 +0000

    Exit with error if token exists but secret is missing
    
    - Cannot make API calls without token secret
    - Script now errors and tells user to delete token and re-run
    - Prevents setup from continuing in broken state

[33mcommit 02722c98d05ae73a4785d408c0981724fc4afa5b[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:23:33 2026 +0000

    Never fail on missing token, just warn and continue
    
    - Token creation is now optional if token already exists on Proxmox
    - Load config early in mode_setup to preserve existing token
    - Setup will continue even if we can't retrieve existing token secret
    - Token is preserved across all runs

[33mcommit 9c123811ff62002ba44eac40cab32de7d10d18c9[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:22:24 2026 +0000

    Simplify script to only support setup, reset, clean commands
    
    - Remove all --skip-* flags (too many options, not needed)
    - Remove --dry-run, -h/--proxmox-host options
    - Only use PROXMOX_HOST environment variable
    - Usage: export PROXMOX_HOST='IP' && ./script.sh {setup|reset|clean|status|fix}

[33mcommit 20ccabe4bc8da8d1b1a216876a35bb7c47c051d0[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:20:54 2026 +0000

    Fix: Never overwrite or delete existing token
    
    - save_config() now preserves existing token when PROXMOX_API_TOKEN is empty
    - Prevents token loss when running setup with --skip-infrastructure
    - Removed automatic token deletion (user must manually delete if needed)
    - Token is only created once and preserved across all subsequent runs

[33mcommit 7a6ca06910cbea63ac778f4f92f6ec84c85c062b[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:19:17 2026 +0000

    Fix challenge variant creation and preserve workspace GUIDs on reset
    
    - Fix challenge JSON encoding (was string, should be object)
    - Verify challenge variants are actually added
    - Preserve workspaces during cleanup (only remove templates)
    - Ensures consistent workspace GUIDs across reset/setup cycles

[33mcommit 3f972caa201e53b74e0ab7421053f64b2b64a34f[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:16:41 2026 +0000

    Fix: Prevent duplicate template creation
    
    - Check if workspace already has templates before creating
    - Skip template creation if templates exist
    - Prevents duplicate templates on multiple runs

[33mcommit 846d2b3508921e67c873edac5349640b5357236f[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:16:00 2026 +0000

    Fix: Auto-delete and recreate token when missing from config
    
    - Previously errored when token existed on Proxmox but not in config
    - Now automatically deletes old token and creates new one
    - Handles case where reset clears config file

[33mcommit fc35c06d527fe5301d3c3fdfa5e38e5a053aa94b[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:13:53 2026 +0000

    Fix: Create challenge spec even when workspace already exists
    
    - Previously only created variants when creating new workspace
    - Now creates/updates challenge spec and templates for existing workspaces
    - Ensures 3 challenge variants are present for Moodle testing

[33mcommit d53d4bc36ed590ddb740a398c4db5ffcea7ca625[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 15:08:03 2026 +0000

    Fix Proxmox OIDC to use Windows host IP instead of Docker IP
    
    - Auto-detect Hyper-V Default Switch gateway (x.x.16.1) for KEYCLOAK_HOST
    - Previous detection used Docker container IP (unreachable from browser)
    - Now uses Windows host IP that both Proxmox and browser can reach
    - Fixes ERR_TOO_MANY_REDIRECTS when logging in via OIDC

[33mcommit 4e482c2e50d4b6c25070c8bac48cb41da4ff5c91[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Fri May 29 10:56:56 2026 -0400

    Add missing certificateMap to Alloy values for deploying in minikube (#89)

[33mcommit fa42b65d697c9093e74c256d7e4504147c0166b2[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 14:54:26 2026 +0000

    Improve error messages for failed template creation
    
    - Show full error response instead of just 'Error'
    - Use .detail field as fallback for error messages

[33mcommit 119c330a580938aedfcfd3c4d65048a12c5e26b3[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 14:50:29 2026 +0000

    Fix: Create TopoMojo templates even when workspace exists
    
    - Previously skipped template creation if workspace already existed
    - Now always attempts to create stock and workspace templates

[33mcommit b068102f96e7d5f5d7448fa8a100f624aa47128d[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 14:49:32 2026 +0000

    Fix TopoMojo template creation to use correct API endpoints
    
    - Use /api/template-detail to create templates (not /api/workspace/{id}/template)
    - Use /api/template with TemplateLink payload to link templates to workspace
    - Add error messages for failed template creation
    - Add workspace ID to template names to avoid conflicts

[33mcommit 1f527f8ee01a9230554f9e7720c07e0f11e1d8af[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 14:41:29 2026 +0000

    Fix: Load token from config when token already exists
    
    - When token exists on Proxmox, load PROXMOX_API_TOKEN from config file
    - Prevents saving empty token to config on subsequent runs
    - Fail if token exists but not in config (instead of silent empty save)

[33mcommit c9c7d5e32c8eb87f49f14967ff3ae275449b5277[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 14:30:12 2026 +0000

    Fix: Don't regenerate Proxmox token if it already exists
    
    - Check if token exists before creating
    - Keep existing token to avoid invalidating running services
    - Prevents 'invalid token' errors in TopoMojo after re-running setup
    - Only create token on first setup or if missing

[33mcommit 2d00807e0b7cf766b8723235d5fc88a8f3aa0c40[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 14:26:13 2026 +0000

    Add Proxmox OIDC verification and auto-fix
    
    - Automatically add/update keycloak in Proxmox /etc/hosts
    - Verify OIDC realm exists after creation
    - Verify groups exist (crucible-admins, crucible-developers, crucible-observers)
    - Test Keycloak accessibility from Proxmox
    - Fail loudly if configuration is incorrect
    - Ensures Proxmox OIDC is properly configured

[33mcommit 59f648f037f12a44c8da824b38a9b43b06f7d3f9[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 13:55:29 2026 +0000

    Fix: Load config before auto-configure AppHost
    
    - Load ~/.crucible-proxmox to get PROXMOX_API_TOKEN
    - Ensures auto-configure works even when only PROXMOX_HOST is exported
    - AppHost configuration will now run automatically

[33mcommit 8f8600c01a89acd13d6286aba84fa9168cbbb909[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 13:54:28 2026 +0000

    Fix: Call toggle script with bash to avoid permission issues
    
    - Use 'bash script.sh' instead of './script.sh'
    - Avoids permission denied errors if +x bit is lost
    - More portable across different environments

[33mcommit 4a0ca28539753dd461c06315ec5c78c6c5b82aee[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 13:51:27 2026 +0000

    Fix variable name: PROXMOX_API_TOKEN not PROXMOX_TOKEN
    
    - Auto-configure check was using wrong variable name
    - Config file exports PROXMOX_API_TOKEN
    - AppHost auto-configure will now work correctly

[33mcommit ca90e13c6e519816005dfaa33670f5093af88f75[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 13:48:48 2026 +0000

    Fix token extraction: use grep -oE to extract UUID only
    
    - grep -oE extracts only the matching pattern (UUID)
    - Removes leading/trailing whitespace automatically
    - Eliminates empty token issue
    - Token format: root@pam!CRUCIBLE=<clean-uuid>

[33mcommit d7343dfe2f3eaedfa8f02b08950de76cc6e1d4b8[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 13:43:43 2026 +0000

    Fix TopoMojo template creation: stock + workspace-specific + linked
    
    - Create stock templates once (TinyCore-ISO-Stock, Alpine-Disk-Stock)
    - Each workspace gets 5 templates:
      * 2 workspace-specific (not linked)
      * 2 linked from stock templates (test parent/child)
      * 1 Puppy Linux (workspace-specific)
    - Eliminates duplicate stock templates
    - Tests all TopoMojo template scenarios
    - Templates now appear in workspace template list

[33mcommit af6f7eb56d0502bfe5f8984132bd87bbc06014a1[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 13:31:08 2026 +0000

    Fix: Extract token UUID correctly from pveum output
    
    - Filter for UUID pattern (36 chars with hyphens) instead of raw column
    - Removes spurious 'value' text from token string
    - Fixes token format: root@pam!CRUCIBLE=<uuid> (not 'value <uuid>')
    - Use grep -E with UUID regex to extract clean token

[33mcommit 1219c4e0582c7ae4465352a1b29499c7fcf17bcf[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 13:28:05 2026 +0000

    Fix: Remove duplicate proxmox-web client properly
    
    - Used jq unique_by to remove duplicate safely
    - Preserves JSON structure correctly
    - Fixes Keycloak import error at line 3043
    - Only one proxmox-web client remains

[33mcommit 61a14c1940190373afa6c32370b68d2a749fdf0b[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 29 12:58:39 2026 +0000

    Fix: Preserve environment variables passed to script
    
    - Use ${VAR:-default} instead of VAR="" to preserve env vars
    - PROXMOX_HOST can now be passed as environment variable
    - PROXMOX_API_TOKEN also preserved from environment
    - Fixes: PROXMOX_HOST=IP ./script.sh setup now works correctly

[33mcommit 948a321d1b68fad5035e6ed9c6e400d58c58b4a0[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 21:08:00 2026 +0000

    Auto-load Proxmox config from ~/.crucible-proxmox
    
    - If PROXMOX_HOST not set, try loading from config file
    - Eliminates need to export env vars on every shell session
    - Config file created during setup with host and token
    - Matches toggle script behavior (already auto-loads)

[33mcommit f1f0f7d37c60fb6d1d003c1d3f32838be430da73[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 21:06:14 2026 +0000

    Auto-configure AppHost after Proxmox setup completes
    
    - Automatically runs toggle-topomojo-hypervisor.sh proxmox at end
    - Only if PROXMOX_TOKEN is set (from saved config)
    - One less manual step for users
    - Complete workflow: PowerShell → Install → Bash script → Done!

[33mcommit 92b842c8a4637dac44ea5a5cb5e719ba752b1da3[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 21:05:18 2026 +0000

    Rename crucible-proxmox.sh to setup-crucible-proxmox.sh
    
    - Makes script purpose clearer (setup script)
    - Consistent with setup-proxmox-windows.ps1 naming

[33mcommit c1fd146280ade54a4a4a8f9e06748bc3f06ee81b[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 21:03:56 2026 +0000

    Remove obsolete update-proxmox-appsettings.sh script
    
    - Replaced by centralized AppHost configuration
    - toggle-topomojo-hypervisor.sh now updates AppHost appsettings.json
    - AppHost injects environment variables into apps
    - No need to manually edit individual app appsettings files

[33mcommit 2d87856b9f26299ecd58ca6c389067043f93568e[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 21:02:39 2026 +0000

    Remove all legacy scripts
    
    - Legacy scripts replaced by consolidated crucible-proxmox.sh
    - All functionality now in single idempotent script
    - Removes 38 legacy scripts and README

[33mcommit de0bd8e7ff70d011f50171f5d218c0b9a747b847[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 21:00:01 2026 +0000

    Remove TOGGLE-HYPERVISOR.md - consolidated into main README
    
    - All hypervisor documentation now in root README.md
    - Eliminates duplicate documentation

[33mcommit 872c922dde100adaa819373aab63c86f130256f9[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:59:37 2026 +0000

    Remove duplicate proxmox-web client from Keycloak realm
    
    - Duplicate client was accidentally added (lines 3043-3145)
    - Only one proxmox-web client definition needed
    - Same client ID would cause Keycloak import errors

[33mcommit b58c72f6e765bcd7d839634001d1a84244cc61eb[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:56:20 2026 +0000

    Replace IP with placeholder in appsettings example
    
    - Use proxmox.local instead of specific IP address
    - Use placeholder UUID format for token
    - Example file should not contain real infrastructure values

[33mcommit 01bee6d09ca336eef13c324282ce6dc98bf3e241[m
Merge: 59336d6 830be76
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:54:46 2026 +0000

    Merge branch 'main' into feature/proxmox-vm-automation

[33mcommit 59336d64ecd3a25ee9872d678306e49af9364bd8[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:52:10 2026 +0000

    Add TODO directory to gitignore
    
    - Personal TODO files should never be committed
    - Prevents accidental commits of planning notes

[33mcommit 1a49fc6d8ced4b24f1d33420094ec63b49791039[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:50:11 2026 +0000

    Consolidate all documentation into single README.md
    
    - Move hypervisor configuration docs to root README
    - Move Proxmox OIDC authentication docs to root README
    - Delete 4 separate README files from scripts/ folder
    - Update table of contents with new sections
    - Remove old setup-keycloak-portforward.ps1 (replaced by setup-proxmox-windows.ps1)
    - Single source of truth for all Crucible documentation

[33mcommit 4f70c99401e40f5a5049cd7b5d68f4bddee02c59[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:50:04 2026 +0000

    Fix Keycloak hostname and create comprehensive Windows setup script
    
    Keycloak hostname fix:
    - Remove KC_HOSTNAME=keycloak to enable request-based hostname
    - Keycloak now responds to localhost, keycloak, and IPs
    - Fixes 401 errors when accessing Crucible apps via localhost
    - Proxmox OIDC uses direct IP (172.29.16.1), no hostname needed
    
    Comprehensive Windows setup script:
    - Combines VM creation and port forwarding in setup-proxmox-windows.ps1
    - Idempotent: checks for existing VM, skips if present
    - Proper CRLF encoding from start
    - SkipVMCreation flag for port forwarding only
    - Auto-detects Proxmox ISO in repo root
    - Nested virtualization enabled
    - Full installation instructions

[33mcommit 880d4e73d7e9a3efb15cb937e825a67a65967c39[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:39:43 2026 +0000

    Consolidate documentation into single README.md
    
    - Move hypervisor configuration docs to root README
    - Move Proxmox OIDC authentication docs to root README
    - Delete separate README files from scripts/ folder
    - Add new sections: Hypervisor Configuration, Proxmox OIDC Authentication
    - Update table of contents with new sections

[33mcommit e622bdc1b4eede4abc40449bf1f75cbcaf3da619[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:39:35 2026 +0000

    Add Proxmox link to Moodle block_crucible plugin
    
    - Configure CRUCIBLE_PROXMOX_ENABLED and CRUCIBLE_PROXMOX_URL env vars
    - Add Proxmox section to block_crucible configuration
    - Show/hide Proxmox link based on hypervisor configuration
    - URL comes from HypervisorUrl in appsettings.json

[33mcommit 50d684b0f202be830a1e8b99f400812795908620[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:26:50 2026 +0000

    Add vSphere/VMC support to Caster Terraform provider
    
    - Configure vSphere Terraform provider environment variables
    - Support both on-premises vSphere and VMware Cloud (VMC)
    - Parse datacenter/cluster/pool from HypervisorPoolPath
    - Extract datastore name from [datastore] format
    - Full coverage: TopoMojo, Player VM (Proxmox only), Caster (all 3)
    - All three hypervisors now fully supported for development

[33mcommit f049c307ea5222c8dc0b8692888a76f9059262fa[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:16:54 2026 +0000

    Update toggle script to configure AppHost appsettings.json
    
    - Script now updates Crucible.AppHost/appsettings.Development.json
    - Uses jq to merge hypervisor config into Launch section
    - Same CLI interface as before (proxmox|vsphere|vmc|remove)
    - Eliminates need to manually edit JSON files
    - One command to configure all three apps (TopoMojo, Player VM, Caster)

[33mcommit bbd5e8111fed74a62d974a03ab2f1eef41f86f8a[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:13:59 2026 +0000

    Add centralized hypervisor configuration via AppHost
    
    - Support three hypervisor types: Proxmox, vSphere, VMC
    - Configure hypervisors via appsettings.Development.json Launch settings
    - AppHost injects environment variables into TopoMojo, Player VM, Caster
    - Auto-detect VMC vs on-prem vSphere based on URL
    - Backward compatible with UseProxmox property
    - Add example configuration file with all three profiles
    - Comprehensive documentation for hypervisor configuration
    - Replaces need to manually edit individual app appsettings files

[33mcommit 28961c73b86e1f9e688d075e7534d3ec9bfbad00[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 20:10:06 2026 +0000

    Add Proxmox OIDC authentication with Keycloak
    
    - Add proxmox-web OIDC client to Keycloak realm
    - Configure Proxmox to authenticate via Keycloak at http://keycloak:8080
    - Create three role-based Proxmox groups (admins, developers, observers)
    - Add Windows port forwarding script for Keycloak accessibility
    - Update crucible-proxmox.sh with OIDC configuration function
    - Add comprehensive OIDC setup documentation
    - Remove broken create-proxmox-host-hyperv.ps1 script
    - Simplify to two-script setup: Windows prereqs + Proxmox config

[33mcommit 345dcc8ea4081cebf2f3510c490611cb08b679cc[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 28 13:17:13 2026 +0000

    Consolidate 38 Proxmox scripts into single idempotent script
    
    Consolidates all Proxmox test environment management into one script:
    scripts/crucible-proxmox.sh with 5 modes (setup, clean, status, reset, fix)
    
    Features:
    - Command-line arguments instead of environment variables
    - Idempotent resource creation with hardcoded UUIDs
    - API-only interactions (no direct database access)
    - Creates 2 Player views, 2 Caster projects, 2 Alloy events, 2 TopoMojo workspaces
    - All 3 VMs (alpine, tinycore, puppy) used consistently across all apps
    - Resource summary displayed after setup
    - Configuration persistence in ~/.crucible-proxmox
    
    Moved legacy scripts to scripts/legacy/ for reference.
    Documentation: scripts/CRUCIBLE-PROXMOX-USAGE.md

[33mcommit 592a2ba9304662ad4c1c09e64ac23197b52d9bdc[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Wed May 27 19:47:01 2026 +0000

    Fix Player view creation and add cleanup scripts
    
    - Update Player API port to 4300 (was incorrectly 4301)
    - Change Keycloak client to player.vm.admin for direct access grants
    - Add VM and Map applications to live Player view
    - Update Player view names: 'Proxmox Demo' and 'Proxmox On-Demand Template'
    - Use real GUIDs instead of dummy dd000000-... pattern
    - Remove confirmation prompt from master setup script
    - Fix Caster project output extraction in master script
    - Add cleanup-crucible-resources.sh for API-based cleanup
    - Add clear-test-data.sh for PostgreSQL volume reset
    - Token reuse: check config file before recreating Proxmox token

[33mcommit 9b3d0617c8d17fd07aef4131c6fd98fde42baaaa[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Wed May 27 17:21:56 2026 +0000

    Quote values in Proxmox config file to fix bash parsing
    
    - Add quotes around PROXMOX_HOST and PROXMOX_API_TOKEN
    - Prevents bash from misinterpreting = and ! in token string
    - Fixes 'not a valid identifier' error when sourcing config

[33mcommit f41f28e07575055336fe0bec3e3f1cb1ee96825e[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Wed May 27 17:20:46 2026 +0000

    Fix Player Views and Alloy Events display in master script output
    
    - Fix Player View ID extraction for Alloy event creation
    - Add clickable URLs for Player views and Alloy event templates
    - Display each Player view and Alloy event on separate line with link
    - Player views link to http://localhost:4303/views/{id}
    - Alloy events link to http://localhost:4403/templates/{id}

[33mcommit 2a9b015f68e1019f19f0b4467b3851cf768557fb[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Wed May 27 17:18:01 2026 +0000

    Add live Player view with registered VMs to master script
    
    - Create new script create-player-view-with-vms.sh for live views
    - Registers Puppy, Alpine, TinyCore VMs in Player VM API
    - Links VMs to Admin team for visibility
    - Master script now creates two Player views:
      1. Template view for Alloy/Caster (no VMs)
      2. Live view with actual running VMs
    - Idempotent with stable GUIDs
    - Respects CLEAN_SETUP flag

[33mcommit ae658705c3325a56141010e5d779ec14d116bebc[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Tue May 26 16:39:23 2026 +0000

    Fix Proxmox NFS config, add SupportsSubfolders, save config to file
    
    - Fix NFS export to use Proxmox network (172.29.0.0/16) instead of Docker network
    - Add chmod 777 to ISO directory for write access from dev container
    - Add SupportsSubfolders setting (false for Proxmox, true for vSphere/VMC)
    - Save PROXMOX_HOST and PROXMOX_API_TOKEN to ~/.crucible-proxmox
    - Scripts auto-load config from ~/.crucible-proxmox if exists
    - Use environment variables for IP/token in toggle script (DHCP-friendly)
    - Prevents workspace-specific subdirectories for Proxmox ISO uploads

[33mcommit 6972ba768c35c84faa90514f8bdd328b941b8f89[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon May 25 19:47:26 2026 +0000

    Create two Caster projects and two Alloy events, add Puppy template, reuse global templates
    
    - Add second Caster project "Proxmox Test with Alloy" for Alloy integration
    - Add Alloy event with Caster directory integration (create-alloy-event.sh made idempotent)
    - Create three global TopoMojo templates (TinyCore-ISO, Alpine-Disk, Puppy-Linux)
    - Link global templates to workspaces instead of creating duplicates
    - Variants workspace now reuses global templates for each variant
    - Add stable GUIDs for second Caster project and Alloy with Caster event
    - Add cleanup script to remove duplicate templates
    - Remove variants workspace script from master (was creating duplicates)
    - Re-add variants workspace with proper global template linking
    
    Master script now creates:
    - 2 Caster projects (standalone + with Alloy)
    - 1 Player view
    - 2 Alloy events (view only + with Caster)
    - 2 TopoMojo workspaces with 3 global templates each

[33mcommit 611c731fb4bb32fcb9a762698a05ff1f3700b14c[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon May 25 18:21:54 2026 +0000

    Add automated Proxmox setup and idempotent resource creation scripts
    
    - Add setup-crucible-proxmox.sh master orchestrator with phases for infrastructure, templates, and Crucible resources
    - Add setup-proxmox-complete.sh for SSH, nginx, API tokens, and NFS configuration
    - Add VM template creation scripts (Alpine cloud-init, Tiny Core GUI, Puppy Linux)
    - Add TopoMojo workspace creation with variants support
    - Implement idempotent resource creation with stable GUIDs
    - Add CLEAN_SETUP flag for force recreate (delete then create with same GUID)
    - Add deletion helper scripts for cleanup operations
    - Fix Proxmox boot parameter format for Proxmox 8+
    - Fix TopoMojo ISO paths to use correct format (local:iso/filename)
    - Add comprehensive resource tracking output with names and GUIDs

[33mcommit 830be76a9d0ee990404c902eda03155fa1113616[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Thu May 21 14:16:00 2026 -0400

    Ignore .csproj.lscache files (#88)

[33mcommit 52ed572865a72849b0ace3c861c39911b649df5a[m
Merge: ec5fef8 b53b197
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 21 18:15:23 2026 +0000

    Merge main into feature/manage-deployments-page

[33mcommit ec5fef8181c215c93716f23595e9b88521487736[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon May 18 14:59:49 2026 +0000

    Update toggle-topomojo-hypervisor script for VMC
    
    - Use topomojo/ folder instead of GUID path
    - Fix VMC type to vSphere (was Vsphere)
    - Update ticket handler to 'none' for VMC
    - Simplify VMC configuration notes

[33mcommit ab4c67927274a6ad5338644e348cf28a9a26d8fe[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Sun May 17 04:10:27 2026 +0000

    Fix Proxmox ISO path format in template creation script
    
    Use correct flat file naming format with workspace GUID prefix: local:iso/guid#filename.iso
    Updated to use existing TinyCore-current.iso from workspace 9f2f2a82d0df496c92ff80d7acb7a259

[33mcommit 324665288df3b44f30ce7d497d8f9c897b17a0cd[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Sat May 16 03:18:11 2026 +0000

    Fix Proxmox IsoStore config to use 'local' instead of 'local:iso'

[33mcommit b53b197b87f0b0389c76b3251bcba761250b0ce9[m[33m ([m[1;32mfix/player-vm-ui-error-handling[m[33m, [m[1;32mfix/block-crucible-reserved-docs[m[33m)[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon May 11 13:57:45 2026 -0400

    Create a new skill for updating docs (#87)
    
    * Adds update docs skill

[33mcommit 4ae5774620fd6dba65685d4ea951b356e8246381[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon May 11 17:54:23 2026 +0000

    Add email addresses to Keycloak users for Moodle integration
    
    Moodle requires email addresses for user synchronization.

[33mcommit 1ca1f1dac6bfabdcf956cbeb565dbb28f3231d67[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Mon May 11 17:36:23 2026 +0000

    Rename scripts for clarity
    
    - Rename create-alloy-event-simple.sh to create-alloy-event-without-caster.sh
    - Rename create-topomojo-workspace-template-v2.sh to create-topomojo-workspace-template.sh
    - Update default event name to 'Alloy Event (No Caster)'

[33mcommit 6883fccfab0c11fee92d2423daec91a6def7f800[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Sat May 9 01:19:46 2026 +0000

    Automate TopoMojo API key creation for Moodle integration
    
    - Run get-or-create-topomojo-apikey.sh script after TopoMojo starts
    - Script creates Moodle Service Account with admin role and API key
    - Moodle waits for script completion before starting
    - Bind mount /tmp/crucible for API key file sharing between host and container
    - Enables fully automated TopoMojo plugin configuration in Moodle

[33mcommit 910bb40fb246caaff2e3b496d9454c8df53b3838[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Sat May 9 01:17:29 2026 +0000

    Add Dashboard application to Player view template script
    
    - Add DASHBOARD_APP_TEMPLATE_ID variable
    - Create Dashboard application on view
    - Add Dashboard instance to Admin team with displayOrder 1
    - Update view description to mention both applications

[33mcommit 21796f38137a72601a4efc279930d6aaebc98fcf[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Sat May 9 01:05:00 2026 +0000

    Configure Alloy API client URL for browser requests in Moodle

[33mcommit ed4e8f77907f24efb977ab9c9a551c6ad3feef32[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Sat May 9 00:48:18 2026 +0000

    Set TopoMojo Moodle Service Account to admin role (Role=3)
    
    The Moodle Service Account needs admin permissions to access all TopoMojo
    API endpoints including challenges. Changed from Role=2 to Role=3.

[33mcommit fa789ac2252ee4fa6effc6c6a1d0aba0dcc998b4[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 8 23:49:25 2026 +0000

    Add Alloy event automation scripts with VM registration
    
    - create-player-view-template.sh: Creates Player view templates with Virtual Machines app
    - create-caster-directory-for-alloy.sh: Creates Caster directory with Proxmox VM infrastructure
      * Uses Crucible provider to register VMs with Player teams
      * Leverages Alloy's automatic view_id and team variable injection
      * No data sources needed - uses variables Alloy provides
    - create-alloy-event.sh: Links Caster directory + Player view into Alloy event template
    - create-alloy-event-simple.sh: Simple Alloy events with view only (no infrastructure)
    - register-proxmox-vms-to-player.sh: Manual VM registration helper (fallback)
    
    Complete workflow:
    1. Create view template with VM app
    2. Create Caster directory with Terraform for VM creation + registration
    3. Create Alloy event template linking directory and view
    4. Launch event - Alloy clones view, injects variables, Terraform creates VMs and registers to teams
    
    Scripts show current env vars and output pasteable commands for next steps.

[33mcommit f9da2d5cb99aaba43bc5c9057177b7c9c91af04f[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 8 22:41:04 2026 +0000

    Re-add API token injection to Proxmox nginx WebSocket proxy
    
    The Authorization header with API token is required for WebSocket
    connections to succeed. Ticket-based auth alone is not sufficient.
    
    Reverts part of commit 98d405b.

[33mcommit 6ff3e4c11945750ba6369daa484f5e49ed5b751d[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 8 22:39:27 2026 +0000

    Configure TopoMojo to use Proxmox nginx proxy at port 443
    
    Changes:
    - Set Pod__Url to port 443 instead of 8006
    - Use crucible API token instead of topomojo token
    - Set Pod__TicketUrlHandler to "none" to prevent vmhost query parameter
    - Update Caster script to clone from VM 105 instead of 101
    
    This enables TopoMojo console WebSocket connections to work through the
    nginx reverse proxy, matching Player console behavior.

[33mcommit 98d405b995e2d3e55e1d175a29c4b24ae091cd10[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 8 21:49:07 2026 +0000

    Remove API token injection from Proxmox WebSocket proxy
    
    TopoMojo and Player both use ticket-based auth for VNC WebSocket.
    Nginx should pass through the vncticket query param, not inject API token.
    API token injection causes HTTP 400 - can't use both auth methods.

[33mcommit ba342b0aae5df462d279f49268cbad7d5257e285[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 8 21:35:32 2026 +0000

    Add Virtual Machines application and admin user to Test Team
    
    - Add Virtual Machines application referencing existing template
    - Add admin user to Test Team with app instance
    - Ensures VMs are visible in Player view after deployment

[33mcommit c77da21f93a00d45696ceaee61761753508f27ca[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 8 21:27:50 2026 +0000

    Fix Caster Proxmox topology script for single-apply workflow
    
    - Remove team_id variable, reference team directly from view resource
    - Fix OAuth scope from "vm" to "player-vm"
    - Update Keycloak URLs to https://host.docker.internal:8443
    - Update API URLs to use host.docker.internal for Kubernetes pods
    - Fix Caster UI port from 4311 to 4310
    - Add auto-increment logic for duplicate project names
    - Use crucible.provider client with proper scopes
    
    VMs now register to teams in single Terraform apply without manual intervention.

[33mcommit 2a334140925091383beb170027d54085becb07bd[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 8 18:34:04 2026 +0000

    Remove original create-topomojo-workspace-template.sh
    
    The v2 version follows the official Proxmox.md documentation workflow correctly.

[33mcommit e47b22b7e94d3a11ec41e66d534ff838db91d23f[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Fri May 8 18:33:44 2026 +0000

    Add TopoMojo Proxmox automation scripts
    
    - create-topomojo-workspace-template-v2.sh: Creates workspace and templates following Proxmox.md documentation workflow (creates Proxmox template VMs, then TopoMojo templates that reference them)
    - setup-proxmox-topomojo.sh: Creates API token and configures AppHost for TopoMojo Proxmox integration
    - delete-topomojo-workspace.sh: Deletes all workspaces and stock templates for testing
    - AppHost.cs: Added Proxmox hypervisor configuration (Pod__Type, Pod__AccessToken, Pod__Url, datastores)
    - LaunchOptions.cs: Added UseProxmox, ProxmoxHost, ProxmoxApiToken properties
    
    Templates reference Proxmox template VMs via 'template' field in detail JSON.
    Deploy creates linked clones from Proxmox templates (not Initialize).
    Template names use hyphens for DNS-valid Proxmox VM names.

[33mcommit 0c0a13dc1e6b485dc6d3cf542dee48caac51cbaa[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 7 22:39:46 2026 +0000

    Add validation and remove hardcoded paths from download scripts
    
    - Add PROXMOX_HOST validation with helpful error messages
    - Use SSH_KEY_PATH and PROXMOX_USER variables instead of hardcoded values
    - Consistent with other Proxmox scripts

[33mcommit 834bf224d75e52bfa799d9bfe28d5088271b9fb5[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 7 22:38:56 2026 +0000

    Restore missing Puppy and TinyCore ISO download scripts
    
    Re-add download-puppy-iso.sh and download-tinycore-iso.sh that were lost.
    Updated to remove hardcoded IP defaults to match other scripts.

[33mcommit dc56df47f0e6aa4630a78726c256bde76e04fdd1[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 7 22:35:13 2026 +0000

    Remove hardcoded IPs from Proxmox scripts
    
    - Remove all hardcoded IP defaults (172.22.x.x) from script variables
    - Require PROXMOX_HOST to be set via environment variable
    - Add validation checks for required PROXMOX_HOST variable
    - Update error messages with copy-pasteable export commands
    - Emphasize using single quotes to prevent bash ! expansion
    - Update create-caster-proxmox-topology.sh to use env vars in tfvars
    
    All scripts now require explicit PROXMOX_HOST configuration to prevent
    accidental use of wrong/stale IP addresses.

[33mcommit 99473c4def0a5021c886424be4585a959c9b9098[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 7 22:29:03 2026 +0000

    Update Proxmox config script to use port 443 for nginx proxy
    
    - Change update-proxmox-appsettings.sh to set Port 443 instead of 8006
    - Add comment explaining port 443 is required for nginx reverse proxy
    - Delete duplicate update-proxmox-config.sh script
    
    Port 443 is required because the nginx proxy injects the API token header
    for VNC websocket authentication. Direct connection to port 8006 fails with
    websocket auth errors.

[33mcommit fb6f082ff667f9aa9f556ac2eb028225778e8a5b[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 7 22:12:23 2026 +0000

    Update Proxmox topology script to use bpg/proxmox provider
    
    Switch from Telmate/proxmox to bpg/proxmox v0.106.0 due to API token auth issues.
    Add Crucible provider v2.5 for Player resource management.
    
    Known issue: Crucible provider fails with connection refused to Keycloak -
    localhost URL not reachable from either K8s pods or Caster API container.

[33mcommit d22f6a1910cde217c1d95d6058526c1ff135c066[m
Author: Adam Welle <arwelle@sei.cmu.edu>
Date:   Thu May 7 18:52:36 2026 +0000

    Add Proxmox VM automation for Crucible
    
    Complete workflow for creating and managing Proxmox VMs:
    
    Proxmox Host Setup:
    - PowerShell script to create Proxmox VE host in Hyper-V
    - SSH key authentication setup
    - API token creation and management
    - NGINX proxy configuration
    - Automated appsettings.json updates for Player VM API and Caster API
    
    VM Creation Scripts:
    - Alpine Linux (ID 101)
    - TinyCore Linux (ID 102)
    - Puppy Linux (ID 103)
    - Download ISO automation
    - Database-aware creation (checks Proxmox and Player VM API)
    - Handles all scenarios: VM exists in both/neither/Proxmox-only/DB-only
    
    VM Registration:
    - create-vm-api-record.sh: comprehensive script that creates/reuses View, Team, Application, and VM
    - Checks for existing resources before creating
    - Single script replaces manual setup
    
    Utilities:
    - remove-vms-from-db.sh: clean up orphaned database records
    - Improved error handling and user guidance
    - All scripts have proper executable permissions

[33mcommit c95c213894545290bc8a15e5cf53959f65e5ed8b[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Thu May 7 13:10:55 2026 -0400

    Devcontainer CI (#86)
    
    * Adds devcontainer ci workflow
    - GitHub Actions workflow that builds the dev container, runs a modified postCreate, and verifies that core tools are installed as expected. This builds on amd64 and arm64. Images are cached to GHCR so PRs are faster
    
    * Fix the missing ci_skip_clone var
    
    * Update claude md

[33mcommit f4d91801b4ae20293760f890d2eb7861208be219[m[33m ([m[1;32mfeature/hide-integration-target-datafield[m[33m)[m
Author: Adam Welle <arwelle@cert.org>
Date:   Thu May 7 12:32:49 2026 -0400

    Add xAPI configuration for Player API and Player VM API (#83)
    
    * Add xAPI configuration for Player API and Player VM API
    
    - Configure xAPI options for Player API (port 4300/4301)
    - Configure xAPI options for Player VM API (port 4302/4303)
    - Uses shared ConfigureXApi helper with LRsql endpoint
    - Platform identifiers: 'Player' and 'Player VM'
    
    * Add dynamic XApiEnabled configuration for Player, Gallery, and CITE UIs
    
    - Create CopyUiSettingsWithXApi helper to dynamically inject XApiEnabled setting
    - Update Player, Gallery, and CITE UI configuration to use dynamic helper
    - Remove hardcoded XApiEnabled from UI settings JSON files
    - XApiEnabled now set to true via AppHost for UIs with xAPI tracking
    
    * Make UI XApiEnabled dynamic based on Lrsql being enabled
    
    - Update CopyUiSettingsWithXApi calls for CITE and Gallery to use IsEnabled(lrsqlMode)
    - Add XApiEnabled: true to CITE and Gallery settings files (dynamically overwritten by AppHost)
    - CITE and Gallery UIs now only enable xAPI when Lrsql is running
    - Player UI remains always enabled (API always has xAPI configured)
    
    * Add dynamic XApiEnabled to Steamfitter and Blueprint UIs
    
    - Replace File.Copy with CopyUiSettingsWithXApi for Steamfitter and Blueprint
    - Add XApiEnabled: true to steamfitter.ui.json and blueprint.ui.json settings
    - Both UIs now only enable xAPI when Lrsql is running (IsEnabled(lrsqlMode))
    
    All xAPI-capable UIs now have dynamic configuration:
    - Player: always enabled (API unconditionally configured)
    - CITE, Gallery, Steamfitter, Blueprint: enabled only when Lrsql is enabled
    
    * Simplify xAPI configuration using settings.shared.json
    
    - Add XApiEnabled to settings.shared.json.template (single toggle for all UIs)
    - Remove XApiEnabled from individual UI settings files
    - Replace CopyUiSettingsWithXApi calls with simple File.Copy
    - Remove CopyUiSettingsWithXApi helper method
    
    Now XApiEnabled is controlled in one place and can be toggled post-deploy by editing settings.shared.json
    
    * Add XApiOptions__Enabled to ConfigureXApi method
    
    All APIs with xAPI now get Enabled=true environment variable set
    
    * Conditionally configure xAPI based on Lrsql mode
    
    Only call ConfigureXApi for Player and Player VM APIs when Lrsql is enabled,
    matching the pattern used by other apps (Steamfitter, CITE, Gallery, Blueprint).
    
    * Conditionally configure xAPI based on Lrsql mode
    
    Only call ConfigureXApi for Player and Player VM APIs when Lrsql is enabled,
    matching the pattern used by other apps (Steamfitter, CITE, Gallery, Blueprint).
    Pass lrsqlMode parameter to AddPlayerVm method.

[33mcommit e604818b2fe62c6af34e312c2082efc1072fa076[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Thu May 7 10:22:28 2026 -0400

    Fix playwright-cli version (#84)

[33mcommit 09e3e4b446f7646306e49f1283a87c1e2da6e701[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Tue May 5 14:52:56 2026 -0400

    Feature lock (#81)
    
    * Adds feature lock file for consistent builds
    * Pin feature and software versions
    * Reorder features

[33mcommit 8741d2a0fdcdeb90bc8308facc4dd345b8e40d67[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon May 4 14:29:55 2026 -0400

    Fix gh cli not having permission to write (#82)

[33mcommit 1dd10bbca53e6765e8e58d09df92be813c051656[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon May 4 13:30:28 2026 -0400

    Adds docker volumes for package caches (#80)

[33mcommit 6f9618e90e99a347006addc109a3cd9563034730[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon May 4 13:30:10 2026 -0400

    Playwright updates (#79)
    
    * Ensure the playwright-test mcp is allowed
    
    * Update readme with playwright-test instructions
    
    * Install playwright dependencies as part of feature install

[33mcommit 1ff9e740eb4c0a3a1d4a971998c4f4da8f017668[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon May 4 11:04:09 2026 -0400

    Move Claude Code install to a local feature (#78)

[33mcommit db046801c3e882c13e4ebe69f65148b13a2fde44[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon May 4 10:51:06 2026 -0400

    Adds "Competition" launch profile env to start up both TM and GB (#77)

[33mcommit 2839e95de8c3858dcaa672b2f9b94956583c0e51[m
Author: Adam Welle <arwelle@cert.org>
Date:   Mon Apr 27 09:53:50 2026 -0400

    Fix LRsql container lifecycle management (#76)
    
    Add WithLifetime(ContainerLifetime.Persistent) to LRsql container configuration to prevent "container name already in use" errors after dev container rebuilds.
    
    Without lifecycle management, the fixed container name ("/lrsql") persists across rebuilds causing conflicts. This change aligns LRsql with other infrastructure containers (Postgres, Keycloak, Moodle, MISP, Superset) that use Persistent lifetime.

[33mcommit 306d05dcb8af74e08892bac859672b63f6c95073[m
Author: Adam Welle <arwelle@cert.org>
Date:   Fri Apr 24 16:04:25 2026 -0400

    Add LRSql authority template and xAPI actor identity config (#73)
    
    * Add LRSql authority template and LRSQL_AUTHORITY_URL env var
    
    Bind-mount an authority.json.template into the LRSql container so
    xAPI statement authorities can be configured with a proper homePage
    URL and credential-based name.
    
    * Configure logstore_xapi for Keycloak account-based actor identity

[33mcommit cb2f130645950b7633f60f3c7cc724616fa4dc13[m
Author: Adam Welle <arwelle@cert.org>
Date:   Fri Apr 24 11:35:11 2026 -0400

    Fix crucible tests mcp path (#75)
    
    * Move crucible-tests to root repos array for correct MCP path
    
    crucible-tests should be cloned to /mnt/data/crucible/crucible-tests/
    to match the playwright-test MCP server configuration in .mcp.json
    
    * Updates path for PLAYWRIGHT_TESTING_DIR

[33mcommit 57697def8136bd7094c1940764089bd5ab1756a2[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Fri Apr 24 10:04:42 2026 -0400

    Minikube updates (#63)
    
    * Minikube updates
    - Rename directory from helm-charts/ to minikube/
    - Rename helm-deploy.sh to crucible-deploy.sh
    - Update crucible-deploy.sh to deploy using the latest crucible umbrella chart, which includes using K8s operators
    - Update postcreate.sh script to include different helm repos based on latest crucible chart requirements
    
    * Adds a persistent minikube image registry
    - Apps deployed to minikube will have images cached in the registry
    - Prevents 2+ GB image downloads on each rebuild of minikube - huge time savings on slow network connections
    - Mitigates docker image download limits
    - Cache is purged when minikube is reset with --purge
    
    * Fix registry ca bundle

[33mcommit ea6985f8963aab56183b4096986d8db9d062997b[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Fri Apr 24 09:55:31 2026 -0400

    upgrade Aspire to 13.2 (#72)
    
    - Upgrade all Aspire packages to 13.2
    - Removed playwright MCP in favor of playwright-cli
    - Added aspire and playwright-cli skills with aspire agent init
    - Added vs code task for aspire resource rebuild

[33mcommit c5ddeefe172bc12c2c227c09883f2e91106e4113[m
Author: Adam Welle <arwelle@cert.org>
Date:   Fri Apr 24 09:33:01 2026 -0400

    Document shared UI settings and populate template with full config (#74)
    
    * Document shared UI settings and populate template with full config
    
    Add README section explaining the three-file settings merge chain
    and available HeaderBarSettings keys. Update the template from empty
    JSON to include all configuration keys with sensible defaults
    (banner disabled by default).
    
    * Removes Configuration section from shared IO settings section

[33mcommit ef420963f65a8735927aa7ee539ae5bef7efb09f[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Thu Apr 23 09:03:04 2026 -0400

    Add local Angular library dev mode and shared UI settings (#71)
    
    Summary
    
      - Local Angular library development (LinkCommonUI): Adds a launch option to build and watch @cmusei/crucible-common locally, with npm link propagation to all Angular UIs. Uses a single Aspire resource with a custom health
      check to prevent UIs from starting before the library build completes.
      - Shared UI settings (settings.shared.json): Adds support for the settings.shared.json layer in the three-file merge chain (settings.json → settings.shared.json → settings.env.json). A checked-in template is copied on first
       run and symlinked into each app, so edits are picked up immediately by ng serve without restarting Aspire. The user's local copy is git-ignored.
      - Settings file reorganization: Moves all *.ui.json files from resources/ to resources/ui/settings/ for better organization.
      - README documentation: Documents the Angular library development workflow alongside the existing .NET library section.
    
    Details
    
      LinkCommonUI
    
      When enabled, the AppHost:
      1. Runs ng build crucible-common --watch and detects the "Compilation complete" message in stdout
      2. Creates a global npm link to the built library and touches a marker file
      3. A custom health check polls for the marker — UIs use WaitFor to wait until healthy
      4. Each UI's setup-local resource runs npm link @cmusei/crucible-common and copies tsconfig.local-npm.json
      5. UIs start with --configuration localNPM
    
      settings.shared.json
    
      - resources/ui/settings.shared.json.template — checked-in default (starts as {})
      - On first aspire run, copied to resources/ui/settings.shared.json (git-ignored)
      - Symlinked into each standard app's src/assets/config/settings.shared.json
      - Gameboard and TopoMojo are excluded (they don't use the three-file merge system)

[33mcommit 288a3093fbb02d6c907167ac963a9bee0d817902[m[33m ([m[1;32mconfigure-local-ai-provider[m[33m)[m
Author: Adam Welle <arwelle@cert.org>
Date:   Tue Apr 21 08:51:18 2026 -0400

    MISP: Auto-generate Redis password + OIDC auth via Keycloak and add Moodle training links JS (#70)
    
    * Auto-generate MISP Redis password instead of requiring user secret
    
    * Switch MISP to HTTP for dev environment
    
    * Add MISP OIDC authentication via Keycloak
    
    - Add MISP client with realm roles protocol mapper to crucible-realm.json
    - Pass OIDC environment variables to MISP container in AppHost.cs
    - Install socat in Dockerfile for localhost->Keycloak port forwarding
    - Add customize_misp.sh with OIDC configuration via config.php
    
    * Add MISP training links panel for ATT&CK techniques
    
    Client-side JS panel on MISP event pages shows Moodle competency
    links for detected MITRE ATT&CK techniques. Checks Moodle API to
    distinguish techniques with training content from those without.
    Scoped to a configurable competency framework to avoid ID collisions
    (e.g., ATT&CK T1005 vs NICE T1005). Gracefully degrades if Moodle
    is unreachable.
    
    * Change training link button text color to black
    
    * Update MISP port from 8082/8443 to 8444

[33mcommit e1e441609acae34f0358f6ca059bcd2eb5ade4b5[m
Author: sei-npacheco <106097162+sei-npacheco@users.noreply.github.com>
Date:   Mon Apr 20 13:55:11 2026 -0400

    Add Playwright end-to-end testing infrastructure to dev container  (#68)
    
    Summary
    - Configure the dev container to install Playwright (Chromium browser, system dependencies, npm packages)
    and the VS Code Playwright extension automatically during container creation
    - Add the crucible-tests repo to repos.json so it is cloned alongside other Crucible repositories
    - Register the playwright-test MCP server alongside the existing playwright MCP server so Claude Code can
    plan, generate, and heal tests using Playwright test agents
    
    ---------
    
    Co-authored-by: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
    Co-authored-by: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>

[33mcommit e980caa20ca15f3e0d34f13ea5bf21cf3f2c2d89[m
Author: Adam Welle <arwelle@cert.org>
Date:   Fri Apr 17 11:16:34 2026 -0400

    Fix prod-mode dist path for player-ui and alloy-ui (#69)
    
    Both repos migrated to Angular's application builder which outputs
    to dist/browser/ instead of dist/. Update AddAngularUI calls to
    match the other UIs that already specify the correct path.

[33mcommit 78859fdf5fb73c4839d08976ab13d3331f1e67f9[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Wed Apr 15 13:21:19 2026 -0400

    Persist gh cli authentication across container rebuilds (#67)
    
    * Persist gh cli authentication across container rebuilds
    
    * Use GH CLI auth for GitHub MCP
    - Fixes error where the GitHub MCP fails to authenticate
    
    * Adds deny permissions to prevent destructive actions by claude
    
    * Update readme with gh permissions

[33mcommit 618eceb15eeb4d97de82c9b55af9ca1e6ff550f7[m
Author: Adam Welle <arwelle@cert.org>
Date:   Wed Apr 15 08:28:36 2026 -0400

    Fix prod-mode UI startup and increase dev token lifespan (#66)
    
    * Fix serve.json path for prod-mode UI startup
    
    npx serve resolves -c config path relative to the content directory,
    not the working directory. Writing serve.json to the project root
    caused serve to look for it at dist/serve.json (or dist/browser/serve.json)
    and fail. Write it to the dist path instead.
    
    * Increase Keycloak access token lifespan for dev environment
    
    Bump realm-level accessTokenLifespan from 300s (5 min) to 1800s
    (30 min). The short default causes frequent token expiration during
    Swagger testing and development workflows.

[33mcommit 567dc5cd47f538aceb4db16d7a966f0846e59f33[m[33m ([m[1;33mtag: [m[1;33mdocker-v1.1.3[m[33m, [m[1;33mtag: [m[1;33mdocker-v1.1[m[33m, [m[1;33mtag: [m[1;33mdocker-v1[m[33m)[m
Author: Adam Welle <arwelle@cert.org>
Date:   Thu Apr 2 09:21:12 2026 -0400

    Fix auth-callback-silent routing error in prod-mode UIs (#65)
    
    Disable clean URLs in npx serve to prevent 301 redirects from
    stripping the .html extension on auth-callback-silent.html, which
    caused Angular to intercept the request and fail with NG04002.

[33mcommit a858fc052634bc50dd467744de51cf359ba124c6[m
Author: Adam Welle <arwelle@cert.org>
Date:   Wed Apr 1 09:59:31 2026 -0400

    Add Apache Superset for xAPI/LRsql analytics (#64)
    
    * Add Apache Superset for xAPI/LRsql analytics
    
    - Add Superset container with custom Dockerfile (psycopg2, authlib)
    - Configure Keycloak OAuth SSO with internal/external URL split
    - Auto-register LRsql database connection on startup
    - Add superset client to Keycloak realm
    - Add launch configurations and env file
    
    * Add xAPI analytics dashboard and remove unrelated changes
    
    - Add ORM-based dashboard creation script with 7 charts including
      client app breakdown (Blueprint, CITE, Gallery, Steamfitter)
    - Auto-create dashboard on Superset startup via init-superset.sh
    - Add README documenting Superset integration and xAPI data model
    - Remove unrelated KC_SPI and CSP changes (belong in separate branch)
    
    * Add missing document markings
    
    ---------
    
    Co-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>

[33mcommit 255015eebaf37313c62e887381a920b921db5ab8[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Fri Mar 27 13:53:28 2026 -0400

    configure vm.api dev credentials (#62)

[33mcommit 763f042acae4b290370d95fe1890948335928338[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Fri Mar 27 12:29:23 2026 -0400

    add Crucible-Github-Actions repo (#61)

[33mcommit 4e5802a7d828c9b7f75262a687df402a5ea0a486[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Wed Mar 18 12:31:10 2026 -0400

    Adds the console-forge library (#59)

[33mcommit 3e496c621f5c16b4d3e5616952c24497642bb0ae[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Wed Mar 18 12:12:12 2026 -0400

    add support for terraform provider dev (#58)
    
    - added go, terraform, go-task features
    - added terraform-provider-crucible to repos.json under a new terraform-providers group

[33mcommit 4f02e85418242f8602896f960bd69a6b4a834668[m
Author: Adam Welle <arwelle@cert.org>
Date:   Tue Mar 17 09:49:30 2026 -0400

    Configure topomojo.api as public client for Swagger UI (#57)
    
    Make topomojo.api a public client to match the pattern used by all other
    Crucible API clients (alloy.api, player.api, caster.api, etc.). This allows
    the Swagger UI to authenticate properly without requiring client secrets,
    which cannot be securely stored in browser-based applications.

[33mcommit b449f5ee4732b8d05cbb139e9460359d0e8b36fa[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Fri Mar 13 10:18:16 2026 -0400

    Developer Experience Enhancements (#56)
    
    ## Summary
    
    A collection of dev container and Aspire orchestration improvements focused on certificate handling, developer experience, and configuration.
    
    ### Certificate handling overhaul
    - Switched from custom-generated certificates to the `dotnet dev-certs` certificate for Keycloak HTTPS, allowing the Aspire dashboard and Keycloak to share the same trusted cert. Removed custom cert bind mounts and `WithoutHttpsCertificate()` from Keycloak configuration, now using Aspire's built-in HTTPS plumbing instead. Keycloak's HTTPS endpoint (8443) is configured via a `BeforeStartEvent` subscription.
    - Set `SSL_CERT_DIR` in `devcontainer.json` to include the dev-cert trust path, and added `libnss3-tools` (provides `certutil`) to the Dockerfile so Aspire can verify cert trust — this eliminates the "dev cert is not trusted" error on every `aspire run`.
    - For Moodle, dev-cert `.pem` files are copied into `resources/moodle/certs/` as `.crt` files at startup via a `BeforeStartEvent` so the Moodle container trusts them. Updated Moodle OAuth URLs to use `keycloak.dev.internal` instead of `keycloak`.
    - Updated Moodle's `post_configure.sh` to update existing OAuth provider settings on boot (previously skipped updates after initial setup), and added the `--id` flag passthrough in `setup_environment.php` to support updates.
    - Removed the explicit `dotnet dev-certs https --trust` call from `postcreate.sh` (now handled by Aspire/certutil).
    
    ### Aspire installation moved to local dev container feature
    - Moved Aspire CLI installation from `postcreate.sh` to a local dev container feature (`.devcontainer/features/aspire/`). This ensures Aspire is on the PATH immediately after container creation, preventing the Aspire VS Code extension from erroring until a VS Code restart.
    
    ### Caster terraform directory
    - Added `mkdir -p /mnt/data/terraform/root` to `postcreate.sh` so the directory exists before `chown /mnt/data/` runs, preventing permissions issues for Caster.
    
    ### Angular apps use Aspire proxy by default
    - Added a `UseAspireProxy` setting to `LaunchOptions` and `appsettings.json` (defaults to `true`). When enabled, Angular UI apps in dev mode use Aspire's proxy (`isProxied: true`) with a dynamically assigned target port passed via `--port` arg, matching the behavior of other application types. The existing static ports are still used as the proxy port. Can be toggled off via `appsettings.Development.json`.
    
    ### Player API seed data
    - Added environment variables to seed default Application Templates (Virtual Machines, Map, and Dashboard) into the Player API on startup.
    
    ### Solution file organization
    - Added all `.csproj` files (including client libraries, data projects, migrations, and test projects) to `Crucible.slnx`, organized into virtual folders by application (Alloy, Blueprint, Caster, CITE, Gallery, Gameboard, Libraries, Player, Steamfitter, TopoMojo). This enables IntelliSense across all C# projects.
    
    ### Minikube cert ConfigMap automation
    - Updated `scripts/start-minikube.sh` to automatically create/update a `caster-certs` ConfigMap containing all trusted certificates from `.devcontainer/certs/` and the dotnet dev-cert, so Caster jobs running in minikube trust the same certs as the dev container.
    
    ### Other improvements
    - Updated welcome message in `poststart.sh` with getting-started instructions
    - Rewrote and reorganized `README.md` with table of contents, launch profile docs, default credentials, and formatting improvements

[33mcommit 43e210f5269b4c7079bac6efab7c57676a00aebb[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Thu Mar 12 14:36:51 2026 -0400

    Use new randomized keycloak realm (#55)
    
    * Use new randomized keycloak realm
    
    * Update to using realm secret rather than configmap
    
    * Remove mention of realm from readme

[33mcommit cc75051ceab01330856548dfd691b28c5d58d362[m
Author: Adam Welle <arwelle@cert.org>
Date:   Tue Mar 10 15:38:18 2026 -0400

    Update repository URLs to new locations (#53)
    
    * Update Crucible repository URLs to canonical names
    
    Updates repository URLs in scripts/repos.json to use the canonical GitHub repository names with proper casing. This eliminates redirect warnings during git operations and ensures consistency with actual repository names on GitHub.
    
    Updated repositories (19 total):
    - Alloy: alloy.api → Alloy.Api, alloy.ui → Alloy.Ui
    - Caster: caster.api → Caster.Api, caster.ui → Caster.Ui
    - Player group: console.ui → Console.Ui, player.api → Player.Api, player.ui → Player.Ui, vm.api → Vm.Api, vm.ui → Vm.Ui
    - Steamfitter: steamfitter.api → Steamfitter.Api, steamfitter.ui → Steamfitter.Ui
    - CITE: cite.api → CITE.Api, cite.ui → CITE.Ui
    - Gallery: gallery.api → Gallery.Api, gallery.ui → Gallery.Ui
    - Blueprint: blueprint.api → Blueprint.Api, blueprint.ui → Blueprint.Ui
    - Gameboard: gameboard → Gameboard
    - TopoMojo: TopoMojo-ui → topomojo-ui (corrected to actual lowercase repo name)
    
    * updates sync scritp with same login as clone script regarding repo locations
    
    * removes xdebug_filter.php since it is generated by generate-xdebug-filter.sh
    
    * Updates AppHost to run npm install for prod mode apps, updates CITE UI path to dist/browser
    
    * Make AWS credentials optional for Moodle and fix Steamfitter UI path
    
    - Update ReadAwsCredentials() to return null when credentials file doesn't exist
    - Conditionally set AWS Bedrock environment variables on Moodle container
    - Add console logging for AWS credential status (found/not found/error)
    - Fix Steamfitter UI production mode build path (dist/browser)
    
    * Skip AWS Bedrock configuration in Moodle when credentials are missing
    
    - post_configure.sh: Check for AWS credentials before calling configure_ai_bedrock
    - setup_environment.php: Fix syntax error (missing closing parenthesis on line 53)
    
    This prevents the error:
    "Failed to configure AWS Bedrock AI provider: Missing required parameters"
    when AWS credentials are not available.
    
    The configure_ai_bedrock section is now only executed if:
    - AWS_ACCESS_KEY_ID is set
    - AWS_SECRET_ACCESS_KEY is set
    - AWS_REGION is set
    
    This completes the AWS credentials optional changes started in commit 45ed60b.
    
    * fix sync-repos exiting on any repo failure
    
    ---------
    
    Co-authored-by: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>

[33mcommit 84932f7c59a811d5a39ca8bae1699d2e552ff0d0[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Wed Mar 4 08:40:32 2026 -0500

    Update the crucible values to use the new version of the moodle helm chart (#54)

[33mcommit 9b5b9ae780c009cfba3311c6499f03aa3c028bca[m
Author: Adam Welle <arwelle@cert.org>
Date:   Fri Feb 27 14:59:04 2026 -0500

    Update Keycloak realm and AppHost for OIDC silent redirect URIs (#52)
    
    * Make toggle-local-library.sh executable
    
    * Document toggle-local-library.sh usage in README
    
    Add usage examples showing how to enable/disable/check status of local
    library debugging for EntityEvents.
    
    * Update Keycloak realm and UI resource templates for OIDC silent redirect URIs
    
    - Update crucible-realm.json redirect URIs to use .html extension
    - Update UI resource templates (*.ui.json) to generate correct OIDC settings
    - Ensures silent token renewal uses static HTML files instead of Angular routes
    
    ---------
    
    Co-authored-by: Adam Welle <arwelle@sei.cmu.edu>

[33mcommit fc314cdb2a6e4b1264674d04cea1de03613b082a[m
Author: Adam Welle <arwelle@cert.org>
Date:   Thu Feb 26 14:37:39 2026 -0500

    Make generate-xdebug-filter.sh executable (#51)
    
    Fixes permission denied error during postcreate.sh execution.
    
    Co-authored-by: Adam Welle <arwelle@sei.cmu.edu>

[33mcommit 8bd197e40f18434d222a633adcc8278831425605[m
Author: Adam Welle <arwelle@cert.org>
Date:   Thu Feb 26 13:13:26 2026 -0500

    Optimize memory and reduce overhead (#50)
    
    * Exclude node_modules and build artifacts from VS Code file watching
    
    * default intelephense.enable to false - set manually if doing PHP dev
    
    * disables Intelephense and CloudFormation
    
    * reduces keycloak memory usage
    
    * work in progress
    
    * updates env defaults
    
    * Add xAPI configuration for Steamfitter
    
    * sets all apps to use off,prod,dev
    
    * removes unused function
    
    * settings.json and readme updates
    
    * build apps set to prod if stale
    
    * Uses helped function AddAngularUI to start UIs in desired mode
    
    * env file updates
    
    * adds repos.local.json for adding additional repos
    
    * changes moodle task defaults
    
    * Add migration script for hierarchical Moodle plugin structure
    
    * Implement dynamic Moodle plugin configuration with hierarchical structure
    
      BREAKING CHANGE: Moodle plugins now use hierarchical directory structure.
      Existing dev environments must run ./scripts/migrate-moodle-hierarchical.sh.
    
      Major changes:
      - Restructure Moodle plugins from flat (mod_topomojo) to hierarchical (mod/topomojo)
      - Implement dynamic bind mount generation in AppHost.cs from repos.json/repos.local.json
      - Add repos.local.json pattern for private/internal repositories (git-ignored)
      - Simplify launch.json pathMappings from 13+ to 6 (automatic for new plugins)
      - Auto-generate xdebug_filter.php from repos at build time (git-ignored)
    
      Dynamic configuration (no manual updates needed):
      - Clone script: Automatically maps plugin names to hierarchical paths
      - AppHost.cs: Reads repos.json + repos.local.json at runtime, creates bind mounts
      - xdebug_filter.php: Generated from repos during devcontainer postcreate
      - launch.json: General pathMapping covers all plugins automatically
    
      Files changed:
      - scripts/clone-repos.sh: Add hierarchical path mapping for moodle group
      - Crucible.AppHost/AppHost.cs: Add ReadMoodlePlugins() and dynamic bind mount loop
      - scripts/generate-xdebug-filter.sh: New script to generate xdebug filter
      - Crucible.AppHost/resources/moodle/xdebug_filter.php.template: Template with core paths
      - Crucible.AppHost/resources/moodle/Dockerfile.MoodleCustom: Use template fallback
      - .vscode/launch.json: Simplify to 6 pathMappings (5 core + 1 general)
      - .devcontainer/postcreate.sh: Run generate-xdebug-filter.sh
      - .gitignore: Ignore repos.local.json and generated xdebug_filter.php
      - README.md: Document new workflow and hierarchical structure
    
      Benefits:
      - Add plugins to repos.local.json → automatic configuration
      - No manual AppHost.cs or launch.json updates needed
      - Private repo URLs stay private (git-ignored)
      - Structure mirrors container layout (easier to understand)
    
    * readme update
    
    * add support for moodle ai provider plugin mappings
    
    * adds support for gradereport plugins and configured crucible block plugin settings
    
    * fixes path for prod build of topomojo ui
    
    * fixes path for prod build of gameboard ui
    
    * fixes port for gameboard in moodle block crucible plugin setting
    
    * corrects block crucible settings
    
    * I've updated the build detection logic in AppHost.cs to also check if the dist directory is empty. The new check now
      verifies:
      1. distPath directory doesn't exist, OR
      2. distPath directory is empty, OR
      3. Any files in src are newer than distPath
    
    * puts all defaults in appsettings.json to make it easier to copy and override in appsettings.Development.json
    
    * updates 015-copy-plugins.sh to add aiplacement path
    
    * env files return to boolean values indicating dev mode
    appsettings.development.json used for overrides:
      Launch: {
        Prod: [PGAdmin, Gallery, Cite, Player, Steamfitter],
        Dev: [],
        XdebugMode: off,
        AddAllApplications: false
      }
    
    moodle configuraiton sets block_crucible values for apps that are deployed
    
    * updates readme with new task configuration information  Key updates:
    
      1. Configuration section (lines 114-180):
        - Explained boolean flag system (.env files): Launch__AppName=true = dev mode
        - Documented Prod/Dev arrays in appsettings.Development.json
        - Clear configuration precedence explanation
        - Example workflows
      2. Supported Applications (lines 182-195):
        - Listed all Angular UIs (dev/prod support)
        - Added container services (Moodle, Lrsql, Misp, PGAdmin, Docs)
      3. Moodle Configuration (lines 226-249):
        - Documented two task approach (moodle.env vs moodle-xdebug.env)
        - Explained dynamic Crucible integration
        - How Moodle auto-configures based on running services
      4. Moodle Debugging (lines 547-567):
        - Updated to reflect two-task approach
        - Clarified when to use each task
        - Better instructions for debugging workflow
    
      The README now accurately reflects the new configuration system we built and provides clear guidance for developers on how to use it
    
    * updates caster api url in moodle config
    
    * Updates URL paths for the APIs on the swagger dashboard
    
    * addresses on api endpoint settings and topomojo wkms build
    
    * Typo in README
    
    * makes readme more general for local servers
    
    * remove note about changing node memory size from readme
    
    * Create new LogLaunchOptions(LaunchOptions launchOptions) function
    
    ---------
    
    Co-authored-by: Adam Welle <arwelle@sei.cmu.edu>

[33mcommit 837d614c36d4298749834a99e205e7431a998f19[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Thu Feb 19 08:59:38 2026 -0500

    add IdentityClient config (#49)

[33mcommit 8f81e2b24606db74cda592da55617c032f50fec3[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon Feb 16 12:41:21 2026 -0500

    Optimize to increase rebuild speed (#48)
    
    - Adds dockerignore to prevent accidental data leakage
    - Combine unminimize and apt install layers -- unminimize does an `apt update` in the background already. Combining apt steps increases docker's ability to reuse context within the same layer and removes an extra `apt update` step
    - Use a Docker cache mount for apt layer. Allows the build to reuse apt artifacts across rebuild
    - Remove temp files from tool installs to reduce image size
    - Postcreate installs a few tools in parallel instead of serially
    - Poststart checks for claude code updates.  Since the Claude install is in the docker file, the installed version of claude is cached by docker on image build and may not update unless you ask for an update

[33mcommit e605357d05f9995b95471401831e663b897204ef[m
Author: Adam Welle <arwelle@cert.org>
Date:   Mon Feb 16 09:19:44 2026 -0500

    Add xAPI configuration for Blueprint API (#47)
    
    - Configure xAPI settings in AppHost for Blueprint (endpoint, credentials, URLs)
    - Enable LRsql in blueprint.env for xAPI support
    - Uses same ConfigureXApi helper as CITE and Gallery
    
    Co-authored-by: Adam Welle <arwelle@sei.cmu.edu>

[33mcommit 7167e6cbe33f6a08b7a578c636325e4b3aba0c01[m
Author: Adam Welle <arwelle@cert.org>
Date:   Thu Feb 12 10:45:08 2026 -0500

    Adding MISP (#46)
    
    * initial MISP setup
    
    * misp tag tooltip and enrichment added
    
    * uses newer MISP image
    
    * updates misp apphost
    
    * remove zscalar
    
    * updates cert copy
    
    * updating to latest misp
    
    * updates misp-modules image
    
    * updates moodle to debug ai
    
    * adds bedrock config to moodle
    
    * updated tag manager path
    
    * adds misp requirements
    
    * adds misp to launch
    
    * pinning kubectl-helm-minikube version
    
    * adding misp back in
    
    * sets aws creds for moodle ai
    
    * sets image model
    
    * misp redis update
    
    * moves php installation into dockerfile
    
    * apphost pulls aws creds from sso file
    
    * move mispo mitre doc to misp module
    
    * configure cite and gallery with lrsql settings
    
    remove pptbook
    
    remove misp form moodle env
    
    * remove old files
    
    remove repo for misp
    
    remove proxy script
    
    * copyright date correction
    
    * kubectl version pin
    
    * kubectl version ordering
    
    * checks for region in file
    
    * adds missing variable MIST_CERT_DEST
    
    * updates certificate copy in moodle and misp dockerfiles
    
    * cite gallery use a common function to set xapi settings
    
    * adds WithExplicitStart to moodle, misp, lrsql
    
    * uses workspaceFolder for path to setup_environment.php in launch.json
    
    * uses builder.AddRedis
    
    ---------
    
    Co-authored-by: Adam Welle <arwelle@sei.cmu.edu>
    Co-authored-by: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>

[33mcommit 81a7e707d9c75dd708f60af5abd8149cfecbf79c[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Thu Feb 12 09:14:46 2026 -0500

    add local library debugging option (#45)

[33mcommit f2042bca77b51a1fe1d7eda2874aaaa1f3bd3f54[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Wed Feb 11 07:49:54 2026 -0500

    Add "Include Error Detail=true" to API postgres connection strings (#44)
    
    Adds an extension method .WithDevSettings that can be called on an
    IResourceBuilder<PostgresDatabaseResource> resource that appends common
    development settings to the connection string.
    
    Currently, it only adds "Include Error Detail=true" to show detailed
    error messages, but additional settings could be added as needed in the
    future.

[33mcommit 31e0adf7177c948e4b376718f9c51132a4d10e86[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Mon Feb 9 10:41:53 2026 -0500

    pin k8s version (#43)
    
    The kubectl-helm-minikube devcontainer feature pulls https://dl.k8s.io/release/stable.txt
    (https://github.com/devcontainers/features/blob/main/src/kubectl-helm-minikube/install.sh#L167) when latest is specified as a version, but this file sometimes fails to load, breaking the build. Pinning a specific version bypasses this.

[33mcommit 8c037be84ab6e1f547881606a0b14a4e428ee727[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Mon Feb 9 07:39:20 2026 -0500

    Aws cli (#42)
    
    * add aws sso login option
    * add aws tab completion

[33mcommit fe5b7c4cc59b02dc200e9f7118bda006ac67e0a5[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Mon Feb 2 10:51:39 2026 -0500

    update base image tag (#41)
    
    Contains some fixes for yarn key rotation

[33mcommit f9b9b42cd221146a5b58080fdaaf0eea599c9bbe[m
Author: Matt Kaar <66427159+sei-mkaar@users.noreply.github.com>
Date:   Mon Feb 2 10:35:11 2026 -0500

    Switch Claude Code to use native installer (#40)
    
    Anthropic now recommends to use the native install for Claude Code:
    https://code.claude.com/docs/en/setup#installation
    
    Given that the [dev container feature](https://github.com/anthropics/devcontainer-features) is seven months old, this switches to installing with the recommended method and adds the VS Code extension separately.
    
    Finally, there's a small edit to the VS Code settings to stop the C# Dev Kit from changing the output focus during the dev container build.

[33mcommit 1d20918e2a716fb61dcdb83c874ce6600b16dd42[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Wed Jan 28 08:45:39 2026 -0500

    Updates and maintenance (#39)
    
    - upgrade to aspire 13.1
    - removed deprecated aspire dotnet tool and switched to official install script from aspire.dev
    - use specific dotnet image
      - this avoids some users being stuck on older 10.x.x or rc versions
    - pull repos on start
    - run fixup-wmks.sh for topo
    - add health checks to ui apps
    - refactor launch options
      - moved AddAllApplications to LaunchOptions
      - added pgadmin and mkdocs to launch options
      - default all applications to false to minimize env files
    - update extensions
      - add versions lens
      - remove prerelease for aspire
    - persistent keycloak and pgAdmin
    - update launch.json with aspire extension and ui debug options
    - enable aspire and playwright mcp servers

[33mcommit 71acd8d9db9628117d5e7508aff07b9ed480b3b5[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Tue Jan 27 09:00:57 2026 -0500

    persist claude sessions, etc. (#38)

[33mcommit 7aafa73c5104aea69a203b0abab4f8e64a8ca22e[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon Jan 26 14:24:35 2026 -0500

    Fix build fail due to yarn gpg key (#37)

[33mcommit 558f9a675c9dab3208eabb7f580323919a8073f4[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon Jan 26 10:21:14 2026 -0500

    Feature/helm charts (#35)
    
    * Keycloak helm deploy working
    
    * Change to using the crucible-dev cert
    
    1. Use the crucible-dev cert from the devcontainer for the crucible chart
    2. Remove the infra helm chart since we no longer need to generate certs
    
    * Fix chart dependency checking
    
    * Patch coredns for minikube resolution of crucible hostname without external dns
    
    * Adjust to only show UI URLs in output
    
    * Remove checks for installed commands -- devcontainer has those
    
    * Adds script for removing postgres data
    
    * Fix keycloak db job to allow keycloak to startup properly
    
    * Adds Player and pgadmin
    
    * Change execution mode of scripts
    
    * Grafana Stack WIP
    
    * Working Grafana, Prometheus, Loki
    
    * Document Grafana values
    
    * Remove prometheus ingress
    
    * Adds build-and-load script to use local dev image builds in minikube
    
    * Adds dependent helm repos
    
    * Fix Tempo config for otel traces
    
    * Bump player.api and configure otel
    
    * Adds comments for values documentation
    
    * Ignore certs in helm directory
    
    * Grafana Keycloak auth
    - Fix cert trust in grafana so it trusts keycloak's https cert
    - Add cert to grafana's trust chain so it can download plugins behind zscaler
    - point grafana auth at keycloak
    - update keycloak realm to include grafana client
    
    * Allow disabling subcharts
    
    * Adds Crucible Alloy
    - There's a bug in Helm where you cannot have 2 different charts with the same name from different repos. So if you want to deploy alloy, you have to comment out Grafana Alloy.  PR for that Helm bug is [here](https://github.com/helm/helm/pull/30976)
    
    * Adds Caster
    
    * Removed grafana creds print since it is integrated with keycloak now
    
    * Adds Blueprint
    
    * Remove CPU and RAM args from minikube startup
    
    * Adds CITE
    
    * Rearrange Caster and CITE for alphabetical order
    
    * Bump CITE chart version to fix path-based bug
    
    * Adds Gallery
    
    * Adds Gameboard and updates TopoMojo
    - Adds GB to deployed apps
    - Updates Keycloak realm for GB/TM Client Credentials Flow
    - Updates helm-deploy.sh to clean up GB PVC resources on uninstall
    - Updates TM to new chart that supports certificateMap for custom certs
    
    * Adds Steamfitter
    
    * Rearrange and add some comments
    
    * Reorganize deploy script so all script logic is at below functions
    
    * Adds moodle pointing to a local version of the chart
    
    * Update keycloak database creation to use variables from keycloak values
    
    * Add Claude Code support for dev container
    
    Configures Claude Code to use AWS Bedrock for model access inside dev container.
    
    Instructions for getting started with Claude are added to the README.
    
    * Output formatting
    
    * Fix database job bug
    
    * Remove default values from chart values
    
    * Remove unused gitea helper
    
    * Update clean-postgres.sh to reference new release by default
    
    * Update helm deploy to target 3 new charts (stored on a branch in the cmu-sei/helm-charts repo).
    
    * Use crucible umbrella charts from the helm-charts repo and move old work to a crucible-mono folder for now.
    
    * Removed unused env file
    
    * Update to use the updated, more generic, infra chart
    
    * Update monitoring values
    
    * Update to match current charts
    
    * Delete old mono-chart
    
    * Update files location
    
    * Update readme
    
    * Use common minikube start script
    
    * Move duplicate welcome message
    
    * Realm formatted on save
    
    * Generate dev certs on container rebuild. Allows removal of dev certs from git repo
    
    * Update helm chart certs to symlinks
    
    * Fix cert bug by splitting dev certs into their own directory
    
    - When dynamically generated dev certs are added to the .devcontainer/certs directory, Docker caching will see all changes to that directory and invalidated the container rebuild cache, leading to long rebuild times. Fix this by creating a new directory just for the dynamically generated dev certs - other certs, like corp proxy certs, stayed in the current directory
    
    * Update values to use cert
    
    * Allow parallel image pulls to speed up deployments in minikube
    
    * Update resource owner
    
    * Allow deployment from SEI repo in addition to local charts
    
    * Update dev cert location
    
    * Refactor helm-deploy
    
    * Fix coredns spacing
    
    * Refactor build and load
    
    * Add license
    
    * Adds license headers
    
    * Add details to readme
    
    * Remove hard coded path
    
    ---------
    
    Co-authored-by: Matt Kaar <66427159+sei-mkaar@users.noreply.github.com>

[33mcommit 41a80e501997080cf13974eca6791e279d5544e2[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Mon Jan 26 09:56:21 2026 -0500

    fix cite api scope and add crucible.common.ui repo (#36)
    
    * fix cite api scope and add crucible.common.ui repo

[33mcommit 5c4fa39ce7865fcf4900fe281060045b417c57af[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Fri Jan 9 13:36:37 2026 -0500

    add minikube resource and configure caster to use k8s jobs (#34)
    
    - added host.docker.internal to dev certs
    - moved minikube start out of poststart script
      - created aspire resource to start minikube when launching caster
      - added explicit start resources to stop or delete minikube
    - moved welcome message to poststart script
    - added env vars to Caster to use kubernetes jobs for terraform

[33mcommit b355fe53d702aefb0fd188b6aa08ac0b2edcbe8f[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Thu Jan 8 11:42:40 2026 -0500

    Adds servicedefaults project to solution (#17)

[33mcommit 7fc8143f509170145bb51e22a1bd8dae94461da3[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Thu Jan 8 11:42:07 2026 -0500

    writes the DB Provider and ConnectionString to user secrets for each … (#31)
    
    * writes the DB Provider and ConnectionString to user secrets for each api project, so that ef migrations work from the cli
    
    * refactor (#33)
    
    - removed hardcoded postgres port
    - disabled aspire proxy for postgres so tools can connect when apphost is off
    - replaced hardcoded connection string format with ConnectionStringExpression from db resources
    - replaced hardcoded project paths with aspire project metadata classes
    - added secrets for player vm api and it's additional VmUsageLogging db
    - useed dotnet user-secrets init for setting UserSecretsId
    - added connection string env var format expected by Topomojo and Gameboard
    
    ---------
    
    Co-authored-by: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>

[33mcommit d07c81a3a1191f2f98982f2d9b3a03ff6567d00c[m
Author: Matt Kaar <66427159+sei-mkaar@users.noreply.github.com>
Date:   Tue Jan 6 15:40:57 2026 -0500

    Add Claude Code support (#30)
    
    * Add Claude Code support for dev container
    
    Configures Claude Code to use AWS Bedrock for model access inside dev container.
    
    Instructions for getting started with Claude are added to the README.
    
    * Move AWS keys to ~/.aws/credentials in container
    
    Allows user to update AWS keys without rebuilding the dev container
    
    * Update README
    
    * retain claude history across rebuilds (#32)
    
    ---------
    
    Co-authored-by: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>

[33mcommit bb04e88bd4d829fff1515c92275bb8d7b868118d[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Tue Dec 9 14:05:42 2025 -0500

    Adds shell history volume (#29)

[33mcommit 5dd91dd9931a406df1fa48da43174e8f39dd411d[m
Author: Adam Welle <arwelle@cert.org>
Date:   Wed Nov 26 13:53:33 2025 -0500

    lrsql can now be toggled via env files (#28)
    
    Co-authored-by: Adam Welle <arwelle@sei.cmu.edu>

[33mcommit 9eb9793829dce1ef93d6afd4af82643ede0be766[m
Author: sei-npacheco <106097162+sei-npacheco@users.noreply.github.com>
Date:   Wed Nov 19 14:45:31 2025 -0500

    Moodle updates (#27)
    
    * adds launchoption xdebugmode to toggle moodle xdebug mode
    
    * hides xdebug launch configuration
    
    * updates readme to improve oauth and debug sections
    
    * Makes Moodle work with Zscaler
    
    ---------
    
    Co-authored-by: Adam Welle <arwelle@sei.cmu.edu>

[33mcommit 5b1111e76f5d9c334c0e994585c70f33194ae852[m
Author: sei-npacheco <106097162+sei-npacheco@users.noreply.github.com>
Date:   Tue Nov 18 14:21:00 2025 -0500

    Setting PHP Version to 8.3 (#26)

[33mcommit 956c93020b3d8bf0a3d0f274366d4ad69920480f[m
Author: Adam Welle <arwelle@cert.org>
Date:   Tue Nov 18 12:45:24 2025 -0500

    Addition of Moodle and SQL LRS (#25)
    
    * adds moodle container, url is localhost:8081
    
    * enable moodle in default env
    
    * adds all cmusei moodle repos
    
    * adding crucible cert for keycloak
    
    * adds php support to dev container
    
    * adds xdebug to moodle container
    
    * moves moodle-core files into directory created by scripts called by postcreat.sh
    
    * adds corspolicy to alloy-api configuration
    
    * updated copy plugins script to be aware of logstore plugin path
    
    * set lrsql default key for moodle and enabled logstore xapi
    
    * sets keycloak and moodle user/pass to admin/admin and binds pgadmin to a port
    
    * modifies curlsecurity before calling oauth, resets site admins to include oauth admin user
    
    * adds moodle information to the readme
    
    * changing apps to use https keycloak
    
    ---------
    
    Co-authored-by: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
    Co-authored-by: Adam Welle <arwelle@sei.cmu.edu>
    Co-authored-by: Nuria Pacheco <npacheco@cert.org>
    Co-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>

[33mcommit bd31fbe91bf9b454aaa189b775e98aa77ee15e6c[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Thu Nov 13 14:42:06 2025 -0500

    add dotnet ef 10 (#24)

[33mcommit 21438b91ab056c8c36ae132062ffd476219f23ae[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Thu Nov 13 12:58:21 2025 -0500

    add .net 10 support (#23)

[33mcommit de77753da052ee0680f7a33cea47d7988d49f65a[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Tue Nov 11 14:35:03 2025 -0500

    Feature/gameboard (#22)
    
    adds Gameboard applications

[33mcommit b7423bd55960f012a7ebfb4e2972027e487d8bb0[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Mon Nov 10 11:03:28 2025 -0500

    Adds really cool welcome message with ASCII art (#20)
    
    * Adds really cool welcome message with ASCII art
    
    * Update message
    
    * Revert "Merge branch `main` into feature/welcome-message"
    
    This reverts commit 392b1c7a1ddcfe819206ba02fa1d41a4806cc476, reversing
    changes made to fa9eb3e876088254be9a20c3d486f4a36eba3107.
    
    * Adds really cool welcome message with ASCII art
    
    * Update message
    
    * Revert "Merge branch `main` into feature/welcome-message"
    
    This reverts commit 392b1c7a1ddcfe819206ba02fa1d41a4806cc476, reversing
    changes made to fa9eb3e876088254be9a20c3d486f4a36eba3107.
    
    * File mode
    
    * README.md
    
    * Dockerfile
    
    * EOF newline
    
    * Removes chmod line

[33mcommit 6901edba1097f6f9e6f52804e9264d948e8249cc[m
Author: Matt Kaar <66427159+sei-mkaar@users.noreply.github.com>
Date:   Fri Nov 7 22:18:01 2025 +0700

    Add arm64 support for Vale install (#21)
    
    Fixes issue where dev container will not build on Apple Silicon due to arch mismatch.

[33mcommit b7b72089c9c59a94ecffb76980033e280c9cae2a[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Wed Nov 5 13:12:06 2025 -0500

    Adds GitHub CLI feature (#18)
    
    * Adds GitHub CLI feature
    
    * Remove the Vale VSCode extension (#19)

[33mcommit 7415b258cf7fce6e4ad97e9cf55cd5450d2cbd24[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Fri Oct 31 11:23:51 2025 -0400

    fix showing all repos in vs code git tab (#16)
    
    Increases git.repositoryScanMaxDepth to 3 so that vs code automatically finds all repos under /mnt/data/Crucible, including those multiple levels deep. This will allow all repos to show up in vs code's source control tab by default

[33mcommit 42e8f1035c46c33ad7f1eff5375ad7461712865f[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Thu Oct 30 15:03:03 2025 -0400

    Change devcontainer to ubuntu-noble and install man pages (#15)

[33mcommit 60e19d2f301d6738d5d9381ca4f9d7d9dda795fb[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Tue Oct 28 16:27:14 2025 -0400

    Move scripts to new folder (#14)

[33mcommit 0d4b3c362228d8118897c21896b3e4c12f4a7b94[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Tue Oct 28 16:14:26 2025 -0400

    Fix default formatter error (#13)

[33mcommit 1a216288b66f327622aad510b041408a3d6c230e[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Tue Oct 28 16:03:26 2025 -0400

    configure npm funding and move angular install to postcreate (#12)

[33mcommit efcbc65f7cdd6cca12c63b4742dd2c61a478822a[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Tue Oct 28 11:44:34 2025 -0400

    Chore/add launches (#10)
    
    * persist keycloak to postgres and app data, name the dev container and add launches to launch.json
    
    * additional launches, rename postgres container, db dump/restore instructions
    
    * remove unrequired changes
    
    * keycloak now uses postgres and the dev container works with zscalar
    
    * revert unneeded change
    
    * PR responses
    
    * update readme and remove unnecessary parameter

[33mcommit 5d7ff6343aaa04ae09658cd6395fc1b09aa607a2[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Fri Oct 17 13:40:23 2025 -0400

     added angular cli and four launch configs

[33mcommit bd2a5ee36ed18a656af3687ad8d72681b7010f5f[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Fri Oct 17 10:45:51 2025 -0400

    Adjusted nested directory approach to adding a new array of non-grouped repos to repos.json (#8)

[33mcommit 78aa0d8cdb5de181f219df7b563616f3bd394976[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Thu Oct 16 16:53:52 2025 -0400

    Adds support for helm-charts repo and local helm deploys to minikube (#7)
    
    -Adds helm-charts repo
    - Adds k-alias commands
    - Adds custom ca certs to minikube so it can pull container images

[33mcommit c9e590aa6a998980bea007915bfe3ab10952a9f0[m
Author: Tim Spencer <72101647+sei-tspencer@users.noreply.github.com>
Date:   Thu Oct 16 09:23:51 2025 -0400

    Feature/add scenario apps (#6)

[33mcommit f6d35189495af45298185157ecb67005aa06a22a[m
Author: Jarrett Booz <89405171+sei-jbooz@users.noreply.github.com>
Date:   Thu Oct 16 09:04:50 2025 -0400

    Feature/crucible docs (#5)
    
    - Adds Crucible Docs repo and additional improvements
      - Add mkdocs to Aspire deployments
      - Installs additional vscode extensions for markdown editing/linting
      - Sets some default VSCode settings
      - Ignore devcontainer additional certs

[33mcommit 77204e48f2b8cc2d0710f81f1f7a2877c029ad4f[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Tue Oct 14 13:05:50 2025 -0400

    added explicit AppHostDirectory to local resource paths (#4)

[33mcommit 31edc6aba957866a4f602aa79ffc8409458cd5fb[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Tue Oct 14 08:55:23 2025 -0400

    added minikube on container start (#3)

[33mcommit 2581af9e09aa3025a0a6f77b683ba6fa1dd371ac[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Thu Oct 9 15:16:51 2025 -0400

    Added CODEOWNERS and license-header workflow (#2)

[33mcommit e7b7eba982f132527ff063bd334b57e879133036[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Thu Oct 9 12:18:58 2025 -0400

    Update README.md (#1)

[33mcommit a46f626408ee9a5ac7e17af6c5772e720237c7f7[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Thu Oct 9 12:13:08 2025 -0400

    change crucible-dev to crucible-development (#10)

[33mcommit 6ad0b6219fb0290f4a505ad35f2265d298a703d5[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Thu Oct 9 12:08:13 2025 -0400

    added license information and removed unused ServiceDefaults project (#9)

[33mcommit 3c9180b40b0d2fa95baa9a75ec8647d73da462eb[m
Author: Ben Stein <115497763+sei-bstein@users.noreply.github.com>
Date:   Tue Oct 7 15:04:37 2025 -0400

    Update repos.json and clone script (#8)

[33mcommit 2bb2b779b22925c1e4e674cf6825f5bfb8238dfc[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Mon Oct 6 16:28:52 2025 -0400

    switch to community toolkit package for npm installation (#7)

[33mcommit 24b14bc1239e8ee39a3028a72d8e217e3bdac8eb[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Mon Oct 6 12:08:06 2025 -0400

    adds Dockerfile, custom cert support, and other minor tweaks (#6)

[33mcommit 5391bfbc5a7d1fb38d29ba92e632b21e904af00a[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Fri Oct 3 17:48:18 2025 -0400

    initial set of minimally working applications (#5)

[33mcommit 0ca5a9560a8eee28597d4ba6f23ef1feaf299956[m
Author: Andrew Schlackman <72105194+sei-aschlackman@users.noreply.github.com>
Date:   Tue Sep 30 10:05:38 2025 -0400

    Initial commit
