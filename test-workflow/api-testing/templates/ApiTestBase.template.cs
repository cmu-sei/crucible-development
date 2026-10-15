// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/ApiTestBase.cs. Substitute AppDbContext,
// AppAppFactory and the namespaces. The HTTP helpers and the per-test database routing come from the
// shared ApiTestBase<TContext>; this class adds the app's actors. Keep Root, RootClient, Actor() and
// Client(actor) with these names in every repo. Root is the seeded all-permissions actor: point
// WithAllSystemPermissions at the seeded administrator role (TestData.Roles.Administrator). In the
// per-class factory variant the constructor is the same, and test classes add
// IClassFixture<AppAppFactory> to receive the factory. App-specific additions, only where the app needs
// them: an MVC app whose JsonExceptionFilter answers application/json uses the shared AssertJsonError
// rather than a copy; an app whose AddJsonOptions adds converters keeps them in one
// JsonSerializerOptions field and hides ReadAsync with
//     protected static new Task<TValue> ReadAsync<TValue>(HttpResponseMessage response) => ReadAsync<TValue>(response, AppJson);
// and an app that forwards the caller's bearer token to sibling APIs (alloy.api) sets it in Client(actor):
//     client.DefaultRequestHeaders.Authorization ??= new("Bearer", actor.Id.ToString());
// (the value TestAuthentication:UserFromBearer would read back as the same user).

using App.Api.Data;

namespace App.Api.Tests.Support;

/// <summary>
/// Base class for tests that drive the application over HTTP: the real routes, the real middleware, the
/// real claims transformer, the real handlers, over a database no other test can see.
/// </summary>
/// <remarks>
/// Derived classes forward both fixtures:
/// <c>MyTests(DatabaseFixture fixture, AppAppFactory factory) : ApiTestBase(fixture, factory)</c>.
/// </remarks>
public abstract class ApiTestBase(DatabaseFixture fixture, AppAppFactory factory)
    : ApiTestBase<AppDbContext>(fixture, factory)
{
    protected DatabaseFixture Fixture { get; } = fixture;

    protected AppAppFactory Factory { get; } = factory;

    /// <summary>
    /// An actor holding every system permission, for the tests that are about what an endpoint does
    /// rather than who may call it. Seeded before each test.
    /// </summary>
    protected TestActor Root { get; private set; } = null!;

    /// <summary>A client that acts as <see cref="Root"/>.</summary>
    protected HttpClient RootClient => Client(Root);

    /// <summary>Starts describing an actor to seed: <c>await Actor().WithSystemPermissions(...).SeedAsync()</c>.</summary>
    protected TestActorBuilder Actor() => new(Db, Ct);

    /// <summary>A client that acts as <paramref name="actor"/>, cached per actor.</summary>
    protected HttpClient Client(TestActor actor)
    {
        ArgumentNullException.ThrowIfNull(actor);

        return ClientFor(actor.Id, actor.Name);
    }

    public override async ValueTask InitializeAsync()
    {
        await base.InitializeAsync();

        Root = await Actor().WithName("Root").WithAllSystemPermissions().SeedAsync();
    }
}
