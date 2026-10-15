// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/TestData.cs. Object mothers for the entities
// most tests need, and the ids of the rows the migrations seed (roles, permissions): read them from the
// context's OnModelCreating seed calls or the SeedData classes, never from appsettings.json (that seed
// runs only in InitializeDatabase, which the harness's template database never sees). Every mother sets
// an explicit Guid.NewGuid() id, so a test can compose references before saving, and fills only the
// required members; a test sets what it asserts on. Add a mother when a second test needs the entity.
// A connected graph many tests need (an evaluation with teams, moves and a scoring model) is a seed-graph
// helper in Support/ named for the graph (cite.api's TestScenario), built from these mothers
// (CONVENTIONS.md section 1).

using App.Api.Data.Models;

namespace App.Api.Tests.Support;

/// <summary>Object mothers, and the ids of the rows the migrations seed.</summary>
public static class TestData
{
    /// <summary>Ids of the system roles the migrations seed.</summary>
    public static class Roles
    {
        public static readonly Guid Administrator = new("00000000-0000-0000-0000-000000000000");
    }

    /// <summary>A fixed creation timestamp. Tests that care about ordering pass their own.</summary>
    public static readonly DateTime DefaultDateCreated = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    public static UserEntity User(Guid? id = null, string name = "Test User", Guid? roleId = null) =>
        new()
        {
            Id = id ?? Guid.NewGuid(),
            Name = name,
            RoleId = roleId
        };

    /// <summary>A system role of its own, named uniquely because role names are uniquely indexed.</summary>
    public static SystemRoleEntity SystemRole(bool allPermissions = false, SystemPermission[] permissions = null)
    {
        var id = Guid.NewGuid();

        return new SystemRoleEntity
        {
            Id = id,
            Name = $"role-{id:N}",
            AllPermissions = allPermissions,
            Permissions = [.. permissions ?? []]
        };
    }
}
