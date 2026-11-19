// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using Microsoft.Extensions.Configuration;
using Crucible.AppHost;
using System.Diagnostics;
using Aspire.Hosting.Dotnet;
using Aspire.Hosting.JavaScript;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

var builder = DistributedApplication.CreateBuilder(args);


LaunchOptions launchOptions = builder.Configuration.GetSection("Launch").Get<LaunchOptions>() ?? new();

LogLaunchOptions(launchOptions);

var postgres = builder.AddPostgres(launchOptions);
var keycloak = builder.AddKeycloak(postgres);
var commonUiDev = builder.AddCommonUIDev(launchOptions);
builder.SetSharedLandingBackgroundImage(launchOptions);

builder.AddPlayer(postgres, keycloak, launchOptions, commonUiDev);
builder.AddCaster(postgres, keycloak, launchOptions, commonUiDev);
builder.AddAlloy(postgres, keycloak, launchOptions, commonUiDev);
builder.AddTopoMojo(postgres, keycloak, launchOptions);
builder.AddSteamfitter(postgres, keycloak, launchOptions, commonUiDev);
builder.AddCite(postgres, keycloak, launchOptions, commonUiDev);
builder.AddGallery(postgres, keycloak, launchOptions, commonUiDev);
builder.AddBlueprint(postgres, keycloak, launchOptions, commonUiDev);
builder.AddGameboard(postgres, keycloak, launchOptions);
builder.AddMoodle(postgres, keycloak, launchOptions);
builder.AddLrsql(postgres, keycloak, launchOptions);
builder.AddMisp(postgres, keycloak, launchOptions);
builder.AddSuperset(postgres, keycloak, launchOptions);
builder.AddCatapult(postgres, keycloak, launchOptions);
builder.AddRangerAI(keycloak, launchOptions);
builder.AddDocs(launchOptions);

builder.Build().Run();

static void LogLaunchOptions(LaunchOptions launchOptions)
{
    Console.WriteLine($"LaunchOptions:");
    Console.WriteLine($"  Player: {launchOptions.Player}, Caster: {launchOptions.Caster}, Alloy: {launchOptions.Alloy}");
    Console.WriteLine($"  Gallery: {launchOptions.Gallery}, Cite: {launchOptions.Cite}");
    Console.WriteLine($"  Blueprint: {launchOptions.Blueprint}, Steamfitter: {launchOptions.Steamfitter}");
    Console.WriteLine($"  Moodle: {launchOptions.Moodle}, Moodle52: {launchOptions.Moodle52}, Moodle53: {launchOptions.Moodle53}, Lrsql: {launchOptions.Lrsql}, Misp: {launchOptions.Misp}, Catapult: {launchOptions.Catapult}");
    Console.WriteLine($"  TopoMojo: {launchOptions.TopoMojo}, TopoMojo Launchpoint: {launchOptions.TopoMojoLaunchpoint}, Gameboard: {launchOptions.Gameboard}, RangerAI: {launchOptions.RangerAI}, RangerAIKeycloak: {launchOptions.RangerAIKeycloak}");
    Console.WriteLine($"  PGAdmin: {launchOptions.PGAdmin}, Docs: {launchOptions.Docs}, Gitea: {launchOptions.Gitea}, AddAllApplications: {launchOptions.AddAllApplications}");
    Console.WriteLine($"  DefaultUiMode: {launchOptions.DefaultUiMode}");
    Console.WriteLine($"  Prod: [{string.Join(", ", launchOptions.Prod)}]");
    Console.WriteLine($"  Dev: [{string.Join(", ", launchOptions.Dev)}]");
}

public static partial class BuilderExtensions
{
    /// <summary>
    /// Checks whether an application has an explicit dev or prod selection.
    /// </summary>
    private static bool IsEnabled(UiMode? mode)
    {
        return mode.HasValue;
    }

    /// <summary>
    /// Resolves the mode for an app based on boolean flag and Prod/Dev arrays
    /// </summary>
    /// <returns>The selected mode, or null when the application is unselected.</returns>
    private static UiMode? ResolveMode(bool flag, string appName, LaunchOptions options)
    {
        // Boolean flag takes precedence (true = dev mode)
        if (flag)
            return UiMode.Dev;

        // Check if app is in Dev array
        if (options.Dev != null && options.Dev.Contains(appName, StringComparer.OrdinalIgnoreCase))
            return UiMode.Dev;

        // Check if app is in Prod array
        if (options.Prod != null && options.Prod.Contains(appName, StringComparer.OrdinalIgnoreCase))
            return UiMode.Prod;

        return null;
    }

    /// <summary>
    /// Chooses hosting separately from whether the application is enabled for startup.
    /// </summary>
    private static UiMode ResolveUiMode(UiMode? mode, LaunchOptions options)
    {
        return mode ?? options.DefaultUiMode;
    }

    /// <summary>
    /// The URL a UI loads Launch:LandingBackgroundImage from: a URL is passed through, and a
    /// local file (e.g. a licensed image that can't be committed) is served from each UI's
    /// assets/local folder (see CopyLandingBackgroundImage).
    /// </summary>
    private static string? LandingBackgroundImageUrl(LaunchOptions options)
    {
        var image = options.LandingBackgroundImage;
        if (string.IsNullOrWhiteSpace(image))
            return null;

        if (image.StartsWith("http://") || image.StartsWith("https://"))
            return image;

        if (File.Exists(image))
            return $"/assets/local/landing-background{Path.GetExtension(image)}";

        Console.WriteLine($"Launch:LandingBackgroundImage not found: {image}");
        return null;
    }

    /// <summary>
    /// Copies a local Launch:LandingBackgroundImage file into a UI's assets/local folder. The
    /// folder ignores itself, so the copy is never committed whatever branch the UI is on.
    /// </summary>
    private static void CopyLandingBackgroundImage(LaunchOptions options, string assetsDir)
    {
        var image = options.LandingBackgroundImage;
        if (string.IsNullOrWhiteSpace(image) || !File.Exists(image))
            return;

        Directory.CreateDirectory($"{assetsDir}/local");
        File.WriteAllText($"{assetsDir}/local/.gitignore", "*\n");
        File.Copy(image, $"{assetsDir}/local/landing-background{Path.GetExtension(image)}", overwrite: true);
    }

    /// <summary>
    /// Sets AppLandingBackgroundImage in a UI's settings file, for a UI that doesn't read
    /// settings.shared.json (Gameboard).
    /// </summary>
    private static void SetLandingBackgroundImage(LaunchOptions options, string assetsDir, string settingsPath)
    {
        var url = LandingBackgroundImageUrl(options);
        if (url == null)
            return;

        CopyLandingBackgroundImage(options, assetsDir);
        var settings = System.Text.Json.Nodes.JsonNode.Parse(File.ReadAllText(settingsPath))!;
        settings["AppLandingBackgroundImage"] = url;
        File.WriteAllText(settingsPath, settings.ToJsonString(new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
    }

    /// <summary>
    /// The local settings.shared.json symlinked into the crucible-common UIs, created from the
    /// template on first launch.
    /// </summary>
    private static string SharedUiSettingsPath(IDistributedApplicationBuilder builder)
    {
        var sharedLocal = $"{builder.AppHostDirectory}/resources/ui/settings.shared.json";
        if (!File.Exists(sharedLocal))
        {
            File.Copy($"{builder.AppHostDirectory}/resources/ui/settings.shared.json.template", sharedLocal);
        }
        return sharedLocal;
    }

    /// <summary>
    /// Sets AppLandingBackgroundImage in settings.shared.json from Launch:LandingBackgroundImage,
    /// once for all the crucible-common UIs. With the option empty the file is left alone, so a
    /// value set there by hand stays.
    /// </summary>
    public static void SetSharedLandingBackgroundImage(this IDistributedApplicationBuilder builder, LaunchOptions options)
    {
        var url = LandingBackgroundImageUrl(options);
        if (url == null)
            return;

        var sharedLocal = SharedUiSettingsPath(builder);
        var settings = System.Text.Json.Nodes.JsonNode.Parse(File.ReadAllText(sharedLocal))!;
        settings["AppLandingBackgroundImage"] = url;
        File.WriteAllText(sharedLocal, settings.ToJsonString(new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
    }

    /// <summary>
    /// Adds an Angular UI with dev mode (ng serve) or production mode (build + serve)
    /// </summary>
    private static IResourceBuilder<ExecutableResource> AddAngularUI(
        this IDistributedApplicationBuilder builder,
        string name,
        string app,
        string appRoot,
        int port,
        UiMode? mode,
        LaunchOptions options,
        string distPath = "dist",
        string buildArgs = "",
        IResourceBuilder<ExecutableResource>? commonUiSetup = null,
        string? settingsConfigDir = "src/assets/config")
    {
        if (settingsConfigDir != null)
        {
            var sharedLocal = SharedUiSettingsPath(builder);

            var sharedTarget = $"{appRoot}/{settingsConfigDir}/settings.shared.json";
            File.Delete(sharedTarget);
            File.CreateSymbolicLink(sharedTarget, sharedLocal);
        }

        IResourceBuilder<ExecutableResource> ui;

        if (ResolveUiMode(mode, options) == UiMode.Dev)
        {
            ui = builder.AddJavaScriptApp(name, appRoot, "start");

            var installerResource = builder.Resources.OfType<JavaScriptInstallerResource>()
                .FirstOrDefault(r => r.Name == $"{name}-installer");
            if (installerResource != null)
            {
                builder.CreateResourceBuilder(installerResource).WithTags(app, "tooling");
            }

            if (options.UseAspireProxy)
            {
                ui = ui
                    .WithHttpEndpoint(port: port, isProxied: true)
                    .WithArgs(ctx =>
                    {
                        if (ctx.Resource is IResourceWithEndpoints resourceWithEndpoints)
                        {
                            var endpoint = resourceWithEndpoints.GetEndpoint("http");
                            ctx.Args.Add("--");
                            if (commonUiSetup != null)
                            {
                                ctx.Args.Add("--configuration");
                                ctx.Args.Add("localNPM");
                            }
                            ctx.Args.Add("--port");
                            ctx.Args.Add(endpoint.Property(EndpointProperty.TargetPort));
                        }
                    });
            }
            else
            {
                ui = ui.WithHttpEndpoint(port: port, isProxied: false);
                if (commonUiSetup != null)
                {
                    ui = ui.WithArgs("--", "--configuration", "localNPM");
                }
            }

            // Set up local common UI library: copy tsconfig.local-npm.json and use --configuration localNPM
            if (commonUiSetup != null)
            {
                if (installerResource != null)
                {
                    var setupLocal = builder.AddExecutable($"{name}-setup-local", "bash", appRoot, [
                        "-c",
                        $"npm link @cmusei/crucible-common && cp {builder.AppHostDirectory}/resources/tsconfig.local-npm.json ."
                    ])
                    .WithParentRelationship(installerResource)
                    .WithTags(app, "tooling");

                    setupLocal.Resource.Annotations.Add(new WaitAnnotation(installerResource, WaitType.WaitForCompletion));
                    setupLocal.WaitFor(commonUiSetup);
                    ui.WaitForCompletion(setupLocal);
                }
            }
        }
        else
        {
            var buildCommand = string.IsNullOrEmpty(buildArgs) ? "npm run build" : $"npm run build {buildArgs}";
            var serveProd = $"if [ ! -d {distPath} ] || [ -z \"$(ls -A {distPath} 2>/dev/null)\" ] || [ -n \"$(find src -newer {distPath} -print -quit)\" ]; then npm install && {buildCommand}; fi; echo '{{\"cleanUrls\":false,\"rewrites\":[{{\"source\":\"**\",\"destination\":\"/index.html\"}}]}}' > {distPath}/serve.json && npx serve -c serve.json {distPath} -l {port}";
            ui = builder.AddExecutable(name, "bash", appRoot, "-c", serveProd)
                .WithHttpEndpoint(port: port, isProxied: false);
        }

        return ui.WithHttpHealthCheck()
            .WithTags(app, "ui");
    }

    public static IResourceBuilder<PostgresServerResource> AddPostgres(this IDistributedApplicationBuilder builder, LaunchOptions options)
    {
        var pgAdminMode = ResolveMode(options.PGAdmin, "PGAdmin", options);

        var postgres = builder.AddPostgres("postgres")
            .WithTags("shared", "database")
            // AddPostgres defaults to version 18. Postgres 18 changed the data layout.
            // Consult https://aspire.dev/whats-new/aspire-13-4/#postgresql-default-image-bumped-to-183-breaking-existing-data-volumes
            // when changing this tag to 18+ to avoid data loss.
            .WithImageTag("17.6")
            .WithDataVolume()
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("crucible-postgres")
            .WithEndpoint("tcp", endpoint =>
            {
                endpoint.IsProxied = false; // so tools (e.g. dotnet ef migrations) can connect to db when apphost is off
            });

        // Always registered so it can be started from the dashboard; only auto-starts when enabled
        postgres.WithPgAdmin(pgAdmin =>
        {
            pgAdmin.WithEndpoint("http", endpoint =>
            {
                endpoint.Port = 33000;
                endpoint.IsProxied = false;
            });
            pgAdmin.WithLifetime(ContainerLifetime.Persistent)
                .WithTags("shared", "tooling");

            if (!IsEnabled(pgAdminMode))
            {
                pgAdmin.WithExplicitStart();
            }
        });

        return postgres;
    }

    public static void AddDocs(this IDistributedApplicationBuilder builder, LaunchOptions options)
    {
        var docsMode = ResolveMode(options.Docs, "Docs", options);

        if (!options.AddAllApplications && !IsEnabled(docsMode))
            return;

        var docs = builder.AddContainer("mkdocs", "squidfunk/mkdocs-material")
            .WithBindMount("/mnt/data/crucible/crucible-docs", "/docs", isReadOnly: true)
            .WithHttpEndpoint(port: 8000, targetPort: 8000)
            .WithArgs("serve", "-a", "0.0.0.0:8000")
            .WithTags("docs", "service");

        if (!IsEnabled(docsMode))
        {
            docs.WithExplicitStart();
        }
    }

    public static IResourceBuilder<KeycloakResource> AddKeycloak(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres)
    {
        var keycloakDb = postgres.AddDatabase("keycloakDb", "keycloak")
            .WithTags("shared", "database");

        var keycloak = builder.AddKeycloak("keycloak", 8443)
            .WithTags("shared", "service")
            .WithReference(keycloakDb)
            .WaitFor(keycloakDb)
            .WithLifetime(ContainerLifetime.Persistent)
            // Configure environment variables for the PostgreSQL connection
            .WithEnvironment("KC_DB", "postgres")
            .WithEnvironment("KC_DB_URL_HOST", postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("KC_DB_USERNAME", postgres.Resource.UserNameReference)
            .WithEnvironment("KC_DB_PASSWORD", postgres.Resource.PasswordParameter)
            .WithEnvironment("KC_HOSTNAME", "localhost")
            .WithEnvironment("KC_HTTPS_PORT", "8443")
            .WithEnvironment("KC_HOSTNAME_STRICT", "false")
            .WithEnvironment("KC_HOSTNAME_STRICT_BACKCHANNEL", "false")
            .WithEnvironment("KC_BOOTSTRAP_ADMIN_PASSWORD", "admin")
            // Limit Java heap to reduce memory usage (from ~636MB to ~400MB)
            .WithEnvironment("JAVA_OPTS", "-Xms256m -Xmx384m")
            // Creates the realm with the seed users' fixed IDs on an empty database; skipped once the
            // realm exists. keycloak-config applies the rest of the file. See KeycloakRealmBootstrap.
            .WithRealmImport(KeycloakRealmBootstrap.Write(
                $"{builder.AppHostDirectory}/resources/crucible-realm.json",
                $"{builder.AppHostDirectory}/obj/keycloak-import"));

        // Keycloak only reports healthy once crucible-realm.json is applied, so WaitFor(keycloak)
        // covers both the server and the realm, including the crucible-admin service account.
        var realmConfig = builder.AddKeycloakRealmConfig(keycloak);
        builder.Services.AddHealthChecks().AddTypeActivatedCheck<KeycloakRealmAppliedCheck>(
            "keycloak-realm-applied", realmConfig.Resource.Name);
        keycloak.WithHealthCheck("keycloak-realm-applied");

        return keycloak;
    }

    /// <summary>
    /// Applies crucible-realm.json to the live crucible realm with keycloak-config-cli. Keycloak's
    /// own realm import only ever reaches a fresh database, so on its own, changes to the file never
    /// reached existing environments; it now only creates the realm (see KeycloakRealmBootstrap).
    ///
    /// The import is skipped while the file's checksum matches the last one applied, so the file
    /// only overwrites conflicting manual edits when the file itself changes. Remote state limits
    /// deletions to resources this tool created and the file later dropped, so clients, users,
    /// roles and groups added by hand survive.
    ///
    /// Replace with Aspire's own support once https://github.com/microsoft/aspire/issues/19693 ships.
    /// </summary>
    private static IResourceBuilder<ContainerResource> AddKeycloakRealmConfig(this IDistributedApplicationBuilder builder, IResourceBuilder<KeycloakResource> keycloak)
    {
        // The 26.6 Keycloak image has no matching build; the newest 26.x client is used.
        return builder.AddContainer("keycloak-config", "adorsys/keycloak-config-cli", "6.5.1-26.5.5")
            .WithParentRelationship(keycloak)
            .WithTags("shared", "tooling")
            // Not WaitFor: Keycloak's health waits on this container, so that would deadlock.
            // The availability check below waits for Keycloak to answer instead.
            .WaitForStart(keycloak)
            .WithBindMount($"{builder.AppHostDirectory}/resources/crucible-realm.json", "/config/crucible-realm.json", isReadOnly: true)
            // Keycloak's plain HTTP listener (start-dev keeps it on 8080), over the container network.
            // Aspire's HTTPS endpoint uses its dev certificate, which isn't in config-cli's Java trust
            // store, and config-cli's user profile update ignores KEYCLOAK_SSLVERIFY:
            // https://github.com/adorsys/keycloak-config-cli/issues/1680
            .WithEnvironment("KEYCLOAK_URL", ReferenceExpression.Create(
                $"http://{keycloak.GetEndpoint("http").Property(EndpointProperty.Host)}:8080"))
            // KC_BOOTSTRAP_ADMIN_PASSWORD in AddKeycloak; Aspire's default bootstrap username
            .WithEnvironment("KEYCLOAK_USER", "admin")
            .WithEnvironment("KEYCLOAK_PASSWORD", "admin")
            .WithEnvironment("KEYCLOAK_AVAILABILITYCHECK_ENABLED", "true")
            .WithEnvironment("KEYCLOAK_AVAILABILITYCHECK_TIMEOUT", "300s")
            .WithEnvironment("IMPORT_FILES_LOCATIONS", "/config/crucible-realm.json");
    }

    public static void AddPlayer(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, IResourceBuilder<ExecutableResource>? commonUiSetup = null)
    {
        var playerMode = ResolveMode(options.Player, "Player", options);

        if (!options.AddAllApplications && !IsEnabled(playerMode))
            return;

        var playerDb = postgres.AddDatabase("playerDb", "player")
            .WithTags("player", "database")
            .WithDevSettings();

        const string playerApiProject = "/mnt/data/crucible/player/player.api/Player.Api/Player.Api.csproj";

        builder.ConfigureApiSecrets(
            playerApiProject,
            "cmu-sei-crucible-player-api",
            playerDb.Resource.ConnectionStringExpression);

        var playerApi = builder.AddDotnetProject("player-api", playerApiProject, project => project.LaunchProfileName = "Player.Api")
            .WithTags("player", "api")
            .WithUrl("/api", "Player Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(playerDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "player.api")
            .WithEnvironment("SeedData__ApplicationTemplates__0__Id", "ace19f19-8916-4169-84de-ad00565d8456")
            .WithEnvironment("SeedData__ApplicationTemplates__0__Name", "Virtual Machines")
            .WithEnvironment("SeedData__ApplicationTemplates__0__Url", "http://localhost:4303/views/{viewId}?{theme}")
            .WithEnvironment("SeedData__ApplicationTemplates__0__Icon", "assets/img/SP_Icon_Virtual.png")
            .WithEnvironment("SeedData__ApplicationTemplates__0__Embeddable", "true")
            .WithEnvironment("SeedData__ApplicationTemplates__1__Id", "fb7b173d-9f5b-45d2-8be2-6bab8b8b2d57")
            .WithEnvironment("SeedData__ApplicationTemplates__1__Name", "Map")
            .WithEnvironment("SeedData__ApplicationTemplates__1__Url", "http://localhost:4303/views/{viewId}/map?{theme}")
            .WithEnvironment("SeedData__ApplicationTemplates__1__Icon", "assets/img/SP_Icon_Map.png")
            .WithEnvironment("SeedData__ApplicationTemplates__1__Embeddable", "true")
            .WithEnvironment("SeedData__ApplicationTemplates__2__Id", "a4c361cc-b43f-4c44-99a7-7e2e2b3a9f88")
            .WithEnvironment("SeedData__ApplicationTemplates__2__Name", "Dashboard")
            .WithEnvironment("SeedData__ApplicationTemplates__2__Url", "http://localhost:4403/views/{viewId}")
            .WithEnvironment("SeedData__ApplicationTemplates__2__Icon", "assets/img/SP_Icon_Dashboard.png")
            .WithEnvironment("SeedData__ApplicationTemplates__2__Embeddable", "true");

        // Configure xAPI if LRS is enabled
        var lrsqlMode = ResolveMode(options.Lrsql, "Lrsql", options);
        if (IsEnabled(lrsqlMode))
        {
            ConfigureXApi(playerApi, "Player", "http://localhost:4300/api/", "http://localhost:4301/");
        }

        var playerUiRoot = "/mnt/data/crucible/player/player.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/player.ui.json", $"{playerUiRoot}/src/assets/config/settings.env.json", overwrite: true);
        CopyLandingBackgroundImage(options, $"{playerUiRoot}/src/assets");

        var playerUi = builder.AddAngularUI("player-ui", "player", playerUiRoot, port: 4301, playerMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Player UI");

        if (!IsEnabled(playerMode))
        {
            playerApi.WithExplicitStart();
            playerUi.WithExplicitStart();
        }

        builder.AddPlayerVm(postgres, keycloak, options, playerMode, lrsqlMode, commonUiSetup);
    }

    private static void AddPlayerVm(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, UiMode? playerMode, UiMode? lrsqlMode, IResourceBuilder<ExecutableResource>? commonUiSetup = null)
    {
        var vmDb = postgres.AddDatabase("vmDb", "player_vm")
            .WithTags("player", "database")
            .WithDevSettings();
        var vmLoggingDb = postgres.AddDatabase("vmLoggingDb", "player_vm_logging")
            .WithTags("player", "database")
            .WithDevSettings();

        const string vmApiProject = "/mnt/data/crucible/player/vm.api/src/Player.Vm.Api/Player.Vm.Api.csproj";

        builder.ConfigureApiSecrets(
            vmApiProject,
            "cmu-sei-crucible-vm-api",
            vmDb.Resource.ConnectionStringExpression,
            new Dictionary<string, ReferenceExpression>
            {
                ["VmUsageLogging:PostgreSQL"] = vmLoggingDb.Resource.ConnectionStringExpression
            });

        var vmApi = builder.AddDotnetProject("player-vm-api", vmApiProject, project => project.LaunchProfileName = "Player.Vm.Api")
            .WithTags("player", "api")
            .WithUrl("/api", "Player VM Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(vmDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("VmUsageLogging__Enabled", "true")
            .WithEnvironment("VmUsageLogging__PostgreSQL", vmLoggingDb.Resource.ConnectionStringExpression)
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "player.vm.api")
            .WithEnvironment("IdentityClient__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("IdentityClient__ClientId", "player.vm.admin")
            .WithEnvironment("IdentityClient__UserName", "crucible-admin")
            .WithEnvironment("IdentityClient__Password", "admin");

        vmApi.WithApiConfig(builder.AppHostDirectory, options.ApiConfig, required: IsEnabled(playerMode));

        // Configure xAPI if LRS is enabled
        if (IsEnabled(lrsqlMode))
        {
            ConfigureXApi(vmApi, "Player VM", "http://localhost:4302/api/", "http://localhost:4303/");
        }

        var vmUiRoot = "/mnt/data/crucible/player/vm.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/vm.ui.json", $"{vmUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var vmUi = builder.AddAngularUI("player-vm-ui", "player", vmUiRoot, port: 4303, playerMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Player VM UI");

        var consoleUiRoot = "/mnt/data/crucible/player/console.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/console.ui.json", $"{consoleUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var consoleUi = builder.AddAngularUI("player-vm-console-ui", "player", consoleUiRoot, port: 4305, playerMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Player Console UI");

        if (!IsEnabled(playerMode))
        {
            vmApi.WithExplicitStart();
            vmUi.WithExplicitStart();
            consoleUi.WithExplicitStart();
        }
    }

    public static void AddCaster(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, IResourceBuilder<ExecutableResource>? commonUiSetup = null)
    {
        var casterMode = ResolveMode(options.Caster, "Caster", options);

        if (!options.AddAllApplications && !IsEnabled(casterMode))
            return;

        var casterDb = postgres.AddDatabase("casterDb", "caster")
            .WithTags("caster", "database")
            .WithDevSettings();

        const string casterApiProject = "/mnt/data/crucible/caster/caster.api/src/Caster.Api/Caster.Api.csproj";

        builder.ConfigureApiSecrets(
            casterApiProject,
            "cmu-sei-crucible-caster-api",
            casterDb.Resource.ConnectionStringExpression);

        var minikubeStart = builder.AddExecutable("minikube", "bash", $"{builder.AppHostDirectory}/../minikube/", [
            "-c",
            "./start-minikube.sh"
        ])
        .WithTags("caster", "service");

        var minikubeStop = builder.AddExecutable("stop-minikube", "minikube", "",
        [
            "stop",
        ])
        .WithExplicitStart()
        .WithParentRelationship(minikubeStart)
        .WithTags("caster", "tooling");

        var minikubeDelete = builder.AddExecutable("delete-minikube", "minikube", "",
        [
            "delete",
        ])
        .WithExplicitStart()
        .WithParentRelationship(minikubeStart)
        .WithTags("caster", "tooling");

        var casterApi = builder.AddDotnetProject("caster-api", casterApiProject, project => project.LaunchProfileName = "Caster.Api")
            .WithTags("caster", "api")
            .WithUrl("/api", "Caster Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WaitForCompletion(minikubeStart)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(casterDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "caster.api")
            .WithEnvironment("Terraform__RootWorkingDirectory", "/mnt/data/terraform/root")
            .WithEnvironment("Terraform__KubernetesJobs__Enabled", "true")
            .WithEnvironment("Terraform__KubernetesJobs__UseHostVolume", "true")
            // Mount the caster-certs ConfigMap (created by minikube/start-minikube.sh) so terraform
            // in the job pod trusts custom/corporate CAs (e.g. Zscaler) when reaching registry.terraform.io.
            // terraform is a Go binary: SSL_CERT_DIR adds these dirs while the system bundle file is still loaded.
            .WithEnvironment("Terraform__KubernetesJobs__ConfigMaps__0__Name", "caster-certs")
            .WithEnvironment("Terraform__KubernetesJobs__ConfigMaps__0__MountPath", "/usr/local/share/ca-certificates")
            .WithEnvironment("Terraform__EnvironmentVariables__Direct__SSL_CERT_DIR", "/etc/ssl/certs:/usr/local/share/ca-certificates")
            .WithEnvironment("Terraform__EnvironmentVariables__Direct__TF_CLI_CONFIG_FILE", "/terraform/terraformrc");

        casterApi.WithApiConfig(builder.AppHostDirectory, options.ApiConfig, required: IsEnabled(casterMode));

        builder.AddGitea(casterApi, casterMode, options);

        var casterUiRoot = "/mnt/data/crucible/caster/caster.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/caster.ui.json", $"{casterUiRoot}/src/assets/config/settings.env.json", overwrite: true);
        CopyLandingBackgroundImage(options, $"{casterUiRoot}/src/assets");

        var casterUi = builder.AddAngularUI("caster-ui", "caster", casterUiRoot, port: 4310, casterMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Caster UI");

        if (!IsEnabled(casterMode))
        {
            casterApi.WithExplicitStart();
            casterUi.WithExplicitStart();
            minikubeStart.WithExplicitStart();
        }
    }

    /// <summary>
    /// Adds a dev Gitea as Caster's module source. Off unless Gitea is enabled.
    /// </summary>
    private static void AddGitea(this IDistributedApplicationBuilder builder, IResourceBuilder<DotnetProjectResource> casterApi, UiMode? casterMode, LaunchOptions options)
    {
        var giteaMode = ResolveMode(options.Gitea, "Gitea", options);

        if (!options.AddAllApplications && !IsEnabled(giteaMode))
            return;

        // Job pods reach the devcontainer as host.minikube.internal, so the port binds
        // on all interfaces rather than Aspire's loopback default; caster-api runs in
        // the devcontainer, where that name doesn't resolve, so git rewrites it to
        // localhost for caster-api only. Not persistent: it stops with the AppHost,
        // and the volume keeps the repository between runs.
        var gitea = builder.AddContainer("gitea", "gitea/gitea", "1.27.3")
            .WithTags("caster", "service")
            .WithVolume("crucible-dev-gitea", "/data")
            .WithHttpEndpoint(port: 3010, targetPort: 3000)
            .WithEndpoint("http", endpoint => endpoint.TargetHost = "0.0.0.0")
            .WithHttpHealthCheck(path: "/api/healthz", endpointName: "http")
            .WithEnvironment("GITEA__security__INSTALL_LOCK", "true")
            .WithEnvironment("GITEA__security__MIN_PASSWORD_LENGTH", "5")
            .WithEnvironment("GITEA__server__ROOT_URL", "http://host.minikube.internal:3010/")
            .WithEnvironment("GITEA__server__DISABLE_SSH", "true")
            .WithEnvironment("GITEA__service__DISABLE_REGISTRATION", "true")
            .WithEnvironment("GITEA__repository__DEFAULT_BRANCH", "main");

        var giteaSeed = builder.AddExecutable("gitea-seed", "bash", $"{builder.AppHostDirectory}/resources/gitea/", [
            "-c",
            "./seed-gitea.sh"
        ])
        .WaitFor(gitea)
        .WithParentRelationship(gitea)
        .WithTags("caster", "tooling")
        .WithEnvironment(async context =>
        {
            // Aspire names the container gitea-<suffix>, so the script can't docker exec
            // by resource name; pass the running container's id instead. It changes
            // whenever gitea restarts, so it's read each time the seed starts.
            // "container.id" is Aspire's KnownProperties.Container.Id, which is internal.
            static string? ContainerId(ResourceEvent e) =>
                e.Snapshot.Properties.FirstOrDefault(p => p.Name == "container.id")?.Value as string;

            var notifications = context.ExecutionContext.Services.GetRequiredService<ResourceNotificationService>();
            var giteaEvent = await notifications.WaitForResourceAsync(gitea.Resource.Name,
                e => !string.IsNullOrEmpty(ContainerId(e)), context.CancellationToken);

            context.EnvironmentVariables["GITEA_CONTAINER"] = ContainerId(giteaEvent)!;
        });

        casterApi
            .WithEnvironment("Terraform__ModuleSources__0__Name", "crucible-modules")
            .WithEnvironment("Terraform__ModuleSources__0__Url", "http://host.minikube.internal:3010/crucible/crucible-terraform-modules.git")
            .WithEnvironment("Terraform__ModuleSources__0__Layout", "Subdirectories")
            .WithEnvironment("GIT_CONFIG_COUNT", "1")
            .WithEnvironment("GIT_CONFIG_KEY_0", "url.http://localhost:3010/.insteadOf")
            .WithEnvironment("GIT_CONFIG_VALUE_0", "http://host.minikube.internal:3010/")
            // the job pods inherit caster-api's environment, rewrite and all, and in a pod localhost is the pod; the pods
            // reach Gitea as host.minikube.internal, so they take no rewrite
            .WithEnvironment("Terraform__EnvironmentVariables__Direct__GIT_CONFIG_COUNT", "0");

        if (!IsEnabled(casterMode) || !IsEnabled(giteaMode))
        {
            gitea.WithExplicitStart();
            giteaSeed.WithExplicitStart();
        }
    }

    public static void AddAlloy(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, IResourceBuilder<ExecutableResource>? commonUiSetup = null)
    {
        var alloyMode = ResolveMode(options.Alloy, "Alloy", options);

        if (!options.AddAllApplications && !IsEnabled(alloyMode))
            return;

        var alloyDb = postgres.AddDatabase("alloyDb", "alloy")
            .WithTags("alloy", "database")
            .WithDevSettings();

        const string alloyApiProject = "/mnt/data/crucible/alloy/alloy.api/Alloy.Api/Alloy.Api.csproj";

        builder.ConfigureApiSecrets(
            alloyApiProject,
            "cmu-sei-crucible-alloy-api",
            alloyDb.Resource.ConnectionStringExpression);

        var alloyApi = builder.AddDotnetProject("alloy-api", alloyApiProject, project => project.LaunchProfileName = "Alloy.Api")
            .WithTags("alloy", "api")
            .WithUrl("/api", "Alloy Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(alloyDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "alloy.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("ResourceOwnerAuthorization__ClientId", "alloy.admin")
            .WithEnvironment("ResourceOwnerAuthorization__ClientSecret", "gn3D1s0UKCeqUB5ZjtN0aZsStiJjecRW")
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "crucible-admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "player player-vm alloy steamfitter caster")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false")
            .WithEnvironment("CorsPolicy__Origins__0", "http://localhost:4403") // for alloy-ui
            .WithEnvironment("CorsPolicy__Origins__1", "http://localhost:8081") // for moodle
            .WithEnvironment("CorsPolicy__Origins__2", "http://localhost:8082") // for moodle52
            .WithEnvironment("CorsPolicy__Origins__3", "http://localhost:8083"); // for moodle53

        var alloyUiRoot = "/mnt/data/crucible/alloy/alloy.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/alloy.ui.json", $"{alloyUiRoot}/src/assets/config/settings.env.json", overwrite: true);
        CopyLandingBackgroundImage(options, $"{alloyUiRoot}/src/assets");

        var alloyUi = builder.AddAngularUI("alloy-ui", "alloy", alloyUiRoot, port: 4403, alloyMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Alloy UI");

        if (!IsEnabled(alloyMode))
        {
            alloyApi.WithExplicitStart();
            alloyUi.WithExplicitStart();
        }
    }

    public static void AddTopoMojo(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var configuredTopoMojoMode = ResolveMode(options.TopoMojo, "TopoMojo", options);
        var launchpointMode = ResolveMode(options.TopoMojoLaunchpoint, "TopoMojoLaunchpoint", options);
        var topoMojoMode = IsEnabled(configuredTopoMojoMode)
            ? configuredTopoMojoMode
            : launchpointMode;
        var launchpointIncluded = IsEnabled(launchpointMode) || options.AddAllApplications;
        var topoUiMode = ResolveUiMode(topoMojoMode, options);
        // An unselected Launchpoint starts with a selected TopoMojo, so keep it static rather than
        // applying DefaultUiMode; DefaultUiMode only covers it when TopoMojo is also left stopped.
        var effectiveLaunchpointMode = launchpointMode
            ?? (IsEnabled(topoMojoMode) ? UiMode.Prod : options.DefaultUiMode);

        if (!options.AddAllApplications && !IsEnabled(topoMojoMode))
            return;

        var topoDb = postgres.AddDatabase("topoDb", "topomojo")
            .WithTags("topomojo", "database")
            .WithDevSettings();

        const string topoApiProject = "/mnt/data/crucible/topomojo/topomojo/src/TopoMojo.Api/TopoMojo.Api.csproj";

        builder.ConfigureApiSecrets(
            topoApiProject,
            "cmu-sei-crucible-topomojo-api",
            topoDb.Resource.ConnectionStringExpression);

        var topoApi = builder.AddDotnetProject("topomojo", topoApiProject)
            .WithTags("topomojo", "api")
            .WithUrl("/api", "TopoMojo Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithReference(topoDb, "PostgreSQL")
            .WithEnvironment("Database__ConnectionString", topoDb.Resource.ConnectionStringExpression)
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Oidc__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Oidc__Audience", "topomojo")
            // TopoMojo's default map only matches lowercase "administrator", but Keycloak sends
            // "Administrator". Without this the realm admin is a plain user whenever another
            // account (e.g. the Moodle service account) took the first-user Administrator slot.
            .WithEnvironment("Oidc__UserRolesClaimMap__Administrator", "Administrator")
            .WithEnvironment("OpenApi__Client__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("OpenApi__Client__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("OpenApi__Client__ClientId", "topomojo.api")
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("Headers__Cors__Origins__0", "http://localhost:4201") // for topo-ui
            .WithEnvironment("Headers__Cors__Origins__1", "http://localhost:8081") // for moodle
            .WithEnvironment("Headers__Cors__Origins__2", "http://localhost:8082") // for moodle52
            .WithEnvironment("Headers__Cors__Origins__3", "http://localhost:8083") // for moodle53
            .WithEnvironment("Headers__Cors__Methods__0", "*")
            .WithEnvironment("Headers__Cors__Headers__0", "*")
            .WithEnvironment("Headers__Cors__AllowCredentials", "true");
        // Load the selected profile after TopoMojo's own .conf files so it wins.
        topoApi.WithApiConfig(builder.AppHostDirectory, options.ApiConfig,
            configPathEnvironmentVariable: "APPSETTINGS_PATH", required: IsEnabled(topoMojoMode));

        var topoUiRoot = "/mnt/data/crucible/topomojo/topomojo-ui/";
        const int topoWorkUiPort = 4201;
        const int topoLaunchpointUiPort = 4204;
        var topoLaunchpointUiUrl = $"http://localhost:{topoLaunchpointUiPort}";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/topomojo.ui.json", $"{topoUiRoot}/projects/topomojo-work/src/assets/settings.json", overwrite: true);

        if (launchpointIncluded)
        {
            topoApi = topoApi
                .WithEnvironment("Headers__Cors__Origins__2", topoLaunchpointUiUrl)
                .WithEnvironment("Core__LaunchUrl", topoLaunchpointUiUrl);
        }

        IResourceBuilder<ExecutableResource> topoUi;
        IResourceBuilder<ExecutableResource>? topoLaunchpointUi = null;

        if (topoUiMode == UiMode.Dev)
        {
            topoUi = builder.AddJavaScriptApp("topomojo-ui", topoUiRoot, "start")
                .WithArgs("--", "topomojo-work", "--configuration", "development", "--port", topoWorkUiPort.ToString())
                .WithHttpEndpoint(port: topoWorkUiPort, isProxied: false)
                .WithHttpHealthCheck();

            var topoUiInstaller = builder.Resources.OfType<JavaScriptInstallerResource>()
                .FirstOrDefault(r => r.Name == "topomojo-ui-installer");
            if (topoUiInstaller != null)
            {
                builder.CreateResourceBuilder(topoUiInstaller).WithTags("topomojo", "tooling");
            }

            if (launchpointIncluded && effectiveLaunchpointMode == UiMode.Dev)
            {
                topoLaunchpointUi = builder.AddJavaScriptApp("topomojo-launchpoint", topoUiRoot, "start")
                    .WithNpm(install: false)
                    .WithArgs("--", "topomojo-launchpoint", "--configuration", "development", "--port", topoLaunchpointUiPort.ToString())
                    .WithHttpEndpoint(port: topoLaunchpointUiPort, isProxied: false)
                    .WithHttpHealthCheck()
                    .WaitFor(topoUi);
            }
            else if (launchpointIncluded)
            {
                // The development build contains the local API and console URL settings needed when serving the app statically.
                topoLaunchpointUi = builder.AddExecutable(
                    "topomojo-launchpoint",
                    "bash",
                    topoUiRoot,
                    "-c",
                    $"npm run build -- topomojo-launchpoint --configuration development && npx serve -s dist/topomojo-launchpoint/browser -l {topoLaunchpointUiPort}")
                    .WithHttpEndpoint(port: topoLaunchpointUiPort, isProxied: false)
                    .WithHttpHealthCheck()
                    .WaitFor(topoUi);
            }
        }
        else
        {
            const string topoWorkDistPath = "dist/topomojo-work/browser";
            const string topoLaunchpointDistPath = "dist/topomojo-launchpoint/browser";

            // Development configuration is required for the local API and console URLs; serve its build statically to avoid Angular dev servers.
            var builds = new List<string>
            {
                "npm run build -- topomojo-work --configuration development"
            };

            if (launchpointIncluded && effectiveLaunchpointMode != UiMode.Dev)
            {
                builds.Add("npm run build -- topomojo-launchpoint --configuration development");
            }

            var serveTopoUi =
                $"npm install && {string.Join(" && ", builds)} && " +
                $"npx serve -s {topoWorkDistPath} -l {topoWorkUiPort}";

            topoUi = builder.AddExecutable("topomojo-ui", "bash", topoUiRoot, "-c", serveTopoUi)
                .WithHttpEndpoint(port: topoWorkUiPort, isProxied: false)
                .WithHttpHealthCheck();

            if (launchpointIncluded && effectiveLaunchpointMode == UiMode.Dev)
            {
                topoLaunchpointUi = builder.AddJavaScriptApp("topomojo-launchpoint", topoUiRoot, "start")
                    .WithNpm(install: false)
                    .WithArgs("--", "topomojo-launchpoint", "--configuration", "development", "--port", topoLaunchpointUiPort.ToString())
                    .WithHttpEndpoint(port: topoLaunchpointUiPort, isProxied: false)
                    .WithHttpHealthCheck()
                    .WaitFor(topoUi);
            }
            else if (launchpointIncluded)
            {
                topoLaunchpointUi = builder.AddExecutable(
                    "topomojo-launchpoint",
                    "npx",
                    topoUiRoot,
                    "serve",
                    "-s",
                    topoLaunchpointDistPath,
                    "-l",
                    topoLaunchpointUiPort.ToString())
                    .WithHttpEndpoint(port: topoLaunchpointUiPort, isProxied: false)
                    .WithHttpHealthCheck()
                    .WaitFor(topoUi);
            }
        }

        topoUi.WithTags("topomojo", "ui")
            .WithUrlForEndpoint("http", url => url.DisplayText = "TopoMojo UI");
        topoLaunchpointUi?.WithTags("topomojo", "ui")
            .WithUrlForEndpoint("http", url => url.DisplayText = "TopoMojo Launchpoint UI");

        if (!IsEnabled(topoMojoMode))
        {
            topoApi.WithExplicitStart();
            topoUi.WithExplicitStart();
            topoLaunchpointUi?.WithExplicitStart();
        }
    }

    public static void AddSteamfitter(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, IResourceBuilder<ExecutableResource>? commonUiSetup = null)
    {
        var steamfitterMode = ResolveMode(options.Steamfitter, "Steamfitter", options);
        var lrsqlMode = ResolveMode(options.Lrsql, "Lrsql", options);

        if (!options.AddAllApplications && !IsEnabled(steamfitterMode))
            return;

        var steamfitterDb = postgres.AddDatabase("steamfitterDb", "steamfitter")
            .WithTags("steamfitter", "database")
            .WithDevSettings();

        const string steamfitterApiProject = "/mnt/data/crucible/steamfitter/steamfitter.api/Steamfitter.Api/Steamfitter.Api.csproj";

        builder.ConfigureApiSecrets(
            steamfitterApiProject,
            "cmu-sei-crucible-steamfitter-api",
            steamfitterDb.Resource.ConnectionStringExpression);

        var steamfitterApi = builder.AddDotnetProject("steamfitter-api", steamfitterApiProject, project => project.LaunchProfileName = "Steamfitter.Api")
            .WithTags("steamfitter", "api")
            .WithUrl("/api", "Steamfitter Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(steamfitterDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__AuthorizationScope", "steamfitter player player-vm")
            .WithEnvironment("Authorization__ClientId", "steamfitter.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("ResourceOwnerAuthorization__ClientId", "steamfitter.admin")
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "crucible-admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "steamfitter player player-vm cite gallery")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        // Configure xAPI if LRS is enabled
        if (IsEnabled(lrsqlMode))
        {
            ConfigureXApi(steamfitterApi, "steamfitter", "http://localhost:4400/api/", "http://localhost:4401/");
        }

        var steamfitterUiRoot = "/mnt/data/crucible/steamfitter/steamfitter.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/steamfitter.ui.json", $"{steamfitterUiRoot}/src/assets/config/settings.env.json", overwrite: true);
        CopyLandingBackgroundImage(options, $"{steamfitterUiRoot}/src/assets");

        var steamfitterUi = builder.AddAngularUI("steamfitter-ui", "steamfitter", steamfitterUiRoot, port: 4401, steamfitterMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Steamfitter UI");

        if (!IsEnabled(steamfitterMode))
        {
            steamfitterApi.WithExplicitStart();
            steamfitterUi.WithExplicitStart();
        }
    }

    public static void AddCite(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, IResourceBuilder<ExecutableResource>? commonUiSetup = null)
    {
        var citeMode = ResolveMode(options.Cite, "Cite", options);
        var lrsqlMode = ResolveMode(options.Lrsql, "Lrsql", options);

        if (!options.AddAllApplications && !IsEnabled(citeMode))
            return;

        var citeDb = postgres.AddDatabase("citeDb", "cite")
            .WithTags("cite", "database")
            .WithDevSettings();

        const string citeApiProject = "/mnt/data/crucible/cite/cite.api/Cite.Api/Cite.Api.csproj";

        builder.ConfigureApiSecrets(
            citeApiProject,
            "cmu-sei-crucible-cite-api",
            citeDb.Resource.ConnectionStringExpression);

        var citeApi = builder.AddDotnetProject("cite-api", citeApiProject, project => project.LaunchProfileName = "Cite.Api")
            .WithTags("cite", "api")
            .WithUrl("/api", "CITE Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(citeDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__AuthorizationScope", "cite")
            .WithEnvironment("Authorization__ClientId", "cite.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("ResourceOwnerAuthorization__ClientId", "cite.admin")
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "crucible-admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "openid profile email gallery")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        // Configure xAPI if LRS is enabled
        if (IsEnabled(lrsqlMode))
        {
            ConfigureXApi(citeApi, "cite", "http://localhost:4720/api/", "http://localhost:4721/");
        }

        var citeUiRoot = "/mnt/data/crucible/cite/cite.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/cite.ui.json", $"{citeUiRoot}/src/assets/config/settings.env.json", overwrite: true);
        CopyLandingBackgroundImage(options, $"{citeUiRoot}/src/assets");

        var citeUi = builder.AddAngularUI("cite-ui", "cite", citeUiRoot, port: 4721, citeMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "CITE UI");

        if (!IsEnabled(citeMode))
        {
            citeApi.WithExplicitStart();
            citeUi.WithExplicitStart();
        }
    }

    public static void AddGallery(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, IResourceBuilder<ExecutableResource>? commonUiSetup = null)
    {
        var galleryMode = ResolveMode(options.Gallery, "Gallery", options);
        var lrsqlMode = ResolveMode(options.Lrsql, "Lrsql", options);

        if (!options.AddAllApplications && !IsEnabled(galleryMode))
            return;

        var galleryDb = postgres.AddDatabase("galleryDb", "gallery")
            .WithTags("gallery", "database")
            .WithDevSettings();

        const string galleryApiProject = "/mnt/data/crucible/gallery/gallery.api/Gallery.Api/Gallery.Api.csproj";

        builder.ConfigureApiSecrets(
            galleryApiProject,
            "cmu-sei-crucible-gallery-api",
            galleryDb.Resource.ConnectionStringExpression);

        var galleryApi = builder.AddDotnetProject("gallery-api", galleryApiProject, project => project.LaunchProfileName = "Api")
            .WithTags("gallery", "api")
            .WithUrl("/api", "Gallery Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(galleryDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__AuthorizationScope", "gallery")
            .WithEnvironment("Authorization__ClientId", "gallery.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("ResourceOwnerAuthorization__ClientId", "gallery.admin")
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "crucible-admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "player player-vm steamfitter")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        // Configure xAPI if LRS is enabled
        if (IsEnabled(lrsqlMode))
        {
            ConfigureXApi(galleryApi, "gallery", "http://localhost:4722/api/", "http://localhost:4723/");
        }

        var galleryUiRoot = "/mnt/data/crucible/gallery/gallery.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/gallery.ui.json", $"{galleryUiRoot}/src/assets/config/settings.env.json", overwrite: true);
        CopyLandingBackgroundImage(options, $"{galleryUiRoot}/src/assets");

        var galleryUi = builder.AddAngularUI("gallery-ui", "gallery", galleryUiRoot, port: 4723, galleryMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Gallery UI");

        if (!IsEnabled(galleryMode))
        {
            galleryApi.WithExplicitStart();
            galleryUi.WithExplicitStart();
        }
    }

    public static void AddBlueprint(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, IResourceBuilder<ExecutableResource>? commonUiSetup = null)
    {
        var blueprintMode = ResolveMode(options.Blueprint, "Blueprint", options);
        var lrsqlMode = ResolveMode(options.Lrsql, "Lrsql", options);

        if (!options.AddAllApplications && !IsEnabled(blueprintMode))
            return;

        var blueprintDb = postgres.AddDatabase("blueprintDb", "blueprint")
            .WithTags("blueprint", "database")
            .WithDevSettings();

        const string blueprintApiProject = "/mnt/data/crucible/blueprint/blueprint.api/Blueprint.Api/Blueprint.Api.csproj";

        builder.ConfigureApiSecrets(
            blueprintApiProject,
            "cmu-sei-crucible-blueprint-api",
            blueprintDb.Resource.ConnectionStringExpression);

        var blueprintApi = builder.AddDotnetProject("blueprint-api", blueprintApiProject, project => project.LaunchProfileName = "Blueprint.Api")
            .WithTags("blueprint", "api")
            .WithUrl("/api", "Blueprint Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(blueprintDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "blueprint.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("ResourceOwnerAuthorization__ClientId", "blueprint.admin")
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "crucible-admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "player player-vm gallery steamfitter cite caster")
            .WithEnvironment("ClientSettings__CasterApiUrl", "http://localhost:4309/")
            .WithEnvironment("ClientSettings__CasterUiUrl", "http://localhost:4310")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        if (IsEnabled(lrsqlMode))
        {
            ConfigureXApi(blueprintApi, "blueprint", "http://localhost:4724/api/", "http://localhost:4725/");
        }

        var blueprintUiRoot = "/mnt/data/crucible/blueprint/blueprint.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/blueprint.ui.json", $"{blueprintUiRoot}/src/assets/config/settings.env.json", overwrite: true);
        CopyLandingBackgroundImage(options, $"{blueprintUiRoot}/src/assets");

        var blueprintUi = builder.AddAngularUI("blueprint-ui", "blueprint", blueprintUiRoot, port: 4725, blueprintMode, options, distPath: "dist/browser", commonUiSetup: commonUiSetup)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Blueprint UI");

        if (!IsEnabled(blueprintMode))
        {
            blueprintApi.WithExplicitStart();
            blueprintUi.WithExplicitStart();
        }
    }

    public static void AddGameboard(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var gameboardMode = ResolveMode(options.Gameboard, "Gameboard", options);

        if (!options.AddAllApplications && !IsEnabled(gameboardMode))
            return;

        var gameboardDb = postgres.AddDatabase("gameboardDb", "gameboard")
            .WithTags("gameboard", "database")
            .WithDevSettings();

        const string gameboardApiProject = "/mnt/data/crucible/gameboard/gameboard/src/Gameboard.Api/Gameboard.Api.csproj";

        builder.ConfigureApiSecrets(
            gameboardApiProject,
            "cmu-sei-crucible-gameboard-api",
            gameboardDb.Resource.ConnectionStringExpression);

        var gameboardApi = builder.AddDotnetProject("gameboard", gameboardApiProject, project => project.LaunchProfileName = "Project")
            .WithTags("gameboard", "api")
            .WithUrl("/api", "Gameboard Swagger UI")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithReference(gameboardDb, "PostgreSQL")
            .WithEnvironment("Database__ConnectionString", gameboardDb.Resource.ConnectionStringExpression)
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("PathBase", "")
            .WithEnvironment("Oidc__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Oidc__Audience", "gameboard")
            .WithEnvironment("OpenApi__Client__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("OpenApi__Client__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("OpenApi__Client__ClientId", "gameboard.api")
            .WithEnvironment("OpenApi__Enabled", "true")
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("Core__GameEngineUrl", "http://localhost:5000/api")
            .WithEnvironment("Core__ChallengeDocUrl", "http://localhost:5000/api")
            .WithEnvironment("GameEngine__ClientId", "topomojo.api")
            .WithEnvironment("GameEngine__ClientSecret", "aoctxRpJThNs9rpNuHATBiT18afno78R")
            .WithEnvironment("Headers__Cors__Origins__0", "http://localhost:4202")
            .WithEnvironment("Headers__Cors__Methods__0", "*")
            .WithEnvironment("Headers__Cors__Headers__0", "*")
            .WithEnvironment("Headers__Cors__AllowCredentials", "true")
            .WithEnvironment("Oidc__UserRolesClaimMap__Administrator", "Admin");

        var gameboardUiRoot = "/mnt/data/crucible/gameboard/gameboard-ui/";

        File.Copy($"{builder.AppHostDirectory}/resources/ui/settings/gameboard.ui.json", $"{gameboardUiRoot}/projects/gameboard-ui/src/assets/settings.json", overwrite: true);
        SetLandingBackgroundImage(options, $"{gameboardUiRoot}/projects/gameboard-ui/src/assets", $"{gameboardUiRoot}/projects/gameboard-ui/src/assets/settings.json");

        var gameboardUi = builder.AddAngularUI("gameboard-ui", "gameboard", gameboardUiRoot, port: 4202, gameboardMode, options, distPath: "dist/gameboard-ui/browser", buildArgs: "gameboard-ui", commonUiSetup: null, settingsConfigDir: null)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Gameboard UI");

        if (!IsEnabled(gameboardMode))
        {
            gameboardApi.WithExplicitStart();
            gameboardUi.WithExplicitStart();
        }
    }

    public static void AddLrsql(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var lrsqlMode = ResolveMode(options.Lrsql, "Lrsql", options);

        if (!options.AddAllApplications && !IsEnabled(lrsqlMode))
            return;

        var lrsqlDb = postgres.AddDatabase("lrsqlDb", "lrsql")
            .WithTags("lrsql", "database");

        var lrsql = builder.AddContainer("lrsql", "yetanalytics/lrsql")
            .WithTags("lrsql", "service")
            .WaitFor(postgres)
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("lrsql")
            .WithHttpEndpoint(port: 9274, targetPort: 8080)
            .WithHttpHealthCheck(endpointName: "http")
            .WithEntrypoint("bin/run_postgres.sh")
            .WithEnvironment("LRSQL_ADMIN_USER_DEFAULT", "admin")
            .WithEnvironment("LRSQL_ADMIN_PASS_DEFAULT", "admin")
            .WithEnvironment("LRSQL_LOG_LEVEL", "INFO")
            .WithEnvironment("LRSQL_API_KEY_DEFAULT", "defaultkey")
            .WithEnvironment("LRSQL_API_SECRET_DEFAULT", "defaultsecret")
            .WithEnvironment("LRSQL_ALLOW_ALL_ORIGINS", "true")
            .WithEnvironment("LRSQL_DB_TYPE", "postgres")
            .WithEnvironment("LRSQL_DB_USER", postgres.Resource.UserNameReference)
            .WithEnvironment("LRSQL_DB_PASSWORD", postgres.Resource.PasswordParameter)
            .WithEnvironment("LRSQL_DB_HOST", postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("LRSQL_DB_PORT", postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Port))
            .WithEnvironment("LRSQL_DB_NAME", lrsqlDb.Resource.DatabaseName)
            .WithEnvironment("LRSQL_AUTHORITY_URL", "http://localhost:9274")
            .WithBindMount("resources/lrsql/authority.json.template", "/lrsql/config/authority.json.template", isReadOnly: true);

        if (!IsEnabled(lrsqlMode))
        {
            lrsql.WithExplicitStart();
        }
    }

    public static void AddMisp(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var mispMode = ResolveMode(options.Misp, "Misp", options);

        if (!options.AddAllApplications && !IsEnabled(mispMode))
            return;

        // Redis for MISP background jobs (without TLS for dev environment)
        var mispRedis = builder.AddRedis("misp-redis")
            .WithContainerName("misp-redis")
            .WithTags("misp", "database");

        // MySQL for MISP (MISP requires MySQL/MariaDB, not PostgreSQL)
        var mispMysql = builder.AddMySql("misp-mysql")
            .WithContainerName("misp-mysql")
            .WithDataVolume()
            .WithTags("misp", "database");

        var mispDb = mispMysql.AddDatabase("mispDb", "misp")
            .WithTags("misp", "database");

        // MISP Core application with custom fast-startup image
        var misp = builder.AddContainer("misp", "misp-custom-image")
            .WithDockerfile("./resources/misp", "Dockerfile.MispCustom")
            .WithContainerName("misp")
            .WithTags("misp", "service")
            .WaitFor(mispMysql)
            .WaitFor(mispRedis)
            .WithHttpEndpoint(port: 8444, targetPort: 80, name: "http", isProxied: false)
            .WithEnvironment("INIT", "true")
            .WithEnvironment("DISABLE_SSL_REDIRECT", "true")
            .WithEnvironment("MYSQL_HOST", mispMysql.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("MYSQL_DATABASE", mispDb.Resource.DatabaseName)
            .WithEnvironment("MYSQL_USER", "root")
            .WithEnvironment("MYSQL_PASSWORD", mispMysql.Resource.PasswordParameter)
            .WithEnvironment("MYSQL_PORT", mispMysql.Resource.PrimaryEndpoint.Property(EndpointProperty.Port))
            .WithEnvironment("REDIS_HOST", mispRedis.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("REDIS_PORT", "6380") // Use non-TLS port for dev environment
            .WithEnvironment("REDIS_PASSWORD", mispRedis.Resource.PasswordParameter)
            .WithEnvironment("HOSTNAME", "http://localhost:8444")
            .WithEnvironment("MISP_ADMIN_EMAIL", "admin@admin.test")
            .WithEnvironment("MISP_ADMIN_PASSPHRASE", "admin")
            .WithEnvironment("BASE_URL", "http://localhost:8444")
            .WithEnvironment("TIMEZONE", "UTC")
            .WithEnvironment("CRON_USER_ID", "1")
            .WithEnvironment("USERID", "33")
            .WithEnvironment("GROUPID", "33")
            .WithEnvironment("MOODLE_URL", "http://localhost:8081")
            // OIDC authentication via Keycloak
            .WithEnvironment("OIDC_PROVIDER_URL", "http://keycloak:8080/realms/crucible")
            .WithEnvironment("OIDC_ISSUER", "http://localhost:8080/realms/crucible")
            .WithEnvironment("OIDC_CLIENT_ID", "misp")
            .WithEnvironment("OIDC_CLIENT_SECRET", "misp-client-secret")
            .WithEnvironment("OIDC_LOGOUT_URL", "http://localhost:8080/realms/crucible/protocol/openid-connect/logout");

        // Training links JS panel — deployed to MISP webroot by customize_misp.sh
        misp.WithBindMount("./resources/misp/custom_training_links.js", "/custom/files/custom_training_links.js", isReadOnly: true);

        // MISP modules with custom module mounted
        var mispModules = builder.AddContainer("misp-modules", "misp-modules-custom")
            .WithDockerfile("./resources/misp", "Dockerfile.MispModules")
            .WithContainerName("misp-modules")
            .WithTags("misp", "service")
            .WithHttpEndpoint(port: 8666, targetPort: 6666, isProxied: false)
            .WithBindMount("/mnt/data/crucible/misp/misp-module-moodle/misp_module.py", "/usr/local/lib/python3.12/site-packages/misp_modules/modules/action_mod/moodle.py", isReadOnly: false);

        if (!IsEnabled(mispMode))
        {
            mispRedis.WithExplicitStart();
            mispMysql.WithExplicitStart();
            misp.WithExplicitStart();
            mispModules.WithExplicitStart();
        }
    }

    public static IResourceBuilder<ExecutableResource>? AddCommonUIDev(this IDistributedApplicationBuilder builder, LaunchOptions options)
    {
        if (!options.LinkCommonUI)
        {
            return null;
        }

        var commonUiRoot = "/mnt/data/crucible/libraries/Crucible.Common.Ui";
        var markerFile = $"{builder.AppHostDirectory}/.common-ui-build-ready";

        builder.Services.AddHealthChecks().AddCheck("common-ui-healthy", () =>
        {
            return File.Exists(markerFile)
                ? HealthCheckResult.Healthy()
                : HealthCheckResult.Unhealthy("Initial build not yet complete");
        });

        var commonUi = builder.AddExecutable("common-ui-dev", "bash", commonUiRoot, [
            "-c",
            $"rm -f {builder.AppHostDirectory}/.common-ui-build-ready && npm install && npx ng build crucible-common --watch | while IFS= read -r line; do echo \"$line\"; if echo \"$line\" | grep -q 'Compilation complete' && [ ! -f {builder.AppHostDirectory}/.common-ui-build-ready ]; then npm link dist/@crucible-common && touch {builder.AppHostDirectory}/.common-ui-build-ready; fi; done"
        ])
        .WithHealthCheck("common-ui-healthy")
        .WithTags("shared", "tooling");

        return commonUi;
    }

    public static void AddSuperset(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var supersetMode = ResolveMode(options.Superset, "Superset", options);

        if (!options.AddAllApplications && !IsEnabled(supersetMode))
            return;

        var supersetDb = postgres.AddDatabase("supersetDb", "superset")
            .WithTags("superset", "database");

        var superset = builder.AddContainer("superset", "superset-custom-image")
            .WithDockerfile("./resources/superset", "Dockerfile.SupersetCustom")
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("superset")
            .WithTags("superset", "service")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpEndpoint(port: 8088, targetPort: 8088)
            .WithHttpHealthCheck(path: "/health", endpointName: "http")
            .WithBindMount("./resources/superset/superset_config.py", "/app/superset_config.py", isReadOnly: true)
            .WithBindMount("./resources/superset/init-superset.sh", "/app/init-superset.sh", isReadOnly: true)
            .WithBindMount("./resources/superset/create-dashboard-orm.py", "/app/create-dashboard-orm.py", isReadOnly: true)
            .WithEnvironment("SUPERSET_CONFIG_PATH", "/app/superset_config.py")
            .WithEnvironment("SUPERSET_SECRET_KEY", "crucible-dev-superset-secret-key")
            .WithEnvironment("KEYCLOAK_EXTERNAL_URL", "http://localhost:8080/realms/crucible")
            .WithEnvironment(context =>
            {
                // Internal Keycloak URL for server-to-server communication
                var keycloakEndpoint = keycloak.GetEndpoint("http");
                var keycloakHost = keycloakEndpoint.Property(EndpointProperty.Host);
                var keycloakPort = keycloakEndpoint.Property(EndpointProperty.Port);
                context.EnvironmentVariables["KEYCLOAK_INTERNAL_URL"] =
                    ReferenceExpression.Create($"http://{keycloakHost}:{keycloakPort}/realms/crucible");
            })
            .WithEnvironment("KEYCLOAK_CLIENT_ID", "superset")
            .WithEnvironment("KEYCLOAK_CLIENT_SECRET", "superset-client-secret")
            .WithEnvironment(context =>
            {
                var host = postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Host);
                var port = postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Port);
                var user = postgres.Resource.UserNameReference;
                var password = postgres.Resource.PasswordParameter;
                var dbName = supersetDb.Resource.DatabaseName;

                context.EnvironmentVariables["DATABASE_HOST"] = host;
                context.EnvironmentVariables["DATABASE_PORT"] = port;
                context.EnvironmentVariables["DATABASE_USER"] = user;
                context.EnvironmentVariables["DATABASE_PASSWORD"] = password;
                context.EnvironmentVariables["DATABASE_DB"] = dbName;

                // Compose the SQLAlchemy URI for Superset metadata DB
                context.EnvironmentVariables["SUPERSET_SQLALCHEMY_DATABASE_URI"] =
                    ReferenceExpression.Create($"postgresql+psycopg2://{user}:{password}@{host}:{port}/{dbName}");

                // LRsql database connection for xAPI analytics
                context.EnvironmentVariables["LRSQL_SQLALCHEMY_URI"] =
                    ReferenceExpression.Create($"postgresql+psycopg2://{user}:{password}@{host}:{port}/lrsql");
            })
            .WithEnvironment("SUPERSET_LOAD_EXAMPLES", "no")
            .WithEnvironment("CYPRESS_CONFIG", "false")
            .WithArgs("bash", "/app/init-superset.sh");

        if (!IsEnabled(supersetMode))
        {
            superset.WithExplicitStart();
        }
    }

    public static void AddCatapult(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var catapultMode = ResolveMode(options.Catapult, "Catapult", options);
        var moodleMode = ResolveMode(options.Moodle, "Moodle", options);
        var catapultEnabled = IsEnabled(catapultMode) && IsEnabled(moodleMode);

        if (!options.AddAllApplications && !catapultEnabled)
            return;

        // CATAPULT's cmi5 player uses knex with the "mysql" client hard-coded and ships
        // only the mysql driver (no pg), so it cannot use the centralized crucible-postgres
        // instance. It gets its own MySQL container, like MISP.
        // CATAPULT's legacy "mysql" node driver can't authenticate against MySQL 8/9's
        // default caching_sha2_password. Upstream pins 8.0 with mysql_native_password
        // (which is removed in MySQL 9.x), so pin the image and force the legacy plugin.
        var catapultMysql = builder.AddMySql("catapult-mysql")
            .WithImageTag("8.0.31")
            .WithContainerName("catapult-mysql")
            .WithArgs("--default-authentication-plugin=mysql_native_password")
            .WithDataVolume()
            .WithTags("catapult", "database");

        var catapultDb = catapultMysql.AddDatabase("catapultPlayerDb", "catapult_player")
            .WithTags("catapult", "database");

        // ADL publishes no prebuilt image; the repo's own Dockerfile builds the Node app
        // from source. Build from the cloned repo's player directory.
        // Context is the cloned player source dir (so the upstream COPY steps resolve),
        // but the Dockerfile is our patched copy in resources/ (survives re-clone and is
        // version-controlled). Upstream's npm ci fails on an out-of-sync lock file.
        var catapultDockerfile = Path.Combine(builder.AppHostDirectory, "resources", "catapult", "Dockerfile.CatapultPlayer");
        var catapult = builder.AddContainer("catapult-player", "catapult-player-image")
            .WithDockerfile("/mnt/data/crucible/catapult/catapult/player", catapultDockerfile)
            .WithContainerName("catapult-player")
            .WithTags("catapult", "service")
            // Imported package content lives on the container filesystem while the course
            // rows live in MySQL. The container is recreated on every Aspire run, so without
            // a volume the content goes and every existing cmi5 activity 404s on launch.
            .WithVolume("crucible-dev-catapult-content", "/usr/src/app/var/content")
            .WaitFor(catapultMysql)
            .WithHttpEndpoint(port: 3398, targetPort: 3398)
            .WithEnvironment("DB_HOST", catapultMysql.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("DB_NAME", catapultDb.Resource.DatabaseName)
            .WithEnvironment("DB_USERNAME", "root")
            .WithEnvironment("DB_PASSWORD", catapultMysql.Resource.PasswordParameter)
            // xAPI statements flow to the existing LRsql container (reachable by container name).
            .WithEnvironment("LRS_ENDPOINT", "http://lrsql:8080/xapi")
            .WithEnvironment("LRS_USERNAME", "defaultkey")
            .WithEnvironment("LRS_PASSWORD", "defaultsecret")
            .WithEnvironment("TOKEN_SECRET", "crucible-dev-catapult-token-secret")
            .WithEnvironment("API_KEY", "catapult")
            .WithEnvironment("API_SECRET", "catapult-dev-secret")
            // First tenant is created on startup; mod_cmi5launch authenticates against it.
            .WithEnvironment("FIRST_TENANT_NAME", "crucible")
            // PLAYER_API_ROOT is only for proxied (nginx) deployments; it is prepended to
            // routes that already live under /api/v1. Leave empty for direct access so
            // paths resolve as /api/v1/... rather than /api/v1/api/v1/...
            .WithEnvironment("PLAYER_API_ROOT", "")
            .WithEnvironment("PLAYER_STANDALONE_LAUNCH_URL_BASE", "http://localhost:3398")
            .WithEnvironment("PLAYER_REQUIRE_STRICT_HEADERS", "false")
            .WithEnvironment("CONTENT_URL", "http://localhost:3398/content");

        if (!catapultEnabled)
        {
            catapultMysql.WithExplicitStart();
            catapult.WithExplicitStart();
        }
    }

    /// <summary>
    /// RangerAI (https://github.com/cmu-sei/rangerai): Chronicle and Scenario Builder, each a .NET API
    /// with an Angular UI. Each API uses its own storage configuration (currently SQLite).
    /// The APIs target net11.0. Launch:RangerAIKeycloak enables sign-in through the crucible realm.
    /// </summary>
    public static void AddRangerAI(this IDistributedApplicationBuilder builder, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var rangerMode = ResolveMode(options.RangerAI, "RangerAI", options);

        if (!options.AddAllApplications && !IsEnabled(rangerMode))
            return;

        var rangerSrc = "/mnt/data/crucible/rangerai/src";

        // The UIs' proxy.conf.json files hard-code the API ports (Chronicle :5285, Scenario Builder
        // :5280), so those stay. Scenario Builder's UI defaults to :4310, which Caster UI already
        // uses here, so it runs on :4330 and both APIs' app switcher entries (Apps:0) point there.
        const int scenarioBuilderUiPort = 4330;
        var scenarioBuilderUiUrl = $"http://localhost:{scenarioBuilderUiPort}";

        // The repo has no launchSettings.json, so the endpoints and environment are set here.
        var chronicleApi = builder.AddDotnetProject("chronicle-api", $"{rangerSrc}/chronicle/Chronicle.Api/Chronicle.Api.csproj")
            .WithTags("rangerai", "api")
            .WithHttpEndpoint(port: 5285, isProxied: false)
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("Apps__0__Url", scenarioBuilderUiUrl)
            .WithHttpHealthCheck("/health")
            .WithUrl("/swagger", "Chronicle Swagger UI");

        var uiMode = ResolveUiMode(rangerMode, options);
        var chronicleUi = builder.AddRangerUI("chronicle-ui", $"{rangerSrc}/chronicle/ui", 4320, uiMode)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Chronicle UI")
            .WaitFor(chronicleApi);

        var scenarioBuilderApi = builder.AddDotnetProject("scenario-builder-api", $"{rangerSrc}/scenario-builder/api/ScenarioBuilder.Api/ScenarioBuilder.Api.csproj")
            .WithTags("rangerai", "api")
            .WithUrl("/swagger", "Scenario Builder Swagger UI")
            .WithHttpEndpoint(port: 5280, isProxied: false)
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("Apps__0__Url", scenarioBuilderUiUrl)
            .WithHttpHealthCheck("/api/version");

        // Both prestart and prebuild bundle the agent using its locked development dependencies.
        var scenarioBuilderAgentInstall = builder.AddExecutable("scenario-builder-agent-install", "npm",
            $"{rangerSrc}/scenario-builder/agent", "ci", "--include=dev")
            .WithTags("rangerai", "tooling");

        var scenarioBuilderUi = builder.AddRangerUI("scenario-builder-ui", $"{rangerSrc}/scenario-builder/ui", scenarioBuilderUiPort, uiMode)
            .WithUrlForEndpoint("http", url => url.DisplayText = "Scenario Builder UI")
            .WaitForCompletion(scenarioBuilderAgentInstall)
            .WaitFor(scenarioBuilderApi);

        if (options.RangerAIKeycloak)
        {
            ConfigureRangerAIKeycloak(chronicleApi, keycloak, "chronicle");
            ConfigureRangerAIKeycloak(scenarioBuilderApi, keycloak, "scenario-builder");
            scenarioBuilderApi
                .WithEnvironment("Admins__0", "admin")
                // Development service account in crucible-realm.json, used when publishing a scenario.
                .WithEnvironment("Chronicle__Token__ClientId", "scenario-builder.service")
                .WithEnvironment("Chronicle__Token__ClientSecret", "f1d58ac0e58a3ab290d22ecd064a54dd");
            chronicleUi.WaitFor(keycloak);
            scenarioBuilderUi.WaitFor(keycloak);
        }

        if (!IsEnabled(rangerMode))
        {
            chronicleApi.WithExplicitStart();
            chronicleUi.WithExplicitStart();
            scenarioBuilderApi.WithExplicitStart();
            scenarioBuilderAgentInstall.WithExplicitStart();
            scenarioBuilderUi.WithExplicitStart();
        }
    }

    private static IResourceBuilder<ExecutableResource> AddRangerUI(this IDistributedApplicationBuilder builder,
        string name, string uiRoot, int port, UiMode mode)
    {
        IResourceBuilder<ExecutableResource> ui;
        if (mode == UiMode.Dev)
        {
            ui = builder.AddJavaScriptApp(name, uiRoot, "start")
                .WithArgs("--", "--host", "0.0.0.0", "--port", port.ToString());

            var installer = builder.Resources.OfType<JavaScriptInstallerResource>()
                .FirstOrDefault(r => r.Name == $"{name}-installer");
            if (installer != null)
            {
                builder.CreateResourceBuilder(installer).WithTags("rangerai", "tooling");
            }
        }
        else
        {
            // Keep ng serve's API proxy (including Chronicle's WebSocket) for the static build.
            ui = builder.AddExecutable(name, "bash", uiRoot, "-c",
                "npm ci --include=dev && npm run build -- --output-path dist/ui && " +
                "exec npx --yes vite@8.3.8 preview --config \"$1\" --port \"$2\"",
                name, Path.Combine(builder.AppHostDirectory, "resources", "rangerai-preview.mjs"), port.ToString());
        }

        return ui.WithEnvironment("NG_CLI_ANALYTICS", "false")
            .WithEnvironment("NG_FORCE_AUTOCOMPLETE", "false")
            .WithHttpEndpoint(port: port, isProxied: false)
            .WithHttpHealthCheck()
            .WithTags("rangerai", "ui");
    }

    /// <summary>
    /// Keycloak settings for a RangerAI API, named like the Crucible APIs' Authorization section.
    /// </summary>
    private static void ConfigureRangerAIKeycloak(IResourceBuilder<DotnetProjectResource> api, IResourceBuilder<KeycloakResource> keycloak, string audience)
    {
        const string realm = "https://localhost:8443/realms/crucible";

        api.WaitFor(keycloak)
            .WithEnvironment("Authorization__Authority", realm)
            .WithEnvironment("Authorization__AuthorizationUrl", $"{realm}/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", $"{realm}/protocol/openid-connect/token")
            // Browser callbacks go through the UI's /api proxy. Swagger callbacks use the API port.
            .WithEnvironment("Authorization__ClientId", $"{audience}.ui")
            .WithEnvironment("Authorization__SwaggerClientId", $"{audience}.api")
            .WithEnvironment("Authorization__Audience", audience);
    }

    private static void ConfigureApiSecrets(
        this IDistributedApplicationBuilder builder,
        string apiProjectPath,
        string userSecretsId,
        ReferenceExpression connectionStringExpression,
        Dictionary<string, ReferenceExpression>? extraSecrets = null)
    {
        builder.Eventing.Subscribe<AfterResourcesCreatedEvent>(async (@event, cancellationToken) =>
        {
            await WriteApiDevelopmentSettingsAsync(apiProjectPath, userSecretsId, connectionStringExpression, extraSecrets, cancellationToken);
        });
    }

    private static async Task WriteApiDevelopmentSettingsAsync(
        string apiProjectFilePath,
        string userSecretsId,
        ReferenceExpression connectionStringExpression,
        Dictionary<string, ReferenceExpression>? extraSecrets,
        CancellationToken cancellationToken = default)
    {
        InitUserSecrets(apiProjectFilePath, userSecretsId);
        try
        {
            var connectionString = await connectionStringExpression.GetValueAsync(cancellationToken);

            // Set user secrets using dotnet user-secrets
            if (connectionString is not null)
            {
                SetUserSecret(apiProjectFilePath, "ConnectionStrings:PostgreSQL", connectionString);
                SetUserSecret(apiProjectFilePath, "Database:Provider", "PostgreSQL");
                SetUserSecret(apiProjectFilePath, "Database:ConnectionString", connectionString);
            }

            if (extraSecrets is not null)
            {
                foreach (var secret in extraSecrets)
                {
                    var expressionVal = await secret.Value.GetValueAsync(cancellationToken);

                    if (expressionVal is not null)
                    {
                        SetUserSecret(apiProjectFilePath, secret.Key, expressionVal);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to create configuration for {apiProjectFilePath}: {ex.Message}");
        }
    }

    private static void InitUserSecrets(string projecFilePath, string userSecretsId)
    {
        var doc = System.Xml.Linq.XDocument.Load(projecFilePath);
        var ns = doc.Root?.Name.Namespace ?? System.Xml.Linq.XNamespace.None;

        // Check if UserSecretsId already exists
        var existingUserSecretsId = doc.Descendants(ns + "UserSecretsId").FirstOrDefault();
        if (existingUserSecretsId == null)
        {
            RunProcess("dotnet", $"user-secrets init --id {userSecretsId} --project {projecFilePath}");
        }
    }

    private static void SetUserSecret(string projectFilePath, string key, string value)
    {
        RunProcess("dotnet", $"user-secrets set \"{key}\" \"{value}\" --project {projectFilePath}");
    }

    private static int? RunProcess(string fileName, string arguments)
    {
        try
        {
            var process = Process.Start(new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            });

            process?.WaitForExit();

            if (process?.ExitCode != 0 && process is not null)
            {
                var error = process.StandardError.ReadToEnd();
                Console.WriteLine($"Warning: Failed to run {fileName} with {arguments}: {error}");
            }

            return process?.ExitCode;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to run {fileName} with {arguments}: {ex.Message}");
            return -1;
        }
    }

    private static void ConfigureXApi<T>(IResourceBuilder<T> resource, string platform, string apiUrl, string uiUrl) where T : IResourceWithEnvironment
    {
        resource
            .WithEnvironment("XApiOptions__Enabled", "true")
            .WithEnvironment("XApiOptions__Endpoint", "http://localhost:9274/xapi")
            .WithEnvironment("XApiOptions__Username", "defaultkey")
            .WithEnvironment("XApiOptions__Password", "defaultsecret")
            .WithEnvironment("XApiOptions__IssuerUrl", "https://localhost:8443/realms/crucible")
            .WithEnvironment("XApiOptions__ApiUrl", apiUrl)
            .WithEnvironment("XApiOptions__UiUrl", uiUrl)
            .WithEnvironment("XApiOptions__EmailDomain", "crucible.local")
            .WithEnvironment("XApiOptions__Platform", platform);
    }
}
