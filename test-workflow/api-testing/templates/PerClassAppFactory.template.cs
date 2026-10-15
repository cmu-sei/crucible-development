// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). The per-class factory variant (blueprint.api and vm.api today): one host
// per test class, through IClassFixture<AppAppFactory>, for apps whose tests assert on NSubstitute
// doubles that the host resolves (generated clients of sibling APIs, a hypervisor client). A substitute is
// safe here because one class's tests run one after another: no other class's request can reach it. Use
// it only for that reason; everything that can be a recorder stays a recorder. Destination and
// substitutions as in AppFactory.template.cs, the scheme included (the plain registration or the Bearer
// recipe below it, never both). Do not list this factory in AssemblyFixtures.cs.
// Each test class declares: public class XTests(DatabaseFixture fixture, AppAppFactory factory)
//     : ApiTestBase(fixture, factory), IClassFixture<AppAppFactory>
// The host gets a throwaway database of its own for Program.Main's InitializeDatabase, as in the run-wide
// template's step 1B, and the two-argument ReplaceRegistration routes a resolution outside a request to
// it until the host has started. A repo whose tests resolve services off Factory.Services outside a
// request (blueprint.api's composition tests) may pass () => _hostSession instead, and says why here.
// Hub contexts are recorders, as in the run-wide template; a class whose tests connect real SignalR
// clients and assert what they receive keeps the real IHubContext for that hub (vm.api's ProgressHub) and
// says so here. Substitute only what leaves the process (CONVENTIONS.md section 1, "Substitutes in a
// per-class factory").

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
/// Hosts <c>App.Api</c> in process, once per test class, with the sibling-API clients substituted.
/// </summary>
/// <remarks>
/// Takes the run-wide <see cref="DatabaseFixture"/> (a class fixture may take assembly fixtures) and gives
/// the host its own throwaway database for <c>Program.Main</c>'s <c>InitializeDatabase</c>. Requests still
/// reach the database of the test that sent them, through <see cref="TestDatabaseScope"/>.
/// </remarks>
public sealed class AppAppFactory(DatabaseFixture database) : WebApplicationFactory<Program>, ITestHttpHost, IAsyncLifetime
{
    private ITestDatabaseSession<AppDbContext> _hostSession;

    /// <summary>Set once the host has started, which is after <c>Program.Main</c>'s <c>InitializeDatabase</c>.</summary>
    private volatile bool _started;

    // public ISiblingApiClient Sibling { get; } = Substitute.For<ISiblingApiClient>();

    public HubRecorder<AppHub> Hub { get; } = new();

    public StubHttpMessageHandler OutboundHttp { get; } = new();

    public async ValueTask InitializeAsync() => _hostSession = await database.BeginSessionAsync();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Production");
        builder.UseSetting("Database:Provider", "PostgreSQL");
        builder.UseSetting("ConnectionStrings:PostgreSQL", _hostSession.ConnectionString);

        builder.ConfigureAppConfiguration(configuration =>
            configuration.AddInMemoryCollection(TestConfiguration.Values));

        builder.ConfigureTestServices(services =>
        {
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

            // Outside a request, the host's own database until the host has started: Main's
            // InitializeDatabase seeds it, and its entity events go to that session's own mediator rather
            // than to the real handlers and this class's recorders.
            TestDatabaseScope.ReplaceRegistration<AppDbContext>(services, () => _started ? null : _hostSession);

            // services.Replace(ServiceDescriptor.Singleton(Sibling));
            services.AddSingleton<IHubContext<AppHub>>(Hub);
            services.RemoveAll<IHttpClientFactory>();
            services.AddSingleton<IHttpClientFactory>(new StubHttpClientFactory(OutboundHttp));
        });
    }

    /// <remarks>
    /// One class's tests run one after another, so nothing here races to build the host; the run-wide
    /// template's lock is not needed.
    /// </remarks>
    protected override IHost CreateHost(IHostBuilder builder)
    {
        var host = base.CreateHost(builder);
        _started = true;

        return host;
    }

    public override async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();

        if (_hostSession is not null)
        {
            await _hostSession.DisposeAsync();
        }
    }
}
