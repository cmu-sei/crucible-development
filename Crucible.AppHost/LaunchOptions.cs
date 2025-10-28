// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

namespace Crucible.AppHost;

public class LaunchOptions
{
    public bool Player { get; set; } = true;
    public bool Caster { get; set; } = true;
    public bool Alloy { get; set; } = true;
    public bool TopoMojo { get; set; } = true;
    public bool Steamfitter { get; set; } = true;
    public bool Cite { get; set; } = true;
    public bool Gallery { get; set; } = true;
    public bool Blueprint { get; set; } = true;
    public bool Prometheus { get; set; } = false;
}
