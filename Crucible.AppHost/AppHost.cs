// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Crucible.AppHost;

var builder = DistributedApplication.CreateBuilder(args);

// builder.Configuration
//     .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
//     .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true)
//     .AddEnvironmentVariables();

LaunchOptions launchOptions = new();
builder.Configuration.GetSection("Launch").Bind(launchOptions);

var postgres = builder.AddPostgres("postgres")
    .WithDataVolume()
    .WithLifetime(ContainerLifetime.Persistent)
    .WithPgAdmin();

var keycloak = builder.AddKeycloak("keycloak", 8080)
    .WithLifetime(ContainerLifetime.Persistent)
    .WithRealmImport($"{builder.AppHostDirectory}/resources/crucible-realm.json");

builder.AddPlayer(postgres, keycloak, launchOptions);
builder.AddCaster(postgres, keycloak, launchOptions);
builder.AddAlloy(postgres, keycloak, launchOptions);
builder.AddTopoMojo(postgres, keycloak, launchOptions);

builder.Build().Run();

public static class BuilderExtensions
{
    public static void AddPlayer(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.Player) return;

        var playerDb = postgres.AddDatabase("playerDb", "player");

        var playerApi = builder.AddProject<Projects.Player_Api>("player-api", launchProfileName: "Player.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(playerDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "player.api");

        var playerUiRoot = "/mnt/data/crucible/player/player.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/player.ui.json", $"{playerUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var playerUi = builder.AddNpmApp("player-ui", playerUiRoot)
                .WithHttpEndpoint(port: 4301, env: "PORT", isProxied: false)
                .WithNpmPackageInstallation();

        builder.AddPlayerVm(postgres, keycloak);
    }

    private static void AddPlayerVm(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak)
    {
        var vmDb = postgres.AddDatabase("vmDb", "player_vm");
        var vmLoggingDb = postgres.AddDatabase("vmLoggingDb", "player_vm_logging");

        var vmApi = builder.AddProject<Projects.Player_Vm_Api>("player-vm-api", launchProfileName: "Player.Vm.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(vmDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
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
    }

    public static void AddCaster(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.Caster) return;

        var casterDb = postgres.AddDatabase("casterDb", "caster");

        var casterApi = builder.AddProject<Projects.Caster_Api>("caster-api", launchProfileName: "Caster.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(casterDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
            .WithEnvironment("Authorization__Authority", "http://localhost:8080/realms/crucible")
            .WithEnvironment("Authorization__AuthorizationUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/auth")
            .WithEnvironment("Authorization__TokenUrl", "http://localhost:8080/realms/crucible/protocol/openid-connect/token")
            .WithEnvironment("Authorization__ClientId", "caster.api");

        var casterUiRoot = "/mnt/data/crucible/caster/caster.ui";

        File.Copy($"{builder.AppHostDirectory}/resources/caster.ui.json", $"{casterUiRoot}/src/assets/config/settings.env.json", overwrite: true);

        var casterUi = builder.AddNpmApp("caster-ui", casterUiRoot)
            .WithHttpEndpoint(port: 4310, env: "PORT", isProxied: false)
            .WithNpmPackageInstallation();
    }

    public static void AddAlloy(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.Alloy) return;

        var alloyDb = postgres.AddDatabase("alloyDb", "alloy");

        var alloyApi = builder.AddProject<Projects.Alloy_Api>("alloy-api", launchProfileName: "Alloy.Api")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            .WithHttpHealthCheck("api/health/ready")
            .WithReference(alloyDb, "PostgreSQL")
            .WithEnvironment("Database__Provider", "PostgreSQL")
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
    }

    public static void AddTopoMojo(this IDistributedApplicationBuilder builder, IResourceBuilder<PostgresServerResource> postgres, IResourceBuilder<KeycloakResource> keycloak, LaunchOptions options)
    {
        if (!options.TopoMojo) return;

        var topoDb = postgres.AddDatabase("topoDb", "topomojo");

        var topoApi = builder.AddProject<Projects.TopoMojo_Api>("topomojo")
            .WaitFor(postgres)
            .WaitFor(keycloak)
            //.WithHttpHealthCheck("api/health/ready")
            .WithReference(topoDb, "PostgreSQL")
            .WithEnvironment("Database__ConnectionString", topoDb.Resource.ConnectionStringExpression)
            .WithEnvironment("Database__Provider", "PostgreSQL")
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
    }
}