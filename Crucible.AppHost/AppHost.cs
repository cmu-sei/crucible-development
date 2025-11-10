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

var postgres = builder.AddPostgres("postgres")
    .WithDataVolume()
    .WithLifetime(ContainerLifetime.Persistent)
    .WithContainerName("crucible-postgres")
    .WithPgAdmin();

var keycloakDb = postgres.AddDatabase("keycloakDb", "keycloak");
var keycloak = builder.AddKeycloak("keycloak", 8080)
    .WithReference(keycloakDb)
    // Configure environment variables for the PostgreSQL connection
    .WithEnvironment("KC_DB", "postgres")
    .WithEnvironment("KC_DB_URL_HOST", postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
    .WithEnvironment("KC_DB_USERNAME", postgres.Resource.UserNameReference)
    .WithEnvironment("KC_DB_PASSWORD", postgres.Resource.PasswordParameter)
    .WithEnvironment("KC_HOSTNAME", "localhost")
    .WithEnvironment("KC_HOSTNAME_PORT", "8080")
    .WithEnvironment("KC_HOSTNAME_STRICT", "false")
    .WithRealmImport($"{builder.AppHostDirectory}/resources/crucible-realm.json");

var mkdocs = builder.AddContainer("mkdocs", "squidfunk/mkdocs-material")
    .WithBindMount("/mnt/data/crucible/crucible-docs", "/docs", isReadOnly: true)
    .WithHttpEndpoint(port: 8000, targetPort: 8000)
    .WithArgs("serve", "-a", "0.0.0.0:8000");

<<<<<<< HEAD
builder.AddPlayer(postgres, keycloak, launchOptions, addAllApplications);
builder.AddCaster(postgres, keycloak, launchOptions, addAllApplications);
builder.AddAlloy(postgres, keycloak, launchOptions, addAllApplications);
builder.AddTopoMojo(postgres, keycloak, launchOptions, addAllApplications);
builder.AddSteamfitter(postgres, keycloak, launchOptions, addAllApplications);
builder.AddCite(postgres, keycloak, launchOptions, addAllApplications);
builder.AddGallery(postgres, keycloak, launchOptions, addAllApplications);
builder.AddBlueprint(postgres, keycloak, launchOptions, addAllApplications);
builder.AddGameboard(postgres, keycloak, launchOptions, addAllApplications);
=======
builder.AddPlayer(postgres, keycloak, launchOptions);
builder.AddCaster(postgres, keycloak, launchOptions);
builder.AddAlloy(postgres, keycloak, launchOptions);
builder.AddTopoMojo(postgres, keycloak, launchOptions);
builder.AddSteamfitter(postgres, keycloak, launchOptions);
builder.AddCite(postgres, keycloak, launchOptions);
builder.AddGallery(postgres, keycloak, launchOptions);
builder.AddBlueprint(postgres, keycloak, launchOptions);
builder.AddMoodle(postgres, keycloak, launchOptions);
>>>>>>> 78f16c0 (adds initial moodle container)

builder.Build().Run();

public static class BuilderExtensions
{
    public static void AddPlayer(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.Player)
            return;

        var playerDb = postgres.AddDatabase("playerDb", "player");

        var playerApi = builder.AddProject<Projects.Player_Api>("player-api", launchProfileName: "Player.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(playerDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
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
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
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

    public static void AddCaster(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.Caster)
            return;

        var casterDb = postgres.AddDatabase("casterDb", "caster");

        var casterApi = builder.AddProject<Projects.Caster_Api>("caster-api", launchProfileName: "Caster.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(casterDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
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

    public static void AddAlloy(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.Alloy)
            return;

        var alloyDb = postgres.AddDatabase("alloyDb", "alloy");

        var alloyApi = builder.AddProject<Projects.Alloy_Api>("alloy-api", launchProfileName: "Alloy.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(alloyDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "alloy.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("ResourceOwnerAuthorization__ClientId", "alloy.admin")
            .WithEnvironment("ResourceOwnerAuthorization__ClientSecret", "gn3D1s0UKCeqUB5ZjtN0aZsStiJjecRW")
            .WithEnvironment("ResourceOwnerAuthorization__UserName", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Password", "admin")
            .WithEnvironment("ResourceOwnerAuthorization__Scope", "player player-vm alloy steamfitter caster")
            .WithEnvironment("ResourceOwnerAuthorization__ValidateDiscoveryDocument", "false");

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

    public static void AddTopoMojo(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.TopoMojo)
            return;

        var topoDb = postgres.AddDatabase("topoDb", "topomojo");

        var topoApi = builder.AddProject<Projects.TopoMojo_Api>("topomojo")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            //.WithHttpHealthCheck("api/health/ready")
            .WithReference(topoDb, "PostgreSQL")
            .WithEnvironment("Database__ConnectionString", topoDb.Resource.ConnectionStringExpression)
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Oidc__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Oidc__Audience", "topomojo")
            .WithEnvironment("OpenApi__Client__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("OpenApi__Client__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("OpenApi__Client__ClientId", "topomojo.api")
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("ASPNETCORE_URLS", "http://localhost:5000")
            .WithEnvironment("Headers__Cors__Origins__0", "http://localhost:4201")
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

    public static void AddSteamfitter(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.Steamfitter)
            return;

        var steamfitterDb = postgres.AddDatabase("steamfitterDb", "steamfitter");

        var steamfitterApi = builder.AddProject<Projects.Steamfitter_Api>("steamfitter-api", launchProfileName: "Steamfitter.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(steamfitterDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__AuthorizationScope", "steamfitter player player-vm")
            .WithEnvironment("Authorization__ClientId", "steamfitter.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "http://localhost:8080/realms/crucible")
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

    public static void AddCite(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.Cite)
            return;

        var citeDb = postgres.AddDatabase("citeDb", "cite");

        var citeApi = builder.AddProject<Projects.Cite_Api>("cite-api", launchProfileName: "Cite.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(citeDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__AuthorizationScope", "cite")
            .WithEnvironment("Authorization__ClientId", "cite.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "http://localhost:8080/realms/crucible")
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

    public static void AddGallery(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.Gallery)
            return;

        var galleryDb = postgres.AddDatabase("galleryDb", "gallery");

        var galleryApi = builder.AddProject<Projects.Gallery_Api>("gallery-api", launchProfileName: "Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(galleryDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__AuthorizationScope", "gallery")
            .WithEnvironment("Authorization__ClientId", "gallery.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "http://localhost:8080/realms/crucible")
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

    public static void AddBlueprint(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.Blueprint)
            return;

        var blueprintDb = postgres.AddDatabase("blueprintDb", "blueprint");

        var blueprintApi = builder.AddProject<Projects.Blueprint_Api>("blueprint-api", launchProfileName: "Blueprint.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(blueprintDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "blueprint.api")
            .WithEnvironment("ResourceOwnerAuthorization__Authority", "http://localhost:8080/realms/crucible")
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

    public static void AddGameboard(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options, bool addAll)
    {
        if (!addAll && !options.Gameboard)
            return;

        var gameboardDb = postgres.AddDatabase("gameboardDb", "gameboard");

        var gameboardApi = builder.AddProject<Projects.Gameboard_Api>("gameboard", launchProfileName: "Project")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithReference(gameboardDb, "PostgreSQL")
            .WithEnvironment("Database__ConnectionString", gameboardDb.Resource.ConnectionStringExpression)
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Database__DevModeRecreate", "false")
            .WithEnvironment("PathBase", "")
            .WithEnvironment("Oidc__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Oidc__Audience", "gameboard")
            .WithEnvironment("OpenApi__Client__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("OpenApi__Client__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
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

        var moodle = builder.AddContainer("moodle", "erseco/alpine-moodle")
            .WithImageTag("v5.0.0")
            .WithEnvironment("DB_USER", postgres.Resource.UserNameReference)
            .WithEnvironment("DB_PASS", postgres.Resource.PasswordParameter)
            .WithEnvironment("DB_HOST", postgres.Resource.PrimaryEndpoint.Property(EndpointProperty.Host))
            .WithEnvironment("DB_NAME", moodleDb.Resource.DatabaseName)
            .WithEnvironment("POST_CONFIGURE_COMMANDS", @"
                    php /var/www/html/admin/cli/cfg.php --name=curlsecurityblockedhosts --unset;
                    php /var/www/html/admin/cli/cfg.php --name=curlsecurityallowedport --set=$'80\n443\n8080'")
            .WithHttpEndpoint(port: 80, targetPort: 8080)
            .WithBindMount("/mnt/data/crucible/moodle/block_crucible", "/var/www/html/blocks/crucible", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_crucible", "/var/www/html/mod/crucible", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/mod_groupquiz", "/var/www/html/mod/groupquiz", isReadOnly: true)
            //.WithBindMount("/mnt/data/crucible/moodle/mod_topomojo", "/var/www/html/mole/mod/topomojo", isReadOnly: true)
            //.WithBindMount("/mnt/data/crucible/moodle/qtype_mojomatch", "/var/www/html/question/type/mojomatch", isReadOnly: true)
            //.WithBindMount("/mnt/data/crucible/moodle/qbehaviour_mojomatch", "/var/www/html/question/behaviour/mojomatch", isReadOnly: true)
            .WithBindMount("/mnt/data/crucible/moodle/tool_lptmanager", "/var/www/html/admin/tool/lptmanager", isReadOnly: true);
    }
}
