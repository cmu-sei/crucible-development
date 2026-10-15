// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/DatabaseHarnessTests.cs. Keep every test;
// verify.sh requires this class to exist and pass. Substitute:
// - UNIQUE_SET, UNIQUE_MOTHER and UNIQUE_COLUMN: a DbSet, its TestData mother taking the key, and a
//   column with a unique index in the real migrations (read the model snapshot for `.IsUnique()`; a
//   column that is only queried by name is not enough). The isolation probes prove nothing without it,
//   and A_second_row_with_the_isolation_key_is_refused fails if the index is missing.
// - an entity and its snake_case table name, a seeded row the mothers depend on, and the entity type of
//   the EntityCreated<T> event (UserEntity, users, TestData.Roles.Administrator below).
// A repo may add tests; it removes none.

using Crucible.Common.EntityEvents.Events;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using App.Api.Data.Models;

namespace App.Api.Tests.Support;

/// <summary>
/// Tests for the harness itself. Every other test trusts it, and a harness that quietly does nothing reads
/// as a green suite.
/// </summary>
public class DatabaseHarnessTests(DatabaseFixture fixture) : DatabaseTestBase(fixture)
{
    /// <summary>
    /// A value of a uniquely indexed column: if the two <c>Duplicates_*</c> tests shared a database,
    /// whichever ran second would fail. <see cref="A_second_row_with_the_isolation_key_is_refused"/>
    /// proves the index is there.
    /// </summary>
    private const string SharedKey = "Isolation Probe";

    [Fact]
    public async Task Saved_entities_survive_a_new_context()
    {
        var entity = TestData.User();
        await Seed(entity);

        await using var context = NewContext();
        Assert.NotNull(await context.Users.SingleOrDefaultAsync(x => x.Id == entity.Id, Ct));
    }

    [Fact]
    public async Task Duplicates_across_tests_are_isolated_first()
    {
        await Seed(TestData.UNIQUE_MOTHER(SharedKey));

        Assert.Equal(1, await Db.UNIQUE_SET.CountAsync(x => x.UNIQUE_COLUMN == SharedKey, Ct));
    }

    [Fact]
    public async Task Duplicates_across_tests_are_isolated_second()
    {
        await Seed(TestData.UNIQUE_MOTHER(SharedKey));

        Assert.Equal(1, await Db.UNIQUE_SET.CountAsync(x => x.UNIQUE_COLUMN == SharedKey, Ct));
    }

    /// <summary>
    /// The probes above are an isolation check only because the database refuses a second row with the
    /// same key; this proves the unique index on the probe column is in force.
    /// </summary>
    [Fact]
    public async Task A_second_row_with_the_isolation_key_is_refused()
    {
        await Seed(TestData.UNIQUE_MOTHER(SharedKey));
        await using var context = NewContext();
        context.UNIQUE_SET.Add(TestData.UNIQUE_MOTHER(SharedKey));

        var error = await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync(Ct));

        Assert.Equal(PostgresErrorCodes.UniqueViolation, Assert.IsType<PostgresException>(error.InnerException).SqlState);
    }

    [Fact]
    public async Task Explicit_ids_survive_the_round_trip()
    {
        var entity = TestData.User();
        var assignedId = entity.Id;

        await Seed(entity);

        await using var context = NewContext();
        Assert.NotNull(await context.Users.FindAsync([assignedId], Ct));
    }

    [Fact]
    public async Task The_seeded_administrator_role_is_present()
    {
        Assert.True(await Db.SystemRoles.AnyAsync(x => x.Id == TestData.Roles.Administrator, Ct));
    }

    /// <summary>
    /// Entity events must publish. This is what ruled out transaction-per-test isolation: the
    /// interceptor defers publishing to TransactionCommitted and discards it on rollback.
    /// </summary>
    [Fact]
    public async Task Saving_publishes_entity_events()
    {
        await Seed(TestData.User());

        // INotification, not object: the context casts to INotification before publishing, which binds
        // the generic Publish overload, and a substitute records the two separately.
        await Mediator.Received(1).Publish(
            Arg.Is<INotification>(x => x is EntityCreated<UserEntity>),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public void Uses_the_real_postgres_provider()
    {
        Assert.True(Db.Database.IsNpgsql());
    }

    [Fact]
    public void Applies_postgres_snake_case_naming()
    {
        var entityType = Db.Model.FindEntityType(typeof(UserEntity));

        Assert.Equal("users", entityType.GetTableName());
    }

    [Fact]
    public async Task Applies_the_real_migration_history()
    {
        // EnsureCreated leaves no history, so this proves the template was built by migrations.
        Assert.NotEmpty(await Db.Database.GetAppliedMigrationsAsync(Ct));
    }
}
