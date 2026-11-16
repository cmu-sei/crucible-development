# Repo-specific notes for Dependabot reviews

Only facts about one repo that change how its Dependabot PRs are reviewed and that can't be found
with a quick grep of that repo. Add a bullet under the repo (alphabetical) when you learn one.
Delete it when it stops being true. Keep version numbers out.

## cmu-sei/crucible-development
- An `Aspire.AppHost.Sdk` bump in `Crucible.AppHost.csproj` also needs the `./features/aspire`
  version in `.devcontainer/devcontainer.json`, which Dependabot never bumps (see the comments in
  both files). Don't merge the SDK bump alone.

## cmu-sei/Player.Api
- To exercise a config-gated package, use the test-suite recipe in ecosystems.md (NuGet). Running
  the app directly doesn't work for this: InMemory with AutoMigrate throws, and Sqlite has no
  migrations.
