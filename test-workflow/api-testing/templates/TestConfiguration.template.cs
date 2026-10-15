// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/TestConfiguration.cs. List only keys whose
// shipped appsettings.json value breaks or weakens a test run, each with a comment saying which. Of the
// entries below, open-api-only is step 1A's alone, and the claims-cache entry applies to every Crucible
// API with a claims cache (check the key name in the app's ClaimsTransformationOptions). There is no
// IdP-roles or IdP-groups entry: TestAuthHandler mints no realm_access, role or group claims, so
// UseRolesFromIdP and UseGroupsFromIdP have nothing to read and their shipped values neither break nor
// weaken a run (alloy.api removed the first with no effect; several writers dropped both). A test that adds such claims to cover that path sets what it needs itself. Typical app
// entries: Database:DevModeRecreate off (cite.api, or it drops the step 1B database), a limit small
// enough to exceed. Override a coherent group whole or not at all (in player.api, setting
// CorsPolicy:AllowAnyOrigin alone left SupportsCredentials in place and the host failed to start).
// TestAuthHandler's opt-ins (TestAuthentication:Issuer, TestAuthentication:UserFromBearer) go here too,
// each with the code path that reads it.

namespace App.Api.Tests.Support;

/// <summary>
/// The configuration the app factory layers over the application's own <c>appsettings.json</c>.
/// </summary>
/// <remarks>
/// <c>WebApplicationFactory</c> resolves the content root to the API project directory, so the shipped
/// configuration is already in force and only keys whose shipped value breaks or weakens a test run belong
/// here. Every entry states which.
/// </remarks>
internal static class TestConfiguration
{
    public static Dictionary<string, string> Values => new()
    {
        // Only for the factory's step 1A: the switch Program.Main and Startup gate InitializeDatabase and
        // the hosted services on. Delete for step 1B.
        ["open-api-only"] = "true",

        // One host serves the whole run, and the claims cache is keyed on user id alone, so cached claims
        // would leak across tests: a user whose permissions one test seeds would keep them in the next
        // test that uses the same id. A test whose subject is the cache drives it directly.
        ["ClaimsTransformation:EnableCaching"] = "false",
    };
}
