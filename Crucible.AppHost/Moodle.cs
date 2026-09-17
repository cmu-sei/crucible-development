// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using Crucible.AppHost;

// Moodle resource wiring, split out of AppHost.cs.
public static partial class BuilderExtensions
{
    /// <summary>
    /// A Moodle version Aspire can run. Each instance needs its own container name,
    /// port, database and moodle-core mount: booting a newer Moodle against another
    /// instance's database runs irreversible upgrade migrations.
    ///
    /// WebRoot is where the Moodle tree lives inside the container. Moodle 5.1 moved
    /// everything web-accessible under public/, so plugins and core directories sit one
    /// level deeper on 5.1+ (admin/cli stays outside the web root in both layouts).
    /// </summary>
    private sealed record MoodleInstance(
        string Name,
        string BaseImage,
        int Port,
        string DbResourceName,
        string DbName,
        string CoreMountRoot,
        string WebRoot,
        string Mode,
        bool IncludeWithAll,
        string MarketplacePlugins);

    /// <summary>
    /// Marketplace plugin downloads for a given Moodle branch. The version ids are
    /// branch-specific: installing a 5.0 build of these on 5.2 fails, so each Moodle
    /// instance pins the versions the plugin API reports for its own branch.
    ///
    /// Only ever move a pin forward. An existing instance records the installed version in
    /// config_plugins, so a lower pin lands older code under a newer database and Moodle
    /// reports a plugin downgrade instead of upgrading. The same applies to an instance that
    /// was upgraded by hand past its pin: drop its database, or uninstall the plugin, before
    /// rebuilding it.
    /// </summary>
    private static string MarketplacePluginsFor(string toolUserdebug, string boostUnion, string boostDark) =>
        $"tool_userdebug=https://marketplace.moodle.com/api/plugins/tool_userdebug/versions/{toolUserdebug}/download " +
        $"theme_boost_union=https://marketplace.moodle.com/api/plugins/theme_boost_union/versions/{boostUnion}/download " +
        $"local_boost_dark=https://marketplace.moodle.com/api/plugins/local_boost_dark/versions/{boostDark}/download";

    public static void AddMoodle(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var instances = new[]
        {
            new MoodleInstance(
                Name: "moodle",
                BaseImage: "erseco/alpine-moodle:v5.0.0",
                Port: 8081,
                DbResourceName: "moodleDb",
                DbName: "moodle",
                CoreMountRoot: "/mnt/data/crucible/moodle/moodle-core",
                WebRoot: "/var/www/html",
                Mode: ResolveMode(options.Moodle, "Moodle", options),
                IncludeWithAll: true,
                // boost_dark 1.3.7, matching production and the 5.2 instance below.
                MarketplacePlugins: MarketplacePluginsFor(
                    toolUserdebug: "2025070100",
                    boostUnion: "2025041407",
                    boostDark: "2026052400")),
            // Moodle 5.2 test instance. Left out of AddAllApplications so it only
            // builds and appears in the dashboard when Launch__Moodle52 asks for it.
            new MoodleInstance(
                Name: "moodle52",
                BaseImage: "erseco/alpine-moodle:v5.2.2",
                Port: 8082,
                DbResourceName: "moodle52Db",
                DbName: "moodle52",
                CoreMountRoot: "/mnt/data/crucible/moodle/moodle-core-52",
                // 5.2 serves out of public/; the base image re-points nginx at it on boot.
                WebRoot: "/var/www/html/public",
                Mode: ResolveMode(options.Moodle52, "Moodle52", options),
                IncludeWithAll: false,
                // Versions the plugin API reports for branch 5.2 (boost_union v5.2-r8,
                // boost_dark 1.3.7, userdebug v5.0.3 which spans through 5.2).
                MarketplacePlugins: MarketplacePluginsFor(
                    toolUserdebug: "2025070300",
                    boostUnion: "2026042012",
                    boostDark: "2026052400")),
        };

        var enabled = instances
            .Where(instance => IsEnabled(instance.Mode) || (options.AddAllApplications && instance.IncludeWithAll))
            .ToArray();

        if (enabled.Length == 0)
            return;

        // Fetched once and shared by every instance: the script writes a single
        // ~/.topomojo-apikey, and an Aspire resource name can only be registered once,
        // so this cannot move inside the per-instance call.
        var topoMojoApiKey = builder.AddTopoMojoApiKeyScript(options);

        foreach (var instance in enabled)
        {
            builder.AddMoodleInstance(postgres, keycloak, options, instance, topoMojoApiKey);
        }

        // Copy dotnet dev-cert(s) into resources/moodle/certs so they get trusted through the Dockerfile
        builder.Eventing.Subscribe<BeforeStartEvent>((@event, cancellationToken) =>
        {
            var aspireDevCertDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                ".aspnet", "dev-certs", "trust");
            var moodleCertDir = Path.Combine(builder.AppHostDirectory, "resources", "moodle", "certs");

            if (Directory.Exists(aspireDevCertDir))
            {
                Directory.CreateDirectory(moodleCertDir);
                foreach (var pem in Directory.GetFiles(aspireDevCertDir, "*.pem"))
                {
                    var destName = Path.GetFileNameWithoutExtension(pem) + ".crt";
                    File.Copy(pem, Path.Combine(moodleCertDir, destName), overwrite: true);
                }
            }

            return Task.CompletedTask;
        });
    }

    /// <summary>
    /// Get or create TopoMojo's API key before any Moodle instance starts, so post_configure.sh
    /// can wire mod_topomojo up. Returns null when TopoMojo is not running, in which case Moodle
    /// starts without TOPOMOJO_APIKEY.
    /// </summary>
    private static IResourceBuilder<ExecutableResource>? AddTopoMojoApiKeyScript(
        this IDistributedApplicationBuilder builder, LaunchOptions options)
    {
        if (!IsEnabled(ResolveMode(options.TopoMojo, "TopoMojo", options)))
            return null;

        // Find the TopoMojo API resource builder by display name
        var topoMojoApiBuilder = builder.Resources
            .OfType<IResourceBuilder<ProjectResource>>()
            .FirstOrDefault(r => r.Resource.Name.StartsWith("topomojo") && !r.Resource.Name.Contains("ui"));

        if (topoMojoApiBuilder == null)
            return null;

        return builder.AddExecutable("get-topomojo-apikey", "bash",
            builder.AppHostDirectory,
            "-c",
            $"bash {builder.AppHostDirectory}/../scripts/get-or-create-topomojo-apikey.sh")
            .WaitFor(topoMojoApiBuilder);
    }

    /// <summary>
    /// Create the host side of an instance's moodle-core bind mounts. Docker creates missing
    /// mount sources 0755 owned by whoever runs the AppHost, but the container runs as nobody
    /// (65534) and pre_configure.sh has to seed these directories on first boot - so they have
    /// to be world-writable, the same thing scripts/add-moodle-mounts.sh does at setup time.
    /// Doing it here means a newly added Moodle version works without re-running that script.
    /// </summary>
    private static void EnsureMoodleCoreMounts(MoodleInstance instance)
    {
        const UnixFileMode worldWritableDir =
            UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute |
            UnixFileMode.GroupRead | UnixFileMode.GroupWrite | UnixFileMode.GroupExecute |
            UnixFileMode.OtherRead | UnixFileMode.OtherWrite | UnixFileMode.OtherExecute;

        // The host layout stays flat across versions; only the container side moves under public/.
        string[] coreDirs = ["", "theme", "lib", "admin/cli", "ai/provider", "ai/classes"];

        foreach (var relative in coreDirs)
        {
            var path = relative.Length == 0 ? instance.CoreMountRoot : Path.Combine(instance.CoreMountRoot, relative);

            try
            {
                Directory.CreateDirectory(path);
                File.SetUnixFileMode(path, worldWritableDir);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Warning: could not prepare {instance.Name} core mount {path}: {ex.Message}");
            }
        }
    }

    private static void AddMoodleInstance(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, MoodleInstance instance, IResourceBuilder<ExecutableResource>? topoMojoApiKey)
    {
        var moodleMode = instance.Mode;

        EnsureMoodleCoreMounts(instance);

        var moodleDb = postgres.AddDatabase(instance.DbResourceName, instance.DbName);

        // Read AWS credentials from ~/.aws/credentials file
        var awsCreds = AwsCredentials.Read();

        // Check which Crucible services are enabled
        var playerMode = ResolveMode(options.Player, "Player", options);
        var casterMode = ResolveMode(options.Caster, "Caster", options);
        var alloyMode = ResolveMode(options.Alloy, "Alloy", options);
        var topoMojoMode = ResolveMode(options.TopoMojo, "TopoMojo", options);
        var topoMojoLaunchpointMode = ResolveMode(options.TopoMojoLaunchpoint, "TopoMojoLaunchpoint", options);
        var steamfitterMode = ResolveMode(options.Steamfitter, "Steamfitter", options);
        var citeMode = ResolveMode(options.Cite, "Cite", options);
        var galleryMode = ResolveMode(options.Gallery, "Gallery", options);
        var blueprintMode = ResolveMode(options.Blueprint, "Blueprint", options);
        var gameboardMode = ResolveMode(options.Gameboard, "Gameboard", options);

        // Held as a string so WithEnvironment binds the plain-string overload rather than
        // the ReferenceExpression one, which rejects the interpolated int port.
        var siteUrl = "http://localhost:" + instance.Port;

        var moodle = builder.AddContainer(instance.Name, $"{instance.Name}-custom-image")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithDockerfile("./resources/moodle", "Dockerfile.MoodleCustom")
            .WithBuildArg("MOODLE_BASE_IMAGE", instance.BaseImage)
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName(instance.Name)
            .WithHttpEndpoint(port: instance.Port, targetPort: 8080)
            .WithHttpHealthCheck(endpointName: "http")
            .WithEnvironment("memory_limit", "512M") // needs to be set for moosh plugin-list to work
            .WithEnvironment("XDEBUG_MODE", options.XdebugMode)
            .WithEnvironment("REVERSEPROXY", "true")
            .WithEnvironment("SITE_URL", siteUrl)
            .WithEnvironment("SSLPROXY", "false")
            .WithEnvironment("MOODLE_ADMIN_USERNAME", "admin")
            .WithEnvironment("MOODLE_ADMIN_PASSWORD", "admin")
            .WithEnvironment("DB_USER", postgres.Resource.UserNameReference)
            .WithEnvironment("DB_PASS", postgres.Resource.PasswordParameter)
            .WithEnvironment("DB_HOST", postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("DB_NAME", moodleDb.Resource.DatabaseName);

        if (topoMojoApiKey != null)
        {
            // Wait for the shared API key script to finish before this instance starts.
            moodle.WaitForCompletion(topoMojoApiKey);

            // Read the API key file at runtime (via callback) rather than during graph
            // construction: the file is produced by the script, so on a fresh machine
            // it does not exist yet at build time. The callback runs when Moodle starts,
            // after WaitForCompletion has ensured the script finished and wrote the file.
            var apiKeyFilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".topomojo-apikey");
            moodle.WithEnvironment(context =>
            {
                if (File.Exists(apiKeyFilePath))
                {
                    context.EnvironmentVariables["TOPOMOJO_APIKEY"] = File.ReadAllText(apiKeyFilePath).Trim();
                }
            });
        }

        // Only set AWS credentials if the credentials file exists
        if (awsCreds != null)
        {
            moodle
                .WithEnvironment("AWS_ACCESS_KEY_ID", awsCreds["aws_access_key_id"])
                .WithEnvironment("AWS_SECRET_ACCESS_KEY", awsCreds["aws_secret_access_key"])
                .WithEnvironment("AWS_SESSION_TOKEN", awsCreds["aws_session_token"])
                .WithEnvironment("AWS_REGION", awsCreds["region"]);
        }

        moodle
            // Pass which Crucible services are enabled
            .WithEnvironment("CRUCIBLE_PLAYER_ENABLED", IsEnabled(playerMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_CASTER_ENABLED", IsEnabled(casterMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_ALLOY_ENABLED", IsEnabled(alloyMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_TOPOMOJO_ENABLED", IsEnabled(topoMojoMode) || IsEnabled(topoMojoLaunchpointMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_STEAMFITTER_ENABLED", IsEnabled(steamfitterMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_CITE_ENABLED", IsEnabled(citeMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_GALLERY_ENABLED", IsEnabled(galleryMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_BLUEPRINT_ENABLED", IsEnabled(blueprintMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_GAMEBOARD_ENABLED", IsEnabled(gameboardMode) ? "1" : "0")
            .WithEnvironment("CRUCIBLE_CATAPULT_ENABLED", IsEnabled(ResolveMode(options.Catapult, "Catapult", options)) ? "1" : "0")
            // 5.1+ images can rsync --delete the image's Moodle tree over /var/www/html on
            // boot. That is for named volumes; here the tree is baked into the image and the
            // core/plugin directories are bind mounts (some read-only), so keep it off.
            .WithEnvironment("SYNC_MOODLE_CODE", "never")
            .WithEnvironment("PLUGINS", instance.MarketplacePlugins)
            .WithEnvironment("PRE_CONFIGURE_COMMANDS", @"/usr/local/bin/pre_configure.sh;")
            .WithEnvironment("POST_CONFIGURE_COMMANDS", @"/usr/local/bin/post_configure.sh")
            // Bind mount moodle-core directories (writable for xdebug)
            // pre_configure.sh seeds these from the image when they are empty, so a new
            // version's mount root can start out as an empty directory. The host side
            // stays flat across versions; only the container side moves under public/.
            .WithBindMount($"{instance.CoreMountRoot}/theme", $"{instance.WebRoot}/theme", isReadOnly: false)
            .WithBindMount($"{instance.CoreMountRoot}/lib", $"{instance.WebRoot}/lib", isReadOnly: false)
            .WithBindMount($"{instance.CoreMountRoot}/admin/cli", "/var/www/html/admin/cli", isReadOnly: false)
            .WithBindMount($"{instance.CoreMountRoot}/ai/provider", $"{instance.WebRoot}/ai/provider", isReadOnly: false)
            .WithBindMount($"{instance.CoreMountRoot}/ai/classes", $"{instance.WebRoot}/ai/classes", isReadOnly: false)
            .WithBindMount("/tmp/crucible", "/tmp/crucible", isReadOnly: true);

        // When CATAPULT is enabled, mount the Apache-2.0 cmi5 sample package from the
        // cloned CATAPULT repo (single source of truth - avoids vendoring a duplicate
        // binary). post_configure.sh uses it to seed/repair the demo cmi5 activity.
        if (IsEnabled(ResolveMode(options.Catapult, "Catapult", options)))
        {
            moodle.WithBindMount(
                "/mnt/data/crucible/catapult/catapult/course_examples/packages/single_au_basic_framed.zip",
                "/usr/local/share/cmi5/sample_cmi5.zip",
                isReadOnly: true);
        }

        // Dynamically bind mount all Moodle plugins from repos.json + repos.local.json
        var moodlePlugins = ReadMoodlePlugins(instance.WebRoot);
        foreach (var plugin in moodlePlugins)
        {
            moodle.WithBindMount(plugin.HostPath, plugin.ContainerPath, isReadOnly: true);
            Console.WriteLine($"  Mounting {instance.Name} plugin: {plugin.Name} -> {plugin.ContainerPath}");
        }

        if (!IsEnabled(moodleMode))
        {
            moodle.WithExplicitStart();
        }
    }

    private class MoodlePlugin
    {
        public string Name { get; set; } = "";
        public string HostPath { get; set; } = "";
        public string ContainerPath { get; set; } = "";
    }

    /// <summary>
    /// Container path for a plugin, relative to the instance's web root: Moodle 5.1+
    /// keeps the whole plugin tree under public/.
    /// </summary>
    private static string MapPluginToContainerPath(string pluginName, string webRoot)
    {
        var parts = pluginName.Split('_', 2);
        if (parts.Length < 2) return $"{webRoot}/{pluginName}";

        var pluginType = parts[0];
        var pluginSubdir = parts[1];

        return pluginType switch
        {
            "mod" => $"{webRoot}/mod/{pluginSubdir}",
            "block" => $"{webRoot}/blocks/{pluginSubdir}",
            "tool" => $"{webRoot}/admin/tool/{pluginSubdir}",
            "logstore" => $"{webRoot}/admin/tool/log/store/{pluginSubdir}",
            "local" => $"{webRoot}/local/{pluginSubdir}",
            "qtype" => $"{webRoot}/question/type/{pluginSubdir}",
            "qbehaviour" => $"{webRoot}/question/behaviour/{pluginSubdir}",
            "qformat" => $"{webRoot}/question/format/{pluginSubdir}",
            "aiplacement" => $"{webRoot}/ai/placement/{pluginSubdir}",
            "aiprovider" => $"{webRoot}/ai/provider/{pluginSubdir}",
            "gradereport" => $"{webRoot}/grade/report/{pluginSubdir}",
            "theme" => $"{webRoot}/theme/{pluginSubdir}",
            _ => $"{webRoot}/{pluginType}/{pluginSubdir}"
        };
    }

    private static string MapPluginToHostPath(string pluginName, string moodleBasePath)
    {
        var parts = pluginName.Split('_', 2);
        if (parts.Length < 2) return Path.Combine(moodleBasePath, pluginName);

        var pluginType = parts[0];
        var pluginSubdir = parts[1];

        return pluginType switch
        {
            "mod" => Path.Combine(moodleBasePath, "mod", pluginSubdir),
            "block" => Path.Combine(moodleBasePath, "blocks", pluginSubdir),
            "tool" => Path.Combine(moodleBasePath, "admin", "tool", pluginSubdir),
            "logstore" => Path.Combine(moodleBasePath, "admin", "tool", "log", "store", pluginSubdir),
            "local" => Path.Combine(moodleBasePath, "local", pluginSubdir),
            "qtype" => Path.Combine(moodleBasePath, "question", "type", pluginSubdir),
            "qbehaviour" => Path.Combine(moodleBasePath, "question", "behaviour", pluginSubdir),
            "qformat" => Path.Combine(moodleBasePath, "question", "format", pluginSubdir),
            "aiplacement" => Path.Combine(moodleBasePath, "ai", "placement", pluginSubdir),
            "aiprovider" => Path.Combine(moodleBasePath, "ai", "provider", pluginSubdir),
            "gradereport" => Path.Combine(moodleBasePath, "grade", "report", pluginSubdir),
            "theme" => Path.Combine(moodleBasePath, "theme", pluginSubdir),
            _ => Path.Combine(moodleBasePath, pluginType, pluginSubdir)
        };
    }

    private static List<MoodlePlugin> ReadMoodlePlugins(string webRoot)
    {
        var plugins = new List<MoodlePlugin>();
        var workspaceRoot = "/workspaces/crucible-development";
        var reposJsonPath = Path.Combine(workspaceRoot, "scripts", "repos.json");
        var reposLocalJsonPath = Path.Combine(workspaceRoot, "scripts", "repos.local.json");

        if (!File.Exists(reposJsonPath))
        {
            Console.WriteLine($"Warning: {reposJsonPath} not found. No Moodle plugins will be loaded.");
            return plugins;
        }

        try
        {
            // Read and parse repos.json
            var reposJson = File.ReadAllText(reposJsonPath);
            var reposDoc = System.Text.Json.JsonDocument.Parse(reposJson);

            // Read and parse repos.local.json if it exists
            System.Text.Json.JsonDocument? reposLocalDoc = null;
            if (File.Exists(reposLocalJsonPath))
            {
                Console.WriteLine("Found repos.local.json, merging with repos.json...");
                var reposLocalJson = File.ReadAllText(reposLocalJsonPath);
                reposLocalDoc = System.Text.Json.JsonDocument.Parse(reposLocalJson);
            }

            // Process groups from both files
            var moodleBasePath = "/mnt/data/crucible/moodle";

            ProcessReposDocument(reposDoc, plugins, moodleBasePath, webRoot);
            if (reposLocalDoc != null)
            {
                ProcessReposDocument(reposLocalDoc, plugins, moodleBasePath, webRoot);
            }

            Console.WriteLine($"Loaded {plugins.Count} Moodle plugin(s) from repos.json{(reposLocalDoc != null ? " + repos.local.json" : "")}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error reading Moodle plugins from repos.json: {ex.Message}");
        }

        return plugins;
    }

    private static void ProcessReposDocument(System.Text.Json.JsonDocument doc, List<MoodlePlugin> plugins, string moodleBasePath, string webRoot)
    {
        if (!doc.RootElement.TryGetProperty("groups", out var groups))
            return;

        foreach (var group in groups.EnumerateArray())
        {
            if (!group.TryGetProperty("name", out var groupName) || groupName.GetString() != "moodle")
                continue;

            if (!group.TryGetProperty("repos", out var repos))
                continue;

            foreach (var repo in repos.EnumerateArray())
            {
                if (!repo.TryGetProperty("name", out var nameProperty))
                    continue;

                var pluginName = nameProperty.GetString();
                if (string.IsNullOrEmpty(pluginName))
                    continue;

                // Skip if already added (repos.local.json takes precedence)
                if (plugins.Any(p => p.Name == pluginName))
                    continue;

                var plugin = new MoodlePlugin
                {
                    Name = pluginName,
                    HostPath = MapPluginToHostPath(pluginName, moodleBasePath),
                    ContainerPath = MapPluginToContainerPath(pluginName, webRoot)
                };

                plugins.Add(plugin);
            }
        }
    }
}
