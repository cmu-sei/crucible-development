# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Crucible Development is a Development Container and .NET Aspire orchestration environment for the Crucible platform - a cybersecurity training and simulation platform developed by Carnegie Mellon University's Software Engineering Institute (SEI).

This is a **meta-repository** that orchestrates 30+ external repositories cloned into `/mnt/data/crucible/`. The main orchestrator (`Crucible.AppHost`) manages all microservices using .NET Aspire.

## Architecture

### Core Components
- **Crucible.AppHost** - Central .NET Aspire orchestrator that manages all services
- **PostgreSQL** - Centralized multi-tenant database (container: `crucible-postgres`)
- **Keycloak** - OpenID Connect identity provider (ports 8080/8443)
- **MkDocs** - Documentation server (port 8000)
- **PGAdmin** - Database admin UI (port 33000)

### Microservices (in `/mnt/data/crucible/`)
| Service | Purpose | Ports |
|---------|---------|-------|
| Player API/UI | Main learning platform | 4301 |
| Player VM API/UI | Virtual machine management | 4303 |
| Console UI | Console access | 4305 |
| Caster API/UI | Infrastructure orchestration | 4310 |
| Alloy API/UI | Advanced orchestration | 4403 |
| TopoMojo API/UI | Network topology simulation | 5000/4201 |
| Steamfitter API/UI | Scenario execution | 4401 |
| CITE API/UI | Collaborative training | 4721 |
| Gallery API/UI | Content management | 4723 |
| Blueprint API/UI | Scenario design | 4725 |
| Gameboard API/UI | Competition/scoring | 4202 |
| Moodle | LMS integration | 8081 |
| LRsql | Learning Record Store (xAPI) | 9274 |

### Service Configuration
Services are controlled via environment files in `.env/` directory and `LaunchOptions` class. Environment files use `Launch__<ServiceName>=true/false` pattern (e.g., `Launch__Player=true`). Each service can be individually toggled without rebuilding.

## Common Commands

### Building
```bash
dotnet build Crucible.slnx
dotnet publish Crucible.slnx
```

### Running Services
Use VS Code's Run and Debug panel with launch configurations. Each configuration uses a corresponding `.env/<name>.env` file:
- **Default** - All default services (excluding Moodle/LRsql)
- **Exercise**, **TTX** - Specific service combinations
- **Service-specific** - Player, Caster, Alloy, TopoMojo, Steamfitter, CITE, Gallery, Blueprint, Gameboard
- **Moodle** - Runs Moodle without xdebug
- **Moodle Debug** - Compound task that runs Moodle with xdebug enabled (starts both Moodle-Xdebug and Xdebug configurations)
- **Lrsql** - Runs Learning Record Store

### Database Operations
```bash
# Seed/restore database (example: blueprint)
docker cp blueprint.dump crucible-postgres:/tmp/blueprint.dump
docker exec -it crucible-postgres /bin/bash
/usr/lib/postgresql/17/bin/psql --username=postgres blueprint < /tmp/blueprint.dump

# Backup database
docker exec -it crucible-postgres /bin/bash
pg_dump -U postgres blueprint > /tmp/blueprint.dump
exit
docker cp crucible-postgres:/tmp/blueprint.dump blueprint.dump
```

### Global Tools
```bash
dotnet tool install -g Aspire.Cli
dotnet tool install --global dotnet-ef --version 10
npm install -g @angular/cli@latest
```

## Development Patterns

### Adding New Services
1. Add repository to `scripts/repos.json`
2. Update `Crucible.AppHost/AppHost.cs` with service registration
3. Add launch configuration to `.vscode/launch.json`
4. Create environment file in `.env/` directory

### Adding Moodle Plugins
1. Add repository to `scripts/repos.json`
2. Update `.vscode/launch.json` (add path mappings for xdebug)
3. Update `Crucible.AppHost/AppHost.cs` (add bind mounts)
4. Update `scripts/xdebug_filter.sh`
5. For additional paths: also update `Dockerfile.MoodleCustom`, `add-moodle-mounts.sh`, `pre_configure.sh`

### Service Dependencies Pattern
All services follow this pattern in `AppHost.cs`:
- `.WaitFor(postgres)` - Wait for database
- `.WaitFor(keycloak)` - Wait for identity provider
- `.WithReference(db, "PostgreSQL")` - Database connection
- `.WithExplicitStart()` - Service won't auto-start

## Key Files

- `Crucible.AppHost/AppHost.cs` - Main service orchestration logic
- `Crucible.AppHost/LaunchOptions.cs` - Service toggle options
- `Crucible.slnx` - Solution file including external projects
- `scripts/repos.json` - List of repositories to clone
- `scripts/clone-repos.sh` - Repository cloning script
- `.env/*.env` - Environment configurations for different launch profiles
- `Crucible.AppHost/resources/` - UI configuration files and Keycloak realm

## Requirements

### License Headers
All source files require MIT (SEI)-style copyright headers. Enforced by GitHub Actions on PRs.

```csharp
// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
```

### Docker Resources
- Memory: 16GB minimum
- Disk: 120GB minimum

### Custom Certificates
For corporate proxy environments (Zscaler), place certificates in `.devcontainer/certs/`. See `.devcontainer/certs/README.md`.

## Moodle Development

### OAuth Setup
After first Moodle start:
1. Login with oauth admin user to create account in Moodle
2. Make oauth admin a site admin (either via local admin UI or restart Moodle container - it auto-adds oauth admin on restart)
3. Login as oauth admin, go to Site Administration > Server > OAuth server settings and connect the system account

### Xdebug
- Control xdebug mode via `Launch__XdebugMode` in env files (values: `off`, `debug`, `coverage`, etc.)
- **Warning**: PHP will pause execution after "Upgrading config.php..." if xdebug is enabled but VS Code debugger isn't running
- Xdebug listens on port 9003; ensure the Xdebug launch config is running before starting Moodle with xdebug enabled
- Debug display in browser: use `tool_userdebug` plugin icon (left of user avatar)

### Plugin Configuration
- **Crucible Plugin**: Requires oauth configured, service account connected, and user logged in via oauth
- **TopoMojo Plugin**: Generate API key in TopoMojo UI and add to Moodle plugin config or `post_configure.sh`
- **Additional Official Plugins**: Add to `PLUGINS` environment variable in `AppHost.cs`

## Troubleshooting

- **Aspire resources exit with no log**: Run `docker ps -a` to see stopped containers and error codes
- **npm install issues on ARM**: May need additional OS packages; run `npm i` manually to see errors
- **C# extension fails in container**: Reinstall extensions listed in `devcontainer.json`
