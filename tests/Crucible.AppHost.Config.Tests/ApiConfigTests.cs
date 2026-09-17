using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Crucible.AppHost;
using Microsoft.Extensions.Configuration;
using Xunit;

public sealed class ApiConfigTests : IDisposable
{
    private readonly string root = Directory.CreateTempSubdirectory("api-config-tests-").FullName;

    private string Write(string profile, string app, string contents)
    {
        var directory = Path.Combine(root, "resources/api/config/local", profile);
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, $"{app}.conf");
        File.WriteAllText(path, contents);
        return path;
    }

    [Fact]
    public void DisabledConfigurationDoesNotRequireAFile()
    {
        Assert.Null(ApiConfigFile.Resolve(root, "caster-api", new()));
        var options = new ApiConfigOptions
        {
            Enabled = true,
            Apps = { ["caster-api"] = new() { Enabled = false, Profile = "../invalid" } }
        };
        Assert.Null(ApiConfigFile.Resolve(root, "caster-api", options));
        options.Enabled = false;
        options.Apps["caster-api"].Enabled = true;
        Assert.Null(ApiConfigFile.Resolve(root, "caster-api", options));
    }

    [Fact]
    public void ProfilesInheritAndOverrideIndependently()
    {
        Write("proxmox", "topomojo", "Pod__HypervisorType=Proxmox");
        Write("hybrid", "player-vm-api", "Proxmox__Enabled=true\nVsphere__Hosts__0__Enabled=true");
        var options = new ApiConfigOptions
        {
            Enabled = true, Profile = "proxmox",
            Apps = { ["player-vm-api"] = new() { Profile = "hybrid" } }
        };
        Assert.Equal("Proxmox", ApiConfigFile.Resolve(root, "topomojo", options)!.Values["Pod__HypervisorType"]);
        Assert.Equal("true", ApiConfigFile.Resolve(root, "player-vm-api", options)!.Values["Vsphere__Hosts__0__Enabled"]);
        // No file for an unlaunched Caster is read by either call.
    }

    [Theory]
    [InlineData("")]
    [InlineData("../escape")]
    [InlineData("nested/profile")]
    [InlineData("profile.conf")]
    public void InvalidProfileNamesFail(string profile) =>
        Assert.Throws<InvalidOperationException>(() =>
            ApiConfigFile.Resolve(root, "caster-api", new() { Enabled = true, Profile = profile }));

    [Fact]
    public void MissingSelectedFileFailsWithAppAndPath()
    {
        var error = Assert.Throws<InvalidOperationException>(() =>
            ApiConfigFile.Resolve(root, "caster-api", new() { Enabled = true, Profile = "missing" }));
        Assert.Contains("caster-api", error.Message);
        Assert.Contains("missing", error.Message);
    }

    [Fact]
    public void ParserPreservesLiteralValuesAndEmptyStrings()
    {
        var file = Write("test", "caster-api",
            "\uFEFF# comment\r\n \r\n TOKEN =user@realm!id=secret$HOME#literal\r\nEMPTY=\nQUOTED=\"literal\"\n");
        var values = ApiConfigFile.Read(file, "caster-api");
        Assert.Equal("user@realm!id=secret$HOME#literal", values["TOKEN"]);
        Assert.Equal("", values["EMPTY"]);
        Assert.Equal("\"literal\"", values["QUOTED"]);
    }

    [Theory]
    [InlineData("secret without equals")]
    [InlineData("BAD-KEY=secret")]
    [InlineData("KEY=secret\nKEY=another")]
    [InlineData("key=secret\nKEY=another")]
    public void InvalidEntriesFailWithoutLeakingValues(string contents)
    {
        var file = Write("test", "caster-api", contents);
        var error = Assert.Throws<InvalidOperationException>(() => ApiConfigFile.Read(file, "caster-api"));
        Assert.Contains(file, error.Message);
        Assert.Contains("line ", error.Message);
        Assert.DoesNotContain("secret", error.Message);
    }

    [Theory]
    [InlineData("player-vm-api")]
    [InlineData("caster-api")]
    public async Task FileValuesOverrideMatchingAppsettingsButPreserveOtherKeys(string app)
    {
        Write("test", app, "Example__Value=profile");
        var env = await EnvironmentFor(app, new() { Enabled = true, Profile = "test" });
        Assert.Equal("profile", env["Example__Value"]);
        var settings = Path.Combine(root, "appsettings.json");
        File.WriteAllText(settings, """{"Example":{"Value":"appsettings","Other":"keep"}}""");
        var key = "Example__Value";
        var previous = Environment.GetEnvironmentVariable(key);
        try
        {
            Environment.SetEnvironmentVariable(key, (string)env[key]);
            var configuration = new ConfigurationBuilder().AddJsonFile(settings).AddEnvironmentVariables().Build();
            Assert.Equal("profile", configuration["Example:Value"]);
            Assert.Equal("keep", configuration["Example:Other"]);
        }
        finally { Environment.SetEnvironmentVariable(key, previous); }
    }

    [Fact]
    public async Task TopomojoReceivesAnAbsoluteFilePathInsteadOfOverridableEntries()
    {
        var path = Write("proxmox", "topomojo", "Pod__HypervisorType=Proxmox");
        var env = await EnvironmentFor("topomojo", new() { Enabled = true, Profile = "proxmox" });
        Assert.Equal(path, env["APPSETTINGS_PATH"]);
        Assert.False(env.ContainsKey("Pod__HypervisorType"));
        var disabled = await EnvironmentFor("topomojo", new());
        Assert.False(disabled.ContainsKey("APPSETTINGS_PATH"));
    }

    [Fact]
    public async Task SwitchingProfilesDoesNotRetainPreviouslyInjectedValues()
    {
        Write("proxmox", "player-vm-api", "Proxmox__Enabled=true\nVsphere__Hosts__0__Enabled=false\nOnlyInProxmox=yes");
        Write("vsphere", "player-vm-api", "Proxmox__Enabled=false\nVsphere__Hosts__0__Enabled=true");
        foreach (var profile in new[] { "proxmox", "vsphere", "proxmox" })
        {
            var env = await EnvironmentFor("player-vm-api", new() { Enabled = true, Profile = profile });
            Assert.Equal(profile == "proxmox" ? "true" : "false", env["Proxmox__Enabled"]);
            Assert.Equal(profile == "proxmox", env.ContainsKey("OnlyInProxmox"));
        }
    }

    [Fact]
    public void ConfigurationBindingPreservesPerAppDefaultEnabled()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Enabled"] = "true", ["Profile"] = "proxmox", ["Apps:player-vm-api:Profile"] = "hybrid",
            ["Apps:caster-api:Enabled"] = "false"
        }).Build();
        var options = configuration.Get<ApiConfigOptions>()!;
        Assert.True(options.Apps["player-vm-api"].Enabled);
        Assert.False(options.Apps["caster-api"].Enabled);
    }

    private async Task<Dictionary<string, object>> EnvironmentFor(string app, ApiConfigOptions options)
    {
        var builder = DistributedApplication.CreateBuilder(new DistributedApplicationOptions
        {
            Args = []
        });
        var resource = builder.AddExecutable(app, "unused", root)
            .WithEnvironment("Existing", "unchanged")
            .WithApiConfig(root, options);
        var env = new Dictionary<string, object>();
        var context = new EnvironmentCallbackContext(builder.ExecutionContext, resource.Resource, env, default);
        foreach (var annotation in resource.Resource.Annotations.OfType<EnvironmentCallbackAnnotation>())
            await annotation.Callback(context);
        Assert.Equal("unchanged", env["Existing"]);
        return env;
    }

    public void Dispose() => Directory.Delete(root, recursive: true);
}
