// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/AssemblyFixtures.cs. Replace App with the app's
// name (Player, Cite, Gallery, ...). Keep the DatabaseFixture line in every repo. Keep the factory line
// only for the run-wide factory variant (AppFactory.template.cs); a repo that uses the per-class variant
// (PerClassAppFactory.template.cs, because its tests assert on NSubstitute doubles registered in the
// host) deletes it, and its ApiTestBase classes take the factory through IClassFixture instead.
// check-repo.js reads this file to find the run-wide factory and fails it if it registers a substitute.

using App.Api.Tests.Support;

// Starting a PostgreSQL container and running the migrations costs seconds, so it happens once for the
// whole assembly. xUnit v3 constructs this before the first test and injects it into any test class
// with a matching constructor parameter. The container itself starts on the first test that asks for a
// database (see PostgresTestDatabase), so tests that need none run without Docker.
[assembly: AssemblyFixture(typeof(DatabaseFixture))]

// Starting the application costs about a second, and everything it registers as a singleton is shared
// by every test that uses it: see AppAppFactory, which says how each shared surface is dealt with.
[assembly: AssemblyFixture(typeof(AppAppFactory))]
