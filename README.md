# crucible-development

Development Environment for Crucible

## Getting Started

`crucible-development` is a [Development-Containers](https://containers.dev/)-based solution that uses .NET Aspire to orchestrate the various components of Crucible, along with supporting resources like an identity provider (Keycloak), a Postgres database server, and PGAdmin.

### Setting up Docker

To use any dev container, you'll need to run Docker on your machine. [Docker Desktop](https://www.docker.com/) is a great way to get started if you're not confident administering Docker from the command line.

#### Setting memory and storage limits

If you're on a Windows machine, Docker's consumption of your host machine's memory and storage is managed by [WSL2](https://learn.microsoft.com/en-us/windows/wsl/about). These will automatically scale to a percentage of your system's available resources, so you typically don't need to do any additional configuration.

**If you're on Mac/Linux using Docker Desktop**, you'll need to manually adjust these limits. In Docker Desktop, go to Settings -> Resources. We recommend the following minimums:

- Memory Limit: 16GB
- Disk Usage Limit: 120GB

### Custom Certificates

For details on how to add root CA certificates (including Zscaler), see the [Custom Certs Docs](.devcontainer/certs/README.md).

#### Development Certificates

Development certificates, including a CA, are generated at container build time via the `postcreate.sh` script. These certificates are git ignored and placed in the `.devcontainer/dev-certs` directory.

## Claude Code

The dev container includes [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's CLI for Claude, configured to use AWS Bedrock via the official [Claude Code devcontainer feature](https://github.com/anthropics/devcontainer-features).  There are two setup methods that can be used to authenticate to AWS.  Select the one that fits your use case.

### Setup option 1 - credential authentication

1. Copy the example credentials file:
   ```bash
   cp .devcontainer/.aws/credentials.example .devcontainer/.aws/credentials
   ```

2. Edit `.devcontainer/.aws/credentials` and add your AWS credentials:
   ```ini
   [default]
   aws_access_key_id = <AWS Access Key for Bedrock>
   aws_secret_access_key = <AWS Secret Key for Bedrock>
   ```

3. Build or rebuild the dev container

The credentials file is mounted to `/home/vscode/.aws/credentials` inside the container and is excluded from git via `.devcontainer/.gitignore`.

### Setup option 2 - sso login authentication

1. Copy the example config file:
   ```bash
   cp .devcontainer/.aws/config.example .devcontainer/.aws/config
   ```

2. Edit `.devcontainer/.aws/config` and add your AWS account information:
   ```ini
   [sso-session crucible-sso]
   sso_start_url = https://<YOUR-ORG>.awsapps.com/start
   sso_region = <your-region>
   sso_registration_scopes = sso:account:access

   [profile default]
   sso_session = crucible-sso
   sso_account_id = <your-account-id>
   sso_role_name = <your-role>
   region = <your-region>
   output = json
   ```

3. Build or rebuild the dev container
4. Run the aws-sso-login.sh script
   ```ini
   scripts/aws-sso-login.sh
   ```

The config file is mounted to `/home/vscode/.aws/config` inside the container and is excluded from git via `.devcontainer/.gitignore`.

### Usage

Once the container is running with valid credentials, run `claude` in the terminal to start Claude Code.

## Memory Optimization

The Crucible development environment includes 30+ microservices and can be memory-intensive. Several optimizations are configured to reduce memory usage:

### Intelephense PHP Extension

The Intelephense PHP language server is **disabled by default** (configured in `.devcontainer/devcontainer.json`) to save approximately 337MB of memory.

**When to enable:** When working on Moodle/PHP code:
1. Open Extensions panel (Ctrl+Shift+X)
2. Search for "Intelephense"
3. Click the gear icon → "Enable (Workspace)"
4. Reload VS Code window (Ctrl+Shift+P → "Reload Window")

**To disable again:** Follow the same steps but select "Disable (Workspace)"

### UI Development vs Production Mode

The Crucible AppHost supports running Angular UIs in two modes to optimize memory usage during development:

**Dev Mode**: Full `ng serve` with hot reload (~1.5GB per UI)
- Use for your primary development app
- Instant code changes without rebuild
- Full debugging capabilities

**Production Mode**: Lightweight production build server (~90MB per UI)
- Use for supporting apps during integration testing
- Saves ~1.4GB per UI compared to dev mode
- Requires manual rebuild when code changes

#### Configuration

The configuration system uses a two-tier approach:

**1. Primary App Selection (`.env/*.env` files - committed to git)**

Task-specific `.env` files define which app is the primary development focus using boolean flags:

```bash
# .env/blueprint.env - Blueprint development task
Launch__Blueprint=true   # Dev mode with hot reload (~1.5GB)

# .env/player.env - Player development task
Launch__Player=true      # Dev mode with hot reload (~1.5GB)

# .env/ttx.env - Multi-app development task
Launch__Player=true
Launch__Steamfitter=true
Launch__Cite=true
Launch__Gallery=true
Launch__Blueprint=true
```

**Boolean flag behavior:**
- `true` = Launch in **dev mode** (ng serve with hot reload)
- `false` or omitted = App is **off** (not launched)

**2. Supporting Apps (`.env/*.env` or `appsettings.Development.json` - local overrides)**

Add supporting apps in production or dev mode using `appsettings.Development.json` (git-ignored):

```json
{
  "Launch": {
    "Prod": ["Gallery", "Cite", "Lrsql", "PGAdmin"],
    "Dev": ["Steamfitter"]
  }
}
```

Or directly in `.env` files for team-shared configurations:
```bash
# All team members working on this task need these supporting apps
Launch__Blueprint=true    # Primary dev app
Launch__Gallery=true      # Supporting dev app
Launch__Cite=true         # Supporting dev app
```

**Configuration Precedence (highest to lowest):**
1. Boolean flag in `.env` file = `true` → **Dev mode**
2. App name in `Dev` array → **Dev mode**
3. App name in `Prod` array → **Production mode**
4. Otherwise → **Off**

**Memory Savings:**

Running 5 UIs in production mode instead of dev mode saves approximately **6-8GB** of memory, allowing you to run comprehensive integration tests while actively developing on a single primary application.

**Example Workflow:**

1. Select your task in VS Code's launch picker (e.g., "Blueprint Task")
2. The `.env/blueprint.env` file launches Blueprint in dev mode
3. Add supporting apps to your local `appsettings.Development.json`:
   ```json
   {
     "Launch": {
       "Prod": ["Player", "Gallery"],  // Prod mode for testing
       "Dev": []                        // Additional dev mode apps
     }
   }
   ```
4. Restart the task to apply changes

**Moodle Integration:**

Moodle automatically configures itself based on which Crucible services are running:
- The Crucible block only shows links to services that are currently running
- URLs are only configured for enabled services
- This prevents timeouts and slow page loads when services aren't available

#### Supported Applications

**Angular UIs** (support dev/prod modes):
- Player (player-ui, player-vm-ui, player-vm-console-ui)
- Caster (caster-ui)
- Alloy (alloy-ui)
- TopoMojo (topomojo-ui)
- Steamfitter (steamfitter-ui)
- CITE (cite-ui)
- Gallery (gallery-ui)
- Blueprint (blueprint-ui)
- Gameboard (gameboard-ui)

**Containers** (support prod mode only via boolean flags or Prod array):
- Moodle (with optional Xdebug - see Moodle Configuration below)
- Lrsql (Learning Record Store for xAPI)
- Misp (threat intelligence platform)
- PGAdmin (database administration)
- Docs (MkDocs documentation server)

## Troubleshooting

This repo is still under construction, so you may run into the occasional challenge or oddity. From our lessons learned:

- **Aspire resources appearing to have exited with no crash log:** Use Docker Desktop or otherwise exec into the container and run `docker ps -a` to see all containers, regardless of their status. Stopped containers typically show an error code that might give you a hint.
- **`npm i` issues:** Even though the devcontainer allows us to work in a container based on the same image, the image has independent builds for various architectures. This means that when you `npm i` in a `x86_64` container, some dependnecies may require precompiled binaries there that are unavailable on the ARM version. An ARM environment needs to compile these locally, which may require additional APT packages. This is why our `postcreate.sh` installs `python3-dev` currently. TL;DR - if you're having problems related to `npm install` in your container, shell in and execute it yourself to see the error log. It may be related to an OS package dependency that isn't present by default in the image.

## Known issues

- Some extensions (e.g. C#) very rarely seem to fail to install in the container's VS Code environment. If you see weird intellisense behavior or have compilation/debugging problems, ensure all extensions in the `devcontainers.json` file are installed in your container.

## Database seeding and backup

### Setup

... using blueprint as the example
create a db-dumps folder under crucible-dev
copy your blueprint.dump file into the db-dumps folder

### Seed/Restore a database

navigate to the db-dumps folder in the integrated terminal
drop the blueprint database using pgadmin
create a new blueprint database using pgadmin
assuming crucible-postgres is the postgres container name,
docker cp blueprint.dump crucible-postgres:/tmp/blueprint.dump
docker exec -it crucible-postgres /bin/bash
/usr/lib/postgresql/17/bin/psql --username=postgres blueprint < /tmp/blueprint.dump
exit

### Backup/Dump a database

docker exec -it crucible-postgres /bin/bash
pg_dump -U postgres blueprint > /tmp/blueprint.dump
exit
docker cp crucible-postgres:/tmp/blueprint.dump blueprint.dump

## Moodle configuration

Moodle will be configured using files located in `scripts/` and `resources/moodle/`.
When starting for the first time, Moodle will make a copy of some core files that will
be copied into mounts on the dev container's file system so that they are accessible for
debugging with xdebug. These files will be mounted alongside our repos under the folder
`/mnt/data/crucible/moodle/moodle-core/`. The xAPI logstore plugin will also be configured
automatically as will one default Moodle course with no activities within it.

### Moodle Tasks

Two Moodle task configurations are available:

- **`.env/moodle.env`** - Moodle without Xdebug (faster, for general development/testing)
- **`.env/moodle-xdebug.env`** - Moodle with Xdebug enabled (for PHP debugging)

Use the appropriate task based on whether you need to debug PHP code. Xdebug has significant performance overhead, so only enable it when actively debugging.

### Dynamic Crucible Integration

Moodle automatically configures the Crucible block based on which services are running:

- Only enabled services have their API URLs configured
- Disabled services have empty URLs (prevents connection timeouts)
- The block only displays links to running services
- This is configured dynamically via environment variables passed from AppHost.cs

This ensures fast dashboard loading regardless of which services are running in your current task.

### OAUTH

Moodle will be configured for oauth automatically. The oauth admin user has an email
address set and the Moodle client has a hard-coded secret.

After Moodle starts for the first time, login using the oauth admin user account and
it will than have an account on Moodle. Make the oauth admin account a site admin by
either logging in as local admin and using the Site Administration menu, or, simply
restart the Moodle container via the Aspire dashboard and when the container restarts,
the oauth admin user will be added to the list of site admins. Please note that every
time the container restarts the list of site admins will be reset to the local admin
and the oauth admin account. When the oauth admin account has been made a site admin,
login with it and navigate to the oauth server settings under Site Administration,
Server, and connect the system account. This will enable our plugins to communicate with
the various Crucible applications.

### Crucible Plugin

To configure Moodle to work with Crucible, oauth must be configured on Moodle, the service
account must be connected, and the user must be logged an with oauth.

### TopoMojo Plugin

To configure Moodle to work with TopoMojo, login to TopoMojo, generate an API key, and
add that API key to the Moodle crucible plugin's configuration in the Moodle UI or in the
script `post_configure.sh`.

### Developing New Moodle Plugins

Moodle plugins are stored in a hierarchical directory structure that mirrors the Moodle container layout:

```
/mnt/data/crucible/moodle/
  ├── mod/topomojo/          # mod_topomojo plugin
  ├── mod/crucible/          # mod_crucible plugin
  ├── admin/tool/lptmanager/ # tool_lptmanager plugin
  ├── blocks/crucible/       # block_crucible plugin
  └── moodle-core/           # Core Moodle files (theme, lib, etc.)
```

To add new Moodle plugin repositories, add them to `scripts/repos.json` or `scripts/repos.local.json`. The clone script automatically maps plugin names to the correct hierarchical paths. **Everything else is automatic:**

- **Clone script** creates hierarchical directory structure
- **AppHost.cs** dynamically reads repos.json + repos.local.json and creates bind mounts
- **xdebug_filter.php** is auto-generated during devcontainer setup
- **launch.json** uses a general pathMapping that covers all plugins automatically

**No manual configuration needed!** Just add the plugin to repos.json or repos.local.json and rebuild.

#### Adding Private/Internal Repositories

For private repositories (internal Git servers, private GitHub repos, or third-party plugins that shouldn't be committed to this public repo), use the **local repository configuration** pattern:

1. Create `scripts/repos.local.json` from the example template:
   ```bash
   cp scripts/repos.local.json.example scripts/repos.local.json
   ```

2. Add your private repositories to `scripts/repos.local.json`:
   ```json
   {
     "groups": [
       {
         "name": "moodle",
         "repos": [
           {
             "name": "logstore_xapi",
             "url": "https://github.com/xAPI-vle/moodle-logstore_xapi"
           },
           {
             "name": "prototype_plugin",
             "url": "https://git.internal.example.com/moodle/prototype_plugin.git"
           }
         ]
       }
     ]
   }
   ```

3. Run the clone script:
   ```bash
   ./scripts/clone-repos.sh
   ```

The `repos.local.json` file is git-ignored, so your private repository URLs remain private. The clone script automatically merges this with the public `repos.json` configuration.

**Supported URL formats:**
- HTTPS: `https://github.com/org/repo.git`
- SSH: `git@github.com:org/repo.git`
- Internal Git server: `https://git.internal.example.com/project/repo.git`
- Personal access tokens: `https://token@github.com/org/repo.git`

#### Creating a Private Mirror for Custom Development

If you need to customize a public plugin (like `logstore_xapi`) that can't be forked privately on GitHub, create a private mirror on your internal Git server:

**Initial Setup:**

1. **Clone the upstream repository:**
   ```bash
   cd /tmp
   git clone https://github.com/xAPI-vle/moodle-logstore_xapi.git
   cd moodle-logstore_xapi
   ```

2. **Create an empty private repo on your internal Git server** (via web UI)
   - Repository name: `moodle-logstore_xapi`
   - Do NOT initialize with README/gitignore

3. **Configure remotes:**
   ```bash
   # Rename GitHub remote to upstream
   git remote rename origin upstream

   # Add your internal Git server as origin
   git remote add origin ssh://git@git.internal.example.com/youruser/moodle-logstore_xapi.git

   # Verify remotes
   git remote -v
   # Should show:
   #   origin    ssh://git@git.internal.example.com/... (your internal Git server)
   #   upstream  https://github.com/xAPI-vle/... (original GitHub)
   ```

4. **Push to your private repository:**
   ```bash
   # Rename master to main (modern convention)
   git branch -m master main

   # Push all branches and tags
   git push -u origin main
   git push origin --all
   git push origin --tags
   ```

5. **Update `repos.local.json`** to use your internal Git server URL:
   ```json
   {
     "groups": [{
       "name": "moodle",
       "repos": [{
         "name": "logstore_xapi",
         "url": "ssh://git@git.internal.example.com/youruser/moodle-logstore_xapi.git"
       }]
     }]
   }
   ```

6. **Clone into development environment:**
   ```bash
   cd /workspaces/crucible-development
   ./scripts/clone-repos.sh
   ```

**Daily Workflow:**

```bash
cd /mnt/data/crucible/moodle/admin/tool/log/store/xapi

# Create feature branch for custom work
git checkout -b feature/branch-name

# Make your changes
# ... edit files ...

# Commit and push to your internal repository
git add .
git commit -m "commit message"
git push -u origin feature/branch-name

# Merge to main when ready
git checkout main
git merge feature/branch-name
git push origin main
```

**Syncing with Upstream (pull latest from GitHub):**

```bash
# Fetch latest from upstream GitHub
git fetch upstream

# Switch to your main branch
git checkout main

# Merge upstream changes
git merge upstream/master
# Note: Many GitHub repos still use 'master' (not 'main')

# Resolve any conflicts with your customizations

# Push updated main to your internal repository
git push origin main

# Update your feature branch
git checkout feature/branch-name
git rebase main  # or: git merge main
```

**Quick Commands:**

```bash
# See what's new on upstream before merging
git fetch upstream
git log main..upstream/master --oneline

# Pull and merge in one step
git checkout main
git pull upstream master
git push origin main
```

#### Automatic Xdebug Configuration

The xdebug filter configuration is automatically generated from `repos.json` and `repos.local.json`:

- **Template:** `Crucible.AppHost/resources/moodle/xdebug_filter.php.template` (checked into git, core paths only)
- **Generated file:** `Crucible.AppHost/resources/moodle/xdebug_filter.php` (git-ignored, includes all plugins)
- **Generated by:** `scripts/generate-xdebug-filter.sh` (runs during devcontainer postcreate)
- **When to regenerate:** Run `./scripts/generate-xdebug-filter.sh` manually if you add/remove plugins after container creation

The generated file is **git-ignored** to prevent accidentally committing private plugin paths from `repos.local.json`. The Dockerfile uses the generated file if it exists, or falls back to the template.

The script automatically maps Moodle plugin naming conventions to their container paths:
- `mod_*` → `/var/www/html/mod/*`
- `tool_*` → `/var/www/html/admin/tool/*`
- `logstore_*` → `/var/www/html/admin/tool/log/store/*`
- `block_*` → `/var/www/html/blocks/*`
- And all other standard Moodle plugin types

#### Hierarchical Directory Structure Benefits

With the hierarchical directory structure, `launch.json` uses **simplified pathMappings**:

```json
{
  // Specific paths for moodle-core (must come first)
  "/var/www/html/theme": "/mnt/data/crucible/moodle/moodle-core/theme",
  "/var/www/html/lib": "/mnt/data/crucible/moodle/moodle-core/lib",
  "/var/www/html/admin/cli": "/mnt/data/crucible/moodle/moodle-core/admin/cli",
  "/var/www/html/ai/provider": "/mnt/data/crucible/moodle/moodle-core/ai/provider",
  "/var/www/html/ai/classes": "/mnt/data/crucible/moodle/moodle-core/ai/classes",

  // General catch-all for ALL plugins
  "/var/www/html": "/mnt/data/crucible/moodle"
}
```

This means you **no longer need to update `launch.json`** when adding new plugins! The general pathMapping automatically covers all plugins because the host and container directory structures now match. Only moodle-core paths need specific mappings.

**Fully automatic workflow:**
1. Add plugin to `repos.json` or `repos.local.json`
2. Run `./scripts/clone-repos.sh` (or rebuild devcontainer)
3. Rebuild/restart containers

Everything else (bind mounts, xdebug filter, path mappings) is handled automatically!

#### Migrating from Flat to Hierarchical Structure

If you have an existing development environment with the old flat structure (`mod_topomojo`, `tool_lptmanager`, etc.), use the migration script:

```bash
./scripts/migrate-moodle-hierarchical.sh
```

This script will:
1. Remove old flat plugin directories (mod_*, tool_*, etc.)
2. Preserve the new hierarchical structure and moodle-core
3. Display the resulting directory structure

After migration:
- Rebuild your devcontainer or restart Docker containers to pick up the new bind mounts
- All xdebug path mappings will work automatically

**Manual migration alternative:**
```bash
# Clone new structure
./scripts/clone-repos.sh

# Remove old flat directories
./scripts/migrate-moodle-hierarchical.sh
```

### Adding Additional Official Plugins for Moodle

To add additional plugins, add them to the `PLUGINS` environment variable in `AppHost.cs`.

### Moodle PHP IntelliSense

The Intelephense PHP language server is disabled by default to save approximately 337MB of memory. When working on Moodle/PHP code, you'll want to enable it for code completion, go-to-definition, and other IntelliSense features.

**To enable Intelephense:**
1. Open VS Code Settings: `Ctrl+,` (or `Cmd+,` on Mac)
2. Search for: `intelephense enable`
3. Check the box for **"Intelephense: Enable"** (make sure you're in the **Workspace** tab)
4. Reload VS Code window: `Ctrl+Shift+P` → "Reload Window"

**To disable when done:** Follow the same steps but uncheck the box to free up the memory.

### Moodle PHP Debugging with xdebug

Two Moodle tasks are available for different debugging needs:

**Normal Moodle Task** (`.env/moodle.env`):
- Xdebug is **off** by default
- Use for general development and testing
- Faster startup and better performance

**Moodle with Xdebug Task** (`.env/moodle-xdebug.env`):
- Xdebug is **enabled** (`XDEBUG_MODE=debug`)
- Use when you need to set breakpoints and debug PHP code
- Requires VS Code debugger listener to be running

**To debug Moodle PHP code:**
1. Select the "Moodle with Xdebug" task in VS Code
2. Start the "Listen for Xdebug" debugger in VS Code (F5 or Run panel)
3. Set breakpoints in your PHP code
4. Access Moodle in the browser - breakpoints will be hit

**Important:** PHP on the Moodle container will pause execution if Xdebug is enabled but the VS Code debugger listener is not running. Always start the "Listen for Xdebug" debugger before accessing Moodle when using the Xdebug task.

**Xdebug Filter:** An xdebug filter (`xdebug_filter.php`) is automatically generated from your plugin configuration to limit the scope of code analyzed by Xdebug. This improves performance by only debugging your custom plugins and core Moodle paths, not third-party dependencies.

To make additional paths available for debugging, add the paths to `Dockerfile.MoodleCustom`,
`add-moodle-mounts.sh`, `AppHost.cs`, `pre_configure.sh` and `launch.json`.

### Moodle UI Debug Display

The standard Moodle debugging level and display via the UI can be set under the normal Site
Administration, Development, menu. The install process for this container installs the plugin
`tool_userdebug` which allows site admins to easily toggle debug display via an icon added
to the header just to the left of the user avatar in the upper right corner of the screen.
This is the preferred method to enable display of debug messages inside of the browser.

## Library Development

The crucible-common-dotnet shared library is cloned into the `/mnt/data.crucible/libraries` directory. By default, APIs that use these libraries pull the published packages from NuGet. When developing or debugging these libraries, it is convenient to point the APIs to the local copy of the library. Developers can use the `scripts/toggle-local-library.sh` script to easily toggle between the default published NuGet packages and local Project References.

A Directory.Build.props file is mounted to `/mnt/data`. This file defines a variable `<UseLocalEntityEvents>false</UseLocalEntityEvents>`. If you want to use the local version of the Crucible.Common.EntityEvents library, copy this file to `/mnt/data/crucible` and set `<UseLocalEntityEvents>true</UseLocalEntityEvents>`. This will tell MSBuild to use a local project reference instead of the NuGet package and this file will not get checked into git. The script automates this process for you.

This pattern should be extended to the other libraries in crucible-common-dotnet as necessary in the future.
