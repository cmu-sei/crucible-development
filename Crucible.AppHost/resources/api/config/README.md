# Local API configuration profiles

This opt-in feature configures the hypervisor settings for `topomojo`,
`player-vm-api`, and `caster-api`. The AppHost retains its existing API defaults,
database wiring, endpoints, authentication, and resource dependencies.

## Guided setup

From the repository root:

```bash
./scripts/configure-hypervisors.sh
# Or go straight to a backend:
./scripts/configure-hypervisors.sh proxmox
./scripts/configure-hypervisors.sh vsphere --profile lab-a
```

The menu offers configure, select, disable, and quit. Setup asks once for the
connection details and fills all three app templates, then selects the profile.
Proxmox asks for host, port, token, VM/disk storage, and ISO storage. vSphere asks
for host, username, password, datastore, and pool path. Enter hostnames or IPs without
a URL scheme or path. The Proxmox port defaults to `443`, matching the reverse proxy
installed by the provisioning script; use `8006` when connecting directly to PVE.
Pool paths may omit a resource pool or include nested pools.
Proxmox and vSphere are the only starting templates. Local profile names are arbitrary;
customize the generated files for other environments as described below.

Passwords and tokens are hidden during entry. Proxmox defaults come from the current
`PROXMOX_HOST` / `PROXMOX_API_TOKEN` environment, then the saved shell configuration:
`PROXMOX_CONFIG_FILE` if specified, otherwise `Crucible.AppHost/resources/proxmox/config`
or `~/.crucible-proxmox`. These are the same files used by the provisioning script.

If files already exist, setup offers **keep** (default), **regenerate**, or **cancel**.
Keeping selects them without edits. Regenerating asks for connection details again,
saves private timestamped `.bak` copies, and replaces the matching files from templates.
Cancellation leaves the files and selection unchanged.
Advanced settings are edited directly in the local `.conf` files; there is no separate
saved-answer file. Regeneration replaces those manual edits, so keep the files to retain
them or recover the edits from the backups.

Guided setup requires a terminal. Switching existing profiles, manual initialization,
and the provisioning script's automatic profile preparation also work without one.

## Manual initialization and selection

```bash
./scripts/configure-hypervisors.sh list
./scripts/configure-hypervisors.sh init proxmox
./scripts/configure-hypervisors.sh init vsphere --profile lab-a
```

The initializer copies `templates/<template>/*.conf.template` into
`local/<profile>/*.conf`. Existing files are preserved. New directories use mode
`0700` and files use `0600`. It does not select the profile or change launch settings.
Only the templates and this guide belong in Git: the entire `local/` directory is
ignored, including temporary files and backups. Do not force-add local profiles.

Edit the local files and replace `<placeholders>`, then select:

```bash
./scripts/toggle-hypervisor.sh lab-a
```

Selection updates the ignored AppHost `appsettings.Development.json`. It requires
and validates files for enabled supported apps selected by the base/local launch
settings and current launch environment, rejecting unfilled template placeholders.
Disabled or unlaunched apps are skipped.
AppHost validates again against
the actual apps launched, including settings supplied later by tasks or user secrets.
Changing the shared profile clears per-app profile overrides, but preserves their
disable flags. Run the toggle before adding per-app overrides.

Switching an existing profile does not prompt or rewrite its files.
`toggle-hypervisor.sh` without arguments opens the guided menu. Selecting `proxmox`
or `vsphere` before that profile exists opens setup for that backend.

Restart Aspire after editing files or selection. There is no live reload.
The scripts do not restart running services. Script updates preserve settings values,
but rewrite the JSON formatting and remove comments.

## Global and per-app settings

File configuration is disabled unless `Launch.ApiConfig.Enabled` is `true`.
Supported apps that are running inherit the shared profile:

```json
{
  "Launch": {
    "ApiConfig": {
      "Enabled": true,
      "Profile": "proxmox",
      "Apps": {
        "player-vm-api": { "Profile": "hybrid" },
        "caster-api": { "Enabled": false }
      }
    }
  }
}
```

Create and customize the local `hybrid` profile before using that override; see below.
Player VM and Caster can use both backends. TopoMojo requires a single backend.

```bash
./scripts/toggle-hypervisor.sh remove
```

This sets the global switch to `false`, retaining local files. Global disable wins
over per-app settings. Disabled or unlaunched apps do not read or require profile
files. Disabling profile delivery does **not** disable the apps or their backends:
their own configuration and AppHost defaults apply again.

Environment variables and user secrets can override AppHost launch settings.
For example, `Launch__ApiConfig__Enabled=false` globally disables delivery and
`Launch__ApiConfig__Apps__caster-api__Enabled=false` disables it for Caster.

## Adapting profiles for other environments

Templates are starting points, not a catalog of environments. Keep general defaults
in the apps and add only environment-specific overrides to local `.conf` files.
The wizard selects the profile when it finishes; complete any manual changes before
restarting Aspire. Choose **keep** on subsequent setup runs to retain those changes.

### VMC

Start with vSphere and give the profile a meaningful name:

```bash
./scripts/configure-hypervisors.sh vsphere --profile vmc
```

Enter your VMC host, credentials, datastore, and pool path. Example values are
`cloudadmin@vmc.local`, `WorkloadDatastore`, and
`SDDC-Datacenter/Cluster-1/Compute-ResourcePool`; use the values for your environment.
Then edit these entries in `local/vmc/` to use the datastore API for ISO uploads:

| File | Setting | Value |
|------|---------|-------|
| `topomojo.conf` | `Pod__TicketUrlHandler` | `none` |
| `topomojo.conf` | `FileUpload__UseDatastoreApi` | `true` |
| `topomojo.conf` | `FileUpload__IsoRoot` | `/mnt/vmc-iso` |
| `player-vm-api.conf` | `Vsphere__IsoUploadViaApi` | `true` |
| `player-vm-api.conf` | `Vsphere__IsoRoot` | `/mnt/vmc-iso` |

Use ISO paths appropriate to your environment. Caster needs no additional VMC-specific
changes beyond the connection and storage values entered during setup.

### Hybrid (Player VM and Caster)

Generate two local profiles as references:

```bash
./scripts/configure-hypervisors.sh proxmox --profile hybrid
./scripts/configure-hypervisors.sh vsphere --profile vsphere
```

In `local/hybrid/player-vm-api.conf`, keep the Proxmox settings, replace
`Vsphere__Hosts__0__Enabled=false` with the `Vsphere__...` entries from
`local/vsphere/player-vm-api.conf`, including `Vsphere__Hosts__0__Enabled=true`.

In `local/hybrid/caster-api.conf`, replace the empty/disabled
`Terraform__EnvironmentVariables__Direct__VSPHERE_...` entries with the corresponding
entries from `local/vsphere/caster-api.conf`. Keep the Proxmox entries and the single
`TF_CLI_CONFIG_FILE` entry. Replace matching keys rather than appending duplicates.
For VMC, apply the upload adjustments above to the hybrid Player VM file.

The generated `local/hybrid/topomojo.conf` still uses Proxmox only. To use vSphere
for TopoMojo and both backends for Player VM and Caster, select `vsphere`, then set
`Launch.ApiConfig.Apps["player-vm-api"].Profile` and
`Launch.ApiConfig.Apps["caster-api"].Profile` to `hybrid` in local AppHost settings.
Set per-app overrides **after** running the toggle, since switching clears them.

## File syntax and precedence

Files use literal environment keys in the app's native configuration schema:

```text
# Full-line comments are allowed.
Proxmox__Enabled=true
Proxmox__Host=pve.example.test
Proxmox__Port=8006
Proxmox__Token=user@realm!token-id=token-secret
```

Blank lines are ignored. Entries split at the **first** `=`; leading/trailing
whitespace on keys and values is trimmed. Empty values are allowed. Do not add shell
quotes, `export`, escapes, variable expansion, or inline comments: they are not
interpreted. For example, `$password`, `!` and additional `=` characters are literal.
Quoted values retain their quotes. Multiline values are unsupported.
Malformed or duplicate keys (including differently cased duplicates) fail validation.
Diagnostics identify files and line numbers without printing values.

Profiles contain one complete file per app; no base/profile/local layering is applied.
Profile names use letters, digits, hyphens and underscores, starting with a letter or digit.
An enabled app with a missing selected file fails startup; templates are never loaded
automatically and there is no fallback to a different profile.

- **Player VM and Caster:** AppHost injects entries as environment variables. These
  override matching `appsettings.json`, environment-specific appsettings, and default
  development user-secret values. App command-line arguments can still override them.
- **TopoMojo:** AppHost sets `APPSETTINGS_PATH` to the selected absolute path.
  TopoMojo loads it after its own `.conf` files, overriding matching keys.
  AppHost does not copy or rewrite files in the TopoMojo repository.

Unspecified keys still come from existing app configuration. A profile does not
replace a whole section or array. Proxmox-only Player VM templates disable vSphere
host index `0`; explicitly disable any other locally configured indices as well.
Caster templates blank the other provider's configured direct variables, but do not
prevent Terraform projects from supplying their own credentials/configuration.
Templates use development certificate defaults; review those for your environment.
Keep dynamic database/endpoints and existing authentication settings out of these profiles.

## Proxmox provisioning

`setup-crucible-proxmox.sh setup` passes its discovered host and token into the same
guided profile setup when run in a terminal. Accept the supplied defaults to use them.
Existing files offer the same keep/regenerate/cancel choice.

Without a terminal, provisioning fills missing Proxmox files and preserves existing
ones, reporting that host/token differences need manual reconciliation. Unfilled
placeholders stop setup before selection. To replace an existing profile, run
`configure-hypervisors.sh proxmox` interactively and choose regenerate.
Neither path rewrites TopoMojo's own development `.conf`.

These profiles configure the three APIs; they do not configure Moodle dashboard links.

## Adding app settings

Prefer app defaults: most new settings require no change here. When development needs
a fixed override, add its native `KEY=value` to the relevant templates. The setup script
copies those lines unchanged. Add a placeholder and a prompt in `scripts/api-config.sh`
only for settings users commonly need to choose; reuse an existing placeholder when
another app needs the same answer. Keep uncommon settings as manual file edits.

AppHost only delivers the files, so adding profile settings does not require AppHost
code changes. Existing profiles are not automatically changed when templates change:
edit them directly or regenerate with a backup.

### Wiring another app

`WithApiConfig` injects the selected file's entries as environment variables by default.
For an app that loads a config file itself, explicitly name the environment variable
through which it accepts that path:

```csharp
api.WithApiConfig(builder.AppHostDirectory, options.ApiConfig,
    configPathEnvironmentVariable: "APPSETTINGS_PATH");
```

This passes only the resolved absolute path, not the individual entries. TopoMojo uses
this option so the selected profile loads after its own `.conf` files. Other apps may
use a different environment variable name. Disabled configuration remains a no-op.

The resolver accepts any app name containing letters, digits, hyphens, or underscores,
starting with a letter or digit, and requires `local/<profile>/<resource-name>.conf`.
There is no app allowlist in the C# helper. Setup still targets the three wired APIs;
to include another app in guided generation and selection checks, add its templates
and launch-name mapping in `scripts/api-config.jq`.

## Validation

```bash
dotnet test tests/Crucible.AppHost.Config.Tests/Crucible.AppHost.Config.Tests.csproj
bash scripts/tests/api-config-smoke.sh
```

These tests use temporary profiles and dummy values, without connecting to hypervisors.
Runtime validation additionally requires starting Aspire with your own completed profiles.
