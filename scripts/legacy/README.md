# Legacy Proxmox Scripts

These scripts have been consolidated into `/workspaces/crucible-development/scripts/crucible-proxmox.sh`.

## What Happened

On 2026-05-27, 38 Proxmox-related scripts were consolidated into a single, idempotent script that:
- Uses API-only interactions (no direct database access)
- Has hardcoded UUIDs for idempotent resource creation
- Provides clean, status, setup, reset, and fix modes
- Supports DRY_RUN and skip flags for testing

## Consolidated Script

**New script:** `../crucible-proxmox.sh`

```bash
# Full setup
./scripts/crucible-proxmox.sh setup

# Check status
./scripts/crucible-proxmox.sh status

# Clean all resources
./scripts/crucible-proxmox.sh clean

# Reset (clean + setup)
./scripts/crucible-proxmox.sh reset
```

## Why Keep These?

These legacy scripts are kept for:
1. **Reference** - Complex logic that may need to be extracted
2. **TopoMojo/Caster** - Full workspace/project creation still uses these
3. **Debugging** - Individual script testing
4. **Documentation** - Understanding the original implementation

## Script Categories

### Infrastructure (Consolidated ✓)
- `setup-proxmox-complete.sh` - Full Proxmox setup
- `setup-proxmox-ssh.sh` - SSH key generation
- `setup-proxmox-nginx.sh` - nginx reverse proxy
- `create-proxmox-api-token.sh` - API token creation
- `setup-proxmox-topomojo.sh` - TopoMojo hypervisor config

### VM Templates (Consolidated ✓)
- `create-proxmox-alpine-template.sh` - Alpine cloud-init template
- `create-proxmox-tinycore-template.sh` - TinyCore template
- `create-puppy-vm.sh` - Puppy Linux VM
- `download-*.iso.sh` - ISO downloaders

### TopoMojo (Referenced)
- `create-topomojo-workspace-template.sh` - Complex workspace creation
- `create-topomojo-workspace-with-variants.sh` - Variant workspaces
- `delete-topomojo-workspace.sh` - Workspace deletion
- `cleanup-topomojo-templates.sh` - Template cleanup

### Caster (Referenced)
- `create-caster-proxmox-topology.sh` - Full Terraform project creation
- `create-caster-directory-for-alloy.sh` - Alloy integration
- `delete-caster-projects.sh` - Project deletion

### Player (Consolidated ✓)
- `create-player-view-template.sh` - View template for Alloy
- `create-player-view-with-vms.sh` - Live view with VMs
- `register-proxmox-vms-to-player.sh` - VM registration
- `delete-player-views.sh` - View deletion

### Alloy (Consolidated ✓)
- `create-alloy-event.sh` - Event with Caster
- `create-alloy-event-without-caster.sh` - View-only event
- `delete-alloy-events.sh` - Event deletion

### Cleanup (Consolidated ✓)
- `cleanup-crucible-resources.sh` - API-based cleanup
- `clear-test-data.sh` - Test data cleanup
- `delete-*.sh` - Individual service cleanup

## Migration Notes

The consolidated script implements:
- ✅ Phases 1-2: Infrastructure & VMs (fully functional)
- ✅ Phase 3: Aspire health checks (fully functional)
- ⚠️ Phase 4: TopoMojo (references legacy script)
- ⚠️ Phase 5: Caster (references legacy script)
- ✅ Phase 6: Player views (fully functional)
- ✅ Phase 7: Alloy events (fully functional)
- ✅ Cleanup: All services (fully functional)

TopoMojo and Caster creation require complex Terraform file generation and template management, so they still reference the full legacy scripts. All other functionality is consolidated.

## Still-Used Scripts

These scripts are **NOT** in legacy (still actively used):
- `toggle-topomojo-hypervisor.sh` - Switch between Proxmox/vSphere/VMC
- `create-proxmox-host-hyperv.ps1` - PowerShell for Hyper-V VM creation
- `clone-repos.sh` - Repository management
- `sync-repos.sh` - Repository sync
- `repos.json` - Repository list

## Removed from Git

These scripts were moved but not tracked in git:
- `reset-crucible-apps.sh`
- `reset-test-environment.sh`
- `cleanup-crucible-database.sh` (duplicate)
