// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/TestActorTests.cs. One test per actor shape
// TestActorBuilder offers, run through the app's real claims service over the seeded rows (not a
// request: a status code cannot tell an effective permission from a direct one). Keep the four below and
// add one per On<Resource>, InGroup and ...ThroughNewGroup step and per guard that throws, and for
// OnNew<Resource> one that the actor holds exactly the permissions passed (it fails if the minted resource's role grants anything, which is
// the point of the step; sketch below). verify.sh requires the class to exist and pass. Substitute the
// claims service and how it is constructed (read its constructor; build its options with caching off
// and roles-from-IdP off, as TestConfiguration does).

using System.Security.Claims;
using App.Api.Data.Models;
using App.Api.Infrastructure.Authorization;
using App.Api.Services;

namespace App.Api.Tests.Support;

/// <summary>Tests for <see cref="TestActorBuilder"/>: an actor that holds more than asked turns an authorization test into a formality.</summary>
public class TestActorTests(DatabaseFixture fixture) : DatabaseTestBase(fixture)
{
    [Fact]
    public async Task WithAllSystemPermissions_grants_every_system_permission()
    {
        var actor = await Actor().WithAllSystemPermissions().SeedAsync();

        Assert.Equal(Enum.GetNames<SystemPermission>().Order(), Permissions(await ClaimsOf(actor)));
    }

    [Fact]
    public async Task WithSystemPermissions_grants_exactly_what_it_names()
    {
        var first = Enum.GetValues<SystemPermission>()[0];
        var actor = await Actor().WithSystemPermissions(first).SeedAsync();

        Assert.Equal([first.ToString()], Permissions(await ClaimsOf(actor)));
    }

    [Fact]
    public async Task An_actor_with_no_role_holds_nothing()
    {
        var actor = await Actor().SeedAsync();

        Assert.Empty(Permissions(await ClaimsOf(actor)));
    }

    [Fact]
    public void WithRole_after_WithSystemPermissions_throws()
    {
        var builder = Actor().WithSystemPermissions(Enum.GetValues<SystemPermission>()[0]);

        Assert.Throws<InvalidOperationException>(() => builder.WithRole(TestData.Roles.Administrator));
    }

    // [Fact]
    // public async Task OnNew<Resource>_grants_exactly_what_it_names()
    // {
    //     var parent = TestData.<Parent>();
    //     await Seed(parent);
    //
    //     var actor = await Actor().OnNew<Resource>(parent.Id, permissions: [<one permission>]).SeedAsync();
    //
    //     Assert.Equal([<that permission>], <Resource>Permissions(await ClaimsOf(actor)));
    // }

    private TestActorBuilder Actor() => new(Db, Ct);

    private async Task<ClaimsPrincipal> ClaimsOf(TestActor actor)
    {
        await using var context = NewContext();
        // var service = new UserClaimsService(context, ...);
        // return await service.AddUserClaims(Principal(actor), update: false);
        throw new NotImplementedException("Construct the app's claims service here.");
    }

    private static string[] Permissions(ClaimsPrincipal principal) =>
        [.. principal.Claims
            .Where(x => x.Type == AuthorizationConstants.PermissionClaimType)
            .Select(x => x.Value)
            .Order()];
}
