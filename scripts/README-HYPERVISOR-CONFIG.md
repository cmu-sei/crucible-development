# Hypervisor Configuration via AppHost

Configure TopoMojo, Player VM, and Caster hypervisor settings centrally via `appsettings.Development.json` instead of editing individual app configuration files.

## Overview

The AppHost now supports configuring three hypervisor types across all Crucible infrastructure apps:
1. **Proxmox** - Local Proxmox VE server
2. **vSphere** - Traditional VMware vCenter on-premises  
3. **VMC** - VMware Cloud on AWS

Configuration is done via `Launch` settings in `Crucible.AppHost/appsettings.Development.json`.

## Application Coverage

| Application | Proxmox | vSphere | VMC | Purpose |
|-------------|---------|---------|-----|---------|
| **TopoMojo** | ✅ | ✅ | ✅ | VM orchestration, workspaces, templates |
| **Player VM** | ✅ | ❌ | ❌ | VM console access, state monitoring |
| **Caster** | ✅ | ✅ | ✅ | Terraform-based infrastructure automation |

**All three hypervisors fully supported for development!**

## How It Works

When you configure hypervisor settings in appsettings.json:

1. **AppHost reads the settings** from `Launch.HypervisorType`, `Launch.HypervisorUrl`, etc.
2. **Environment variables are injected** into TopoMojo, Player VM, and Caster containers at startup
3. **Apps use the environment variables** (same config keys as before, just different source)

**No manual editing of app appsettings files required!**

## Configuration Options

### Common Settings (All Hypervisors)

| Setting | Description | Example |
|---------|-------------|---------|
| `HypervisorType` | Type of hypervisor | `"Proxmox"` or `"Vsphere"` |
| `HypervisorUrl` | Hypervisor API endpoint | `"https://proxmox.local:443"` |
| `HypervisorVmStore` | VM storage location | `"local-lvm"` or `"[datastore] topomojo"` |
| `HypervisorDiskStore` | Disk storage location | `"local-lvm"` or `"[datastore] topomojo"` |
| `HypervisorIsoStore` | ISO storage location | `"local"` or `"[datastore] topomojo"` |

### Proxmox-Specific Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `HypervisorToken` | API token | `"root@pam!CRUCIBLE=uuid-here"` |

### vSphere/VMC-Specific Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `HypervisorUser` | vCenter username | `"administrator@vsphere.local"` |
| `HypervisorPassword` | vCenter password | `"your-password"` |
| `HypervisorPoolPath` | Resource pool path | `"Datacenter/Cluster"` |

## Example Configurations

### Proxmox

```json
{
  "Launch": {
    "HypervisorType": "Proxmox",
    "HypervisorUrl": "https://172.29.24.139:443",
    "HypervisorToken": "root@pam!CRUCIBLE=6d803e6b-5af5-4c02-bb9e-19f57094875c",
    "HypervisorVmStore": "local-lvm",
    "HypervisorDiskStore": "local-lvm",
    "HypervisorIsoStore": "local"
  }
}
```

### vSphere On-Premises

```json
{
  "Launch": {
    "HypervisorType": "Vsphere",
    "HypervisorUrl": "https://vcenter.example.com/sdk",
    "HypervisorUser": "administrator@vsphere.local",
    "HypervisorPassword": "your-password",
    "HypervisorVmStore": "[datastore1] topomojo",
    "HypervisorDiskStore": "[datastore1] topomojo",
    "HypervisorIsoStore": "[datastore1] topomojo",
    "HypervisorPoolPath": "Datacenter/Cluster"
  }
}
```

### VMware Cloud on AWS (VMC)

```json
{
  "Launch": {
    "HypervisorType": "Vsphere",
    "HypervisorUrl": "https://vcenter.sddc-12-34-56-78.vmwarevmc.com/sdk",
    "HypervisorUser": "cloudadmin@vmc.local",
    "HypervisorPassword": "your-vmc-password",
    "HypervisorVmStore": "[WorkloadDatastore] topomojo/",
    "HypervisorDiskStore": "[WorkloadDatastore] topomojo/",
    "HypervisorIsoStore": "[WorkloadDatastore] topomojo/",
    "HypervisorPoolPath": "SDDC-Datacenter/Cluster-1/Compute-ResourcePool"
  }
}
```

## Environment Variables Set

### TopoMojo API

| Environment Variable | Set From |
|---------------------|----------|
| `Pod__Type` | `HypervisorType` |
| `Pod__HypervisorType` | `HypervisorType` |
| `Pod__Url` | `HypervisorUrl` |
| `Pod__AccessToken` | `HypervisorToken` (Proxmox) |
| `Pod__User` | `HypervisorUser` (vSphere) |
| `Pod__Password` | `HypervisorPassword` (vSphere) |
| `Pod__VmStore` | `HypervisorVmStore` |
| `Pod__DiskStore` | `HypervisorDiskStore` |
| `Pod__IsoStore` | `HypervisorIsoStore` |
| `Pod__PoolPath` | `HypervisorPoolPath` |
| `Pod__IgnoreCertificateErrors` | Auto-set based on type |
| `Pod__SupportsSubfolders` | Auto-set based on type |
| `FileUpload__IsoRoot` | Auto-set based on type |
| `FileUpload__UseDatastoreApi` | Auto-set (VMC only) |
| `FileUpload__TempRoot` | Auto-set to `/tmp/topoiso` |

### Player VM API (Proxmox only)

| Environment Variable | Set From |
|---------------------|----------|
| `Proxmox__Enabled` | `true` if HypervisorType=Proxmox |
| `Proxmox__Host` | Extracted from `HypervisorUrl` |
| `Proxmox__Port` | `443` |
| `Proxmox__Token` | `HypervisorToken` |
| `Proxmox__StateRefreshIntervalSeconds` | `60` |

### Caster API (Terraform Providers)

**Proxmox Provider:**

| Environment Variable | Set From |
|---------------------|----------|
| `Terraform__EnvironmentVariables__Direct__PROXMOX_VE_ENDPOINT` | `HypervisorUrl` |
| `Terraform__EnvironmentVariables__Direct__PROXMOX_VE_API_TOKEN` | `HypervisorToken` |
| `Terraform__EnvironmentVariables__Direct__PROXMOX_VE_INSECURE` | `true` |

**vSphere Provider (on-prem and VMC):**

| Environment Variable | Set From |
|---------------------|----------|
| `Terraform__EnvironmentVariables__Direct__VSPHERE_SERVER` | Extracted from `HypervisorUrl` |
| `Terraform__EnvironmentVariables__Direct__VSPHERE_USER` | `HypervisorUser` |
| `Terraform__EnvironmentVariables__Direct__VSPHERE_PASSWORD` | `HypervisorPassword` |
| `Terraform__EnvironmentVariables__Direct__VSPHERE_ALLOW_UNVERIFIED_SSL` | `true` |
| `Terraform__EnvironmentVariables__Direct__VSPHERE_DATACENTER` | Parsed from `HypervisorPoolPath` (1st part) |
| `Terraform__EnvironmentVariables__Direct__VSPHERE_CLUSTER` | Parsed from `HypervisorPoolPath` (2nd part) |
| `Terraform__EnvironmentVariables__Direct__VSPHERE_RESOURCE_POOL` | Parsed from `HypervisorPoolPath` (3rd part) |
| `Terraform__EnvironmentVariables__Direct__VSPHERE_DATASTORE` | Extracted from `HypervisorVmStore` |

## Auto-Detection

### VMC vs vSphere On-Prem

AppHost automatically detects VMC vs on-premises vSphere based on the URL:
- If URL contains `vmwarevmc.com` → VMC mode
  - Sets `FileUpload__UseDatastoreApi=true` (no NFS needed)
  - Sets `Pod__TicketUrlHandler=none`
  - Sets `FileUpload__IsoRoot=/mnt/vmc-iso`
- Otherwise → vSphere on-prem mode
  - Sets `FileUpload__UseDatastoreApi=false` (requires NFS)
  - Sets `Pod__TicketUrlHandler=querystring`
  - Sets `FileUpload__IsoRoot=/mnt/isos`

No separate configuration needed!

## Migration from Old Approach

### Before (Manual appsettings editing)

```bash
# Had to manually edit each app's appsettings file
./scripts/toggle-topomojo-hypervisor.sh proxmox
./scripts/update-proxmox-appsettings.sh
```

### After (Centralized AppHost config)

```json
// Edit ONE file: Crucible.AppHost/appsettings.Development.json
{
  "Launch": {
    "HypervisorType": "Proxmox",
    "HypervisorUrl": "https://172.29.24.139:443",
    "HypervisorToken": "root@pam!CRUCIBLE=..."
  }
}
```

Then just restart Aspire:
```bash
aspire run
```

## Toggling Hypervisors

To switch hypervisors, edit `appsettings.Development.json` and restart Aspire:

```bash
# 1. Edit appsettings.Development.json
# 2. Change HypervisorType and related settings
# 3. Restart
aspire run
```

The `toggle-topomojo-hypervisor.sh` script is **still useful** for:
- Interactive menu-driven configuration
- One-off hypervisor switches without editing JSON
- Scripts/automation that need to toggle hypervisors programmatically

**Both approaches work** - choose what fits your workflow!

## Verification

Check what environment variables TopoMojo received:

```bash
# Via Aspire Dashboard
# Navigate to: Resources → topomojo → Environment

# Or via MCP tool
mcp__aspire__list_resources
# Find topomojo, check environment variables
```

## Troubleshooting

**Environment variables not applied:**
- Restart Aspire (`aspire run`) after editing appsettings.json
- Check for JSON syntax errors in appsettings.Development.json

**Apps still using old appsettings files:**
- Delete `appsettings.Development.conf` from app directories
- Environment variables take precedence over file-based config

**Mixed configuration:**
- Don't configure both appsettings.json AND app-specific files
- Choose one approach (recommended: appsettings.json)

## Related Files

- `Crucible.AppHost/appsettings.Development.json.example` - Example configuration
- `Crucible.AppHost/LaunchOptions.cs` - Configuration model
- `Crucible.AppHost/AppHost.cs` - Environment variable injection logic
- `scripts/toggle-topomojo-hypervisor.sh` - Alternative CLI-based configuration
