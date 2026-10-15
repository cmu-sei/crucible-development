// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/TestActor.cs. This is how an HTTP test gets
// a caller: it seeds the rows the app's real claims transformer reads, never claims written by the test.
// Read the app's UserClaimsService.GetPermissionClaims (or its equivalent) and mirror it:
// - System permissions: the Crucible-family pattern is User.RoleId -> SystemRole { AllPermissions,
//   Permissions } (player.api uses Role -> RolePermissions rows instead). WithAllSystemPermissions points
//   at the seeded administrator role; WithSystemPermissions mints a role for this actor alone (role names
//   are uniquely indexed, so never reuse a shared one); WithRole names an existing role.
// - Resource permissions: one On<Resource>(...) per membership kind the transformer reads (player.api:
//   OnTeam; cite.api: OnEvaluation, OnScoringModel; gallery.api: OnCollection, OnExhibit; ...), each
//   taking either a seeded role id or the exact permissions, which mints a role for the membership.
// - Near misses: where the resource itself grants its members something (player.api: a team's own role,
//   which TestData.Team defaults to the seeded View Member), add OnNew<Resource>(parentId, permissions)
//   too. It mints, inside SeedAsync, a resource under parentId whose own role grants nothing (a role
//   with no permission rows) and puts the actor on it with exactly those permissions, so a denied test's
//   actor holds what the call names and nothing a mother's default role adds (CONVENTIONS.md section 4).
//   Expose the minted id on TestActor (player.api: Memberships[i].TeamId). Where the resource grants
//   nothing of its own, On<Resource> is enough and this step is not needed.
// - Groups: every Crucible transformer reads group memberships, so add InGroup(groupId) (a membership
//   row in a group the test seeded) and, where a group can hold a resource membership, a step that grants
//   through one (caster.api: OnProjectThroughNewGroup(project, permissions) mints a group, puts the actor
//   in it and the group on the project). At least one gate test per resource kind runs through a group.
// - Join rows: where a grant is a row joining the user to something rather than a role (blueprint.api:
//   InUnit(unit), InUnitOf(msel), InGroup(group); cite.api: a team membership), one step per join row,
//   next to On<Resource> and OnNew<Resource>, so a test never hand-seeds the row a gate reads.
// - Refuse a membership with no role (InvalidOperationException) where the app gives a role-less
//   membership a default role that grants (caster.api: a project membership with no role is a Member);
//   the test then names the role or the permissions, so it holds what it says.
// - Fail loudly (InvalidOperationException naming the missing row) when a permission has no row, and when
//   two calls both decide the same role. TestActorTests pins each shape.
// vm.api keeps no permissions of its own (it asks player.api); there the actor is the id and name sent to
// the substituted Player client, and this file shrinks to that.

using App.Api.Data;
using App.Api.Data.Models;

namespace App.Api.Tests.Support;

/// <summary>A seeded user, and the ids of the rows seeded with them.</summary>
public sealed class TestActor
{
    public required Guid Id { get; init; }

    /// <summary>Sent as the <c>name</c> claim, which the claims service writes back to the user row.</summary>
    public required string Name { get; init; }
}

/// <summary>
/// Seeds a user, the role that grants their system permissions, and their memberships, so that the real
/// claims transformer derives the permissions a test needs.
/// </summary>
public sealed class TestActorBuilder(AppDbContext db, CancellationToken ct)
{
    private Guid _id = Guid.NewGuid();
    private string _name = "Test Actor";
    private Guid? _roleId;
    private SystemPermission[] _systemPermissions;

    /// <summary>Fixes the actor's id, for a test that needs to know it before seeding.</summary>
    public TestActorBuilder WithId(Guid id)
    {
        _id = id;
        return this;
    }

    public TestActorBuilder WithName(string name)
    {
        _name = name;
        return this;
    }

    /// <summary>Gives the actor an existing system role, such as <c>TestData.Roles.Administrator</c>.</summary>
    public TestActorBuilder WithRole(Guid roleId)
    {
        if (_systemPermissions is not null)
        {
            throw new InvalidOperationException(
                "WithRole and WithSystemPermissions both decide the actor's system role. Drop one.");
        }

        _roleId = roleId;
        return this;
    }

    /// <summary>Every system permission, by way of the seeded administrator role.</summary>
    public TestActorBuilder WithAllSystemPermissions() => WithRole(TestData.Roles.Administrator);

    /// <summary>Exactly these system permissions, by way of a role minted for this actor.</summary>
    public TestActorBuilder WithSystemPermissions(params SystemPermission[] permissions)
    {
        if (_roleId is not null)
        {
            throw new InvalidOperationException(
                "WithSystemPermissions and WithRole both decide the actor's system role. Drop one.");
        }

        _systemPermissions = permissions;
        return this;
    }

    // public TestActorBuilder On<Resource>(<Resource>Entity resource, Guid? roleId = null,
    //     <Resource>Permission[] permissions = null) { ... }

    // /// <summary>
    // /// Puts the actor on a new <Resource> of <paramref name="parentId"/> whose own role grants nothing,
    // /// so the actor holds exactly <paramref name="permissions"/>: the near miss of a denied test.
    // /// </summary>
    // public TestActorBuilder OnNew<Resource>(Guid parentId, <Resource>Permission[] permissions = null)
    // { ... record a pending membership on a resource SeedAsync mints ... }
    //
    // player.api: Actor().OnNewTeam(view.Id, viewPermissions: [ViewPermission.ViewView]).SeedAsync()

    // /// <summary>Puts the actor in <paramref name="groupId"/>, which must already be saved.</summary>
    // public TestActorBuilder InGroup(Guid groupId) { ... record a pending group membership ... }
    //
    // /// <summary>
    // /// Puts the actor in a new group, and that group on <paramref name="resource"/> with exactly
    // /// <paramref name="permissions"/>: the path by which a group grants its members.
    // /// </summary>
    // public TestActorBuilder On<Resource>ThroughNewGroup(<Resource>Entity resource, params <Resource>Permission[] permissions)

    /// <summary>Writes the actor and everything above to the database.</summary>
    public async Task<TestActor> SeedAsync()
    {
        var roleId = _roleId;

        if (_systemPermissions is not null)
        {
            var role = TestData.SystemRole(permissions: _systemPermissions);
            db.SystemRoles.Add(role);
            roleId = role.Id;
        }

        db.Users.Add(TestData.User(_id, _name, roleId));

        // OnNew<Resource>: first the resource, with a role of no permissions (TestData.<Resource>Role()),
        // under the parent the call named, which must already be saved.
        // Memberships: one row per On<Resource> and OnNew<Resource> call, with a minted or named role.
        // Groups: one group membership row per InGroup call; for a ...ThroughNewGroup call, a minted group,
        // the actor's membership in it, and the group's membership on the resource.

        await db.SaveChangesAsync(ct);

        return new TestActor { Id = _id, Name = _name };
    }
}
