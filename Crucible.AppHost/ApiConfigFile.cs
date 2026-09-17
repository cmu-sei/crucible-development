using System.Text.RegularExpressions;

namespace Crucible.AppHost;

/// <summary>Resolves an opt-in, per-app configuration file without modifying app repositories.</summary>
public sealed record ApiConfigFile(string Path, IReadOnlyDictionary<string, string> Values)
{
    public static ApiConfigFile? Resolve(string appHostDirectory, string app, ApiConfigOptions options)
    {
        if (!options.Enabled)
            return null;

        options.Apps.TryGetValue(app, out var appOptions);
        if (appOptions?.Enabled == false)
            return null;

        var profile = appOptions?.Profile ?? options.Profile;
        if (!Regex.IsMatch(profile, @"\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z"))
            throw new InvalidOperationException($"API configuration for {app}: select a profile containing only letters, digits, '-' and '_'.");

        if (app is not ("topomojo" or "player-vm-api" or "caster-api"))
            throw new InvalidOperationException($"API configuration does not support app '{app}'.");

        var path = System.IO.Path.GetFullPath(System.IO.Path.Combine(
            appHostDirectory, "resources", "api", "config", "local", profile, $"{app}.conf"));
        if (!File.Exists(path))
            throw new InvalidOperationException($"API configuration for {app}: selected file does not exist: {path}. Initialize and edit the profile first.");

        return new(path, Read(path, app));
    }

    public static IReadOnlyDictionary<string, string> Read(string path, string app)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var lineNumber = 0;
        foreach (var line in File.ReadLines(path))
        {
            lineNumber++;
            if (string.IsNullOrWhiteSpace(line) || line.TrimStart().StartsWith('#'))
                continue;

            var separator = line.IndexOf('=');
            if (separator < 0)
                throw InvalidLine("expected KEY=value");

            var key = line[..separator].Trim();
            if (!Regex.IsMatch(key, @"\A[a-zA-Z_][a-zA-Z0-9_]*\z"))
                throw InvalidLine("invalid environment key");
            if (!values.TryAdd(key, line[(separator + 1)..].Trim()))
                throw InvalidLine("duplicate environment key");
        }
        return values;

        InvalidOperationException InvalidLine(string reason) =>
            new($"API configuration for {app}: {path}, line {lineNumber}: {reason}.");
    }
}
