---
name: review-dependabot-prs
description: Use when asked to review, triage, approve, or merge Dependabot pull requests (dependency bump PRs) in crucible-development or any repo in scripts/repos.json, including deciding whether a major version bump is safe, validating bumps against the crucible-tests e2e suites, applying a saved Dependabot plan from .dependabot-plans/, or when a Dependabot merge fails with "required status checks are expected", conflicts with another bump, or waits on a check that never finishes.
---

# Reviewing and merging Dependabot PRs

Decide each bump from evidence: the release notes for every version in the range, checked
against how this repo uses the package. A major bump is fine when none of its breaking changes
affect the repo. A patch is not fine when its notes say it breaks something the repo relies on.
Green CI supports the decision but doesn't replace reading the notes.

In this file, `scripts/*.sh` means this skill's own scripts (run them with `bash`, from
crucible-development). Other paths are relative to the repo under review, whose local clone
`bash scripts/app-map.sh OWNER/REPO` prints.

The scripts print `ERROR` when a GitHub call fails, and GitHub refuses connections in bursts,
especially when many calls run at once. An `ERROR` means unknown, never none: rerun it. Run
the scripts one at a time.

## Ask first

Before reviewing, ask whichever of these two questions the user's request doesn't already
answer: both in one AskUserQuestion call, just the unanswered one, or none if it answers both.

1. **Approve and merge, or dry run?** Either write the plan and apply it right away, or write the
   plan and change nothing until the user approves it (like `terraform plan`, then `apply`).
2. **Validate with e2e first?** Either apply on the strength of review plus CI, or at apply time
   first merge the plan's PRs together in the local clone, run the app's crucible-tests e2e
   suites on the result, and merge on GitHub only if they pass. This sets the plan's `e2e` mode.
   A dry run never runs the suites.

The e2e suites are slow. Run them once per batch, never once per PR, unless the user asks for
per-PR runs.

## Platform upgrades are out of scope

A major bump of a platform is never merged from a Dependabot PR, whatever its release notes or CI
say. Platforms are frameworks, runtimes and servers whose upgrade touches the whole app (Angular,
.NET, Aspire, Node, Go, Postgres, Keycloak), so they get a planned upgrade instead. The exact
package and image names are `PLATFORM_RE` in `scripts/lib.sh`, and the inventory marks matches
`<< PLATFORM major`. A bump whose new version *requires* a platform major counts too: its
peerDependencies need an `@angular/core` major the repo isn't on, or its nuspec has no build for
the repo's TargetFramework. `typescript` and `zone.js` count only that way: a bump is a planned
upgrade only when the new version is outside the peer range of the repo's `@angular/core`
(`npm view @angular/core@<version> peerDependencies`). Leave these PRs open without commenting, and list them under "Needs
a planned upgrade". Minor and patch bumps of platforms are reviewed like any other bump.

## Workflow

1. **Inventory:** `bash scripts/inventory.sh OWNER/REPO`. Set aside `<< PLATFORM major` PRs. Act
   on its other markers: `check ... @angular/core peer range` (typescript and zone.js, see above),
   `CONFLICT` (the PR's text, commit metadata and diff disagree on a version: trust the diff and
   say so), and `duplicate of #N` (verdict "superseded"). It exits 1 when any lookup failed.
   Every app repo's settings match Alloy.Api (Alloy.Ui for UIs), including the Dependabot
   auto-merge workflow `.github/workflows/dependabot-pr-merge.yml`. It approves and auto-merges
   updates up to its `update-types` (default: patch) once checks pass, so review those only if
   they're stuck. A `github-actions` approval on a PR above that level isn't a review: review it.
   The inventory header shows the workflow's state. A `WARNING` there is a settings deviation to
   report and fix; don't review around it.
2. **Read the release notes:** `bash scripts/release-notes.sh OWNER/REPO N [--dep NAME]`. Don't
   rely on the notes Dependabot pastes into the PR: they're truncated, newest first, and usually
   cut before the `.0` releases where breaking changes are listed. Use
   `gh release view <tag> -R <owner/repo>` for anything the script cuts short. When a
   dependency's old version is unknown, take it from the PR's table or manifest diff.
3. **Check the notes against the repo:** for each breaking change, removal or new requirement,
   grep the base branch for what it names, and compare the requirements with what the repo
   runs. A direct package can move transitive packages for every deployment, even when its own
   feature is switched off by config. Honor the repo's holds (`.github/dependabot.yml` `ignore`
   rules, deferral docs, `Deferred:` comments in manifests) by their stated reason, not just the
   version they name: a hold on MediatR 13+ for licensing still allows a 12.x patch. Read
   [ecosystems.md](ecosystems.md) for the PR's ecosystem and [repo-notes.md](repo-notes.md) for
   the repo.

   Read every failing check, required or not (`gh run view <run> --log-failed`): a failure the PR
   causes is a skip even when the check isn't required. Checks that CI never runs are yours to
   cover. Common examples are lint for eslint-family bumps, and generated swagger and clients for
   Swashbuckle bumps. Building, testing or generating locally is part of a review, e2e or not.
   Two PRs you'd merge can conflict even when both show MERGEABLE. Fetch both heads and run
   `git -C <clone> merge-tree --write-tree <head-A> <head-B>`; if it reports a conflict, merge one
   and defer the other.
   To read PR files without changing the clone's checkout:
   `git -C <clone> fetch origin pull/N/head && git -C <clone> worktree add --detach /tmp/<repo>-pr-N FETCH_HEAD`.
   Remove the worktree when you're done.
4. **Decide each PR** with the table below. A PR passes only if every dependency in it passes.
5. **Write the plan:** copy [plan-template.md](plan-template.md) to
   `.dependabot-plans/<YYYY-MM-DD>-<repos>.md` in crucible-development (gitignored). Fill in the
   verdicts with their evidence (the Report section below). Generate the plan data with
   `bash scripts/plan.sh lines merge|defer|skip|upgrade OWNER/REPO N ...`, which records each
   PR's reviewed head commit. List `merge` lines in the order to merge them: a grouped PR before
   the PRs it overlaps. Set `e2e` from question 2. The plan must stand alone: an agent with only
   that file can apply it.
6. **Dry run:** show the plan's lists and its path, then ask in one AskUserQuestion call:
   "Apply this plan now?" Options: apply now; apply with local e2e validation first (offer this
   only when the plan's `e2e` is `none`; choosing it changes the plan to `e2e local`); or not now.
   For "not now", stop: the plan stays in `.dependabot-plans/`, and the user can later ask any
   agent to apply it. Otherwise continue as an apply. Skip this question if the request already
   said whether to apply (e.g. "just write a plan" means not now).
7. **Fix what blocks merging:**
   - A PR missing a check that newer PRs have predates that workflow, and its merge fails with
     "N of N required status checks are expected": `gh pr update-branch N -R OWNER/REPO --rebase`.
     (Being behind the base only blocks when the merge state is `BEHIND`.)
   - A conflicting PR: comment `@dependabot rebase` and come back to it.
   Both move the PR's head. After it rebuilds, confirm that its dependency changes are the ones
   you reviewed (`inventory.sh OWNER/REPO N`). Then refresh its plan line with `plan.sh lines`,
   or `check` reports it stale.
8. **Apply:** with `e2e none`, `bash scripts/plan.sh apply <plan>` (run it in the background).
   It merges, one at a time and in plan order, only the PRs still at their reviewed
   commit. It approves (as the signed-in gh user) only when GitHub refuses the merge for a missing
   review, and it exits non-zero if any PR didn't merge; the summary says why and what to do next. With `e2e local`, follow [local-e2e.md](local-e2e.md) with the plan's merge
   PRs; on failure, stop and ask the user whether to isolate the culprit.
9. **Re-inventory:** merges make Dependabot regroup, opening new PRs and closing superseded ones.
   The new ones aren't in the plan: review them from step 1, into a new plan.
10. **Confirm** that base-branch CI on the last merge commit is green.

## Applying a saved plan

When asked to apply a plan file, don't redo the review. Follow the plan's "How to apply":
`plan.sh check`; leave out and re-review anything `STALE`; then step 8 by the plan's `e2e` mode;
then steps 9 and 10. Applying merges on GitHub, so the user's request to apply it is the go-ahead.

## Decision table

| Merge when all hold | Skip (leave open, give the evidence) when any holds |
|---|---|
| Not a platform major and doesn't require one | Platform major, or requires one: "Needs a planned upgrade" |
| Checks green; `mergeable` not CONFLICTING | Any check fails because of the PR (required or not) |
| Every breaking change in the range was checked and doesn't touch the repo (you can name the grep or file that shows it) | A breaking change applies and needs code or config changes: that's a migration PR. Say what has to change |
| New requirements are met (peers, TargetFramework, engines, runtime), including other packages' declared ranges for it | A requirement isn't met, e.g. a sibling package's range excludes the new version (npm ERESOLVE, NuGet `NU1608`); `legacy-peer-deps=true` in `.npmrc` hides these from CI |
| License unchanged, or still acceptable | License becomes commercial or more restrictive |
| Consistent with every repo hold | Goes against the reason given in a repo hold |
| CI, or your own check, exercises the changed code path | Breaking or behavior changes hit a path CI never runs (config-gated features, manually run workflows) and you can't verify it |
| | Notes can't be found for a `direct:production` major and the diff can't be judged without them |
| | A duplicate or superseded PR (same changes as another open PR, or contained in a grouped one): "superseded by #N" |
| | An obsolete PR: the package is already gone from the base branch, e.g. replaced by another library |

**Defer** a PR that passes review but can't merge in this plan. Typical reasons: it conflicts
with a `merge` PR and needs a rebase after that one merges, or its required checks never ran (it
predates the workflows) and needs `gh pr update-branch`. Record it with
`plan.sh lines defer OWNER/REPO N --reason "..."`. Apply never merges it. After the rebase,
refresh its line with `plan.sh lines` and confirm its changes are the ones you reviewed.

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

The plan document and the final report use the same lists (leave out an empty Deferred list):
- **Merged** (or recommended for merging): for each major, name the breaking changes and why
  each doesn't apply (e.g. "drops Node 18 (repo on 22); removes `foo()`: no hits in
  `projects/app/src`").
- **Skipped:** cite the note, requirement or failing check (e.g. "#120: Microsoft.OpenApi 3
  breaks Swashbuckle 10 (`IOpenApiMediaType` build error); needs a Swashbuckle major with it").
- **Deferred:** passes review, and what has to happen first (e.g. "#146: rebase after #152 merges").
- **Needs a planned upgrade:** the platform and target major (e.g. "#255, #258: Angular 19 -> 21
  build tooling; #276: ngx-markdown 22 requires Angular 22").

Add the e2e result if it ran (suites, pass/fail, the culprit if isolated), any PRs Dependabot
opened or closed during the run, and the base-branch CI result.

## Extending

Ecosystems: [ecosystems.md](ecosystems.md). Repo facts: [repo-notes.md](repo-notes.md). Platform
names: `PLATFORM_RE` in `scripts/lib.sh`. Parsing gaps (`?` versions, `source: unknown`):
`deps_json` in `scripts/lib.sh`.
