// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/ClaimsPrincipalBuilder.cs. For tests of the
// authorization stack itself (requirement handlers, the authorization service, the claims service) and
// for service tests on ServiceTestBase, whose container runs no claims transformer, so the principal
// stands for its output (CONVENTIONS.md section 1, "Never fake authorization"). Never for an HTTP test's
// caller (that is TestActor). Mirror the claim shapes the app's claims transformer produces: the claim
// type constants from AuthorizationConstants, one claim per system permission, and one serialized claim
// per resource membership (player.api's TeamPermissionsClaim, cite.api's EvaluationPermissionClaim, ...).
// Keep WithRaw* and WithClaim: they produce shapes the transformer cannot (an unparseable value), which is
// why handler tests keep this builder. Service tests use only the typed steps for permissions.

using System.Security.Claims;
using App.Api.Data.Models;
using App.Api.Infrastructure.Authorization;

namespace App.Api.Tests.Support;

/// <summary>Builds the principal the authorization stack sees for a signed-in user.</summary>
public sealed class ClaimsPrincipalBuilder
{
    private readonly List<Claim> _claims = [];
    private Guid _userId = Guid.NewGuid();
    private string _name = "Test User";

    public Guid UserId => _userId;

    public ClaimsPrincipalBuilder WithUserId(Guid userId)
    {
        _userId = userId;
        return this;
    }

    public ClaimsPrincipalBuilder WithName(string name)
    {
        _name = name;
        return this;
    }

    /// <summary>Adds system permissions, which grant across every resource.</summary>
    public ClaimsPrincipalBuilder WithSystemPermissions(params SystemPermission[] permissions)
    {
        foreach (var permission in permissions)
        {
            _claims.Add(new Claim(AuthorizationConstants.PermissionClaimType, permission.ToString()));
        }

        return this;
    }

    /// <summary>A raw system-permission value, for values that are not enum names.</summary>
    public ClaimsPrincipalBuilder WithRawSystemPermission(string value)
    {
        _claims.Add(new Claim(AuthorizationConstants.PermissionClaimType, value));
        return this;
    }

    // public ClaimsPrincipalBuilder With<Resource>(Guid resourceId, params <Resource>Permission[] permissions)

    /// <summary>An arbitrary claim, for asserting that unrelated claim types are ignored.</summary>
    public ClaimsPrincipalBuilder WithClaim(string type, string value)
    {
        _claims.Add(new Claim(type, value));
        return this;
    }

    public ClaimsPrincipal Build()
    {
        var claims = new List<Claim>(_claims) { new("sub", _userId.ToString()), new("name", _name) };

        return new ClaimsPrincipal(new ClaimsIdentity(claims, "Test"));
    }

    /// <summary>An authenticated principal with no permissions, the baseline every check must reject.</summary>
    public static ClaimsPrincipal Anonymous() => new ClaimsPrincipalBuilder().Build();
}
