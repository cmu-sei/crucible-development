// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/<App>ContextFactory.cs (PlayerContextFactory,
// CiteContextFactory, ...). Substitute AppDbContext. Check the context's constructor: most take only
// DbContextOptions<T>; one that takes more (an options object, a sanitizer interceptor) gets it here,
// built the way Startup builds it. If production adds interceptors besides EntityEventInterceptor
// (blueprint.api's SanitizerInterceptor), add them here too, in the same order, so a test context saves
// exactly as a request does.

using Crucible.Common.EntityEvents.Interceptors;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using App.Api.Data;

namespace App.Api.Tests.Support;

/// <summary>Builds <see cref="AppDbContext"/> instances wired the way production wires them.</summary>
/// <remarks>
/// <see cref="AppDbContext"/> extends <c>EventPublishingDbContext</c>, whose <c>PublishEventsAsync</c>
/// resolves <see cref="IMediator"/> and a logger off the settable <c>ServiceProvider</c> property with
/// <c>GetRequiredService</c>. Both must be registered or the first event-publishing save throws.
/// </remarks>
internal static class AppContextFactory
{
    /// <summary>
    /// The provider a session shares across its contexts, and the substituted mediator tests assert on.
    /// A substitute is right here: each session gets its own, and only its own test reads it.
    /// </summary>
    public static (IServiceProvider Services, IMediator Mediator) CreateServices()
    {
        var mediator = Substitute.For<IMediator>();

        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton(mediator);

        return (services.BuildServiceProvider(), mediator);
    }

    /// <summary>
    /// A context over the given provider configuration, with the entity event interceptor attached so
    /// SaveChanges publishes events exactly as it does in production.
    /// </summary>
    public static AppDbContext CreateContext(
        Action<DbContextOptionsBuilder<AppDbContext>> configureProvider,
        IServiceProvider services)
    {
        var builder = new DbContextOptionsBuilder<AppDbContext>();
        configureProvider(builder);
        builder.AddInterceptors(new EntityEventInterceptor(NullLogger<EntityEventInterceptor>.Instance));

        return new AppDbContext(builder.Options) { ServiceProvider = services };
    }
}
