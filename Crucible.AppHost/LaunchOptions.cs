// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

namespace Crucible.AppHost;

public class LaunchOptions
{
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
    public string XdebugMode { get; set; } = "off";
    public bool AddAllApplications { get; set; }
}
