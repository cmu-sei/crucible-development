// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

namespace Crucible.AppHost;

public class LaunchOptions
{
    // Primary app per task (.env files): true = dev mode, false/omitted = off
    public bool Player { get; set; }
    public bool Caster { get; set; }
    public bool Alloy { get; set; }
    public bool TopoMojo { get; set; }
    public bool Steamfitter { get; set; }
    public bool Cite { get; set; }
    public bool Gallery { get; set; }
    public bool Blueprint { get; set; }
    public bool Gameboard { get; set; }
    public bool Moodle { get; set; }
    public bool Lrsql { get; set; }
    public bool PGAdmin { get; set; }
    public bool Docs { get; set; }
    public bool Misp { get; set; }
    public bool Superset { get; set; }
    public bool Catapult { get; set; }

    // Supporting apps (appsettings.Development.json): arrays grouped by mode
    public string[] Prod { get; set; } = Array.Empty<string>();
    public string[] Dev { get; set; } = Array.Empty<string>();

    public string XdebugMode { get; set; } = "off";
    public bool AddAllApplications { get; set; }
    public bool UseAspireProxy { get; set; }
    public bool LinkCommonUI { get; set; }

    // Hypervisor configuration (legacy flat fields).
    // A single backend at a time. Still supported for backward compatibility;
    // the nested Hypervisors block below supersedes these when present and is
    // the only way to configure Proxmox AND vSphere simultaneously.
    public string HypervisorType { get; set; } = ""; // Proxmox, Vsphere, or empty for none
    public string HypervisorUrl { get; set; } = "";
    public string HypervisorUser { get; set; } = "";
    public string HypervisorPassword { get; set; } = "";
    public string HypervisorToken { get; set; } = "";
    public string HypervisorVmStore { get; set; } = "";
    public string HypervisorDiskStore { get; set; } = "";
    public string HypervisorIsoStore { get; set; } = "";
    public string HypervisorPoolPath { get; set; } = "";

    // File-layout behavior. Nullable so AppHost falls back to type-based
    // defaults when the toggle script hasn't written an explicit value.
    public bool? HypervisorSupportsSubfolders { get; set; }
    public bool? HypervisorUseDatastoreApi { get; set; }

    // Nested multi-backend config. Player VM API and Caster support Proxmox and
    // vSphere/VMC simultaneously (vm.api routes per-VM, Caster per-project), so
    // both blocks can be populated at once - useful in dev when testing a
    // feature against both. TopoMojo is single-backend and uses the one named
    // by TopomojoHypervisor.
    public HypervisorsConfig? Hypervisors { get; set; }

    // Which backend TopoMojo uses ("Proxmox" or "Vsphere"). Falls back to the
    // legacy HypervisorType, then to whichever single backend is configured.
    public string TopomojoHypervisor { get; set; } = "";

    // Resolve the effective Proxmox backend (nested wins, else legacy flat fields).
    public HypervisorConfig? ResolveProxmox()
    {
        if (Hypervisors?.Proxmox is { } p &&
            !string.IsNullOrEmpty(p.Url) && !string.IsNullOrEmpty(p.Token))
        {
            return p;
        }

        if (HypervisorType?.Equals("Proxmox", StringComparison.OrdinalIgnoreCase) == true &&
            !string.IsNullOrEmpty(HypervisorUrl) && !string.IsNullOrEmpty(HypervisorToken))
        {
            return FromFlat();
        }

        return null;
    }

    // Resolve the effective vSphere/VMC backend (nested wins, else legacy flat fields).
    public HypervisorConfig? ResolveVsphere()
    {
        if (Hypervisors?.Vsphere is { } v &&
            !string.IsNullOrEmpty(v.Url) && !string.IsNullOrEmpty(v.User) && !string.IsNullOrEmpty(v.Password))
        {
            return v;
        }

        if ((HypervisorType?.Equals("Vsphere", StringComparison.OrdinalIgnoreCase) == true) &&
            !string.IsNullOrEmpty(HypervisorUrl) && !string.IsNullOrEmpty(HypervisorUser) &&
            !string.IsNullOrEmpty(HypervisorPassword))
        {
            return FromFlat();
        }

        return null;
    }

    // The (type, config) TopoMojo should use. Explicit TopomojoHypervisor wins,
    // then legacy HypervisorType, then whichever single backend is configured.
    public (string Type, HypervisorConfig Config)? ResolveTopomojo()
    {
        var proxmox = ResolveProxmox();
        var vsphere = ResolveVsphere();

        var pick = !string.IsNullOrEmpty(TopomojoHypervisor) ? TopomojoHypervisor : HypervisorType;

        if (pick?.Equals("Proxmox", StringComparison.OrdinalIgnoreCase) == true && proxmox != null)
            return ("Proxmox", proxmox);
        if (pick?.Equals("Vsphere", StringComparison.OrdinalIgnoreCase) == true && vsphere != null)
            return ("Vsphere", vsphere);

        // No explicit selection: use whichever single backend exists.
        if (proxmox != null && vsphere == null) return ("Proxmox", proxmox);
        if (vsphere != null && proxmox == null) return ("Vsphere", vsphere);

        return null;
    }

    private HypervisorConfig FromFlat() => new()
    {
        Url = HypervisorUrl,
        Token = HypervisorToken,
        User = HypervisorUser,
        Password = HypervisorPassword,
        VmStore = HypervisorVmStore,
        DiskStore = HypervisorDiskStore,
        IsoStore = HypervisorIsoStore,
        PoolPath = HypervisorPoolPath,
        SupportsSubfolders = HypervisorSupportsSubfolders,
        UseDatastoreApi = HypervisorUseDatastoreApi,
    };

    // Backward compatibility
    public bool UseProxmox => HypervisorType?.Equals("Proxmox", StringComparison.OrdinalIgnoreCase) == true;
    public string ProxmoxHost => HypervisorUrl;
    public string ProxmoxApiToken => HypervisorToken;
}

public class HypervisorsConfig
{
    public HypervisorConfig? Proxmox { get; set; }
    public HypervisorConfig? Vsphere { get; set; }
}

public class HypervisorConfig
{
    public string Url { get; set; } = "";
    public string Token { get; set; } = "";      // Proxmox auth
    public string User { get; set; } = "";        // vSphere auth
    public string Password { get; set; } = "";    // vSphere auth
    public string VmStore { get; set; } = "";
    public string DiskStore { get; set; } = "";
    public string IsoStore { get; set; } = "";
    public string PoolPath { get; set; } = "";
    public bool? SupportsSubfolders { get; set; }
    public bool? UseDatastoreApi { get; set; }
}
