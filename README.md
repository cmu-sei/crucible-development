# crucible-development

Development Environment for [Crucible](https://github.com/cmu-sei/crucible) - a cybersecurity training and simulation platform developed by Carnegie Mellon University's Software Engineering Institute (SEI).

## Table of Contents

- [Getting Started](#getting-started)
  - [Setting up Docker](#setting-up-docker)
  - [Custom Certificates](#custom-certificates)
- [Using the Dev Container](#using-the-dev-container)
  - [Opening the Workspace](#opening-the-workspace)
  - [Launch Profiles](#launch-profiles)
  - [Default Credentials](#default-credentials)
- [Claude Code](#claude-code)
- [Playwright Testing](#playwright-testing)
- [GitHub CLI](#github-cli)
- [Memory Optimization](#memory-optimization)
  - [Intelephense PHP Extension](#intelephense-php-extension)
  - [UI Development vs Production Mode](#ui-development-vs-production-mode)
- [Database Seeding and Backup](#database-seeding-and-backup)
- [Moodle Configuration](#moodle-configuration)
- [Library Development](#library-development)
  - [.NET Libraries (crucible-common-dotnet)](#net-libraries-crucible-common-dotnet)
  - [Angular Libraries (Crucible.Common.Ui)](#angular-libraries-cruciblecommonui)

## Getting Started

`crucible-development` is a [Development-Containers](https://containers.dev/)-based solution that uses [Aspire](https://aspire.dev) to orchestrate the various components of Crucible, along with supporting resources like an identity provider (Keycloak), a Postgres database server, and Moodle.

> If your environment is already set up, skip to [Using the Dev Container](#using-the-dev-container).

### Setting up Docker

To use any dev container, you'll need to run Docker on your machine. [Docker Desktop](https://www.docker.com/) is a great way to get started.

#### Setting memory and storage limits

If you're on a Windows machine, Docker's consumption of your host machine's memory and storage may be managed by [WSL2](https://learn.microsoft.com/en-us/windows/wsl/about). These will automatically scale to a percentage of your system's available resources, so you typically don't need to do any additional configuration.

**If you're on Mac/Linux using Docker Desktop**, you'll need to manually adjust these limits. In Docker Desktop, go to Settings -> Resources. We recommend the following minimums:

- Memory Limit: 16GB
- Disk Usage Limit: 120GB

This will vary based on usage. Running all applications simultaneously may require more memory. See [Memory Optimization](#memory-optimization) for tips.

### Custom Certificates

For details on how to add root CA certificates, see the [Custom Certs Docs](.devcontainer/certs/README.md).

#### Development Certificates

The Aspire project uses `dotnet dev-certs` to generate development certificates. Additional development certificates, including a CA, are generated at container build time via the `postcreate.sh` script for testing helm deployments in minikube. These certificates are git ignored and placed in the `.devcontainer/dev-certs` directory.

## Using the Dev Container

This repo is designed exclusively for use within the dev container. The scripts and Aspire orchestration assume dev container paths and configurations and will not work outside of it.

### Opening the Workspace

To see all Crucible repositories in the VS Code file explorer, you need to open the workspace file:

1. Click on `crucible-dev.code-workspace` in the VS Code file explorer
2. Click the **"Open Workspace"** button that appears in the bottom-right corner

Alternatively, use **File > Open Workspace from File** and select `crucible-dev.code-workspace`.

You can confirm you're in the workspace when the VS Code title bar shows **"crucible-dev (Workspace)"**. Without this, the `/mnt/data/crucible` directory (containing all cloned repositories) won't appear in the file explorer. This can be done before or after opening the repo inside the dev container.

### Launch Profiles

Several VS Code launch profiles are pre-configured for different development scenarios. To use them:

1. Click the **Run and Debug** icon in the left panel (or press `Ctrl+Shift+D`)
2. Use the dropdown at the top to select a profile
3. Press **F5** (or the green play button) to launch

Each profile runs a different subset of services depending on what you're working on. Some examples:

- **Default** - Launches most services (resource-intensive)
- **Player**, **Blueprint**, **Caster**, **Steamfitter**, etc. - Focused on a single application
- **Exercise**, **TTX** - Multi-app profiles for specific workflows
- **Moodle**, **Moodle-Xdebug** - Moodle development with optional PHP debugging

Pressing F5 without changing the dropdown launches the Default profile (or your previously selected profile). Be aware that the Default profile launches many applications and uses significant system resources.

### Default Credentials

The default admin user credentials are:

- **Username:** `admin`
- **Password:** `admin`

## Claude Code

The dev container includes [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's CLI for Claude, configured to use AWS Bedrock.  There are two setup methods that can be used to authenticate to AWS.  Select the one that fits your use case.

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
   ```bash
   scripts/aws-sso-login.sh
   ```

The config file is mounted to `/home/vscode/.aws/config` inside the container and is excluded from git via `.devcontainer/.gitignore`.

### Usage

Once the container is running with valid credentials, run `claude` in the terminal to start Claude Code.

## Playwright Testing

The dev container includes [Playwright](https://playwright.dev/) for end-to-end testing of Crucible applications. Dependencies (Node.js packages and Chromium browser) are installed automatically during container creation.

The test suite lives in `/mnt/data/crucible/crucible-tests/` and covers all 11 Crucible applications. Each app has a test plan and organized spec files. See the [crucible-tests README](https://github.com/cmu-sei/crucible-tests) for full documentation.

### VS Code Playwright Extension

The [Playwright Test for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-playwright.playwright) extension is pre-installed and configured to use the Crucible test suite. Open the **Testing** panel in VS Code to browse, run, and debug tests visually.

### Claude Code Playwright Test Agents

The dev container automatically initializes three [Playwright test agents](https://playwright.dev/docs/test-agents) for use with Claude Code during container creation. These agents allow Claude Code to plan, generate, and fix Playwright tests interactively using a real browser.

| Agent | Purpose |
|-------|---------|
| **playwright-test-planner** | Navigates a running application in a browser, explores the UI, and produces a comprehensive test plan (saved as a markdown file) |
| **playwright-test-generator** | Takes a test plan and generates `.spec.ts` files by executing each step in a real browser, then recording the actions |
| **playwright-test-healer** | Runs failing tests, debugs them in a live browser, identifies root causes, and fixes the test code |

To use the agents, start Claude Code in the terminal and ask it to plan, generate, or fix tests. Claude Code will automatically delegate to the appropriate agent. For example:

- *"Create a test plan for the Player application"* — invokes the **planner** to explore the Player UI and produce a test plan
- *"Generate tests for the Blueprint authentication section"* — invokes the **generator** to create spec files from the test plan
- *"Fix the failing Blueprint tests"* — invokes the **healer** to debug and repair broken tests

The agents require Crucible services to be running since they interact with the applications through a real browser.

### Running Tests from the Terminal

Start the Crucible services first (via a VS Code launch profile or `aspire run`), then:

```bash
cd /mnt/data/crucible/libraries/crucible-tests

# Run tests for a specific application
./run-tests.sh topomojo
./run-tests.sh blueprint
./run-tests.sh player

# Run all tests
./run-tests.sh all

# Smoke tests (login/home) for a specific app or all apps
./run-tests.sh quick --app cite
./run-tests.sh quick

# Interactive UI mode
./run-tests.sh ui gameboard

# Headed mode (see browser)
./run-tests.sh headed caster

# Filter tests by pattern
./run-tests.sh alloy --filter login

# Skip health checks
./run-tests.sh topomojo --no-check

# View test report
./run-tests.sh report
```

The script automatically checks that Keycloak and the target application are reachable before running tests. Use `--no-check` to skip these checks.

### Headed Browser Support

Headed mode (visible browser windows) works differently depending on your platform:

**Windows/WSL** -- Headed browsers render natively to your Windows desktop via WSLg. No additional setup is required. The Playwright MCP server, `--headed` tests, and VS Code's Playwright extension all display browser windows on your host automatically.

**Mac** -- There is no native display server, so a VNC-based virtual display is used. Start it on demand:

```bash
scripts/desktop.sh start   # Start VNC/noVNC on display :0
scripts/desktop.sh status  # Check if services are running
scripts/desktop.sh stop    # Stop VNC services
```

After starting, view the desktop at <http://localhost:6080> (password: `crucible`). Headed browsers (including the Playwright MCP server) will render to this virtual display.

VNC services are **not** started automatically to conserve resources. They are only needed when running headed/UI mode tests or using the Playwright MCP server in headed mode.

### Configuring Service URLs

All service URLs used by the test suite are defined in a single file:

```
/mnt/data/crucible/crucible-tests/.env
```

Edit this file to change ports or hostnames for your environment. The `.env` file is loaded by both the shell scripts (`run-tests.sh`, `setup.sh`) and the Playwright TypeScript configuration. If the file is missing, all URLs fall back to their default `localhost` values.
## GitHub CLI

The dev container includes the [GitHub CLI](https://cli.github.com/) (`gh`). The GitHub CLI's authentication is reused by the GitHub MCP server for agentic development.

### Authentication

GitHub CLI authentication is **persisted across container rebuilds** using a bind mount. Credentials stored via `gh auth login` are saved and automatically available inside the container after a rebuild.

To authenticate for the first time:

```bash
gh auth login
```

Follow the prompts to authenticate via browser or token.

### Recommended: Use a Fine-Grained Personal Access Token

We strongly recommend authenticating with a **fine-grained personal access token (PAT)** rather than a full OAuth login. Fine-grained PATs let you limit exactly what `gh` can do on your behalf.

**To create a fine-grained PAT:**

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Click **Generate new token**
3. Set an expiration date
4. Under **Repository access**, select only the repositories relevant to your work
5. Under **Permissions**, grant only what you need — a reasonable read-heavy baseline:

| Permission | Access |
|---|---|
| Contents | Read-only |
| Issues | Read and write |
| Pull requests | Read and write |
| Metadata | Read-only (required) |
| Actions | Read-only |
| Secrets | None |
| Administration | None |

6. Click **Generate token**, copy it, then run:

```bash
gh auth login --with-token <<< "your_token_here"
```

> Avoid granting `Administration`, `Secrets`, or `Members` permissions — these allow destructive or sensitive operations that are unlikely to be needed during normal development.

### Claude Code Restrictions

To prevent accidental or unintended destructive actions, Claude Code has been configured to **deny** the following `gh` commands in `.claude/settings.json`:

**Raw API access**
- `gh api` — bypasses all CLI safeguards; denied entirely

**Delete operations**
- `gh alias delete`, `gh cache delete`, `gh codespace delete`
- `gh extension remove`, `gh gist delete`, `gh gpg-key delete`
- `gh issue delete`, `gh label delete`
- `gh project delete`, `gh project field-delete`, `gh project item-delete`, `gh project item-archive`
- `gh release delete`, `gh release delete-asset`
- `gh repo delete`, `gh repo deploy-key delete`
- `gh run delete`, `gh secret delete`, `gh ssh-key delete`, `gh variable delete`

**Repository state changes**
- `gh repo archive`, `gh repo unarchive`
- `gh repo rename`, `gh repo transfer`
- `gh repo visibility` — prevents accidentally making a private repo public

**Operational disruption**
- `gh run cancel` — halts CI runs
- `gh workflow disable` — disables automation
- `gh issue transfer` — moves issues to other repos
- `gh codespace rebuild` — destroys current codespace state

**Credential operations**
- `gh auth logout` — removes stored credentials
- `gh config clear-cache` — wipes cached auth data

Claude will be blocked from running any of the above and will need to ask you to run them manually if they are genuinely required.



## Memory Optimization

The Crucible development environment includes 30+ microservices and can be memory-intensive. Several optimizations are configured to reduce memory usage:

### Intelephense PHP Extension

The Intelephense PHP language server is **disabled by default** (configured in `.devcontainer/devcontainer.json`) to save approximately 337MB of memory. See [Moodle PHP IntelliSense](#moodle-php-intellisense) for instructions on enabling it when working on PHP code.

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

## Database Seeding and Backup

These examples use `blueprint` as the database name. Replace with the appropriate database name for your use case.

### Setup

1. Create a `db-dumps` folder under the project root:
   ```bash
   mkdir -p db-dumps
   ```
2. Copy your `.dump` file into the `db-dumps` folder

### Seed/Restore a Database

1. Drop the existing database using PGAdmin
2. Create a new empty database with the same name using PGAdmin
3. Copy the dump file into the container and restore it:
   ```bash
   docker cp db-dumps/blueprint.dump crucible-postgres:/tmp/blueprint.dump
   docker exec -it crucible-postgres /bin/bash
   /usr/lib/postgresql/17/bin/psql --username=postgres blueprint < /tmp/blueprint.dump
   exit
   ```

### Backup/Dump a Database

```bash
docker exec -it crucible-postgres /bin/bash
pg_dump -U postgres blueprint > /tmp/blueprint.dump
exit
docker cp crucible-postgres:/tmp/blueprint.dump db-dumps/blueprint.dump
```

## Moodle Configuration

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
1. Open Extensions panel (`Ctrl+Shift+X`)
2. Search for "Intelephense"
3. Click the gear icon and select **"Enable (Workspace)"**
4. Reload VS Code window: `Ctrl+Shift+P` → "Reload Window"

**To disable when done:** Follow the same steps but select "Disable (Workspace)" to free up memory.

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

### .NET Libraries (crucible-common-dotnet)

The crucible-common-dotnet shared library is cloned into the `/mnt/data/crucible/libraries` directory. By default, APIs that use these libraries pull the published packages from NuGet. When developing or debugging these libraries, it is convenient to point the APIs to the local copy of the library. Developers can use the `scripts/toggle-local-library.sh` script to easily toggle between the default published NuGet packages and local Project References.

#### Usage

```bash
# Enable local library debugging (uses local EntityEvents source)
./scripts/toggle-local-library.sh on

# Disable local library debugging (uses NuGet packages)
./scripts/toggle-local-library.sh off

# Check current status
./scripts/toggle-local-library.sh status

# Toggle current state
./scripts/toggle-local-library.sh
```

A Directory.Build.props file is mounted to `/mnt/data`. This file defines a variable `<UseLocalEntityEvents>false</UseLocalEntityEvents>`. If you want to use the local version of the Crucible.Common.EntityEvents library, copy this file to `/mnt/data/crucible` and set `<UseLocalEntityEvents>true</UseLocalEntityEvents>`. This will tell MSBuild to use a local project reference instead of the NuGet package and this file will not get checked into git. The script automates this process for you.

This pattern should be extended to the other libraries in crucible-common-dotnet as necessary in the future.

### Angular Libraries (Crucible.Common.Ui)

The `@cmusei/crucible-common` Angular library is cloned into `/mnt/data/crucible/libraries/Crucible.Common.Ui`. By default, Angular UIs install the published package from npm. To develop the library locally and have UIs use your local changes with live rebuilds, enable the `LinkCommonUI` launch option.

#### Configuration

Set `LinkCommonUI` to `true` in `appsettings.Development.json` (git-ignored):

```json
{
  "Launch": {
    "LinkCommonUI": true
  }
}
```

Or in a `.env` file:

```bash
Launch__LinkCommonUI=true
```

#### What it does

When `LinkCommonUI` is enabled, the AppHost:

1. **Builds and watches** the common library — runs `ng build crucible-common --watch`, which does an initial build then rebuilds automatically when source files change
2. **Creates an npm link** — once the initial build completes, creates a global npm link to the built library
3. **Links each UI** — each Angular UI runs `npm link @cmusei/crucible-common` to use the local build instead of the published npm package
4. **Uses `--configuration localNPM`** — UIs are started with an Angular configuration that resolves the library from the local npm link

The AppHost uses a health check to ensure UIs don't start until the library is fully built and linked, preventing race conditions during startup.

#### Workflow

1. Enable `LinkCommonUI` in your configuration
2. Start the Aspire application (F5 or `aspire run`)
3. Edit files in `/mnt/data/crucible/libraries/Crucible.Common.Ui`
4. The watch process rebuilds the library automatically
5. UIs using `ng serve` pick up the changes via the npm link
