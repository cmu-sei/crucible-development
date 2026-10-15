// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). OPTIONAL. Destination: <Tests>/Support/ServiceTestBase.cs, with
// ApiTestHost.template.cs. Adopt it only when tests must construct a service with options a test chose,
// which the hosted application reads once from configuration for the whole run (player.api's
// FileService upload limits, xAPI settings). Anything with a request to send belongs on ApiTestBase. The
// cost is that ApiTestHost re-declares registrations Startup makes, so a repo that adopts it also keeps
// an ApiTestHostTests that constructs every handler and service through the container, so a missing
// registration fails one test by name. The container runs no authentication handler and no claims
// transformer, so its tests build principals with ClaimsPrincipalBuilder's typed steps, and the real
// authorization service and handlers read them (CONVENTIONS.md section 1, "Never fake authorization").
// Substitute AppDbContext and the system permission enum.

using System.Security.Claims;
using App.Api.Data.Models;

namespace App.Api.Tests.Support;

/// <summary>Base class for tests that resolve a service out of a container built for one principal.</summary>
/// <remarks>
/// A host is built per principal and reused, so services resolved as the same user share one container
/// and one change tracker, which a sequence of production requests would not. Re-read through
/// <c>NewContext()</c> where that matters. Substitutes in an <see cref="ApiTestHost"/> are fine: the host
/// belongs to the test that built it.
/// </remarks>
public abstract class ServiceTestBase(DatabaseFixture fixture) : DatabaseTestBase(fixture)
{
    private readonly Dictionary<ClaimsPrincipal, ApiTestHost> _hosts = [];
    private ClaimsPrincipal _root;

    /// <summary>A principal holding every system permission.</summary>
    protected ClaimsPrincipal Root => _root ??= new ClaimsPrincipalBuilder()
        .WithSystemPermissions(Enum.GetValues<SystemPermission>())
        .Build();

    protected ApiTestHost RootHost => HostFor(Root);

    /// <summary>
    /// The host for <paramref name="user"/>. Asking for options against a principal already hosted
    /// throws, because they could not take effect; build a principal per configuration.
    /// </summary>
    protected ApiTestHost HostFor(ClaimsPrincipal user, Action<ApiTestHostOptions> configure = null)
    {
        if (_hosts.TryGetValue(user, out var host))
        {
            if (configure != null)
            {
                throw new InvalidOperationException(
                    "A host for this principal has already been built, so these options would be " +
                    "ignored. Build a distinct principal for each configuration.");
            }

            return host;
        }

        host = ApiTestHost.Create(Db, user, configure);
        _hosts.Add(user, host);

        return host;
    }

    public override async ValueTask DisposeAsync()
    {
        foreach (var host in _hosts.Values)
        {
            host.Dispose();
        }

        await base.DisposeAsync();
    }
}
