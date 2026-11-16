---
name: review-dependabot-prs
description: Use when asked to review, triage, approve, or merge Dependabot pull requests (dependency bump PRs) in crucible-development or any repo in scripts/repos.json, including deciding whether a major version bump is safe, validating bumps against the crucible-tests e2e suites, applying a saved Dependabot plan from .dependabot-plans/, or when a Dependabot merge fails with "required status checks are expected", conflicts with another bump, or waits on a check that never finishes.
---

# Reviewing and merging Dependabot PRs

Decide each bump from evidence: the release notes for every version in the range, checked
against how this repo uses the package. A major bump is fine when none of its breaking changes
affect the repo. A patch is not fine when its notes say it breaks something the repo relies on.
Green CI supports the decision but doesn't replace reading the notes.

`scripts/` in these files means this skill's scripts folder,
`/workspaces/crucible-development/.agents/skills/review-dependabot-prs/scripts/`: type that full
path in commands, because crucible-development's own `scripts/` (with `repos.json`) is a different
folder. Run them with `bash`. Other paths are relative to the repo under review. The scripts print
`ERROR` when a GitHub call fails, and GitHub refuses connections in bursts, especially when many
calls run at once. An `ERROR` means unknown, never none: rerun it. Run the scripts one at a time.

## When not to use

- Doing a planned platform upgrade itself (e.g. Angular 19 to 21, .NET 10 to 11): that's a
  migration, not a review. This skill only sorts the Dependabot PRs that need one.
- Dependency changes a person made, and repos outside `scripts/repos.json`.

## Ask first

Before reviewing, ask whichever of these two questions the user's request doesn't already
answer: both in one AskUserQuestion call, just the unanswered one, or none if it answers both.

1. **Merge, or dry run?** Either write the plan and apply it right away (approving PRs only where
   GitHub requires a review), or write the plan and change nothing until the user approves it
   (like `terraform plan`, then `apply`).
2. **Validate with e2e first?** Either apply on the strength of review plus CI, or at apply time
   first merge the plan's PRs together in the local clone, run the app's crucible-tests e2e
   suites on the result, and merge on GitHub only if they pass. This sets the plan's `e2e` mode.
   A dry run never runs the suites.

The e2e suites are slow. Run them once per batch, never once per PR, unless the user asks for
per-PR runs.

## Platform upgrades are out of scope

A major bump of a platform is never merged from a Dependabot PR: a framework, runtime or server
upgrade touches the whole app, so it gets a planned upgrade instead. The platforms are Angular,
.NET, Aspire, Node, Go, Postgres and Keycloak; the exact package and image names are
`PLATFORM_RE` in `scripts/lib.sh`, and the inventory marks them `<< PLATFORM major`. A bump whose
new version *requires* a platform major counts too: its peerDependencies need an `@angular/core`
major the repo isn't on, or its nuspec has no build for the repo's TargetFramework. `typescript`
and `zone.js` count only that way: when the new version is outside the peer range of the repo's
`@angular/core` (`npm view @angular/core@<version> peerDependencies`). Leave these PRs open
without commenting and list them under "Needs a planned upgrade". Minor and patch bumps of
platforms are reviewed like any other bump.

## Quick reference

| Script | Use it to | Typical command |
|---|---|---|
| `inventory.sh` | See each open PR: state, required checks, version changes, markers | `bash scripts/inventory.sh OWNER/REPO` |
| `release-notes.sh` | Read every release in each dependency's range, license and requirements | `bash scripts/release-notes.sh OWNER/REPO N [--dep NAME]` |
| `plan.sh` | Record verdicts, check a plan is current, apply it | `bash scripts/plan.sh lines\|check\|apply ...` |
| `merge-when-green.sh` | Merge PRs one at a time once required checks pass (`apply` uses it) | `bash scripts/merge-when-green.sh [--dry-run] OWNER/REPO N ...` |
| `app-map.sh` | Find a repo's clone, Aspire resources and e2e suites | `bash scripts/app-map.sh OWNER/REPO` |
| `local-merge.sh` | Merge PRs in the local clone for e2e, and restore it after | see [local-e2e.md](local-e2e.md) |

## Workflow

1. **Inventory:** `bash scripts/inventory.sh OWNER/REPO`. Set aside `<< PLATFORM major` PRs. Act
   on its other markers: `check ... @angular/core peer range` (typescript and zone.js),
   `CONFLICT` (the PR's text, commit metadata and diff disagree on a version: trust the diff and
   say so) and `duplicate of #N` (a skip: "superseded by #N"). The repo's auto-merge workflow merges
   updates up to its `update-types` (default: patch) by itself: review those only if they're
   stuck. A `github-actions` approval above that level isn't a review. A `WARNING` in the header
   is a settings deviation (app repos match Alloy.Api or Alloy.Ui) to report, not review around.
2. **Read the release notes:** `bash scripts/release-notes.sh OWNER/REPO N`. Don't rely on the
   notes Dependabot pastes into the PR: they're truncated, newest first, and usually cut before
   the `.0` releases where breaking changes are listed.
3. **Check the notes against the repo:** for each breaking change, removal or new requirement,
   grep the base branch for what it names, and compare the requirements with what the repo runs.
   A direct package can move transitive packages for every deployment, even when its own feature
   is switched off by config. Honor the repo's holds (`.github/dependabot.yml` `ignore` rules,
   deferral docs, `Deferred:` comments in manifests) by their stated reason, not just the version
   they name: a hold on a library's next major for licensing still allows its current-major
   patches. Read [ecosystems.md](ecosystems.md): its "All ecosystems" section and the section
   for the PR's ecosystem. Read [repo-notes.md](repo-notes.md) for the repo. Before deciding,
   check the PRs you'd merge against each other for conflicts ("All ecosystems" says how).
4. **Decide each PR** with the table below. A PR passes only if every dependency in it passes.
5. **Write the plan:** copy [plan-template.md](plan-template.md) to
   `.dependabot-plans/<YYYY-MM-DD>-<repos>.md` in crucible-development (gitignored) and fill it
   with the verdicts and their evidence. Generate its data with
   `bash scripts/plan.sh lines merge|defer|skip|upgrade OWNER/REPO N ...`, which records each
   PR's reviewed head commit. List `merge` lines in merge order: a grouped PR before the PRs it
   overlaps. Set `e2e` from question 2. The plan must stand alone: an agent with only that file
   can apply it.
6. **Dry run only:** show the plan's lists and its path, then ask in one AskUserQuestion call:
   "Apply this plan now?" Options: apply now; apply with local e2e validation first (offer this
   only when the plan's `e2e` is `none`; choosing it changes the plan's `e2e` line and header to
   local, with the suites `app-map.sh` lists); or not now.
   For "not now", stop: the plan stays in `.dependabot-plans/`, and the user can later ask any
   agent to apply it. Skip this question if the request already said whether to apply (e.g.
   "just write a plan" means not now).
7. **Apply:** follow [applying.md](applying.md). It's also what to follow when asked to apply a
   saved plan.

## Decision table

| Merge when all hold | Skip (leave open, give the evidence) when any holds |
|---|---|
| Not a platform major and doesn't require one | Platform major, or requires one: "Needs a planned upgrade" |
| Checks green, apart from failures that also happen on the base branch; `mergeable` not CONFLICTING | Any check fails because of the PR (required or not) |
| Every breaking change in the range was checked and doesn't touch the repo (you can name the grep or file that shows it) | A breaking change applies and needs code or config changes: that's a migration PR. Say what has to change |
| New requirements are met (peers, TargetFramework, engines, runtime), including other packages' declared ranges for it | A requirement isn't met, e.g. a sibling package's range excludes the new version (npm ERESOLVE, NuGet `NU1608`); `legacy-peer-deps=true` in `.npmrc` hides these from CI |
| License unchanged, or still acceptable | License becomes commercial or more restrictive |
| Consistent with every repo hold | Goes against the reason given in a repo hold |
| CI, or your own check, exercises the changed code path | Breaking or behavior changes hit a path CI never runs (config-gated features, manually run workflows) and you can't verify it |
| | Notes can't be found for a `direct:production` major and the diff can't be judged without them |
| | A duplicate or superseded PR (same changes as another open PR, or contained in a grouped one): "superseded by #N" |
| | An obsolete PR: the package is already gone from the base branch, e.g. replaced by another library |

**Defer** a PR that passes review but can't merge as it is: it conflicts with a `merge` PR and
needs a rebase after that one merges, it conflicts with the base and needs `@dependabot rebase`,
or its required checks never ran (it predates the workflows). A review never rebases anything,
so these are always defer lines, never merge lines. Record it with
`plan.sh lines defer OWNER/REPO N --reason "..."`; apply never merges it, and
[applying.md](applying.md) says how it becomes a `merge` line later.

Lockfile-only `indirect` patch/minor bumps usually only need the keyword hits checked. Majors and
every `direct:*` bump need the full notes for the range.

## Common mistakes

- **Skipping a non-platform major because it's a major.** Many majors only drop old runtimes or
  APIs the repo doesn't use.
- **Trusting the title.** "Bump vite and @angular-devkit/build-angular" can be a two-major
  build-system upgrade. The inventory's `deps:` and manifest lines show what changed.
- **Detail in public text.** Keep approval and comment bodies generic. Don't name advisories or
  alerts.

## Report

Use the plan's lists, as [plan-template.md](plan-template.md) lays them out, for both the plan and
the final report. Add the e2e result if it ran (suites, pass/fail, the culprit if isolated), any
PRs Dependabot opened or closed during the run, and the base-branch CI result.

## Extending

Ecosystems: [ecosystems.md](ecosystems.md). Repo facts: [repo-notes.md](repo-notes.md). Platform
names: `PLATFORM_RE` in `scripts/lib.sh`. Parsing gaps (`?` versions, `source: unknown`):
`deps_json` in `scripts/lib.sh`.
