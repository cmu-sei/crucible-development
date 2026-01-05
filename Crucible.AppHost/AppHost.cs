// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using System;
using Aspire.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Crucible.AppHost;

var builder = DistributedApplication.CreateBuilder(args);

LaunchOptions launchOptions = new();
builder.Configuration.GetSection("Launch").Bind(launchOptions);
bool addAllApplications = builder.Configuration.GetSection("Options").GetValue<bool>("addAllApplications");
int postgresPort = builder.Configuration.GetValue<int>("PostgresPort", 5432);

var postgres = builder.AddPostgres("postgres")
    .WithDataVolume()
    .WithLifetime(ContainerLifetime.Persistent)
    .WithContainerName("crucible-postgres")
    .WithEndpoint("tcp", endpoint => endpoint.Port = postgresPort)
    .WithPgAdmin(pgAdmin =>
    {
        pgAdmin.WithEndpoint("http", endpoint => endpoint.Port = 33000);
    });

var mkdocs = builder.AddContainer("mkdocs", "squidfunk/mkdocs-material")
    .WithBindMount("/mnt/data/crucible/crucible-docs", "/docs", isReadOnly: true)
    .WithHttpEndpoint(port: 8000, targetPort: 8000)
    .WithArgs("serve", "-a", "0.0.0.0:8000");

var keycloak = builder.AddKeycloak(postgres);
builder.AddPlayer(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddCaster(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddAlloy(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddTopoMojo(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddSteamfitter(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddCite(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddGallery(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddBlueprint(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddGameboard(postgres, keycloak, launchOptions, addAllApplications, postgresPort);
builder.AddMoodle(postgres, keycloak, launchOptions);
builder.AddLrsql(postgres, keycloak, launchOptions, postgresPort);

builder.Build().Run();

public static class BuilderExtensions
{
    public static IResourceBuilder<KeycloakResource> AddKeycloak(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres)
    {
        var keycloakDb = postgres.AddDatabase("keycloakDb", "keycloak");
        var keycloak = builder.AddKeycloak("keycloak", 8080)
            .WithReference(keycloakDb)
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
            .WithBindMount("../.devcontainer/certs/crucible-dev.crt", "/opt/keycloak/conf/crucible-dev.crt", isReadOnly: true)
            .WithBindMount("../.devcontainer/certs/crucible-dev.key", "/opt/keycloak/conf/crucible-dev.key", isReadOnly: true)
            .WithHttpsEndpoint(8443, 8443)
            .WithRealmImport($"{builder.AppHostDirectory}/resources/crucible-realm.json");

        var keycloakManagementEndpointAnnotation = keycloak.Resource.Annotations
            .OfType<EndpointAnnotation>()
            .FirstOrDefault(e => e.Name == "management");

        if (keycloakManagementEndpointAnnotation is not null)
        {
            keycloakManagementEndpointAnnotation.Transport = "https";
            keycloakManagementEndpointAnnotation.UriScheme = "https";
        }

        return keycloak;
    }

    public static void AddPlayer(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.Player)
            return;

        var playerDb = postgres.AddDatabase("playerDb", "player");

        var playerConnectionString = BuildConnectionString(builder, postgresPort, "player");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/player/player.api/Player.Api",
            "cmu-sei-crucible-player-api",
            playerConnectionString);

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

        var playerUi = builder.AddNpmApp("player-ui", playerUiRoot)
                .WithHttpEndpoint(port: 4301, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();

        if (!options.Player)
        {
            playerApi.WithExplicitStart();
            playerUi.WithExplicitStart();
        }

        builder.AddPlayerVm(postgres, keycloak, options.Player);
    }

    private static void AddPlayerVm(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, bool startByDefault)
    {
        var vmDb = postgres.AddDatabase("vmDb", "player_vm");
        var vmLoggingDb = postgres.AddDatabase("vmLoggingDb", "player_vm_logging");

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

        var vmUi = builder.AddNpmApp("player-vm-ui", vmUiRoot)
                .WithHttpEndpoint(port: 4303, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();

        var consoleUiRoot = "/mnt/data/crucible/player/console.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/console.ui.json", $"{consoleUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var consoleUi = builder.AddNpmApp("player-vm-console-ui", consoleUiRoot)
                .WithHttpEndpoint(port: 4305, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();

        if (!startByDefault)
        {
            vmApi.WithExplicitStart();
            vmUi.WithExplicitStart();
            consoleUi.WithExplicitStart();
        }

    }

    public static void AddCaster(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.Caster)
            return;

        var casterDb = postgres.AddDatabase("casterDb", "caster");

        var casterConnectionString = BuildConnectionString(builder, postgresPort, "caster");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/caster/caster.api/src/Caster.Api",
            "cmu-sei-crucible-caster-api",
            casterConnectionString);

        var casterApi = builder.AddProject<Projects.Caster_Api>("caster-api", launchProfileName: "Caster.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(casterDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "https://localhost:8443/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "https://localhost:8443/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "caster.api");

        var casterUiRoot = "/mnt/data/crucible/caster/caster.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/caster.ui.json", $"{casterUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var casterUi = builder.AddNpmApp("caster-ui", casterUiRoot)
            .WithHttpEndpoint(port: 4310, env: "PORT", isProxied: false)
            .WithNpmPackageInstallation();

        if (!options.Caster)
        {
            casterApi.WithExplicitStart();
            casterUi.WithExplicitStart();
        }
    }

    public static void AddAlloy(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.Alloy)
            return;

        var alloyDb = postgres.AddDatabase("alloyDb", "alloy");

        var alloyConnectionString = BuildConnectionString(builder, postgresPort, "alloy");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/alloy/alloy.api/Alloy.Api",
            "cmu-sei-crucible-alloy-api",
            alloyConnectionString);

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

        var alloyUi = builder.AddNpmApp("alloy-ui", alloyUiRoot)
                .WithHttpEndpoint(port: 4403, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();

        if (!options.Alloy)
        {
            alloyApi.WithExplicitStart();
            alloyUi.WithExplicitStart();
        }
    }

    public static void AddTopoMojo(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.TopoMojo)
            return;

        var topoDb = postgres.AddDatabase("topoDb", "topomojo");

        var topoConnectionString = BuildConnectionString(builder, postgresPort, "topomojo");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/topomojo/topomojo/src/TopoMojo.Api",
            "cmu-sei-crucible-topomojo-api",
            topoConnectionString);

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

        var topoUi = builder.AddNpmApp("topomojo-ui", topoUiRoot, args: ["topomojo-work"])
            .WithHttpEndpoint(port: 4201, env: "PORT", isProxied: false)
            .WithNpmPackageInstallation();

        if (!options.TopoMojo)
        {
            topoApi.WithExplicitStart();
            topoUi.WithExplicitStart();
        }
    }

    public static void AddSteamfitter(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.Steamfitter)
            return;

        var steamfitterDb = postgres.AddDatabase("steamfitterDb", "steamfitter");

        var steamfitterConnectionString = BuildConnectionString(builder, postgresPort, "steamfitter");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/steamfitter/steamfitter.api/Steamfitter.Api",
            "cmu-sei-crucible-steamfitter-api",
            steamfitterConnectionString);

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

        var steamfitterUi = builder.AddNpmApp("steamfitter-ui", steamfitterUiRoot)
                .WithHttpEndpoint(port: 4401, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();

        if (!options.Steamfitter)
        {
            steamfitterApi.WithExplicitStart();
            steamfitterUi.WithExplicitStart();
        }
    }

    public static void AddCite(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.Cite)
            return;

        var citeDb = postgres.AddDatabase("citeDb", "cite");

        var citeConnectionString = BuildConnectionString(builder, postgresPort, "cite");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/cite/cite.api/Cite.Api",
            "cmu-sei-crucible-cite-api",
            citeConnectionString);

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
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "openid profile email cite gallery")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

        var citeUiRoot = "/mnt/data/crucible/cite/cite.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/cite.ui.json", $"{citeUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var citeUi = builder.AddNpmApp("cite-ui", citeUiRoot)
                .WithHttpEndpoint(port: 4721, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();
        if (!options.Cite)
        {
            citeApi.WithExplicitStart();
            citeUi.WithExplicitStart();
        }
    }

    public static void AddGallery(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.Gallery)
            return;

        var galleryDb = postgres.AddDatabase("galleryDb", "gallery");

        var galleryConnectionString = BuildConnectionString(builder, postgresPort, "gallery");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/gallery/gallery.api/Gallery.Api",
            "cmu-sei-crucible-gallery-api",
            galleryConnectionString);

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

        var galleryUi = builder.AddNpmApp("gallery-ui", galleryUiRoot)
                .WithHttpEndpoint(port: 4723, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();

        if (!options.Gallery)
        {
            galleryApi.WithExplicitStart();
            galleryUi.WithExplicitStart();
        }
    }

    public static void AddBlueprint(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.Blueprint)
            return;

        var blueprintDb = postgres.AddDatabase("blueprintDb", "blueprint");

        var blueprintConnectionString = BuildConnectionString(builder, postgresPort, "blueprint");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/blueprint/blueprint.api/Blueprint.Api",
            "cmu-sei-crucible-blueprint-api",
            blueprintConnectionString);

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

        var blueprintUi = builder.AddNpmApp("blueprint-ui", blueprintUiRoot)
                .WithHttpEndpoint(port: 4725, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();

        if (!options.Blueprint)
        {
            blueprintApi.WithExplicitStart();
            blueprintUi.WithExplicitStart();
        }
    }

    public static void AddGameboard(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll, int postgresPort)
    {
        if (!addAll && !options.Gameboard)
            return;

        var gameboardDb = postgres.AddDatabase("gameboardDb", "gameboard");

        var gameboardConnectionString = BuildConnectionString(builder, postgresPort, "gameboard");
        WriteApiDevelopmentSettings(
            "/mnt/data/crucible/gameboard/gameboard/src/Gameboard.Api",
            "cmu-sei-crucible-gameboard-api",
            gameboardConnectionString);

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

        var gameboardUi = builder.AddNpmApp("gameboard-ui", gameboardUiRoot)
            .WithHttpEndpoint(port: 4202, env: "PORT", isProxied: false)
            .WithNpmPackageInstallation();

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
            .WithBindMount("/mnt/data/crucible/moodle/tool_lptmanager", "/var/www/html/admin/tool/lptmanager", isReadOnly: true);
    }

    public static void AddLrsql(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, int postgresPort)
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
            .WithEnvironment("LRSQL_DB_PORT", postgresPort.ToString())
            .WithEnvironment("LRSQL_DB_NAME", lrsqlDb.Resource.DatabaseName);
    }

    private static string BuildConnectionString(IDistributedApplicationBuilder builder, int postgresPort, string databaseName)
    {
        var postgresPassword = builder.Configuration["Parameters:postgres-password"] ?? "this-should-never-get-used";
        return $"Server=localhost;Port={postgresPort};Database={databaseName};Username=postgres;Password={postgresPassword};Keepalive=1;";
    }

    private static void WriteApiDevelopmentSettings(
        string apiProjectPath,
        string userSecretsId,
        string connectionString)
    {
        AddUserSecretsIdToProject(apiProjectPath, userSecretsId);
        try
        {
            // Set user secrets using dotnet user-secrets
            SetUserSecret(apiProjectPath, "ConnectionStrings:PostgreSQL", connectionString);
            SetUserSecret(apiProjectPath, "Database:Provider", "PostgreSQL");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to create configuration for {apiProjectPath}: {ex.Message}");
        }
    }

    private static void AddUserSecretsIdToProject(string projectPath, string userSecretsId)
    {
        // Find the .csproj file in the project directory
        var projectFiles = Directory.GetFiles(projectPath, "*.csproj");
        if (projectFiles.Length == 0)
        {
            Console.WriteLine($"Warning: No .csproj file found in {projectPath}");
            return;
        }

        var projectFile = projectFiles[0];
        var doc = System.Xml.Linq.XDocument.Load(projectFile);
        var ns = doc.Root?.Name.Namespace ?? System.Xml.Linq.XNamespace.None;

        // Check if UserSecretsId already exists
        var existingUserSecretsId = doc.Descendants(ns + "UserSecretsId").FirstOrDefault();
        if (existingUserSecretsId == null)
        {
            // Find or create a PropertyGroup to add UserSecretsId
            var propertyGroup = doc.Descendants(ns + "PropertyGroup").FirstOrDefault();
            if (propertyGroup == null)
            {
                // Create a new PropertyGroup
                propertyGroup = new System.Xml.Linq.XElement(ns + "PropertyGroup");
                doc.Root?.Add(propertyGroup);
            }

            // Add UserSecretsId to the PropertyGroup
            propertyGroup.Add(new System.Xml.Linq.XElement(ns + "UserSecretsId", userSecretsId));
        }

        doc.Save(projectFile);
    }

    private static void SetUserSecret(string projectPath, string key, string value)
    {
        try
        {
            var process = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = "dotnet",
                Arguments = $"user-secrets set \"{key}\" \"{value}\"",
                WorkingDirectory = projectPath,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            });

            process?.WaitForExit();

            if (process?.ExitCode != 0 && process is not null)
            {
                var error = process.StandardError.ReadToEnd();
                Console.WriteLine($"Warning: Failed to set user secret {key} for {projectPath}: {error}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to set user secret {key} for {projectPath}: {ex.Message}");
        }
    }
}
