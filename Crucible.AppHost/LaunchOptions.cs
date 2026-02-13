// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

namespace Crucible.AppHost;

public class LaunchOptions
{
    // UI applications with dev mode support: "off" (default), "prod", or "dev"
    public string Player { get; set; } = "off";
    public string Caster { get; set; } = "off";
    public string Alloy { get; set; } = "off";
    public string TopoMojo { get; set; } = "off";
    public string Steamfitter { get; set; } = "off";
    public string Cite { get; set; } = "off";
    public string Gallery { get; set; } = "off";
    public string Blueprint { get; set; } = "off";
    public string Gameboard { get; set; } = "off";
    public bool Moodle { get; set; } = false;
    public bool Lrsql { get; set; } = false;
    public bool PGAdmin { get; set; } = false;
    public bool Docs { get; set; } = false;
    public bool Misp { get; set; } = false;
    public string XdebugMode { get; set; } = "off";
    public bool AddAllApplications { get; set; } = false;
}
