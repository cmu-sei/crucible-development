# Crucible Proxmox Environment Manager

**Single consolidated script for all Proxmox test environment management**

## Quick Start

```bash
# Setup complete environment
export PROXMOX_HOST='192.168.1.100'
./scripts/crucible-proxmox.sh setup

# Check status
./scripts/crucible-proxmox.sh status

# Clean all test resources
./scripts/crucible-proxmox.sh clean

# Reset (clean + recreate)
./scripts/crucible-proxmox.sh reset
```

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Create complete Proxmox test environment |
| `status` | Show current environment state |
| `clean` | Remove all test resources via APIs |
| `reset` | Clean and recreate environment |
| `fix` | Repair broken state (TODO) |
| `help` | Show usage information |

## Environment Variables

### Required
- `PROXMOX_HOST` - Proxmox server IP/hostname

### Service URLs (defaults shown)
- `PLAYER_API_URL` - Default: `http://localhost:4300/api`
- `CASTER_API_URL` - Default: `http://localhost:4309/api`
- `ALLOY_API_URL` - Default: `http://localhost:4402/api`
- `TOPOMOJO_API_URL` - Default: `http://localhost:5000`
- `KEYCLOAK_URL` - Default: `https://localhost:8443`

### Authentication
- `KEYCLOAK_USER` - Default: `admin`
- `KEYCLOAK_PASSWORD` - Default: `admin`

### Mode Flags
- `SKIP_INFRASTRUCTURE=true` - Skip Proxmox setup
- `SKIP_VMS=true` - Skip VM template creation
- `SKIP_TOPOMOJO=true` - Skip TopoMojo workspaces
- `SKIP_CASTER=true` - Skip Caster projects
- `SKIP_PLAYER=true` - Skip Player views
- `SKIP_ALLOY=true` - Skip Alloy events
- `DRY_RUN=true` - Preview without making changes

## Setup Phases

The `setup` command runs through 7 phases:

### Phase 1: Proxmox Infrastructure ✅
- SSH key generation & passwordless access
- nginx reverse proxy with API token injection
- Proxmox API token creation
- NFS export for ISO storage
- TopoMojo hypervisor configuration

### Phase 2: VM Templates ✅
- Alpine Linux (ID: 105) - Cloud-init template
- TinyCore Linux (ID: 106) - Minimal template
- Puppy Linux (ID: 103) - Full GUI VM

### Phase 3: Aspire Services ✅
- Waits for all services to be healthy
- Checks Player, Caster, Alloy, TopoMojo APIs

### Phase 4: TopoMojo Workspaces ⚠️
- References legacy script for complex workspace creation
- See: `scripts/legacy/create-topomojo-workspace-template.sh`

### Phase 5: Caster Projects ⚠️
- References legacy script for Terraform file generation
- See: `scripts/legacy/create-caster-proxmox-topology.sh`

### Phase 6: Player Views ✅
- Creates Player view template (for Alloy)
- Creates live Player view with 3 VMs
- Registers VMs in Player VM API

### Phase 7: Alloy Events ✅
- Creates Alloy event without Caster (view-only)
- Creates Alloy event with Caster (full orchestration)

## Examples

### Full Setup
```bash
export PROXMOX_HOST='192.168.1.100'
./scripts/crucible-proxmox.sh setup
```

### Dry Run (Preview)
```bash
export PROXMOX_HOST='192.168.1.100'
export DRY_RUN=true
./scripts/crucible-proxmox.sh setup
```

### Skip Infrastructure (Already Configured)
```bash
export SKIP_INFRASTRUCTURE=true
./scripts/crucible-proxmox.sh setup
```

### Clean Specific Resources
```bash
# Clean everything
./scripts/crucible-proxmox.sh clean

# Then recreate just Player & Alloy
export SKIP_INFRASTRUCTURE=true
export SKIP_VMS=true
export SKIP_TOPOMOJO=true
export SKIP_CASTER=true
./scripts/crucible-proxmox.sh setup
```

### Check Status
```bash
./scripts/crucible-proxmox.sh status
```

Output:
```
Proxmox Infrastructure:
  Host: 192.168.1.100 ✓ (reachable)

Aspire Services:
  Player API: ✓ Healthy
  Caster API: ✓ Healthy
  Alloy API: ✓ Healthy
  TopoMojo API: ✓ Healthy

Resources:
  Player Views: 2
  Caster Projects: 0
  Alloy Events: 2
  TopoMojo Workspaces: 0
  TopoMojo Templates: 0
```

## Idempotency

The script uses hardcoded UUIDs for all resources, making it safe to run multiple times:

- **First run:** Creates all resources
- **Second run:** Detects existing resources, skips creation
- **After cleanup:** Recreates with same IDs

Example UUIDs:
- Player View Template: `8ab5b8c5-63f6-427b-b3f5-076ed2cfdfd2`
- Alloy Event (No Caster): `e8bd8940-023f-4d6e-8255-9538dc21ad4a`

## Configuration

The script saves configuration to `~/.crucible-proxmox`:

```bash
export PROXMOX_HOST="192.168.1.100"
export PROXMOX_API_TOKEN="root@pam!CRUCIBLE=..."
LAST_SETUP_DATE="2026-05-27T19:44:00Z"
SETUP_COMPLETE="true"
```

This config is automatically loaded on subsequent runs.

## API-Only Cleanup

All cleanup operations use REST APIs (no direct database access):

- **Player:** Deletes views matching "Proxmox%", VMs matching "puppy|alpine|tinycore"
- **Caster:** Deletes projects matching "Proxmox Test%"
- **Alloy:** Deletes events matching "Proxmox Test Event|Alloy Event"
- **TopoMojo:** Deletes workspaces matching "Test Workspace|Moodle Test"
- **TopoMojo:** Deletes templates matching "TinyCore-ISO|Alpine-Disk|Puppy-Linux"

## Moodle Plugin Integration

This environment serves as the backend for Moodle plugins:

### mod_topomojo
- Points to TopoMojo API for workspace deployment
- Students launch VMs from Moodle
- Questions synced from TopoMojo challenge spec

### mod_alloy
- Points to Alloy API for event deployment
- Students launch exercises from Moodle
- Integrates with Player views for VM access

### Stable IDs for Moodle Config
All resources use hardcoded UUIDs so Moodle plugin configs don't break:

```php
// In Moodle mod_alloy settings
$event_template_id = 'e8bd8940-023f-4d6e-8255-9538dc21ad4a';
```

## Troubleshooting

### "PROXMOX_HOST not set"
```bash
export PROXMOX_HOST='192.168.1.100'
```

### "Services not ready"
```bash
# Check Aspire is running
aspire run

# Wait for services to start (2-3 minutes)
./scripts/crucible-proxmox.sh status
```

### "SSH connection failed"
```bash
# Re-run infrastructure setup
export SKIP_VMS=true
./scripts/crucible-proxmox.sh setup
```

### "Failed to get token"
Check Keycloak is running:
```bash
curl -k https://localhost:8443
```

## Legacy Scripts

Original scripts moved to `scripts/legacy/` for reference.

See: `scripts/legacy/README.md`

## Related Scripts

These scripts are **NOT** consolidated (still used independently):

- `toggle-topomojo-hypervisor.sh` - Switch between Proxmox/vSphere/VMC
- `create-proxmox-host-hyperv.ps1` - PowerShell for Hyper-V VM creation

## Development

The script is organized into sections:

1. **Configuration & Constants** - Resource IDs, defaults
2. **Utility Functions** - Logging, auth, health checks
3. **Proxmox Infrastructure** - SSH, nginx, token, NFS
4. **VM Templates** - Alpine, TinyCore, Puppy
5. **Resource Creation** - TopoMojo, Caster, Player, Alloy (partial)
6. **Cleanup Functions** - API-based resource deletion
7. **Phase Orchestration** - 7-phase setup workflow
8. **Mode Handlers** - setup, clean, status, reset, fix
9. **Main Entry Point** - Command dispatch

## Version

Current: `1.0.0`

## Author

Consolidated from 38 scripts on 2026-05-27
