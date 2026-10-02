// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using System.Text.RegularExpressions;

namespace Crucible.AppHost;

public static class ApiConfigExtensions
{
    /// <summary>
    /// Injects profile entries as environment variables, or passes the resolved file path
    /// through the named environment variable when the app loads configuration files itself.
    /// </summary>
    public static IResourceBuilder<T> WithApiConfig<T>(
        this IResourceBuilder<T> resource, string appHostDirectory, ApiConfigOptions options,
        string? configPathEnvironmentVariable = null)
        where T : IResourceWithEnvironment
    {
        var config = ApiConfigFile.Resolve(appHostDirectory, resource.Resource.Name, options);
        if (config is null)
            return resource;

        if (configPathEnvironmentVariable is not null)
        {
            if (!Regex.IsMatch(configPathEnvironmentVariable, @"\A[a-zA-Z_][a-zA-Z0-9_]*\z"))
                throw new ArgumentException("Expected a valid environment variable name.", nameof(configPathEnvironmentVariable));
            resource.WithEnvironment(configPathEnvironmentVariable, config.Path);
        }
        else
        {
            foreach (var (key, value) in config.Values)
                resource.WithEnvironment(key, value);
        }
        Console.WriteLine($"API configuration for {resource.Resource.Name}: {config.Path}");
        return resource;
    }
}
