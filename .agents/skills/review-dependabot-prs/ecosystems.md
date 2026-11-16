# Per-ecosystem checks for Dependabot PRs

Read the section for the PR's ecosystem (the `dependabot/<ecosystem>/...` branch name, also shown
in the `release-notes.sh` header). Paths are relative to the repo under review.

To support a new ecosystem, add a section with the same parts: **Release notes**, **Coupled
packages**, **Check against the repo**, **How to verify**.

## All ecosystems

- **Read every failing check**, required or not: `gh run view <run> --log-failed`. A failure the
  PR causes is a skip even when the check isn't required. A failure that also happens on the
  base branch, or on PRs that don't touch the same packages, isn't the PR's: say so in the plan
  and judge the PR on the rest.
- **Cover what CI never runs.** Building, testing or generating locally is part of a review, with
  or without e2e. The ecosystem sections below name the usual gaps: lint, generated swagger and
  clients, config-gated features, manually run workflows.
- **Read PR files without changing the clone's checkout:**
  `git -C <clone> fetch origin pull/N/head && git -C <clone> worktree add --detach /tmp/<repo>-pr-N FETCH_HEAD`.
  Remove the worktree when you're done.
- **Find conflicts between PRs you'd merge.** Two PRs can conflict even when both show
  MERGEABLE, lockfile-only conflicts included. Fetch the heads and run
  `git -C <clone> merge-tree --write-tree <head-A> <head-B>` for each pair of PRs that touch the
  same manifest or lockfile. For each conflict, merge the PR that changes more dependencies (a
  grouped PR before a single bump) and defer the other until it's rebased. Conflicts that only
  appear after several merges show up at apply time, as merges that fail.
- **A PR with an "Add missing document markings" commit** was pushed to by the shared header
  action (`cmu-sei/Crucible-Github-Actions` `actions/header`), which adds license headers to files
  that lack them. Dependabot then treats the PR as edited by someone else and refuses
  `@dependabot rebase`. Review the diff without that commit. To rebase it, comment
  `@dependabot recreate`, which drops the markings commit (the header check adds it again if the
  file is still unmarked on the base).

## npm (Angular UIs, Crucible.Common.Ui, API client packages)

**Release notes.** `release-notes.sh` finds the source repo from the PR body or `npm view`, and
prints the new version's `peerDependencies` and `engines` next to the old ones.

**Coupled packages.** Angular-versioned libraries (e.g. `ngx-markdown`, `@ng-bootstrap/*`) peer on
a single Angular major, so the peerDependencies line shows when a bump requires an Angular upgrade
(SKILL.md "Platform upgrades"). That applies to the second package of a "Bump X and Y" grouped PR
too. Some couplings go through a wrapper rather than a peer: `@fortawesome/*` icon majors need a
matching `@fortawesome/angular-fontawesome`, whose README has the Angular compatibility table.
`vitest` and `@vitest/*` must move together and within the range `@angular/build` accepts. An
Angular group PR can move `@angular/core` but leave another `@angular/*` package (often
`@angular/animations`) behind: `npm ls` on the PR head shows it as invalid.

**Check against the repo.**
- Breaking changes that name APIs, injection tokens, module config keys or builder options: grep
  the app's `sourceRoot` from `angular.json` (often `projects/<app>/src`, not `src/`) and
  `angular.json` itself.
- `engines`/`typescript` requirements against the repo's Node (Dockerfile `node:` tag, CI setup)
  and `typescript` version.
- Optional peers (e.g. `mermaid` under `ngx-markdown`) only ship if the app imports them; the same
  grep decides whether a change can reach the app.
- Peers: if `.npmrc` sets `legacy-peer-deps=true`, CI installs despite peer conflicts. Check
  `npm view <pkg>@<new> peerDependencies` against the repo yourself.
- eslint-family bumps (`eslint`, `@angular-eslint/*`, `@typescript-eslint/*`, plugins): CI doesn't
  run lint in these repos, so run `npm run lint` (or `ng lint`) on the PR head. eslint 10 drops
  `.eslintrc*` configs. If lint already reports errors on the base branch, compare base and PR
  head: the error count and the set of rules reported. No new rules and no more errors passes.
  If lint can't run at all on the base (e.g. its config fails to load), decide from the notes and
  peers, and say that lint couldn't be used.

**How to verify.** For Angular apps, CI's build-and-test, where its `test-command` runs specs
(some UIs only build: repo-notes.md). In each API repo, the `*.Api.Client` folder's
`package.json` only pins the `nswag` client generator. The client is a C# NuGet package built only
by the `workflow_dispatch` `client.yml`, so no PR check exercises an `nswag` bump: generate the
client on the PR head as `client.yml` does. Local check: in a worktree of the PR head, `npm ci`, then `npm test -- --watch=false`. The
`test` builder in `angular.json` decides Karma or Vitest; Karma needs `CHROME_BIN` pointed at a
Playwright Chromium under `~/.cache/ms-playwright`.

## NuGet (.NET APIs, crucible-common-dotnet)

**Release notes.** `release-notes.sh` reads the old and new `.nuspec` (license, target frameworks)
and the source repo's GitHub releases. Packages built in `dotnet/dotnet` have their notes in
https://github.com/dotnet/core/tree/main/release-notes. The `NuGet.*` client packages stopped
using GitHub releases; their notes are at
`https://learn.microsoft.com/nuget/release-notes/nuget-<major.minor>`. EF Core packages and
`dotnet-ef` have their notes in dotnet/efcore. xunit's notes are only on https://xunit.net. The
dotnet-inspect skill can
diff a package's public API between versions (`--breaking`) and list licenses across a project's
dependency graph.

**Dependency type is not informative here.** Dependabot labels every NuGet package
`direct:production`, test-only ones included. Decide by which projects reference the package.

**Coupled packages.** No build for the repo's `TargetFramework` in the new nuspec means the bump
requires a .NET upgrade. `Swashbuckle.AspNetCore` is built against one `Microsoft.OpenApi` major
(check Swashbuckle's nuspec dependency). A `Microsoft.OpenApi` major breaks Swagger generation
until Swashbuckle moves to a version built on it. `swashbuckle.aspnetcore.cli` in
`.config/dotnet-tools.json` must match the `Swashbuckle.AspNetCore` version for any bump, not just
majors; otherwise the manual `client.yml` release fails in `swagger tofile` with an assembly load
error. Dependabot updates the two separately. A restore warning `NU1608` means another package's
declared range excludes the new version. A `dotnet-ef` major that matches the repo's EF Core major
is a catch-up, not a platform upgrade.

Tool manifests can be nested: a `.config/dotnet-tools.json` under a project folder with
`"isRoot": true` takes over for commands run from that folder. Dependabot bumps only the
manifest it finds (usually the root one), so pins in nested manifests go stale. Run tools from
the folder whose manifest you mean to test.

**Check against the repo.**
- Breaking changes that name types, methods or options: grep the `*.cs` files.
- `xunit.runner.visualstudio` 4 on a repo still on xunit v2: confirm the tests are still found
  and run (CI does, if it runs them; otherwise `dotnet test` on the PR head).
- License: MediatR 13+ and AutoMapper 15+ (RPL-1.5 or paid) and FluentAssertions 8+
  (non-commercial or paid). The tell in the nuspec line: an SPDX id becomes a `LICENSE.md` file.
- Security pins (a direct reference whose only job is to raise a vulnerable transitive package,
  usually commented in the csproj): a major can leave it out of step with the rest of its family
  that still comes in transitively at the old major (e.g. `NuGet.Packaging` 7.x next to
  `NuGet.ProjectModel` 6.x). Compare the family's resolved versions in `obj/project.assets.json`
  after restoring base and PR head.
- Config-gated packages (e.g. `Microsoft.ApplicationInsights.AspNetCore`, which only runs when its
  connection string is set): CI doesn't exercise the feature. Run the test suite with the setting
  as an environment variable (e.g. `ApplicationInsights__ConnectionString` set to a dummy value;
  WebApplicationFactory picks it up). Then run it again with a malformed value: tests failing in
  its validation prove the setting took effect. Its transitive dependencies still move for every
  deployment.
- Coverage packages (`coverlet.*`): the shared `dotnet-test.yaml` workflow deliberately doesn't
  collect coverage, so PR checks never exercise them. Run `dotnet test` with coverage collection
  on the PR head. A repo's manual `coverage.yml`, where it has one, is the only workflow that
  uses them.
- `Corsinvest.ProxmoxVE.Api` (TopoMojo, Vm.Api) lists breaking changes in patch releases. Read the
  notes for every patch in the range and grep the hypervisor code for what they remove; CI has no
  Proxmox to exercise it.
- Swashbuckle bumps, even minors, can change the generated OpenAPI document. The UIs generate
  their TypeScript clients from it, so a change no PR check sees can break a UI. Generate the
  document on base and PR head (`dotnet swagger tofile`, as `client.yml` does) and diff them.

**How to verify.** CI build and test, or `dotnet build`/`dotnet test` in a worktree of the PR head
(nuget-restore-hang skill if restore hangs).

## docker (Dockerfiles, devcontainer and AppHost resource images)

**Release notes.** Image bumps have no GitHub source in the PR. Read the upstream changelog:
- `nginx`: https://nginx.org/en/CHANGES (mainline), `CHANGES-1.<even>` for stable
- `mcr.microsoft.com/dotnet/*`: the .NET release notes above
- `node`: https://github.com/nodejs/node/tree/main/doc/changelogs
- `postgres`: https://www.postgresql.org/docs/release/
- others: the image's registry page links its source.

**Check against the repo.**
- A versioned nginx tag (most UIs use a floating `stable-alpine`): keep the channel it's on (odd
  minor = mainline, even = stable). Check changed directives in CHANGES against the config, found
  by following the Dockerfile's `COPY --from=<stage>` back to its source path.
- A tag that goes from a pinned release to a floating one (e.g. `2.3.2-10.0-noble` ->
  `10.0-noble`) shows as MAJOR in the scripts, but the real change is losing the pin. Judge it
  by whether the repo wants the image pinned.
- A diff line `old mode 100755 / new mode 100644`: Dependabot can drop the executable bit on the
  file it edits. That's harmless for a Dockerfile but breaks a script.

**How to verify.** CI builds the image but usually doesn't run it (crucible-development's CI
doesn't build its AppHost resource Dockerfiles at all: repo-notes.md). For nginx, test the config:
`docker run --rm -v "$PWD/<conf>:/etc/nginx/conf.d/default.conf:ro" nginx:<new-tag>@<digest> nginx -t`

## github-actions

**Release notes.** The dependency name is the action's repo; `release-notes.sh` lists its releases.

**Coupled packages.** `cmu-sei/Crucible-Github-Actions` workflows are pinned by tag prefix (e.g.
`header-v1`), which Dependabot can't map onto semver. Whether a repo ignores it is in that repo's
`.github/dependabot.yml`.

**How to verify.** The PR runs the workflows it triggers. Workflows that only run on `push`,
`schedule` or `workflow_dispatch` aren't exercised by the PR, so read the diff for them.

## devcontainers (crucible-development, crucible-docs)

**Release notes.** Features under `ghcr.io/devcontainers/features/<name>` live in
github.com/devcontainers/features, versioned per feature: `src/<name>/devcontainer-feature.json`
holds the version, and `src/<name>/NOTES.md` and the README hold the notes. Read the git log of
that folder across the version range.

**Check against the repo.** The feature's options in `.devcontainer/devcontainer.json`. A daemon
or service feature (e.g. `docker-in-docker`) changes behavior the dev loop depends on (Aspire,
minikube), and CI only checks tool versions.

**How to verify.** See `.devcontainer/AGENTS.md` in crucible-development. A daemon or service
feature change can only be verified by rebuilding the devcontainer from the PR head and checking
the dev loop (`docker info`, an `aspire run`, minikube). A dry run can't do that: skip the PR and
name that check as what's needed.

## gomod (terraform-provider-crucible)

**Release notes.** Module paths on github.com map to their repo's releases. For `golang.org/x/*`,
read the module's commit log.

**Coupled packages.** `github.com/hashicorp/terraform-plugin-*` modules move together.

**How to verify.** The tasks in the repo's README; acceptance tests need a live stack.
