# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

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
| Player API/UI | Team access to virtual environments | 4301 |
| Player VM API/UI | Virtual machine management | 4303 |
| Console UI | VM console access | 4305 |
| Caster API/UI | Infrastructure orchestration | 4310 |
| Alloy API/UI | On-demand event orchestration | 4403 |
| TopoMojo API/UI | Network topology builder | 5000/4201 |
| Steamfitter API/UI | Scenario execution | 4401 |
| CITE API/UI | Collaborative training | 4721 |
| Gallery API/UI | Content management | 4723 |
| Blueprint API/UI | Scenario design | 4725 |
| Gameboard API/UI | Competition | 4202 |
| Moodle | LMS integration | 8081 |
| LRsql | Learning Record Store (xAPI) | 9274 |
| CATAPULT Player | cmi5 content player (xAPI) | 3398 |

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

## Key Files

- `Crucible.AppHost/AppHost.cs` - Main service orchestration logic
- `Crucible.AppHost/LaunchOptions.cs` - Service toggle options
- `Crucible.slnx` - Solution file including external projects
- `scripts/repos.json` - Repositories to clone
- `.env/*.env` - Environment configurations for different launch profiles
- `Crucible.AppHost/resources/` - UI configuration files and Keycloak realm

## General recommendations for working with Aspire

1. Before making any changes always run the apphost using `aspire run` and inspect the state of resources to make sure you are building from a known state.
2. Changes to the _AppHost.cs_ file will require a restart of the application to take effect.
3. Make changes incrementally and run the aspire application using the `aspire run` command to validate changes.
4. Use the Aspire MCP tools to check the status of resources and debug issues.

## Checking resources
To check the status of resources defined in the app model use the _list resources_ tool. This will show you the current state of each resource and if there are any issues. If a resource is not running as expected you can use the _execute resource command_ tool to restart it or perform other actions.

## Listing integrations
IMPORTANT! When a user asks you to add a resource to the app model you should first use the _list integrations_ tool to get a list of the current versions of all the available integrations. You should try to use the version of the integration which aligns with the version of the Aspire.AppHost.Sdk. Some integration versions may have a preview suffix. Once you have identified the correct integration you should always use the _get integration docs_ tool to fetch the latest documentation for the integration and follow the links to get additional guidance.

## Debugging issues
IMPORTANT! Aspire is designed to capture rich logs and telemetry for all resources defined in the app model. Use the following diagnostic tools when debugging issues with the application before making changes to make sure you are focusing on the right things.

1. _list structured logs_; use this tool to get details about structured logs.
2. _list console logs_; use this tool to get details about console logs.
3. _list traces_; use this tool to get details about traces.
4. _list trace structured logs_; use this tool to get logs related to a trace

## Playwright MCP server
The playwright MCP server has also been configured in this repository and you should use it to perform functional investigations of the resources defined in the app model as you work on the codebase. To get endpoints that can be used for navigation using the playwright MCP server use the list resources tool.

## Playwright Test Suite
End-to-end Playwright tests live at `/mnt/data/crucible/crucible-tests/`. This repo contains test plans and spec files for all 11 Crucible applications. See the `README.md` in that directory for full details on test conventions, fixtures, and how to write/run tests. When asked to create, update, or run Playwright tests, work in that directory.

## Aspire workload
IMPORTANT! The aspire workload is obsolete. You should never attempt to install or use the Aspire workload.

## Troubleshooting: hung `dotnet restore`
If `dotnet restore` (or `aspire run`) hangs for minutes at `Restoring packages for ...` with no output and no error, the cause is almost always orphaned NuGet lock files and/or wedged MSBuild build-server nodes left behind when a previous restore was force-killed (`kill -9`) instead of stopped with Ctrl-C.

- Fix: run `scripts/reset-nuget.sh`, then re-run the restore.
- Prevention: stop a slow restore with **Ctrl-C** (SIGINT lets NuGet release its locks); never `kill -9` it.
- Separate symptom: right after publishing a new package version, restore may report `Unable to find package ... (>= x.y.z)` even though it is on nuget.org — that is a stale cached registration index. Run `dotnet nuget locals http-cache --clear` (also done by `scripts/reset-nuget.sh`).

## Official documentation
IMPORTANT! Always prefer official documentation when available. The following sites contain the official documentation for Aspire and related components

1. https://aspire.dev
2. https://learn.microsoft.com/dotnet/aspire
3. https://nuget.org (for specific integration package details)

## Devcontainer CI
The `.github/workflows/devcontainer-ci.yml` workflow builds the dev container on every PR and `main` push (amd64 and arm64), runs `postCreateCommand`, then executes `.devcontainer/ci-verify-tools.sh` to confirm each expected tool is on `PATH`. Repo cloning is skipped in CI via `CRUCIBLE_CI_SKIP_CLONE=1`, forwarded into the container through `containerEnv` in `devcontainer.json`.

**IMPORTANT:** When adding a new tool to the dev container — whether via a new devcontainer Feature, a Dockerfile `RUN`, or a `postcreate.sh` install step — add a matching `check` line to `.devcontainer/ci-verify-tools.sh`. Prefer the shortest version command that doesn't touch the network or a server (e.g. `kubectl version --client=true`, not `kubectl version`).

## Code Design Specifications
The `design-specs` folder houses documents outlining coding best practices and design specifications for Crucible apps to follow. Review `design-specs/README.md` for high level overviews of the specifications. Then, if doing development that targets an area with a design specification, read that specification and follow it when coding.
