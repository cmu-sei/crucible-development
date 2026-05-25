# TopoMojo Hypervisor Configuration Toggle

This script allows you to quickly switch TopoMojo between different hypervisor configurations.

## Usage

### Interactive Menu (Recommended)

```bash
./scripts/toggle-topomojo-hypervisor.sh
```

This will show you:
- Current configuration
- Menu of available profiles
- Descriptions of each option

### Command Line

```bash
# Interactive (prompts for credentials)
./scripts/toggle-topomojo-hypervisor.sh vmc

# Non-interactive with credentials
./scripts/toggle-topomojo-hypervisor.sh vmc \
  --url "https://vcenter.sddc-xx-xx-xx-xx.vmwarevmc.com/sdk" \
  --user "cloudadmin@vmc.local" \
  --password 'YourPassword' \
  --non-interactive

# Quick switches (no credentials needed)
./scripts/toggle-topomojo-hypervisor.sh proxmox --non-interactive
./scripts/toggle-topomojo-hypervisor.sh vsphere --non-interactive

# Restore from git
./scripts/toggle-topomojo-hypervisor.sh restore
```

## Available Profiles

### 1. Proxmox (Local)
- **Use case**: Local Proxmox development server
- **ISO uploads**: Direct to local storage (no API needed)
- **Config**:
  - Type: Proxmox
  - URL: https://172.22.64.132:443
  - Storage: local-lvm
  - ISO API: Disabled

### 2. vSphere (On-Prem)
- **Use case**: Traditional vSphere/vCenter on-premises
- **ISO uploads**: Via NFS mount (requires `/mnt/isos` mounted to datastore)
- **Config**:
  - Type: Vsphere
  - URL: https://vcenter.example.com/sdk
  - Storage: [datastore] topomojo/...
  - ISO API: Disabled

**⚠️ Important**: You must have NFS mount configured:
```bash
# Example: mount vSphere datastore via NFS
mount -t nfs vcenter.example.com:/datastore/topomojo/isos /mnt/isos
```

### 3. VMware Cloud on AWS (VMC)
- **Use case**: VMware Cloud SDDC
- **ISO uploads**: Via vSphere API (no NFS needed)
- **Config**:
  - Type: Vsphere
  - URL: https://vcenter.sddc-xxx.vmwarevmc.com/sdk
  - Storage: [WorkloadDatastore] topomojo/...
  - ISO API: **Enabled** ✨

**⚠️ Important**: Update credentials after switching:
```bash
# Edit AppHost.cs and update:
Pod__User=cloudadmin@vmc.local
Pod__Password=your-actual-vmc-password
```

## What The Script Does

1. **Prompts** for credentials (vSphere/VMC only)
2. **Modifies** `AppHost.cs` hypervisor configuration
3. **Updates** all Pod__ and FileUpload__ settings
4. **Shows** summary and git diff instructions

**Note**: No backup files created - use git to manage versions!

## Configuration Details

The script modifies these settings in `Crucible.AppHost/AppHost.cs`:

| Setting | Proxmox | vSphere | VMC |
|---------|---------|---------|-----|
| `Pod__HypervisorType` | Proxmox | Vsphere | Vsphere |
| `Pod__Url` | Proxmox IP | vCenter URL | VMC vCenter URL |
| `Pod__VmStore` | local-lvm | [datastore] path | [WorkloadDatastore] path |
| `Pod__IsoStore` | local:iso | [datastore] path | [WorkloadDatastore] path |
| `Pod__PoolPath` | - | Datacenter/Cluster | SDDC-Datacenter/ResourcePool |
| `FileUpload__UseDatastoreApi` | false | false | **true** |

## After Switching

1. **Review credentials** in AppHost.cs
   - Search for "password" or "token"
   - Update with actual values

2. **Restart Aspire**:
   ```bash
   # Stop current instance (Ctrl+C)
   aspire run
   ```

3. **Verify configuration**:
   - Check Aspire dashboard
   - Look for TopoMojo resource
   - Check environment variables

## Troubleshooting

### Script fails with "Could not find hypervisor configuration block"

The script expects this pattern in AppHost.cs:
```csharp
// <something> hypervisor configuration
.WithEnvironment("Pod__HypervisorType", "...")
...
.WithEnvironment("Pod__TicketUrlHandler", "...");
```

If you've modified the structure, restore from backup and manually edit.

### Restore from git

```bash
./scripts/toggle-topomojo-hypervisor.sh restore

# Or manually:
git restore Crucible.AppHost/AppHost.cs

# Or review changes first:
git diff Crucible.AppHost/AppHost.cs
```

### Need to customize a profile?

Edit the script and modify the associative arrays at the top:
```bash
declare -A VMC=(
    [url]="https://your-actual-vmc-url.com/sdk"
    [password]="your-password"
    # etc...
)
```

## Testing ISO Upload

After switching to VMC:

```bash
# 1. Start Aspire
aspire run

# 2. Open TopoMojo UI (usually http://localhost:4201)

# 3. Upload a test ISO
#    - Create workspace
#    - Upload small ISO file
#    - Check logs: should see "uploading to datastore" messages

# 4. Verify in vSphere
#    - Open VMC console
#    - Navigate to Storage → WorkloadDatastore
#    - Check topomojo/isos/ folder
```

## Related Files

- `Crucible.AppHost/AppHost.cs` - Main configuration file (modified by script)
- `Crucible.AppHost/AppHost.cs.bak` - Automatic backup (created by script)
- Feature branch: `feature/vmware-cloud-iso-upload` in TopoMojo repo

## See Also

- [TopoMojo vSphere API Upload Plan](/home/vscode/.claude/plans/2-add-vsphere-proud-owl.md)
- TopoMojo Documentation: `/mnt/data/crucible/topomojo/topomojo/docs/`
