# Setting up an API on the standard

Setup mode of `dotnet-test-writer` (GLOSSARY.md, "Writer mode"): bringing the shared harness into a Crucible-family API that has no tests, or migrating an xUnit 2, EF InMemory or SQLite suite onto it. Create and audit mode do not read this file. The harness these steps build is described in [README.md](README.md); how tests are written is [CONVENTIONS.md](CONVENTIONS.md); the workflow, the file formats and the scripts are in [../testing/README.md](../testing/README.md). Do every step: each is small, and a skipped one is how repos drift. Run commands from the repo root of the worktree; Docker must be running for anything that takes a database.

The rule above everything here: **tests run against what production runs**: the real `Startup`, the real claims transformer and authorization handlers, the real AutoMapper profiles, PostgreSQL with the real migrations. Nothing is simplified below the app.

## 1. Record the setup facts

Read, in this order, and keep the answers for the report (the setup facts, below):

1. **SDK and packages.** `global.json` (SDK `10.0.100`, `rollForward: latestMinor`); whether `Directory.Packages.props` exists (central package management); whether a root `Directory.Build.props` and `.editorconfig` exist.
2. **Tests.** Whether there is a `*.Tests.csproj`; which xUnit (`xunit` 2.x or `xunit.v3`); which database (`UseInMemoryDatabase`, `UseSqlite`, `EnsureCreated`, Testcontainers); hand fakes or a hosted app.
3. **Style.** MVC controllers calling `*Service` classes that call `AuthorizationService.AuthorizeAsync(...)` with requirement classes (alloy, blueprint, cite, gallery, steamfitter); MediatR vertical slices with `BaseHandler.Authorize()` (caster); minimal-API `IEndpoint` slices (player); vm.api mixes MVC controllers and MediatR.
4. **Data.** The `EventPublishingDbContext` subclass; where its migrations live (`*.Migrations.PostgreSQL`, or inside the API for caster); how the administrator role and permissions are seeded; what the claims transformer (`UserClaimsService` or its equivalent) reads to produce permission claims.
5. **Hosting.** `Program.Main -> CreateWebHostBuilder(args).Build().InitializeDatabase().Run()`, and whether a production switch (player.api's `open-api-only`) skips `InitializeDatabase`. This decides the factory's step 1A or 1B (README, "Known pitfalls": a host database, the two-argument `TestDatabaseScope.ReplaceRegistration`, the `_started` flag). Every run-wide factory keeps the template's `CreateHost` lock.
6. **Collaborators that leave the process.** Hubs, `IHttpClientFactory`, sibling-API clients, hosted services, hypervisor clients; and whether a test must assert on an NSubstitute double the host resolves, which decides a run-wide or a per-class factory.

Done when every question has an answer you could quote with its file.

## 2. The test project

Create `<App>.Api.Tests` from `templates/Tests.template.csproj` beside the API projects (or keep the existing project's path; caster.api's is `test/Caster.Api.Tests`) and add it to the solution (`dotnet sln add`). A repo has exactly one `*.Tests.csproj`.

Done when `find . -name '*.Tests.csproj' -not -path '*/bin/*' -not -path '*/obj/*'` prints one path and `dotnet sln list` includes it.

## 3. Packages

The versions in `test-packages.props`, exactly: in `Directory.Packages.props` when the repo has central package management, otherwise as `Version=` attributes in the test `.csproj`. Remove `xunit` 2.x, `xunit.abstractions`, `Microsoft.EntityFrameworkCore.InMemory`, `Microsoft.EntityFrameworkCore.Sqlite` and `Microsoft.Data.Sqlite` from the test project. Restore needs the network; if it fails, report it rather than working around it.

Done when `dotnet restore` succeeds and `node /mnt/data/crucible/agent-docs/api-testing/check-repo.js harness <worktree>` prints no `MISSING`, `DRIFT` or `STALE` package line.

## 4. xUnit 2 to v3 (a migrated suite only)

alloy.api and caster.api had xUnit 2. `OutputType Exe`; `IAsyncLifetime` methods return `ValueTask`; `ITestOutputHelper` comes from `Xunit` (the v3 namespace) or `TestContext.Current.TestOutputHelper`; collection and class fixtures become the assembly fixtures where the standard has one; pass `Ct` wherever xUnit1051 asks. Follow <https://xunit.net/docs/getting-started/v3/migration>.

Done when `dotnet build <Tests>` succeeds with `TreatWarningsAsErrors` and no xUnit 2 reference remains.

## 5. Shared files

Run `/mnt/data/crucible/agent-docs/api-testing/sync.sh <worktree>`: it copies `Support/Shared/*.cs`, the test project's `Directory.Build.props`, `xunit.runner.json`, `coverlet.runsettings` and `.github/workflows/build-and-test.yml`. They are never edited in the repo. Add the xUnit1004 line from `editorconfig` to the repo's root `.editorconfig` (create it with `root = true` if there is none). If the repo already has a test workflow (blueprint.api's and vm.api's `test.yml` were), the standard's `build-and-test.yml` replaces it; say so in the report.

Done when `sync.sh --check <worktree>` reports no `MISSING`, `DRIFT` or `UNKNOWN` line for a shared file, the workflow or the `.editorconfig` line.

## 6. The app-specific harness

From the templates: `AssemblyFixtures.cs`, `Support/DatabaseFixture.cs`, `Support/<App>ContextFactory.cs`, `Support/<App>AppFactory.cs` (run-wide by default; the per-class variant only for the reason its template gives), `Support/TestConfiguration.cs`, `Support/DatabaseTestBase.cs`, `Support/ApiTestBase.cs`, `Support/TestActor.cs`, `Support/TestData.cs`, `Support/ClaimsPrincipalBuilder.cs`, `Support/AuthorizationHarness.cs`, `Support/TestMapper.cs`, and `ServiceTestBase` with `ApiTestHost` only when a service must be built with per-test options. Delete each template's TEMPLATE INSTRUCTIONS paragraph and fill every `UNIQUE_*` placeholder.

- **Never fake authorization.** Permissions come from the rows `TestActor` seeds, read by the app's real claims transformer. Read the transformer and mirror it in `TestActor`: a system role with `AllPermissions`/`Permissions`, one `On<Resource>` per membership kind, `InGroup` and a through-a-group step, one step per join row a gate reads, and `OnNew<Resource>` where the resource itself grants its members (CONVENTIONS sections 1 and 4). An app that asks a sibling API for permissions substitutes that API's generated client and keeps its own service real (CONVENTIONS section 1). An endpoint reachable only by writing claims is reported, never reached by substituting `IAuthorizationService` or overriding a policy.
- **Recorders, not run-wide substitutes** (README, "The recorder rule"): hubs through `HubRecorder<THub>`, outbound HTTP through `StubHttpClientFactory` over `OutboundHttp`, an app collaborator through an app recorder in `Support/` (player.api's `WebhookRecorder` is the model). Substitutes only where one test owns them. Before writing a helper, look for it in the shared files (`ReadBack`, `AssertJsonError`, `ReadAsync` with options, `RespondJson`, base addresses on `StubHttpClientFactory`, `TestAuthHandler`'s opt-ins); a local copy of a shared helper is drift.

Done when `sync.sh --check <worktree>` is clean (it runs `check-repo.js harness`: template-derived files present, no leftover instructions or placeholders, no local copy of a shared type, `DatabaseFixture` over `PostgresTestDatabase`, no `Substitute.For` in a run-wide factory) and `dotnet build <Tests>` succeeds.

## 7. The harness self-tests

`Support/DatabaseHarnessTests.cs`, `HttpHarnessTests.cs` and `TestActorTests.cs` from their templates, adapted to the app's entities and routes. They prove the harness before anything is built on it: write and run them before the first real test.

Done when `dotnet test <Tests> --filter "FullyQualifiedName~.DatabaseHarnessTests|FullyQualifiedName~.HttpHarnessTests|FullyQualifiedName~.TestActorTests" -- xUnit.DiagnosticMessages=true` passes every test of all three classes and prints the PostgreSQL provider banner.

## 8. Replace EF InMemory and SQLite (a migrated suite only)

caster.api's InMemory tests and alloy.api's `EnsureCreated`: every test that built a context over InMemory derives from `DatabaseTestBase` and uses `Db`/`NewContext()` over the PostgreSQL template with the real migrations. Services that were built with null collaborators get real ones from the hosted app (`ApiTestBase`) or from `ApiTestHost`. Hand fakes of collaborators that leave the process become the shared recorders and stubs. Every test removed or rewritten on the way is accounted for (../testing/README.md, "Removed-test accounting").

Done when `check-repo.js tests <worktree>` reports no `STALE` line, `dotnet test <Tests>` passes, and `check-repo.js removed <worktree> <app>` reports 0 unaccounted.

## 9. Docs

Write or update the repo's `docs/Testing.md` from player.api's: running, coverage, build settings, the harness (fixtures, base classes, what is real), adding a test, layout, the app's specifics (factory variant, step 1A or 1B, extras), CI. Point at `agent-docs/api-testing/` for the shared parts rather than copying them. The group `AGENTS.md` lives outside the repo: list it in the report for the orchestrator.

Done when `docs/Testing.md` names the factory variant, the database gate and every extra in `Support/`, and nothing in it contradicts the README.

## 10. Verify the setup

Run `/mnt/data/crucible/agent-docs/api-testing/verify.sh --clean <worktree>`. From here the writer's steps in create mode take over (covering every gate the gates check lists; ../testing/README.md, "The workflow").

Done when every check other than `gates` passes and the log is in `agent-docs/test-work/<app>/`.

## The setup facts the writer reports

Under "Mode and version" in the writer's report:

- SDK and `rollForward`; central package management or not; xUnit and package versions as installed;
- the app's style (MVC, MediatR, minimal API) and what the claims transformer reads;
- the factory variant (run-wide or per-class) and why, and the database gate (step 1A or 1B) and why;
- the extras added in `Support/`, each with what it fakes;
- what was migrated (xUnit 2, InMemory, SQLite, a sibling harness) and the workflow replaced, if any;
- the follow-ups outside the repo: the group `AGENTS.md`, application-project build warnings (listed by `verify.sh`, never silenced in application code).
