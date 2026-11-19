# Repo-specific notes for Dependabot reviews

Only facts about one repo that change how its Dependabot PRs are reviewed and that can't be found
with a quick grep of that repo. Add a bullet under the repo (alphabetical) when you learn one.
Delete it when it stops being true. Keep version numbers out.

## cmu-sei/Console.Ui
- `angular.json` loads `jquery` and `jquery-ui-dist` as global scripts ahead of the vendored
  VMware WMKS SDK (`src/assets/vmware-wmks/js/wmks.min.js`), which calls jQuery APIs that later
  jQuery majors remove (e.g. `$.now`, `$.isFunction`). The unit tests stub WMKS and don't load
  global scripts, so CI can't catch a break. For a jQuery or jQuery UI major, grep the SDK for the
  APIs the release removes, and say the VMware console needs a manual check.

## cmu-sei/crucible-common-dotnet
- `Microsoft.CodeAnalysis.CSharp` in `Crucible.Common.EntityEvents.Generators` sets the minimum
  Roslyn, and so the minimum .NET SDK, for every API that uses EntityEvents. This repo's CI can't
  see that: check the new version's required SDK against the consuming APIs' `global.json`.

## cmu-sei/crucible-development
- CI only builds the devcontainer image and checks license headers. It never builds
  Crucible.AppHost, runs `tests/Crucible.AppHost.Config.Tests`, or builds the Dockerfiles under
  `Crucible.AppHost/resources`, so green CI says nothing about a NuGet or resource-image bump.
  Check locally: `dotnet test tests/Crucible.AppHost.Config.Tests` needs no app clones (it compiles
  the AppHost's config files in directly). `dotnet build Crucible.AppHost` builds only the AppHost:
  it adds the APIs by path with `AddDotnetProject`, and Aspire builds them when it starts them.
- An Aspire package bump in `Crucible.AppHost.csproj` (`Aspire.Hosting.AppHost` and the other
  `Aspire.Hosting.*` packages) also needs the `./features/aspire` version in
  `.devcontainer/devcontainer.json`, which Dependabot never bumps (see the comments in both
  files). Don't merge the package bump alone.

## cmu-sei/devcontainer-features
- Every merge to main runs `release.yml`, which publishes the changed features to GHCR, and a
  change under `bundle/` or the spawn scripts cuts a new bundle release (the one
  `releases/latest` serves) with no further step. A merge is a release: say so in the plan.

## cmu-sei/gameboard-ui
- CI's build-and-test only runs the production build, no specs. Bumps that only the specs
  exercise (karma, jasmine, testing utilities) need a local `ng test` on the PR head.

## cmu-sei/Player.Api
- To exercise a config-gated package, use the test-suite recipe in ecosystems.md (NuGet). Running
  the app directly doesn't work for this: InMemory with AutoMigrate throws, and Sqlite has no
  migrations.

## cmu-sei/TopoMojo
- The `dotnet-ef` pin is only in the root `.config/dotnet-tools.json`. The migration scripts
  (`src/TopoMojo.Api/Data/Scripts/`) run from `src/TopoMojo.Api`, whose own `isRoot` manifest has
  no `dotnet-ef`, so they never use the pin. Verify a `dotnet-ef` bump from the repo root, against
  both `TopoMojoDbContextPostgreSQL` and `TopoMojoDbContextSqlServer`.

## cmu-sei/topomojo-ui
- CI's build-and-test only runs the production builds (topomojo-work and topomojo-launchpoint),
  no specs. Bumps that only the specs exercise (karma, jasmine, testing utilities) need a local
  `ng test` on the PR head.
