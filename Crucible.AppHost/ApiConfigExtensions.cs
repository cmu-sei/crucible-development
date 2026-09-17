using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;

namespace Crucible.AppHost;

public static class ApiConfigExtensions
{
    public static IResourceBuilder<T> WithApiConfig<T>(
        this IResourceBuilder<T> resource, string appHostDirectory, ApiConfigOptions options)
        where T : IResourceWithEnvironment
    {
        var config = ApiConfigFile.Resolve(appHostDirectory, resource.Resource.Name, options);
        if (config is null)
            return resource;

        Console.WriteLine($"API configuration for {resource.Resource.Name}: {config.Path}");
        if (resource.Resource.Name == "topomojo")
        {
            // TopoMojo loads this file after its local .conf files. Injecting the entries
            // directly would let those local files overwrite the selected profile.
            resource.WithEnvironment("APPSETTINGS_PATH", config.Path);
        }
        else
        {
            foreach (var (key, value) in config.Values)
                resource.WithEnvironment(key, value);
        }
        return resource;
    }
}
