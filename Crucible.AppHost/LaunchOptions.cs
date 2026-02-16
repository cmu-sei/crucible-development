// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

namespace Crucible.AppHost;

public class LaunchOptions
{
    // All applications use: "off" (default), "prod", or "dev"
    // If "dev" is not supported by an application, it will be treated as "prod"
    public string Player { get; set; } = "off";
    public string Caster { get; set; } = "off";
    public string Alloy { get; set; } = "off";
    public string TopoMojo { get; set; } = "off";
    public string Steamfitter { get; set; } = "off";
    public string Cite { get; set; } = "off";
    public string Gallery { get; set; } = "off";
    public string Blueprint { get; set; } = "off";
    public string Gameboard { get; set; } = "off";
    public string Moodle { get; set; } = "off";
    public string Lrsql { get; set; } = "off";
    public string PGAdmin { get; set; } = "off";
    public string Docs { get; set; } = "off";
    public string Misp { get; set; } = "off";
    public string XdebugMode { get; set; } = "off";
    public string AddAllApplications { get; set; } = "off";
}
