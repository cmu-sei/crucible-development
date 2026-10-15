// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/DatabaseFixture.cs. Substitute:
// - AppDbContext: the EventPublishingDbContext subclass (PlayerContext, AlloyContext, CasterContext,
//   CiteContext, GalleryDbContext, SteamfitterContext, BlueprintContext, VmContext).
// - Name: the lower-case app name, the prefix of every test database (player, cite, ...).
// - TestAssembly: the test assembly name; it opens the banner CI greps for.
// - MigrationsAssembly: "App.Api.Migrations.PostgreSQL" where migrations live in their own project
//   (alloy, blueprint, cite, gallery, player, steamfitter); delete the line where they live in the
//   context's assembly (caster, vm).
// The class stays a thin wrapper: the mechanics are the shared PostgresTestDatabase. An app with a second
// database (vm.api's VmLoggingContext) adds a second PostgresTestDatabase<TOther> here with its own Name
// and exposes a second BeginSessionAsync; say so in the repo's docs/Testing.md.

using App.Api.Data;

namespace App.Api.Tests.Support;

/// <summary>
/// Owns the PostgreSQL database for the whole test run: starts it on first use and hands out an isolated
/// session per test.
/// </summary>
/// <remarks>
/// PostgreSQL exercises production's actual database, including the <c>if (Database.IsNpgsql())</c>
/// branch of <c>AppDbContext.OnModelCreating</c> and the real migration history. A usable Docker daemon
/// is therefore required by every test that takes a database.
/// </remarks>
public sealed class DatabaseFixture : IAsyncLifetime, ITestDatabaseSessionSource<AppDbContext>
{
    private readonly PostgresTestDatabase<AppDbContext> _database = new(new()
    {
        Name = "app",
        TestAssembly = "App.Api.Tests",
        // Production computes this as {AssemblyName}.Migrations.{provider} in
        // DatabaseExtensions. Without it EF looks in the context's own assembly and finds none.
        MigrationsAssembly = "App.Api.Migrations.PostgreSQL",
        CreateContext = AppContextFactory.CreateContext,
        CreateServices = AppContextFactory.CreateServices
    });

    /// <summary>Nothing to do here: the container starts on the first request for a session.</summary>
    public ValueTask InitializeAsync() => ValueTask.CompletedTask;

    public Task<ITestDatabaseSession<AppDbContext>> BeginSessionAsync() => _database.BeginSessionAsync();

    public ValueTask DisposeAsync() => _database.DisposeAsync();

    // Only for the run-wide factory's step 1B (an app whose Program.Main has no switch that skips
    // InitializeDatabase): make _database static, and give the host one throwaway database for the run.
    // Lazy, and blocking only inside ConfigureWebHost, which runs when the first test uses the host, so
    // tests that need no database still run without Docker. Never drop it: the container goes at the end.
    //
    // private static readonly Lazy<Task<ITestDatabaseSession<AppDbContext>>> _host =
    //     new(() => _database.BeginSessionAsync());
    //
    // public static ITestDatabaseSession<AppDbContext> HostDatabase() => _host.Value.GetAwaiter().GetResult();
}
