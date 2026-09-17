namespace Crucible.AppHost;

public sealed class ApiConfigOptions
{
    public bool Enabled { get; set; }
    public string Profile { get; set; } = "";
    public Dictionary<string, ApiConfigAppOptions> Apps { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}

public sealed class ApiConfigAppOptions
{
    public bool Enabled { get; set; } = true;
    public string? Profile { get; set; }
}
