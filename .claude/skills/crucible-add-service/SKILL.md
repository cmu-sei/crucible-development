---
name: crucible-add-service
description: Checklist of every file to touch when adding a new Crucible microservice or a Moodle plugin to this dev environment (repos.json, AppHost.cs, launch.json, .env, xdebug mappings, Moodle mount scripts). Use when asked to add, register, or wire a new service or Moodle plugin.
---

# Adding services and Moodle plugins

## Adding New Services
1. Add repository to `scripts/repos.json`
2. Update `Crucible.AppHost/AppHost.cs` with service registration
3. Add launch configuration to `.vscode/launch.json`
4. Create environment file in `.env/` directory

## Adding Moodle Plugins
1. Add repository to `scripts/repos.json`
2. Update `.vscode/launch.json` (add path mappings for xdebug)
3. Update `Crucible.AppHost/AppHost.cs` (add bind mounts)
4. Update `scripts/xdebug_filter.sh`
5. For additional paths: also update `Dockerfile.MoodleCustom`, `add-moodle-mounts.sh`, `pre_configure.sh`
