// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). The run-wide factory, one host for the whole run (player.api's shape,
// the default). Destination: <Tests>/Support/<App>AppFactory.cs (PlayerAppFactory, CiteAppFactory, ...).
// Use PerClassAppFactory.template.cs instead only when tests must assert on NSubstitute doubles that the
// host resolves (blueprint.api's four sibling API clients); see CONVENTIONS.md section 4.
// Substitute:
// - Program, or Startup when the API has no Program class the factory can name (every Crucible API has
//   Program.Main -> CreateWebHostBuilder(args) -> UseStartup<Startup>; either works as the type argument).
// - AppDbContext, and every IHubContext<THub> the app registers (one Hub<THub>() line each).
// - The collaborators that leave the process: each becomes a recorder or a stub fixed at construction
//   (HubRecorder<THub>, StubHttpClientFactory over OutboundHttp, an app recorder like player.api's
//   WebhookRecorder). Never Substitute.For in this class: it is one instance for the whole run
//   (check-repo.js fails it).
// - The database gate, step 1 below: pick A or B and delete the other. 1B has three parts: the two
//   UseSetting lines, the two-argument ReplaceRegistration, and the _started flag CreateHost sets (1A
//   deletes _started and its assignment, which would otherwise be warning CS0414).
// - Keep CreateHost, with its lock, in every run-wide factory (README, "Known pitfalls").
// - The scheme: keep the plain TestAuthHandler registration, or, where a hub or controller names its
//   scheme ("Bearer"), the Bearer recipe below it; delete the other.
// No Crucible API's Program matches the CreateHostBuilder convention HostFactoryResolver looks for, so
// WebApplicationFactory falls back to invoking Program.Main on a background thread, and Main runs
// InitializeDatabase. That is why step 1 exists.

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using App.Api.Data;
using App.Api.Hubs;

namespace App.Api.Tests.Support;

/// <summary>
/// Hosts <c>App.Api</c> in process over <c>TestServer</c>, so that tests drive the real application: the
/// real <c>Startup</c>, the real middleware chain, the real authorization stack and the real claims
/// transformer.
/// </summary>
/// <remarks>
/// One instance serves the whole run, declared in <c>AssemblyFixtures.cs</c>. Everything the application
/// registers as a singleton is therefore shared by every test, which is what
/// <see cref="TestConfiguration"/>'s claims-caching entry and <see cref="TestDatabaseScope"/> exist to
/// deal with. Only three things are not the application's own: token validation
/// (<see cref="TestAuthHandler"/>), the context registration (<see cref="TestDatabaseScope"/>), and the
/// collaborators that leave the process.
/// </remarks>
public sealed class AppAppFactory : WebApplicationFactory<Program>, ITestHttpHost
{
    /// <summary>Answers every request the application makes over HTTP. Arrange a url of your own on it.</summary>
    public StubHttpMessageHandler OutboundHttp { get; } = new();

    private readonly System.Collections.Concurrent.ConcurrentDictionary<Type, object> _hubs = new();

    /// <summary>What the application broadcast through a hub, per audience.</summary>
    public HubRecorder<THub> Hub<THub>() where THub : Hub =>
        (HubRecorder<THub>)_hubs.GetOrAdd(typeof(THub), _ => new HubRecorder<THub>());

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Production, so the developer exception page stays off and the application's own exception
        // middleware or filter answers as it does in a deployment. (blueprint.api runs Development
        // because its JsonExceptionFilter puts the message in the 500 body only there; say so if you
        // copy that.)
        builder.UseEnvironment("Production");

        // 1A. The application has a production switch that skips InitializeDatabase in Program.Main
        //     (player.api's open-api-only). Host settings reach Main as --key=value, so set it here as
        //     well as in TestConfiguration.
        builder.UseSetting("open-api-only", "true");

        // 1B. No such switch: Main's InitializeDatabase needs a real database to migrate and seed. Give
        //     the host a throwaway database cloned from the template (migrating it is then a no-op), and
        //     delete 1A (here and in TestConfiguration). Host settings, because Main reads them before the
        //     in-memory collection below is layered in:
        // builder.UseSetting("Database:Provider", "PostgreSQL");
        // builder.UseSetting("ConnectionStrings:PostgreSQL", DatabaseFixture.HostDatabase().ConnectionString);

        builder.ConfigureAppConfiguration(configuration =>
            configuration.AddInMemoryCollection(TestConfiguration.Values));

        builder.ConfigureTestServices(services =>
        {
            // Hosted services start in the background and reach for databases and services no test owns.
            // Each gets a test of its own that drives it directly.
            services.RemoveAll<IHostedService>();

            services
                .AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, null);

            // The Bearer recipe, instead of the registration above, where a hub or controller names its
            // scheme ([Authorize(AuthenticationSchemes = "Bearer")]: every Crucible hub but caster.api's),
            // so a real-connection test authenticates through it. Startup's AddJwtBearer has claimed the
            // name "Bearer", AddScheme refuses a duplicate, and every registration that configures
            // AuthenticationOptions (AddAuthentication's default scheme, AddJwtBearer's scheme) is one
            // IConfigureOptions<AuthenticationOptions>, so drop them all first (alloy.api, blueprint.api,
            // cite.api). With it, add using Microsoft.AspNetCore.Authentication.JwtBearer and
            // Microsoft.Extensions.Options (the API already references the JwtBearer package).
            //
            // services.RemoveAll<IConfigureOptions<AuthenticationOptions>>();
            // services
            //     .AddAuthentication(TestAuthHandler.SchemeName)
            //     .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, null)
            //     .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(JwtBearerDefaults.AuthenticationScheme, null);

            TestDatabaseScope.ReplaceRegistration<AppDbContext>(services);

            // 1B instead of the line above. InitializeDatabase resolves the context from a scope of its
            // own, outside any request, where the one-argument registration has no X-Test-Session header
            // to route by and throws. Until the host has started, such a resolution gets the host's own
            // database, over that session's own services, so the seed's entity events never reach the
            // real handlers or a recorder; afterwards it throws again, so a stray resolution outside a
            // request still fails loudly.
            // TestDatabaseScope.ReplaceRegistration<AppDbContext>(
            //     services, () => _started ? null : DatabaseFixture.HostDatabase());

            // SignalR registers hub contexts as an open generic, which RemoveAll of a closed type cannot
            // match; a later closed registration wins on resolution.
            services.AddSingleton<IHubContext<AppHub>>(Hub<AppHub>());

            // A named client whose base address production configures (AddHttpClient(name, configure)) loses
            // it when the factory is replaced; name it here: new StubHttpClientFactory(OutboundHttp,
            // new Dictionary<string, Uri> { ["gitlab"] = new("http://gitlab.test/api/v4/") }).
            services.RemoveAll<IHttpClientFactory>();
            services.AddSingleton<IHttpClientFactory>(new StubHttpClientFactory(OutboundHttp));
        });
    }

    private readonly System.Threading.Lock _creating = new();
    private IHost _host;

    /// <summary>Set once the host has started, which is after <c>Program.Main</c>'s <c>InitializeDatabase</c>.</summary>
    private volatile bool _started;

    /// <summary>Builds the one host, under a lock, and hands it to every caller.</summary>
    /// <remarks>
    /// <c>WebApplicationFactory.StartServer</c> takes no lock, so two tests asking for their first client at
    /// once would each build a host (each running <c>Program.Main</c>), and the run would continue on two
    /// of them. Every way into the host (<c>CreateClient</c> in any overload, <c>Services</c>,
    /// <c>Server</c>) goes through <c>StartServer</c> to here, so this lock covers them all. A lock around
    /// <c>CreateClient()</c> alone would not: <c>Services</c>, <c>Server</c> and
    /// <c>CreateClient(options)</c> bypass it. <c>base.CreateHost</c> returns once the host has started,
    /// and the deferred host starts only after <c>Main</c> has run <c>InitializeDatabase</c>.
    /// </remarks>
    protected override IHost CreateHost(IHostBuilder builder)
    {
        lock (_creating)
        {
            if (_host is null)
            {
                _host = base.CreateHost(builder);
                _started = true;
            }

            return _host;
        }
    }
}
