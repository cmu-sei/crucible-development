// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/DatabaseTestBase.cs. Substitute
// AppDbContext and the namespaces. Keep it this thin: everything a test uses comes from the shared
// DatabaseTestBase<TContext>, so it reads the same in every repo. Add app helpers here only if every
// database test needs them.

using App.Api.Data;

namespace App.Api.Tests.Support;

/// <summary>
/// Base class for tests that need a database. Each test gets its own isolated database from the shared
/// <see cref="DatabaseFixture"/>.
/// </summary>
/// <remarks>
/// <para>
/// Everything a test uses (<c>Db</c>, <c>NewContext()</c>, <c>ReadBack</c>, <c>Session</c>, <c>Mediator</c>,
/// <c>Ct</c>, <c>Seed</c>, <c>WaitUntil</c>) comes from the shared <see cref="DatabaseTestBase{TContext}"/>.
/// </para>
/// <para>
/// The fixture arrives by constructor injection, which xUnit v3 satisfies from the
/// <c>[assembly: AssemblyFixture(typeof(DatabaseFixture))]</c> declaration in <c>AssemblyFixtures.cs</c>.
/// Derived classes forward it: <c>MyTests(DatabaseFixture fixture) : DatabaseTestBase(fixture)</c>.
/// </para>
/// </remarks>
public abstract class DatabaseTestBase(DatabaseFixture fixture) : DatabaseTestBase<AppDbContext>(fixture)
{
    /// <summary>The run-wide fixture.</summary>
    protected DatabaseFixture Fixture { get; } = fixture;
}
