// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). OPTIONAL, with ServiceTestBase.template.cs. Destination:
// <Tests>/Support/ApiTestHost.cs. Mirror Startup.ConfigureServices for the services under test: MediatR
// over the API assembly (vertical-slice apps), the real AutoMapper profiles with their value resolvers,
// the current user over a real HttpContextAccessor, every options object as a singleton the test can
// change in ApiTestHostOptions, the app's services, the authorization handlers, and recorders or
// substitutes for the collaborators that leave the process (an ApiTestHost belongs to one test, so a
// substitute here is safe; a HubRecorder or a StubHttpMessageHandler of its own reads as the run-wide
// host's do). A service that opens scopes of its own (IServiceScopeFactory, a background service) needs a
// context per scope: take the test's session instead of its context, and register
// services.AddScoped(_ => session.CreateContext()), whose contexts the scopes dispose and whose entity
// events go to the test's Mediator (steamfitter.api). ServiceTestBase then passes Session instead of Db.

using System.Security.Claims;
using System.Security.Principal;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using App.Api.Data;

namespace App.Api.Tests.Support;

/// <summary>The application's services without the web host, over one test's database, as one user.</summary>
public sealed class ApiTestHost : IDisposable
{
    private readonly ServiceProvider _services;

    private ApiTestHost(ServiceProvider services) => _services = services;

    public T Resolve<T>() where T : notnull => _services.GetRequiredService<T>();

    public static ApiTestHost Create(AppDbContext db, ClaimsPrincipal user, Action<ApiTestHostOptions> configure = null)
    {
        var options = new ApiTestHostOptions();
        configure?.Invoke(options);

        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMemoryCache();

        // An instance rather than a factory: the test owns this context's lifetime. With a session
        // instead (services that open their own scopes): services.AddScoped(_ => session.CreateContext());
        services.AddSingleton(db);
        services.AddSingleton(TestMapper.Mapper);

        services.AddSingleton<IHttpContextAccessor>(
            new HttpContextAccessor { HttpContext = new DefaultHttpContext { User = user } });
        services.AddScoped<IPrincipal>(p => p.GetRequiredService<IHttpContextAccessor>().HttpContext.User);

        // services.AddSingleton(options.SomeOptions);
        // services.AddScoped<IXService, XService>();
        // services.AddSingleton(Substitute.For<IHubContext<AppHub>>());

        return new ApiTestHost(services.BuildServiceProvider());
    }

    public void Dispose() => _services.Dispose();
}

/// <summary>The configuration-backed options an <see cref="ApiTestHost"/> exposes, defaulted so every service runs.</summary>
public sealed class ApiTestHostOptions
{
}
