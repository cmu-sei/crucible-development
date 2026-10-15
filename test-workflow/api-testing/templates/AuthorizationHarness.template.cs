// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/AuthorizationHarness.cs. Wire the
// authorization stack the way Startup (or its AuthorizationPolicyExtension) does: the real
// IAuthorizationService plus every IAuthorizationHandler the app registers, so a handler test exercises
// the real handlers rather than asking a substitute whether it was asked. Name the app's own
// authorization service (IPlayerAuthorizationService, IAlloyAuthorizationService, the AuthorizationService
// the MVC apps call with requirement classes) and build it with real collaborators. HandleAsync stays
// as is: it returns the context so a test asserts HasSucceeded and HasFailed separately (they are not
// opposites). The file is required in every repo (sync.sh checks it); an app that registers no
// IAuthorizationHandler (vm.api asks player.api instead) keeps HandleAsync and the framework service with
// no handler lines, and says so in its replacement comment.

using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using App.Api.Infrastructure.Authorization;

namespace App.Api.Tests.Support;

/// <summary>The authorization stack wired as production wires it, for testing handlers directly.</summary>
public static class AuthorizationHarness
{
    /// <summary>The framework authorization service with the app's handlers registered.</summary>
    public static IAuthorizationService CreateFrameworkAuthorizationService()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddAuthorization();
        // services.AddSingleton<IAuthorizationHandler, SystemPermissionHandler>();
        // services.AddSingleton<IAuthorizationHandler, <Resource>PermissionHandler>();

        return services.BuildServiceProvider().GetRequiredService<IAuthorizationService>();
    }

    /// <summary>
    /// Runs a requirement through a handler directly and returns the resulting context.
    /// </summary>
    public static async Task<AuthorizationHandlerContext> HandleAsync<TRequirement>(
        IAuthorizationHandler handler,
        TRequirement requirement,
        ClaimsPrincipal user,
        object resource = null)
        where TRequirement : IAuthorizationRequirement
    {
        var context = new AuthorizationHandlerContext([requirement], user, resource);
        await handler.HandleAsync(context);

        return context;
    }
}
