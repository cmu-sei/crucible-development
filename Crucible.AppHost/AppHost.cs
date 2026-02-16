// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using Microsoft.Extensions.Configuration;
using Crucible.AppHost;
using System.Diagnostics;
using Aspire.Hosting.JavaScript;

var builder = DistributedApplication.CreateBuilder(args);

LaunchOptions launchOptions = builder.Configuration.GetSection("Launch").Get<LaunchOptions>() ?? new();

// Debug: Log launch options
Console.WriteLine($"LaunchOptions:");
Console.WriteLine($"  Player: '{launchOptions.Player}', Caster: '{launchOptions.Caster}', Alloy: '{launchOptions.Alloy}'");
Console.WriteLine($"  TopoMojo: '{launchOptions.TopoMojo}', Steamfitter: '{launchOptions.Steamfitter}', Cite: '{launchOptions.Cite}'");
Console.WriteLine($"  Gallery: '{launchOptions.Gallery}', Blueprint: '{launchOptions.Blueprint}', Gameboard: '{launchOptions.Gameboard}'");
Console.WriteLine($"  AddAllApplications: {launchOptions.AddAllApplications}");

var postgres = builder.AddPostgres(launchOptions);
var keycloak = builder.AddKeycloak(postgres);
builder.AddPlayer(postgres, keycloak, launchOptions);
builder.AddCaster(postgres, keycloak, launchOptions);
builder.AddAlloy(postgres, keycloak, launchOptions);
builder.AddTopoMojo(postgres, keycloak, launchOptions);
builder.AddSteamfitter(postgres, keycloak, launchOptions);
builder.AddCite(postgres, keycloak, launchOptions);
builder.AddGallery(postgres, keycloak, launchOptions);
builder.AddBlueprint(postgres, keycloak, launchOptions);
builder.AddGameboard(postgres, keycloak, launchOptions);
builder.AddMoodle(postgres, keycloak, launchOptions);
builder.AddLrsql(postgres, keycloak, launchOptions);
builder.AddMisp(postgres, keycloak, launchOptions);
builder.AddDocs(launchOptions);

builder.Build().Run();

public static class BuilderExtensions
{
    public static IResourceBuilder<PostgresServerResource> AddPostgres(this IDistributedApplicationBuilder builder, LaunchOptions options)
    {
        var postgres = builder.AddPostgres("postgres")
            .WithDataVolume()
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("crucible-postgres")
            .WithEndpoint("tcp", endpoint =>
            {
                endpoint.IsProxied = false; // so tools (e.g. dotnet ef migrations) can connect to db when apphost is off
            });

        if (options.PGAdmin || options.AddAllApplications)
        {
            postgres.WithPgAdmin(pgAdmin =>
            {
                pgAdmin.WithEndpoint("http", endpoint =>
                {
                    endpoint.Port = 33000;
                    endpoint.IsProxied = false;
                });
                pgAdmin.WithLifetime(ContainerLifetime.Persistent);

                if (!options.PGAdmin)
                {
                    pgAdmin.WithExplicitStart();
                }
            });
        }

        return postgres;
    }

    public static void AddDocs(this IDistributedApplicationBuilder builder, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Docs)
            return;

        var docs = builder.AddContainer("mkdocs", "squidfunk/mkdocs-material")
            .WithBindMount("/mnt/data/crucible/crucible-docs", "/docs", isReadOnly: true)
            .WithHttpEndpoint(port: 8000, targetPort: 8000)
            .WithArgs("serve", "-a", "0.0.0.0:8000");

        if (!options.Docs)
        {
            docs.WithExplicitStart();
        }
    }

    public static IResourceBuilder<KeycloakResource> AddKeycloak(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres)
    {
        var keycloakDb = postgres.AddDatabase("keycloakDb", "keycloak");

        var keycloak = builder.AddKeycloak("keycloak", 8080)
            .WithReference(keycloakDb)
            .WithLifetime(ContainerLifetime.Persistent)
            // Disable built-in HTTPS so we can set a custom cert
            .WithoutHttpsCertificate()
            // Configure environment variables for the PostgreSQL connection
            .WithEnvironment("KC_DB", "postgres")
            .WithEnvironment("KC_DB_URL_HOST", postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("KC_DB_USERNAME", postgres.Resource.UserNameReference)
            .WithEnvironment("KC_DB_PASSWORD", postgres.Resource.PasswordParameter)
            .WithEnvironment("KC_HOSTNAME", "localhost")
            .WithEnvironment("KC_HTTPS_PORT", "8443")
            .WithEnvironment("KC_HOSTNAME_STRICT", "false")
            .WithEnvironment("KC_BOOTSTRAP_ADMIN_PASSWORD", "admin")
            .WithEnvironment("KC_HTTPS_CERTIFICATE_FILE", "/opt/keycloak/conf/crucible-dev.crt")
            .WithEnvironment("KC_HTTPS_CERTIFICATE_KEY_FILE", "/opt/keycloak/conf/crucible-dev.key")
            // Limit Java heap to reduce memory usage (from ~636MB to ~400MB)
            .WithEnvironment("JAVA_OPTS", "-Xms256m -Xmx384m")
            .WithBindMount("../.devcontainer/dev-certs/crucible-dev.crt", "/opt/keycloak/conf/crucible-dev.crt", isReadOnly: true)
            .WithBindMount("../.devcontainer/dev-certs/crucible-dev.key", "/opt/keycloak/conf/crucible-dev.key", isReadOnly: true)
            .WithHttpsEndpoint(port: 8443, targetPort: 8443, isProxied: false)
            .WithEndpoint("management", ep => ep.UriScheme = "https")
            .WithRealmImport($"{builder.AppHostDirectory}/resources/crucible-realm.json");

        return keycloak;
    }

    public static void AddPlayer(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.Player == "off")
            return;

        var playerDb = postgres.AddDatabase("playerDb", "player")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Player_Api().ProjectPath,
            "cmu-sei-crucible-player-api",
            playerDb.Resource.ConnectionStringExpression);

        var playerApi = builder.AddProject<Projects.Player_Api>("player-api", launchProfileName: "Player.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(playerDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "player.api");

        var playerUiRoot = "/mnt/data/crucible/player/player.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/player.ui.json", $"{playerUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        // Use full ng serve in dev mode, or lightweight production server otherwise
        IResourceBuilder<ExecutableResource> playerUi;
        if (options.Player == "dev")
        {
            playerUi = builder.AddJavaScriptApp("player-ui", playerUiRoot, "start")
                .WithHttpEndpoint(port: 4301, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist -l 4301";
            playerUi = builder.AddExecutable("player-ui", "bash", playerUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4301, isProxied: false);
        }

        playerUi = playerUi.WithHttpHealthCheck();

        builder.AddPlayerVm(postgres, keycloak, options);
    }

    private static void AddPlayerVm(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        var vmDb = postgres.AddDatabase("vmDb", "player_vm")
            .WithDevSettings();
        var vmLoggingDb = postgres.AddDatabase("vmLoggingDb", "player_vm_logging")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Player_Vm_Api().ProjectPath,
            "cmu-sei-crucible-vm-api",
            vmDb.Resource.ConnectionStringExpression,
            new Dictionary<string, ReferenceExpression>
            {
                ["VmUsageLogging:PostgreSQL"] = vmLoggingDb.Resource.ConnectionStringExpression
            });

        var vmApi = builder.AddProject<Projects.Player_Vm_Api>("player-vm-api", launchProfileName: "Player.Vm.Api")
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
            .WithEnvironment("Authorization__ClientId", "player.vm.api");

        var vmUiRoot = "/mnt/data/crucible/player/vm.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/vm.ui.json", $"{vmUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        IResourceBuilder<ExecutableResource> vmUi;
        if (options.Player == "dev")
        {
            vmUi = builder.AddJavaScriptApp("player-vm-ui", vmUiRoot, "start")
                .WithHttpEndpoint(port: 4303, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist/browser -l 4303";
            vmUi = builder.AddExecutable("player-vm-ui", "bash", vmUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4303, isProxied: false);
        }

        vmUi = vmUi.WithHttpHealthCheck();

        var consoleUiRoot = "/mnt/data/crucible/player/console.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/console.ui.json", $"{consoleUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        IResourceBuilder<ExecutableResource> consoleUi;
        if (options.Player == "dev")
        {
            consoleUi = builder.AddJavaScriptApp("player-vm-console-ui", consoleUiRoot, "start")
                .WithHttpEndpoint(port: 4305, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist/browser -l 4305";
            consoleUi = builder.AddExecutable("player-vm-console-ui", "bash", consoleUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4305, isProxied: false);
        }

        consoleUi = consoleUi.WithHttpHealthCheck();

    }

    public static void AddCaster(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.Caster == "off")
            return;

        var casterDb = postgres.AddDatabase("casterDb", "caster")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Caster_Api().ProjectPath,
            "cmu-sei-crucible-caster-api",
            casterDb.Resource.ConnectionStringExpression);

        var minikubeStart = builder.AddExecutable("minikube", "bash", $"{builder.AppHostDirectory}/../scripts/", [
            "-c",
            "./start-minikube.sh"
        ]);

        var minikubeStop = builder.AddExecutable("stop-minikube", "minikube", "",
        [
            "stop",
        ])
        .WithExplicitStart()
        .WithParentRelationship(minikubeStart);

        var minikubeDelete = builder.AddExecutable("delete-minikube", "minikube", "",
        [
            "delete",
        ])
        .WithExplicitStart()
        .WithParentRelationship(minikubeStart); ;

        var casterApi = builder.AddProject<Projects.Caster_Api>("caster-api", launchProfileName: "Caster.Api")
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
            .WithEnvironment("Terraform__KubernetesJobs__UseHostVolume", "true");

        var casterUiRoot = "/mnt/data/crucible/caster/caster.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/caster.ui.json", $"{casterUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        IResourceBuilder<ExecutableResource> casterUi;
        if (options.Caster == "dev")
        {
            casterUi = builder.AddJavaScriptApp("caster-ui", casterUiRoot, "start")
                .WithHttpEndpoint(port: 4310, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist -l 4310";
            casterUi = builder.AddExecutable("caster-ui", "bash", casterUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4310, isProxied: false);
        }

        casterUi = casterUi.WithHttpHealthCheck();

        if (options.Caster == "off")
        {
            casterApi.WithExplicitStart();
            casterUi.WithExplicitStart();
            minikubeStart.WithExplicitStart();
        }
    }

    public static void AddAlloy(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.Alloy == "off")
            return;

        var alloyDb = postgres.AddDatabase("alloyDb", "alloy")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Alloy_Api().ProjectPath,
            "cmu-sei-crucible-alloy-api",
            alloyDb.Resource.ConnectionStringExpression);

        var alloyApi = builder.AddProject<Projects.Alloy_Api>("alloy-api", launchProfileName: "Alloy.Api")
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
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "player player-vm alloy steamfitter caster")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false")
            .WithEnvironment("CorsPolicy__Origins__0", "http://localhost:4403") // for alloy-ui
            .WithEnvironment("CorsPolicy__Origins__1", "http://localhost:8081"); // for moodle

        var alloyUiRoot = "/mnt/data/crucible/alloy/alloy.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/alloy.ui.json", $"{alloyUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        IResourceBuilder<ExecutableResource> alloyUi;
        if (options.Alloy == "dev")
        {
            alloyUi = builder.AddJavaScriptApp("alloy-ui", alloyUiRoot, "start")
                .WithHttpEndpoint(port: 4403, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist -l 4403";
            alloyUi = builder.AddExecutable("alloy-ui", "bash", alloyUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4403, isProxied: false);
        }

        alloyUi = alloyUi.WithHttpHealthCheck();

        if (options.Alloy == "off")
        {
            alloyApi.WithExplicitStart();
            alloyUi.WithExplicitStart();
        }
    }

    public static void AddTopoMojo(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.TopoMojo == "off")
            return;

        var topoDb = postgres.AddDatabase("topoDb", "topomojo")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.TopoMojo_Api().ProjectPath,
            "cmu-sei-crucible-topomojo-api",
            topoDb.Resource.ConnectionStringExpression);

        var topoApi = builder.AddProject<Projects.TopoMojo_Api>("topomojo")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            //.WithHttpHealthCheck("api/health/ready")
            .WithReference(topoDb, "PostgreSQL")
            .WithEnvironment("Database__ConnectionString", topoDb.Resource.ConnectionStringExpression)
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Oidc__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Oidc__Audience", "topomojo")
            .WithEnvironment("OpenApi__Client__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("OpenApi__Client__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("OpenApi__Client__ClientId", "topomojo.api")
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("ASPNETCORE_URLS", "http://localhost:5000")
            .WithEnvironment("Headers__Cors__Origins__0", "http://localhost:4201") // for topo-ui
            .WithEnvironment("Headers__Cors__Origins__1", "http://localhost:8081") // for moodle
            .WithEnvironment("Headers__Cors__Methods__0", "*")
            .WithEnvironment("Headers__Cors__Headers__0", "*")
            .WithHttpEndpoint(name: "http", port: 5000, env: "PORT", isProxied: false)
            .WithUrlForEndpoint("http", url =>
            {
                url.Url = "/api";
            });

        var topoUiRoot = "/mnt/data/crucible/topomojo/topomojo-ui/";

        File.Copy($"{builder.AppHostDirectory}/resources/topomojo.ui.json", $"{topoUiRoot}/projects/topomojo-work/src/assets/settings.json", overwrite: true);

        IResourceBuilder<ExecutableResource> topoUi;
        if (options.TopoMojo == "dev")
        {
            topoUi = builder.AddJavaScriptApp("topomojo-ui", topoUiRoot, "start")
                .WithHttpEndpoint(port: 4201, env: "PORT", isProxied: false)
                .WithArgs("topomojo-work");

            var installerResource = builder.Resources.OfType<JavaScriptInstallerResource>()
                .FirstOrDefault(r => r.Name == "topomojo-ui-installer");

            // Add script that runs after npm install but before the UI starts
            if (installerResource != null)
            {
                var script = builder.AddExecutable("fixup-wmks", "bash", topoUiRoot, [
                    "-c",
                    "tools/fixup-wmks.sh"
                ])
                .WithParentRelationship(installerResource);

                script.Resource.Annotations.Add(new WaitAnnotation(installerResource, WaitType.WaitForCompletion));
                topoUi.WaitForCompletion(script);
            }
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build topomojo-work; npx serve -s dist/topomojo-work -l 4201";
            topoUi = builder.AddExecutable("topomojo-ui", "bash", topoUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4201, isProxied: false);
        }

        topoUi = topoUi.WithHttpHealthCheck();

        if (options.TopoMojo == "off")
        {
            topoApi.WithExplicitStart();
            topoUi.WithExplicitStart();
        }
    }

    public static void AddSteamfitter(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.Steamfitter == "off")
            return;

        var steamfitterDb = postgres.AddDatabase("steamfitterDb", "steamfitter")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Steamfitter_Api().ProjectPath,
            "cmu-sei-crucible-steamfitter-api",
            steamfitterDb.Resource.ConnectionStringExpression);

        var steamfitterApi = builder.AddProject<Projects.Steamfitter_Api>("steamfitter-api", launchProfileName: "Steamfitter.Api")
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
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "steamfitter player player-vm cite gallery")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        // Configure xAPI if LRS is enabled
        if (options.Lrsql)
        {
            ConfigureXApi(steamfitterApi, "steamfitter", "http://localhost:4400/api/", "http://localhost:4401/");
        }

        var steamfitterUiRoot = "/mnt/data/crucible/steamfitter/steamfitter.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/steamfitter.ui.json", $"{steamfitterUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        IResourceBuilder<ExecutableResource> steamfitterUi;
        if (options.Steamfitter == "dev")
        {
            steamfitterUi = builder.AddJavaScriptApp("steamfitter-ui", steamfitterUiRoot, "start")
                .WithHttpEndpoint(port: 4401, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist -l 4401";
            steamfitterUi = builder.AddExecutable("steamfitter-ui", "bash", steamfitterUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4401, isProxied: false);
        }

        steamfitterUi = steamfitterUi.WithHttpHealthCheck();

        if (options.Steamfitter == "off")
        {
            steamfitterApi.WithExplicitStart();
            steamfitterUi.WithExplicitStart();
        }
    }

    public static void AddCite(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.Cite == "off")
            return;

        var citeDb = postgres.AddDatabase("citeDb", "cite")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Cite_Api().ProjectPath,
            "cmu-sei-crucible-cite-api",
            citeDb.Resource.ConnectionStringExpression);

        var citeApi = builder.AddProject<Projects.Cite_Api>("cite-api", launchProfileName: "Cite.Api")
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
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "openid profile email gallery")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        // Configure xAPI if LRS is enabled
        if (options.Lrsql)
        {
            ConfigureXApi(citeApi, "cite", "http://localhost:4720/api/", "http://localhost:4721/");
        }

        var citeUiRoot = "/mnt/data/crucible/cite/cite.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/cite.ui.json", $"{citeUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        IResourceBuilder<ExecutableResource> citeUi;
        if (options.Cite == "dev")
        {
            citeUi = builder.AddJavaScriptApp("cite-ui", citeUiRoot, "start")
                .WithHttpEndpoint(port: 4721, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist/browser -l 4721";
            citeUi = builder.AddExecutable("cite-ui", "bash", citeUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4721, isProxied: false);
        }

        citeUi = citeUi.WithHttpHealthCheck();

        if (options.Cite == "off")
        {
            citeApi.WithExplicitStart();
            citeUi.WithExplicitStart();
        }
    }

    public static void AddGallery(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.Gallery == "off")
            return;

        var galleryDb = postgres.AddDatabase("galleryDb", "gallery")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Gallery_Api().ProjectPath,
            "cmu-sei-crucible-gallery-api",
            galleryDb.Resource.ConnectionStringExpression);

        var galleryApi = builder.AddProject<Projects.Gallery_Api>("gallery-api", launchProfileName: "Api")
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
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "player player-vm steamfitter")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        // Configure xAPI if LRS is enabled
        if (options.Lrsql)
        {
            ConfigureXApi(galleryApi, "gallery", "http://localhost:4722/api/", "http://localhost:4723/");
        }

        var galleryUiRoot = "/mnt/data/crucible/gallery/gallery.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/gallery.ui.json", $"{galleryUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        IResourceBuilder<ExecutableResource> galleryUi;
        if (options.Gallery == "dev")
        {
            galleryUi = builder.AddJavaScriptApp("gallery-ui", galleryUiRoot, "start")
                .WithHttpEndpoint(port: 4723, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist/browser -l 4723";
            galleryUi = builder.AddExecutable("gallery-ui", "bash", galleryUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4723, isProxied: false);
        }

        galleryUi = galleryUi.WithHttpHealthCheck();

        if (options.Gallery == "off")
        {
            galleryApi.WithExplicitStart();
            galleryUi.WithExplicitStart();
        }
    }

    public static void AddBlueprint(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.Blueprint == "off")
            return;

        var blueprintDb = postgres.AddDatabase("blueprintDb", "blueprint")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Blueprint_Api().ProjectPath,
            "cmu-sei-crucible-blueprint-api",
            blueprintDb.Resource.ConnectionStringExpression);

        var blueprintApi = builder.AddProject<Projects.Blueprint_Api>("blueprint-api", launchProfileName: "Blueprint.Api")
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
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "player player-vm gallery steamfitter cite")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        if (options.Lrsql)
        {
            ConfigureXApi(blueprintApi, "blueprint", "http://localhost:4724/api/", "http://localhost:4725/");
        }

        var blueprintUiRoot = "/mnt/data/crucible/blueprint/blueprint.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/blueprint.ui.json", $"{blueprintUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        IResourceBuilder<ExecutableResource> blueprintUi;
        if (options.Blueprint == "dev")
        {
            blueprintUi = builder.AddJavaScriptApp("blueprint-ui", blueprintUiRoot, "start")
                .WithHttpEndpoint(port: 4725, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build; npx serve -s dist/browser -l 4725";
            blueprintUi = builder.AddExecutable("blueprint-ui", "bash", blueprintUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4725, isProxied: false);
        }

        blueprintUi = blueprintUi.WithHttpHealthCheck();

        if (options.Blueprint == "off")
        {
            blueprintApi.WithExplicitStart();
            blueprintUi.WithExplicitStart();
        }
    }

    public static void AddGameboard(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && options.Gameboard == "off")
            return;

        var gameboardDb = postgres.AddDatabase("gameboardDb", "gameboard")
            .WithDevSettings();

        builder.ConfigureApiSecrets(
            new Projects.Gameboard_Api().ProjectPath,
            "cmu-sei-crucible-gameboard-api",
            gameboardDb.Resource.ConnectionStringExpression);

        var gameboardApi = builder.AddProject<Projects.Gameboard_Api>("gameboard", launchProfileName: "Project")
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

        File.Copy($"{builder.AppHostDirectory}/resources/gameboard.ui.json", $"{gameboardUiRoot}/projects/gameboard-ui/src/assets/settings.json", overwrite: true);

        IResourceBuilder<ExecutableResource> gameboardUi;
        if (options.Gameboard == "dev")
        {
            gameboardUi = builder.AddJavaScriptApp("gameboard-ui", gameboardUiRoot, "start")
                .WithHttpEndpoint(port: 4202, env: "PORT", isProxied: false);
        }
        else
        {
            var serveProd = $"[ ! -d dist ] && npm run build gameboard-ui; npx serve -s dist/gameboard-ui -l 4202";
            gameboardUi = builder.AddExecutable("gameboard-ui", "bash", gameboardUiRoot, "-c", serveProd)
                .WithHttpEndpoint(port: 4202, isProxied: false);
        }

        gameboardUi = gameboardUi.WithHttpHealthCheck();

        if (options.Gameboard == "off")
        {
            gameboardApi.WithExplicitStart();
            gameboardUi.WithExplicitStart();
        }
    }

    public static void AddMoodle(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Moodle)
            return;

        var moodleDb = postgres.AddDatabase("moodleDb", "moodle");

        // Read AWS credentials from ~/.aws/credentials file
        var awsCreds = ReadAwsCredentials();

        var moodle = builder.AddContainer("moodle", "moodle-custom-image")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithDockerfile("./resources/moodle", "Dockerfile.MoodleCustom")
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("moodle")
            .WithHttpEndpoint(port: 8081, targetPort: 8080)
            .WithHttpHealthCheck(endpointName: "http")
            .WithEnvironment("memory_limit", "512M") // needs to be set for moosh plugin-list to work
            .WithEnvironment("XDEBUG_MODE", options.XdebugMode)
            .WithEnvironment("REVERSEPROXY", "true")
            .WithEnvironment("SITE_URL", "http://localhost:8081")
            .WithEnvironment("SSLPROXY", "false")
            .WithEnvironment("MOODLE_ADMIN_USERNAME", "admin")
            .WithEnvironment("MOODLE_ADMIN_PASSWORD", "admin")
            .WithEnvironment("DB_USER", postgres.Resource.UserNameReference)
            .WithEnvironment("DB_PASS", postgres.Resource.PasswordParameter)
            .WithEnvironment("DB_HOST", postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("DB_NAME", moodleDb.Resource.DatabaseName)
            .WithEnvironment("AWS_ACCESS_KEY_ID", awsCreds["aws_access_key_id"])
            .WithEnvironment("AWS_SECRET_ACCESS_KEY", awsCreds["aws_secret_access_key"])
            .WithEnvironment("AWS_SESSION_TOKEN", awsCreds["aws_session_token"])
            .WithEnvironment("AWS_REGION", awsCreds["region"])
            .WithEnvironment("PLUGINS", @"logstore_xapi=https://moodle.org/plugins/download.php/34860/logstore_xapi_2025021100.zip
                    tool_userdebug=https://moodle.org/plugins/download.php/36714/tool_userdebug_moodle50_2025070100.zip")
            .WithEnvironment("PRE_CONFIGURE_COMMANDS", @"/usr/local/bin/pre_configure.sh;")
            .WithEnvironment("POST_CONFIGURE_COMMANDS", @"/usr/local/bin/post_configure.sh")
            .WithBindMount("/mnt/data/crucible/moodle/moodle-core/theme", "/var/www/html/theme", isReadOnly: false)
            .WithBindMount("/mnt/data/crucible/moodle/moodle-core/lib", "/var/www/html/lib", isReadOnly: false)
            .WithBindMount("/mnt/data/crucible/moodle/moodle-core/admin/cli", "/var/www/html/admin/cli", isReadOnly: false)
            .WithBindMount("/mnt/data/crucible/moodle/moodle-core/ai/provider", "/var/www/html/ai/provider", isReadOnly: false)
            .WithBindMount("/mnt/data/crucible/moodle/moodle-core/ai/classes", "/var/www/html/ai/classes", isReadOnly: false)
            .WithBindMount("/mnt/data/crucible/moodle/block_crucible", "/var/www/html/blocks/crucible", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_crucible", "/var/www/html/mod/crucible", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_groupquiz", "/var/www/html/mod/groupquiz", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_topomojo", "/var/www/html/mod/topomojo", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/qtype_mojomatch", "/var/www/html/question/type/mojomatch", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/qbehaviour_mojomatch", "/var/www/html/question/behaviour/mojomatch", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/tool_lptmanager", "/var/www/html/admin/tool/lptmanager", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/local_tagmanager", "/var/www/html/local/tagmanager", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/aiplacement_competency", "/var/www/html/ai/placement/competency", isReadOnly: true);

        if (!options.Moodle)
        {
            moodle.WithExplicitStart();
        }
    }

    public static void AddLrsql(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Lrsql)
            return;

        var lrsqlDb = postgres.AddDatabase("lrsqlDb", "lrsql");

        var lrsql = builder.AddContainer("lrsql", "yetanalytics/lrsql")
            .WaitFor(postgres)
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
            .WithEnvironment("LRSQL_DB_NAME", lrsqlDb.Resource.DatabaseName);

        if (!options.Lrsql)
        {
            lrsql.WithExplicitStart();
        }
    }

    public static void AddMisp(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Misp)
            return;

        // Redis for MISP background jobs (without TLS for dev environment)
        var mispRedisPassword = builder.AddParameter("misp-redis-password", secret: true);

        var mispRedis = builder.AddRedis("misp-redis", password: mispRedisPassword)
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("misp-redis");

        // MySQL for MISP (MISP requires MySQL/MariaDB, not PostgreSQL)
        var mispMysql = builder.AddMySql("misp-mysql")
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("misp-mysql")
            .WithDataVolume();

        var mispDb = mispMysql.AddDatabase("mispDb", "misp");

        // MISP Core application with custom fast-startup image
        var misp = builder.AddContainer("misp", "misp-custom-image")
            .WithDockerfile("./resources/misp", "Dockerfile.MispCustom")
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("misp")
            .WaitFor(mispMysql)
            .WaitFor(mispRedis)
            .WithHttpsEndpoint(port: 8444, targetPort: 443, name: "https", isProxied: false)
            .WithEnvironment("INIT", "true")
            .WithEnvironment("MYSQL_HOST", mispMysql.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("MYSQL_DATABASE", mispDb.Resource.DatabaseName)
            .WithEnvironment("MYSQL_USER", "root")
            .WithEnvironment("MYSQL_PASSWORD", mispMysql.Resource.PasswordParameter)
            .WithEnvironment("MYSQL_PORT", mispMysql.Resource.PrimaryEndpoint.Property(EndpointProperty.Port))
            .WithEnvironment("REDIS_HOST", mispRedis.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("REDIS_PORT", "6380") // Use non-TLS port for dev environment
            .WithEnvironment("REDIS_PASSWORD", mispRedisPassword)
            .WithEnvironment("HOSTNAME", "https://localhost:8444")
            .WithEnvironment("MISP_ADMIN_EMAIL", "admin@admin.test")
            .WithEnvironment("MISP_ADMIN_PASSPHRASE", "admin")
            .WithEnvironment("BASE_URL", "https://localhost:8444")
            .WithEnvironment("TIMEZONE", "UTC")
            .WithEnvironment("CRON_USER_ID", "1")
            .WithEnvironment("USERID", "33")
            .WithEnvironment("GROUPID", "33")
            .WithEnvironment("MOODLE_URL", "http://localhost:8081");

        // MISP modules with custom module mounted
        var mispModules = builder.AddContainer("misp-modules", "misp-modules-custom")
            .WithDockerfile("./resources/misp", "Dockerfile.MispModules")
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("misp-modules")
            .WithHttpEndpoint(port: 8666, targetPort: 6666, isProxied: false)
            .WithBindMount("/mnt/data/crucible/misp/misp-module-moodle/misp_module.py", "/usr/local/lib/python3.12/site-packages/misp_modules/modules/action_mod/moodle.py", isReadOnly: false);

        if (!options.Misp)
        {
            misp.WithExplicitStart();
            mispModules.WithExplicitStart();
        }
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
            .WithEnvironment("XApiOptions__Endpoint", "http://localhost:9274/xapi")
            .WithEnvironment("XApiOptions__Username", "defaultkey")
            .WithEnvironment("XApiOptions__Password", "defaultsecret")
            .WithEnvironment("XApiOptions__IssuerUrl", "https://localhost:8443/realms/crucible")
            .WithEnvironment("XApiOptions__ApiUrl", apiUrl)
            .WithEnvironment("XApiOptions__UiUrl", uiUrl)
            .WithEnvironment("XApiOptions__EmailDomain", "crucible.local")
            .WithEnvironment("XApiOptions__Platform", platform);
    }

    private static Dictionary<string, string> ReadAwsCredentials()
    {
        var creds = new Dictionary<string, string>
        {
            ["aws_access_key_id"] = "",
            ["aws_secret_access_key"] = "",
            ["aws_session_token"] = "",
            ["region"] = "us-east-1"
        };

        var homeDir = Environment.GetEnvironmentVariable("HOME") ?? "";
        var credentialsPath = Path.Combine(homeDir, ".aws", "sso-credentials");

        if (!File.Exists(credentialsPath)) return creds;

        try
        {
            var json = File.ReadAllText(credentialsPath);
            var doc = System.Text.Json.JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (root.TryGetProperty("AccessKeyId", out var accessKeyId))
                creds["aws_access_key_id"] = accessKeyId.GetString() ?? "";

            if (root.TryGetProperty("SecretAccessKey", out var secretAccessKey))
                creds["aws_secret_access_key"] = secretAccessKey.GetString() ?? "";

            if (root.TryGetProperty("SessionToken", out var sessionToken))
                creds["aws_session_token"] = sessionToken.GetString() ?? "";

            if (root.TryGetProperty("Region", out var region))
                creds["region"] = region.GetString() ?? "us-east-1";
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to parse AWS credentials from {credentialsPath}: {ex.Message}");
        }

        return creds;
    }
}
