# Proxmox OIDC Authentication Setup

Complete guide for configuring Proxmox to authenticate via Keycloak OIDC in the Crucible platform.

## Overview

This setup enables unified SSO authentication across Crucible services and Proxmox, with role-based access control.

## Two-Script Setup

### 1. Windows Prerequisites (Run Once)

**Script:** `scripts/setup-keycloak-portforward.ps1`  
**Run from:** Windows PowerShell (as Administrator)

```powershell
cd C:\path\to\crucible-development
.\scripts\setup-keycloak-portforward.ps1
```

**What it does:**
- Configures port forwarding: `172.29.16.1:8080` → `127.0.0.1:8080`
- Configures port forwarding: `172.29.16.1:8443` → `127.0.0.1:8443`
- Adds firewall rules for ports 8080 and 8443
- Adds Windows hosts entry: `172.29.16.1 keycloak`

### 2. Proxmox Configuration

**Script:** `scripts/crucible-proxmox.sh`  
**Run from:** WSL/Linux/Dev Container

```bash
export PROXMOX_HOST='172.29.24.139'
export KEYCLOAK_HOST='172.29.16.1'  # Optional, auto-detected
./scripts/crucible-proxmox.sh setup
```

**What it does:**
- Configures Proxmox infrastructure (SSH, nginx, API tokens, NFS)
- Creates VM templates (Alpine, TinyCore, Puppy)
- **Configures OIDC realm pointing to Keycloak**
- Creates Proxmox groups with role-based permissions
- Installs group sync script
- Sets up TopoMojo, Caster, Player, Alloy resources

## Architecture

```
┌─────────────────┐
│ Windows Browser │
└────────┬────────┘
         │
         ↓ https://172.29.24.139:8006
┌────────────────────────┐
│ Proxmox VE (Hyper-V)   │
│ Realm: keycloak-crucible│
└────────┬───────────────┘
         │
         ↓ redirects to http://keycloak:8080
┌────────────────────────────────┐
│ Windows                        │
│ hosts: keycloak = 172.29.16.1 │
│ port forward: :8080 → :8080    │
└────────┬───────────────────────┘
         │
         ↓ 127.0.0.1:8080
┌────────────────────┐
│ WSL2 / Dev Container│
│   Aspire AppHost   │
│   ├─ Keycloak      │
│   └─ Crucible Apps │
└────────────────────┘
```

## OIDC Configuration

| Setting | Value |
|---------|-------|
| **Proxmox OIDC Realm** | `keycloak-crucible` |
| **Issuer URL** | `http://keycloak:8080/realms/crucible` |
| **Keycloak Client ID** | `proxmox-web` |
| **Client Secret** | `proxmox-oidc-secret-change-me` |
| **Username Claim** | `preferred_username` |
| **Scopes** | `openid email profile` |
| **Auto-create Users** | Enabled |
| **Default Realm** | Yes (OIDC is default, PAM still available) |

## Role-Based Access Control

Three Proxmox groups are automatically created:

### Administrator Access
- **Keycloak Role:** `Administrators`
- **Proxmox Group:** `crucible-admins`
- **Proxmox Role:** `Administrator`
- **Permissions:** Full datacenter access, VM management, user management, storage, networking

### VM Operator Access
- **Keycloak Role:** `Content Developer`
- **Proxmox Group:** `crucible-developers`
- **Proxmox Role:** `PVEVMAdmin`
- **Permissions:** VM lifecycle (create, start, stop, delete), console access, snapshots, backups

### Read-Only Access
- **Keycloak Role:** `Test`
- **Proxmox Group:** `crucible-observers`
- **Proxmox Role:** `PVEAuditor`
- **Permissions:** View VMs and status, no modification

## Usage

### Login to Proxmox via OIDC

1. Navigate to: **https://172.29.24.139:8006**
2. **Realm dropdown:** Select **"Keycloak Crucible Realm"** (not PAM)
3. Click **Login**
4. Redirected to Keycloak at `http://keycloak:8080`
5. Login with Keycloak credentials:
   - Username: `admin`
   - Password: `admin`
6. Redirected back to Proxmox

### Assign User Groups

After first OIDC login, users need group assignment for permissions:

```bash
# SSH to Proxmox
ssh -i ~/.ssh/crucible_proxmox root@172.29.24.139

# Assign Administrator role
/usr/local/bin/oidc-group-sync.sh admin@keycloak-crucible Administrators

# Assign VM Operator role
/usr/local/bin/oidc-group-sync.sh developer@keycloak-crucible "Content Developer"

# Assign Read-only role
/usr/local/bin/oidc-group-sync.sh observer@keycloak-crucible Test
```

**Important:** Log out and back in after group assignment for permissions to take effect.

## Verification

### Check Port Forwarding (Windows)
```powershell
netsh interface portproxy show v4tov4
```

Should show:
```
Address         Port        Address         Port
--------------- ----------  --------------- ----------
172.29.16.1     8443        127.0.0.1       8443
172.29.16.1     8080        127.0.0.1       8080
```

### Check Hosts Resolution
```powershell
# Windows
ping keycloak
# Should resolve to 172.29.16.1
```

```bash
# Proxmox (from WSL)
ssh -i ~/.ssh/crucible_proxmox root@172.29.24.139 "ping -c 1 keycloak"
# Should resolve to 172.29.16.1
```

### Check OIDC Realm (Proxmox)
```bash
ssh -i ~/.ssh/crucible_proxmox root@172.29.24.139 "pveum realm list"
```

Should show `keycloak-crucible` with type `openid`.

### Check Proxmox Groups
```bash
ssh -i ~/.ssh/crucible_proxmox root@172.29.24.139 "pveum group list | grep crucible"
```

Should show:
- `crucible-admins`
- `crucible-developers`
- `crucible-observers`

## Troubleshooting

### "Invalid parameter: redirect_uri"

**Cause:** Keycloak client doesn't have Proxmox redirect URI configured.

**Fix:**
```bash
# Re-run setup to update client URIs
./scripts/crucible-proxmox.sh setup --skip-infrastructure --skip-vms
```

Or manually add in Keycloak admin console:
- Navigate to: Clients → proxmox-web → Settings
- Add to Valid Redirect URIs: `https://172.29.24.139:8006/*`

### "DNS_PROBE_FINISHED_NXDOMAIN" for keycloak

**Cause:** Windows hosts file missing entry.

**Fix:**
```powershell
# Re-run port forwarding setup
.\scripts\setup-keycloak-portforward.ps1
```

Or manually add to `C:\Windows\System32\drivers\etc\hosts`:
```
172.29.16.1 keycloak
```

### "Validation error: unexpected issuer URI"

**Cause:** Keycloak hostname mismatch (localhost vs keycloak).

**Fix:** Restart Aspire to apply `KC_HOSTNAME=keycloak`:
```bash
# Stop Aspire (Ctrl+C)
aspire run
```

### Certificate Errors

**Solution:** OIDC uses HTTP (port 8080) instead of HTTPS to avoid certificate issues. The admin console still uses HTTPS (8443).

### OIDC Login Works But No Permissions

**Cause:** User not assigned to Proxmox groups.

**Fix:** Run group sync script (see "Assign User Groups" above).

## Security Notes

1. **Client Secret:** Default `proxmox-oidc-secret-change-me` should be changed for production
2. **HTTP vs HTTPS:** Development uses HTTP (8080) for simplicity; production should use HTTPS with proper certificates
3. **Emergency Access:** `root@pam` login remains available as fallback
4. **Token Lifespan:** 1 hour session; consider shorter for high-security environments
5. **Group Sync:** Currently manual; consider automated sync via post-auth hook for production

## Files Modified

- `Crucible.AppHost/AppHost.cs` - Added `KC_HOSTNAME=keycloak`
- `Crucible.AppHost/resources/crucible-realm.json` - Added `proxmox-web` client
- `scripts/crucible-proxmox.sh` - Added `setup_proxmox_oidc()` function
- `scripts/setup-keycloak-portforward.ps1` - New Windows prerequisite script

## Future Enhancements

1. **Automated Group Sync:** Post-authentication hook to sync groups automatically
2. **Certificate Trust:** Install Keycloak CA cert on Proxmox for proper HTTPS validation
3. **Dynamic Redirect URIs:** Runtime update via Keycloak Admin API based on PROXMOX_HOST
4. **Multi-Factor Authentication:** Leverage Keycloak MFA policies
5. **Audit Logging:** Track OIDC authentication events in Proxmox logs
