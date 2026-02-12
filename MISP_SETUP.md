# MISP Integration Setup

## Overview

MISP (Malware Information Sharing Platform) has been successfully added to the Crucible development environment with support for your custom `misp-module-moodle` expansion module.

## Architecture

The MISP setup includes four containers:

1. **misp-mysql** - MySQL 8.x database (MISP requires MySQL, not PostgreSQL)
2. **misp-redis** - Redis cache for background jobs
3. **misp** - MISP Core application (coolacid/misp-docker:core-latest)
4. **misp-modules** - Custom MISP modules container with your Moodle module mounted

## What Was Changed

### Files Created

- `Crucible.AppHost/resources/misp/Dockerfile.MispModules` - Custom Docker image for MISP modules
- `Crucible.AppHost/resources/misp/requirements.txt` - Python dependencies for custom module
- `.env/misp.env` - Environment configuration for MISP launch profile

### Files Modified

- `Crucible.AppHost/LaunchOptions.cs` - Added `Misp` property
- `Crucible.AppHost/AppHost.cs` - Added `AddMisp()` extension method and call
- `.vscode/launch.json` - Added "MISP" launch configuration
- `Crucible.AppHost/Crucible.AppHost.csproj` - Added Aspire.Hosting.MySql and Aspire.Hosting.Redis packages

## How to Use

### Starting MISP

1. In VS Code, open the Run and Debug panel (Ctrl+Shift+D)
2. Select "MISP" from the dropdown
3. Click the green play button

### Accessing MISP

- **Web Interface**: http://localhost:8082 or https://localhost:8443
- **Default Credentials**:
  - Email: `admin@admin.test`
  - Password: `admin`

### MISP Modules API

- **Endpoint**: http://localhost:6666
- Your custom Moodle module is mounted at: `/usr/local/src/misp-modules/misp_modules/modules/expansion/moodle`

## Custom Module Development

Your MISP module is bind-mounted from:
- **Host**: `/mnt/data/crucible/misp/misp-module-moodle`
- **Container**: `/usr/local/src/misp-modules/misp_modules/modules/expansion/moodle`

Changes to your module on the host will be reflected in the container. Restart the misp-modules container to reload changes:

```bash
docker restart misp-modules
```

## Configuration

### Adding Dependencies

If your module needs additional Python packages:

1. Edit `Crucible.AppHost/resources/misp/requirements.txt`
2. Add the package (e.g., `dnspython>=2.4.0`)
3. Rebuild the misp-modules container by running the MISP launch configuration

### Environment Variables

All services can be toggled via `.env/misp.env`:

```
Launch__Player=false
Launch__Caster=false
...
Launch__Misp=true
```

## Container Details

| Service | Container Name | Port | Purpose |
|---------|---------------|------|---------|
| MISP Core | misp | 8082 (HTTP), 8443 (HTTPS) | Main web application |
| MISP Modules | misp-modules | 6666 | Expansion modules service |
| MySQL | misp-mysql | 3306 | Database |
| Redis | misp-redis | 6379 | Cache & jobs |

## Troubleshooting

### MISP not starting

Check the Aspire dashboard logs for the misp container. Common issues:
- MySQL not ready (MISP will retry connection)
- Redis not accessible
- Port conflicts (8082 already in use)

### Module not loading

1. Verify the module path is correct:
   ```bash
   docker exec -it misp-modules ls -la /usr/local/src/misp-modules/misp_modules/modules/expansion/moodle
   ```

2. Check module syntax:
   ```bash
   docker exec -it misp-modules python3 /usr/local/src/misp-modules/misp_modules/modules/expansion/moodle/misp_module.py
   ```

3. Restart the misp-modules container:
   ```bash
   docker restart misp-modules
   ```

### Enabling the module in MISP

1. Login to MISP web interface
2. Go to Administration → Server Settings & Maintenance
3. Navigate to Plugin Settings
4. Enable your custom Moodle module
5. Configure any required API keys or settings

## Next Steps

1. **Configure MISP**: Complete the initial MISP setup via the web interface
2. **Enable Module**: Activate your Moodle module in MISP's plugin settings
3. **Test Integration**: Use the MISP API to test your module
4. **Configure Keycloak** (optional): Integrate MISP with Keycloak for SSO

## Additional Resources

- MISP Documentation: https://www.misp-project.org/documentation/
- MISP Modules: https://github.com/MISP/misp-modules
- Docker MISP: https://github.com/coolacid/docker-misp
