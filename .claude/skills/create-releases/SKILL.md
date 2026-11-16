---
name: create-releases
description: Use when the user invokes `/create-releases` or asks to release, tag or publish new versions of Crucible APIs or UIs, or to update helm-charts after a release.
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
| `--dry-run` | survey, choose versions, draft notes and plan the chart changes, then stop at the plan in step 6: publish nothing and open no PRs |

With no target, ask which to release. An unknown target is an error; say which names are valid.

**Nothing is published until the user confirms the plan** (step 6): one table of every release,
its version and its notes. Once they confirm, the skill may publish those releases, open the
helm-charts PR, and close any bot PRs it replaces without asking again. **Always ask first**
before: releasing a repository whose changes need an unreleased change elsewhere (see step 3),
releasing one whose changes don't change what it ships (also step 3), publishing a release whose
CI isn't green (step 7), publishing a NuGet client package, changing a chart value that alters
what an existing deployment does, folding a hand-written chart PR into the consolidated one, and
approving, merging or admin-merging any PR. An approval is posted under the user's GitHub
account, and GitHub won't let that account approve a PR it opened, which includes the
consolidated chart PR.

## Helpers

This skill's `scripts/` directory (`.claude/skills/create-releases/scripts/` in crucible-dev):

- `survey.sh [--resolve-only] <targets...>`: resolves targets to repositories (APIs first, then UIs),
  and for each prints the latest application release, `main`'s SHA, the commits since, the
  changed-file count and CI on `main` HEAD. Read-only. It tries each GitHub call three times,
  because GitHub drops connections now and then. A repository it still can't read shows
  `status: ERROR` with the command to rerun, and the script exits with 3.
- `settings-diff.mjs diff <kind> <old> <new>` / `keys <kind> <file>`: settings added, removed and
  changed between two versions of an app's settings file, as the flat keys the charts use, with
  defaults. Handles `appsettings.json` with comments, TopoMojo's `.conf` and UI `settings.json`.

Local clones live under `/mnt/data/crucible/` (`alloy/alloy.api`, `player/vm.ui`,
`topomojo/topomojo`, `helm-charts`, ...); `survey.sh` prints each one's path.

## Workflow

### 1. Survey

Run `survey.sh $ARGUMENTS` (it ignores `--dry-run`). Skip a repository with `ahead: 0`. Warn if `behind` isn't 0 (the tag
isn't on `main`). Rerun any repository that shows `status: ERROR` before deciding anything about
it: an error isn't "unchanged". Show the user a short table: repository, last release, commits since, and
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
- **UI dependencies:** the notes may say a bumped npm package isn't in the published image only
  when you've shown it. Either its package-lock entry `node_modules/<name>` has `"dev": true`, or
  the app never imports it (`git grep` for the package name under `src/` finds nothing) and no
  runtime package in the lock file depends on it. Say which check backs the claim. A UI image is
  `nginx` serving the build, so the Node version only builds it.
- **Security fixes:** when a bump fixes advisories, take them from the package's own advisories,
  not only GitHub's global database (`gh api /advisories`), which can lag days behind. The
  Dependabot PR body names them. Confirm each one covers the old version and is fixed by the new
  one with `gh api repos/<owner>/<repo>/security-advisories/<GHSA-id> --jq
  '[.severity, .vulnerabilities[].vulnerable_version_range, .vulnerabilities[].patched_versions]'`,
  where `<owner>/<repo>` is the package's source repository. Name every one that does, with its
  severity, so the count is right.
- **Generated clients:** if only `src/app/generated/**` changed, search the app code for the new
  methods before claiming any user-facing effect.

### 3. Order the releases, check dependencies, and check each is worth making

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
   Releasing a UI before the API it needs also points the chart at a UI whose API isn't released
   yet.

**Is each release worth making?** If nothing since the last release changes what the repository
ships (only development-only or unimported dependency bumps, CI, tests or docs), say so and
**ask** whether to release it now or leave the changes for its next release. A release costs
operators a chart bump and an image rebuild for no change in behavior, so recommend waiting,
unless something outside the image needs it, such as a security scanner that flags the old
version in the repository. Still draft the notes, so the user has them either way. You can ask
this and the dependency questions separately, or fold them into the step 6 confirmation.

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

### 6. Confirm the plan

Publishing makes public releases and images, and `all` can mean 19 of them, so nothing is
published until the user has seen the whole batch and agreed. When every notes file is drafted,
show one table:

| Repository | Last release → new version | Notes file | What's in it |
|---|---|---|---|
| CITE.Ui | 1.13.0 → 1.13.1 (patch) | `/tmp/releases/CITE.Ui/notes-1.13.1.md` | node-forge bump; no image change, so waiting is recommended |

Use "What's in it" for what the user must know before deciding: breaking changes, migrations,
dependencies on other releases, CI that isn't green yet, or a release that changes nothing it
ships. Add a line for the helm-charts PR that step 8 will open (which charts, and any setting whose
default needs a decision). Then ask once with AskUserQuestion: publish all of them, publish some
(the user names which), or stop. Publish only what the user confirms, and leave the notes files in
place for anything they hold back.

With `--dry-run`, show the table, list the chart changes step 8 would make, and stop there.

### 7. Publish

For each confirmed repository, in survey order:

1. Read `main` again: `H=$(gh api repos/cmu-sei/<repo>/commits/main --jq .sha)`. If it moved
   since you researched it, research the new commits and update the notes and version. If that
   changes the version or what the notes say, show the change and confirm that repository again.
2. Check CI for `$H`. Ignore check runs named `Dependabot`: they are Dependabot's own update jobs.
   If `$H` has no build or test runs of its own (a Dependabot merge often doesn't), read the
   checks of the PR that produced it: `gh pr checks <N>`.
   - **Green** (every check `success`, `skipped` or `neutral`): go on.
   - **Still running:** wait for it, with `gh pr checks <N> --watch` or `gh run watch <run-id> -R
     cmu-sei/<repo> --exit-status`, and use the result. A release built from an unfinished CI run
     could ship a broken image.
   - **Red** (`failure`, `cancelled`, `timed_out` or `action_required`): don't publish that
     repository. Tell the user which check failed, with its link, and ask whether to skip it, wait
     for a fix (a fix moves `main`, so restart at item 1), or publish anyway. Recommend skipping,
     and never publish over a red check without that answer. Other repositories go ahead, except
     any whose release depends on this one (step 3), which wait with it.
3. End the notes file with a blank line and the helm skip marker, `<!-- helm-chart-pr: false -->`
   (honored by the update-helm-chart action from v3.3.0, cmu-sei/Crucible-Github-Actions#49).
   The release's Update Helm Chart run then opens no bot PR, because step 8 charts every release
   in one PR. GitHub doesn't render HTML comments, so readers never see it. The action only reads
   the notes when the release is published, so the marker must be there before publishing.
4. Publish against the exact SHA:
   `gh release create <version> -R cmu-sei/<repo> --target $H --title <version> --notes-file <file> --latest`.
5. About 20 seconds later, `gh run list -R cmu-sei/<repo> -e release -L 2` should show
   **Build and Publish Image** and **Update Helm Chart**. Note their links for the report. With
   the marker, Update Helm Chart succeeds with the notice "Helm chart PR skipped" and opens no
   PR. If it opens one anyway, the published notes lack the marker or have it mistyped: say so,
   and handle it with the fallback in `references/helm-charts.md`.
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

### 8. Open the helm-charts PR

After the last release, read `references/helm-charts.md` and follow it. In short: build one PR
from `origin/main` with every chart and subchart bump, and every added or removed setting at the
app's real default, plus README rows for those settings. Commit, then run the repo's own check
scripts (they only see committed changes), and open the PR. The user can't approve a PR this
session opened, so ask who should review it.

Because every release carries the skip marker, the release bot normally opens nothing. The
reference's **Fallback** section covers the exceptions: a release whose notes lacked the marker,
so the bot opened a PR, and zero values that earlier bot PRs already put on `main`.

With `--dry-run`, step 6 lists the chart changes this PR would make instead.

### 9. Report

End with:
- a table of each repository with its new version and release link, plus any repository skipped
  as unchanged;
- what needs a decision or follow-up: unmerged companion PRs, client packages not republished,
  earlier notes to update, chart values whose default changed;
- the helm-charts PR link, any bot PRs it replaced, published chart versions that carry wrong values
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
