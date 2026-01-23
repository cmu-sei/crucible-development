// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using Microsoft.Extensions.Configuration;
using Crucible.AppHost;
using System.Diagnostics;
using Aspire.Hosting.JavaScript;

var builder = DistributedApplication.CreateBuilder(args);

LaunchOptions launchOptions = builder.Configuration.GetSection("Launch").Get<LaunchOptions>() ?? new();

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
<<<<<<< HEAD
builder.AddDocs(launchOptions);
=======
builder.AddMisp(postgres, keycloak, launchOptions);
>>>>>>> 3e0b616 (adds proxy scripts)

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
            .WithBindMount("../.devcontainer/dev-certs/crucible-dev.crt", "/opt/keycloak/conf/crucible-dev.crt", isReadOnly: true)
            .WithBindMount("../.devcontainer/dev-certs/crucible-dev.key", "/opt/keycloak/conf/crucible-dev.key", isReadOnly: true)
            .WithHttpsEndpoint(port: 8443, targetPort: 8443, isProxied: false)
            .WithEndpoint("management", ep => ep.UriScheme = "https")
            .WithRealmImport($"{builder.AppHostDirectory}/resources/crucible-realm.json");

        return keycloak;
    }

    public static void AddPlayer(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Player)
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

        var playerUi = builder.AddJavaScriptApp("player-ui", playerUiRoot, "start")
            .WithHttpEndpoint(port: 4301, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!options.Player)
        {
            playerApi.WithExplicitStart();
            playerUi.WithExplicitStart();
        }

        builder.AddPlayerVm(postgres, keycloak, options.Player);
    }

    private static void AddPlayerVm(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, bool startByDefault)
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

        var vmUi = builder.AddJavaScriptApp("player-vm-ui", vmUiRoot, "start")
            .WithHttpEndpoint(port: 4303, env: "PORT", isProxied: false)
            .WithHttpHealthCheck(); ;

        var consoleUiRoot = "/mnt/data/crucible/player/console.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/console.ui.json", $"{consoleUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var consoleUi = builder.AddJavaScriptApp("player-vm-console-ui", consoleUiRoot, "start")
            .WithHttpEndpoint(port: 4305, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!startByDefault)
        {
            vmApi.WithExplicitStart();
            vmUi.WithExplicitStart();
            consoleUi.WithExplicitStart();
        }

    }

    public static void AddCaster(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Caster)
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

        var casterUi = builder.AddJavaScriptApp("caster-ui", casterUiRoot, "start")
            .WithHttpEndpoint(port: 4310, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!options.Caster)
        {
            casterApi.WithExplicitStart();
            casterUi.WithExplicitStart();
            minikubeStart.WithExplicitStart();
        }
    }

    public static void AddAlloy(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Alloy)
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

        var alloyUi = builder.AddJavaScriptApp("alloy-ui", alloyUiRoot, "start")
            .WithHttpEndpoint(port: 4403, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!options.Alloy)
        {
            alloyApi.WithExplicitStart();
            alloyUi.WithExplicitStart();
        }
    }

    public static void AddTopoMojo(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.TopoMojo)
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

        var topoUi = builder.AddJavaScriptApp("topomojo-ui", topoUiRoot, "start")
            .WithHttpEndpoint(port: 4201, env: "PORT", isProxied: false)
            .WithHttpHealthCheck()
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

        if (!options.TopoMojo)
        {
            topoApi.WithExplicitStart();
            topoUi.WithExplicitStart();
        }
    }

    public static void AddSteamfitter(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Steamfitter)
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

        var steamfitterUiRoot = "/mnt/data/crucible/steamfitter/steamfitter.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/steamfitter.ui.json", $"{steamfitterUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var steamfitterUi = builder.AddJavaScriptApp("steamfitter-ui", steamfitterUiRoot, "start")
            .WithHttpEndpoint(port: 4401, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!options.Steamfitter)
        {
            steamfitterApi.WithExplicitStart();
            steamfitterUi.WithExplicitStart();
        }
    }

    public static void AddCite(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Cite)
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

        var citeUiRoot = "/mnt/data/crucible/cite/cite.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/cite.ui.json", $"{citeUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var citeUi = builder.AddJavaScriptApp("cite-ui", citeUiRoot, "start")
            .WithHttpEndpoint(port: 4721, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!options.Cite)
        {
            citeApi.WithExplicitStart();
            citeUi.WithExplicitStart();
        }
    }

    public static void AddGallery(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Gallery)
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

        var galleryUiRoot = "/mnt/data/crucible/gallery/gallery.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/gallery.ui.json", $"{galleryUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var galleryUi = builder.AddJavaScriptApp("gallery-ui", galleryUiRoot, "start")
            .WithHttpEndpoint(port: 4723, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!options.Gallery)
        {
            galleryApi.WithExplicitStart();
            galleryUi.WithExplicitStart();
        }
    }

    public static void AddBlueprint(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Blueprint)
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

        var blueprintUiRoot = "/mnt/data/crucible/blueprint/blueprint.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/blueprint.ui.json", $"{blueprintUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var blueprintUi = builder.AddJavaScriptApp("blueprint-ui", blueprintUiRoot, "start")
            .WithHttpEndpoint(port: 4725, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!options.Blueprint)
        {
            blueprintApi.WithExplicitStart();
            blueprintUi.WithExplicitStart();
        }
    }

    public static void AddGameboard(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.AddAllApplications && !options.Gameboard)
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

        var gameboardUi = builder.AddJavaScriptApp("gameboard-ui", gameboardUiRoot, "start")
            .WithHttpEndpoint(port: 4202, env: "PORT", isProxied: false)
            .WithHttpHealthCheck();

        if (!options.Gameboard)
        {
            gameboardApi.WithExplicitStart();
            gameboardUi.WithExplicitStart();
        }
    }

    public static void AddMoodle(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.Moodle) return;

        var moodleDb = postgres.AddDatabase("moodleDb", "moodle");

        var moodle = builder.AddContainer("moodle", "moodle-custom-image")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithDockerfile("./resources/moodle", "Dockerfile.MoodleCustom")
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
            .WithEnvironment("PLUGINS", @"logstore_xapi=https://moodle.org/plugins/download.php/34860/logstore_xapi_2025021100.zip
                    tool_userdebug=https://moodle.org/plugins/download.php/36714/tool_userdebug_moodle50_2025070100.zip")
            .WithEnvironment("PRE_CONFIGURE_COMMANDS", @"/usr/local/bin/pre_configure.sh;")
            .WithEnvironment("POST_CONFIGURE_COMMANDS", @"/usr/local/bin/post_configure.sh")
            .WithBindMount("/mnt/data/crucible/moodle/moodle-core/theme", "/var/www/html/theme", isReadOnly: false)
            .WithBindMount("/mnt/data/crucible/moodle/moodle-core/lib", "/var/www/html/lib", isReadOnly: false)
            .WithBindMount("/mnt/data/crucible/moodle/moodle-core/admin/cli", "/var/www/html/admin/cli", isReadOnly: false)
            .WithBindMount("/mnt/data/crucible/moodle/block_crucible", "/var/www/html/blocks/crucible", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_crucible", "/var/www/html/mod/crucible", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_groupquiz", "/var/www/html/mod/groupquiz", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_topomojo", "/var/www/html/mod/topomojo", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/qtype_mojomatch", "/var/www/html/question/type/mojomatch", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/qbehaviour_mojomatch", "/var/www/html/question/behaviour/mojomatch", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_pptbook", "/var/www/html/mod/pptbook", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/tool_lptmanager", "/var/www/html/admin/tool/lptmanager", isReadOnly: true);
    }

    public static void AddLrsql(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.Lrsql) return;

        var lrsqlDb = postgres.AddDatabase("lrsqlDb", "lrsql");

        var moodle = builder.AddContainer("lrsql", "yetanalytics/lrsql")
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
    }

    public static void AddMisp(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.Misp) return;

        // MySQL for MISP (MISP requires MySQL/MariaDB, not PostgreSQL)
        var mispMysql = builder.AddMySql("misp-mysql")
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("misp-mysql")
            .WithDataVolume();

        var mispDb = mispMysql.AddDatabase("mispDb", "misp");

        // Redis for MISP
        var redis = builder.AddRedis("misp-redis")
            .WithLifetime(ContainerLifetime.Persistent)
            .WithContainerName("misp-redis");

        // MISP Core application
        var misp = builder.AddContainer("misp", "coolacid/misp-docker", "core-latest")
            .WaitFor(mispMysql)
            .WaitFor(redis)
            .WithContainerName("misp")
            .WithHttpEndpoint(port: 8082, targetPort: 80)
            .WithHttpsEndpoint(port: 8443, targetPort: 443)
            .WithEnvironment("MYSQL_HOST", mispMysql.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("MYSQL_DATABASE", mispDb.Resource.DatabaseName)
            .WithEnvironment("MYSQL_USER", "root")
            .WithEnvironment("MYSQL_PASSWORD", mispMysql.Resource.PasswordParameter)
            .WithEnvironment("MYSQL_PORT", mispMysql.Resource.PrimaryEndpoint.Property(EndpointProperty.Port))
            .WithEnvironment("REDIS_FQDN", "misp-redis")
            .WithEnvironment("HOSTNAME", "https://localhost:8082")
            .WithEnvironment("MISP_ADMIN_EMAIL", "admin@admin.test")
            .WithEnvironment("MISP_ADMIN_PASSPHRASE", "admin")
            .WithEnvironment("MISP_BASEURL", "https://localhost:8082")
            .WithEnvironment("TIMEZONE", "UTC");

        // MISP modules with custom module mounted
        var mispModules = builder.AddContainer("misp-modules", "misp-modules-custom")
            .WithDockerfile("./resources/misp", "Dockerfile.MispModules")
            .WithContainerName("misp-modules")
            .WithHttpEndpoint(port: 6666, targetPort: 6666)
            .WithBindMount("/mnt/data/crucible/misp/misp-module-moodle", "/usr/local/src/misp-modules/misp_modules/modules/expansion/moodle", isReadOnly: true);
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

}
