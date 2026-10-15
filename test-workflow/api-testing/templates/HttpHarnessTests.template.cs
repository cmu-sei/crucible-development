// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/HttpHarnessTests.cs. Keep every test;
// verify.sh requires this class to exist and pass. Substitute a GET route every authenticated user may
// call but that needs a permission to return data (api/<resources>), the status the app answers a
// caller without that permission with (403 from the authorization service; some list endpoints filter
// to an empty 200 instead, in which case assert the empty list), the create route and body for the two
// concurrency probes, and the swagger path. In the per-class factory variant, add
// IClassFixture<AppAppFactory> to the class declaration.

using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;

namespace App.Api.Tests.Support;

/// <summary>
/// Tests for the HTTP harness itself: a harness that routes to the wrong database or authorizes everything
/// reads as a green suite.
/// </summary>
public class HttpHarnessTests(DatabaseFixture fixture, AppAppFactory factory) : ApiTestBase(fixture, factory)
{
    private const string SharedName = "Http Isolation Probe";

    [Fact]
    public async Task The_swagger_document_is_served()
    {
        await AssertStatus(HttpStatusCode.OK, await Client().GetAsync("/swagger/v1/swagger.json", Ct));
    }

    [Fact]
    public async Task A_request_with_no_identity_is_unauthorized()
    {
        await AssertStatus(HttpStatusCode.Unauthorized, await Client().GetAsync("api/resources", Ct));
    }

    /// <summary>The claims transformer ran and derived nothing, rather than the pipeline granting by default.</summary>
    [Fact]
    public async Task An_actor_with_no_permissions_is_forbidden()
    {
        var actor = await Actor().SeedAsync();

        await AssertStatus(HttpStatusCode.Forbidden, await Client(actor).GetAsync("api/resources", Ct));
    }

    /// <summary>The seeded administrator role becomes real claims, and the request reads this test's database.</summary>
    [Fact]
    public async Task Root_reads_what_the_test_seeded()
    {
        var response = await RootClient.GetAsync("api/users", Ct);

        var users = await ReadAsync<List<IdOnly>>(response);
        Assert.Contains(Root.Id, users.Select(x => x.Id));
    }

    [Fact]
    public Task Concurrent_tests_share_the_host_but_not_the_database_first() => CreateSharedNameResource();

    [Fact]
    public Task Concurrent_tests_share_the_host_but_not_the_database_second() => CreateSharedNameResource();

    private async Task CreateSharedNameResource()
    {
        var response = await RootClient.PostAsJsonAsync("api/resources", new { name = SharedName }, Ct);

        await AssertStatus(HttpStatusCode.Created, response);

        await using var context = NewContext();
        Assert.Equal(1, await context.Resources.CountAsync(x => x.Name == SharedName, Ct));
    }

    private sealed record IdOnly(Guid Id);
}
