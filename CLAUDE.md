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
- `scripts/repos.json` - List of repositories to clone
- `scripts/clone-repos.sh` - Repository cloning script
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

## Aspire workload
IMPORTANT! The aspire workload is obsolete. You should never attempt to install or use the Aspire workload.

## Official documentation
IMPORTANT! Always prefer official documentation when available. The following sites contain the official documentation for Aspire and related components

1. https://aspire.dev
2. https://learn.microsoft.com/dotnet/aspire
3. https://nuget.org (for specific integration package details)
