---
name: create-releases
description: Use when the user invokes `/create-releases <targets...>` or asks to release Crucible applications. Targets are `all`, a project (`alloy`, `blueprint`, `caster`, `cite`, `gallery`, `player`, `vm`, `console`, `steamfitter`, `topomojo`) for its API and UI, or one repository (`alloy.api`, `blueprint.ui`, ...). For each repository with commits since its last release it picks the version, writes release notes in the repo's own format, and publishes a GitHub release from main. It then replaces the release bot's helm-charts PRs with one PR that carries every chart change at the correct defaults.
argument-hint: "[--dry-run] <all | project | project.api | project.ui>..."
---

# create-releases

Release Crucible applications from `main`: one GitHub release per repository that has changed
since its last release, followed by one helm-charts PR that carries every chart change.

**Arguments** (`$ARGUMENTS`, at least one target; case-insensitive; any mix):

| Target | Repositories |
|---|---|
| `all` | all 19 below |
| `alloy` `blueprint` `caster` `cite` `gallery` `player` `steamfitter` | `<Project>.Api` and `<Project>.Ui` |
| `vm` | `Vm.Api`, `Vm.Ui` |
| `console` | `Console.Ui` (there is no Console API) |
| `topomojo` | `TopoMojo` (the API) and `topomojo-ui` |
| `<project>.api`, `<project>.ui` | that one repository, e.g. `cite.ui`, `topomojo.api` |
| `--dry-run` | survey, choose versions and draft notes, but publish nothing and open no PRs |

With no target, ask which to release. An unknown target is an error; say which names are valid.

**What this skill may do without asking:** publish the GitHub releases for the repositories the
user named, open the helm-charts PR, and close the bot PRs it replaces. **Always ask first** before:
releasing a repository whose changes need an unreleased change elsewhere (see step 3), publishing
a NuGet client package, changing a chart value that alters what an existing deployment does,
folding a hand-written chart PR into the consolidated one, and approving, merging or
admin-merging any PR. An approval is posted under the user's GitHub account, and GitHub won't
let that account approve a PR it opened, which includes the consolidated chart PR.

## Helpers

This skill's `scripts/` directory (`.claude/skills/create-releases/scripts/` in crucible-dev):

- `survey.sh [--resolve-only] <targets...>`: resolves targets to repositories (APIs first, then UIs),
  and for each prints the latest application release, `main`'s SHA, the commits since, the
  changed-file count and CI on `main` HEAD. Read-only.
- `settings-diff.mjs diff <kind> <old> <new>` / `keys <kind> <file>`: settings added, removed and
  changed between two versions of an app's settings file, as the flat keys the charts use, with
  defaults. Handles `appsettings.json` with comments, TopoMojo's `.conf` and UI `settings.json`.

Local clones live under `/mnt/data/crucible/` (`alloy/alloy.api`, `player/vm.ui`,
`topomojo/topomojo`, `helm-charts`, ...); `survey.sh` prints each one's path.

## Workflow

### 1. Survey

Run `survey.sh $ARGUMENTS`. Skip a repository with `ahead: 0`. Warn if `behind` isn't 0 (the tag
isn't on `main`). Show the user a short table: repository, last release, commits since, and
whether CI on `main` is green. Then continue; this table isn't a question.

`main` moves during a long run, often with Dependabot merges. The survey is a starting point: every
later step reads `main` again.

### 2. Research each repository

For each repository with commits, collect what the notes need. Write files to a scratch directory
(`/tmp/releases/<repo>/`), not into the repos.

- **Previous notes:** `gh release view <tag> -R cmu-sei/<repo> --json body --jq .body`. Read the
  last one or two: the new notes copy their layout, and their choice to name authors or not.
- **PRs:** take the `(#N)` from each commit subject, then
  `gh pr view N --json number,title,author,body,files`. For Dependabot PRs keep only the body
  before the first `<details>`.
- **Migrations:** files *added* under a `Migrations/` directory, excluding `*.Designer.cs` and
  `*ModelSnapshot.cs`. Edits to existing migration files that only add a license header aren't
  migrations.
- **Settings:** the settings file and its kind are in the repo's
  `.github/workflows/update-helm-chart.yml` (`settings_file`, `settings_file_kind`). Run
  `settings-diff.mjs diff` between the last tag and `main`. Also read the diff of any `Options`
  classes, because a default can live in code.
- **The compare API caps its file list at 300.** When `survey.sh` says `TRUNCATED`, run
  `git fetch origin --tags` in the local clone, then use `git diff --name-status <tag> origin/main`
  for migrations, settings and routes.
- **New routes:** search the diff of controllers for `[Http…("…")]` and `[Route(…)]`.
- **UI dependencies:** a bumped npm package is development-only only if the package-lock entry
  `node_modules/<name>` has `"dev": true`. Only then may the notes say it isn't in the published
  image. A UI image is `nginx` serving the build, so the Node version only builds it.
- **Generated clients:** if only `src/app/generated/**` changed, search the app code for the new
  methods before claiming any user-facing effect.

### 3. Order the releases and check dependencies

Release in `survey.sh` order: APIs before UIs. Then look for cross-repository needs: PR bodies
that say "Needs", "Depends on", "Merge after", "Requires" or "Stacked on" with a `cmu-sei/<repo>#N`
reference. For each one:

1. If PR N isn't merged, say so in the notes (for example "the console half is Console.Ui#756,
   which isn't merged yet"). It doesn't block the release.
2. If it's merged, check whether a release has it. Find the PR's merge commit, then
   `gh api repos/cmu-sei/<repo>/compare/<latest-tag>...<merge-sha> --jq .status`. `behind` or
   `identical` means the latest release includes it.
3. If no release has it and that repository is in this batch, release it first.
4. If no release has it and that repository isn't in this batch, **ask** with AskUserQuestion.
   Recommend releasing the dependency first, and offer to release only this one, or to stop.
   Releasing a UI before the API it needs also has the helm bot point the chart at a UI whose API
   isn't released yet.

### 4. Choose the version

Tags are bare semver (`3.8.0`, no `v`). Compare with the last application release, not a
`*.Client.*` tag.

- **Patch:** bug fixes, security fixes, dependency updates, refactors with no contract change
  (for example AutoMapper → Mapperly), CI, tests or docs only.
- **Minor:** new features, endpoints, response fields, permissions, settings (a new optional UI
  setting counts), database migrations, or response codes that change for working requests.
- **Major:** never on your own. If a change breaks existing deployments badly enough to need one,
  ask. Otherwise use minor and put a **⚠️ Breaking changes** section first in the notes.

Check the tag is free: `gh api repos/cmu-sei/<repo>/git/refs/tags/<version>` must 404.

### 5. Write the release notes

Read `references/release-notes.md` and follow it. Every statement in the notes must be backed by
a PR body, a diff or a check you ran. Drop anything you can't back.

### 6. Publish

1. Read `main` again: `H=$(gh api repos/cmu-sei/<repo>/commits/main --jq .sha)`. If it moved
   since you researched it, research the new commits and update the notes and version first.
2. Confirm CI is green for `$H`. Ignore check runs named `Dependabot`: they are Dependabot's own
   update jobs. If `$H` has no build or test runs of its own (a Dependabot merge often doesn't),
   read the checks of the PR that produced it: `gh pr checks <N>`.
3. End the notes file with a blank line and the helm skip marker, `<!-- helm-charts: skip -->`.
   The release's Update Helm Chart run then opens no bot PR, because step 7 charts every release
   in one PR. GitHub doesn't render HTML comments, so readers never see it. The action only reads
   the notes when the release is published, so the marker must be there before publishing.
4. Publish against the exact SHA:
   `gh release create <version> -R cmu-sei/<repo> --target $H --title <version> --notes-file <file> --latest`.
   With `--dry-run`, stop at the drafted notes file instead.
5. About 20 seconds later, `gh run list -R cmu-sei/<repo> -e release -L 2` should show
   **Build and Publish Image** and **Update Helm Chart**. Note their links for the report. With
   the marker, Update Helm Chart succeeds with the notice "Helm chart update skipped" and opens no
   PR. If it opens one anyway, that repo's action predates the marker: step 7 replaces that PR.
6. Re-read the published notes once, looking for claims you assumed rather than checked. Fix them
   with `gh release edit <version> --notes-file <file>` (the file still ends with the marker), and
   tell the user what changed.

Never run a repository's `client.yml` (it publishes a NuGet client package) without asking. If an
API gains endpoints or fields, the notes may say the client package isn't republished. Two facts
to know: Blueprint.Api calls CITE through a checked-in NSwag copy, not the `Cite.Api.Client`
package, and `Cite.Api.Client` has never been published to NuGet. Other client versions are
pushed unlisted, so check `https://api.nuget.org/v3-flatcontainer/<id-lowercase>/index.json`
rather than search.

When a new release satisfies an earlier release's note that said a dependency "isn't released
yet", offer to update that note at the end.

### 7. Consolidate the helm-charts PRs

After the last release, read `references/helm-charts.md` and follow it. In short: wait for every
release's **Update Helm Chart** run. With the skip marker there are no bot PRs; look for any
anyway (`<app_name> to <version>`), because a repo whose action predates the marker still opens
one. Then build one PR from `origin/main` with every chart and subchart bump and every added or
removed setting at the app's real default, plus README rows for those settings. Also fix any
zero values that already-merged bot PRs put on `main` (older versions of the action write
`false`, `""` or `0`), and say whether they break deployments. Commit, then run the repo's own
check scripts (they only see committed changes), open the PR, and close any bot PRs it replaces.
The user can't approve a PR this session opened, so ask who should review it.

With `--dry-run`, list the chart changes the PR would make instead.

### 8. Report

End with:
- a table of each repository with its new version and release link, plus any repository skipped
  as unchanged;
- what needs a decision or follow-up: unmerged companion PRs, client packages not republished,
  earlier notes to update, chart values whose default changed;
- the helm-charts PR link, the bot PRs it closed, published chart versions that carry wrong values
  and whether they need an upgrade, who was asked to review, and anything still running.

## Tooling pitfalls

- An apostrophe inside `"${var:-…}"` opens a quote in bash. Keep apostrophes out of default
  values.
- Release bodies contain control characters that make plain `jq` fail. Use `gh … --jq` instead.
  The dev container's `python3` has no `pip`, so run Python test suites in a `python:3.x`
  container.
- `git push` over HTTPS has no stored credentials. Push with
  `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push …`. Don't change
  git config.
- Make branches with `--no-track` from `origin/main`. A branch that inherits `origin/main` as its
  upstream can push straight to `main`.
