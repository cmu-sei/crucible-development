# Dependabot plan: <repos>, <YYYY-MM-DD>

<!-- Written by the review-dependabot-prs skill. An agent can apply it without redoing the
     review: see "How to apply". Keep this file out of git. -->

Reviewed <UTC timestamp> by <agent>, at the user's request. Nothing was changed on GitHub while
writing it.
E2e validation for apply: <none | local (suites: ...)>.

## Will merge

- **OWNER/REPO #N** <title>: <evidence: breaking changes checked and why they don't apply,
  license, requirements, CI>. If it also bumps a package that a skipped PR below is about (common
  in grouped PRs), say why this bump is fine when that one isn't.
  <!-- e.g. "Example.Ui #12: drops Node 18, repo on 22; removes foo(), not used in src" -->

## Deferred (passes review; not merged by this plan)

- **OWNER/REPO #N** <title>: <evidence>. First: <what has to happen, e.g. rebase after #M merges>.
  <!-- leave this section out when nothing is deferred -->

## Will not merge (skipped)

- **OWNER/REPO #N** <title>: <the note, requirement or failing check>.
  <!-- e.g. "Example.Api #15: the required build fails, error CS0266; needs a Swashbuckle major" -->

## Needs a planned upgrade

- **OWNER/REPO #N** <title>: <platform and target major>.
  <!-- e.g. "Example.Ui #16: build-angular 19 -> 21 (Angular platform major)" -->

## Plan data

Generated with `plan.sh lines`, given each PR as `N@SHA` with the `head:` that `inventory.sh`
printed for the review. Don't edit the SHAs by hand: they are the commits that were reviewed;
`lines` refuses a PR that has moved off its SHA, and apply refuses any PR whose head has moved
since. To update a line after a rebase, regenerate it with `plan.sh lines` (see `applying.md`).

```dependabot-plan
version 1
created <UTC timestamp>
e2e <none|local>
<output of: plan.sh lines merge OWNER/REPO N@SHA ...>   (in merge order: grouped PRs first)
<output of: plan.sh lines defer OWNER/REPO N@SHA --reason "..." >
<output of: plan.sh lines skip OWNER/REPO N@SHA ...>
<output of: plan.sh lines upgrade OWNER/REPO N@SHA ...>
```

## How to apply

Scripts: `/workspaces/crucible-development/.agents/skills/review-dependabot-prs/scripts/`. The
full procedure is `applying.md` next to them, in the skill folder: read it first.

1. `bash <scripts>/plan.sh check <this file>`. A `STALE` PR whose head moved only by a rebase gets
   a refreshed line; one whose dependency changes changed is left out and reviewed again.
2. Unblock the deferred PRs that need a rebase, as `applying.md` says.
3. If e2e is `none`: `bash <scripts>/plan.sh apply <this file>` (add `--dry-run` to preview). It
   merges only the PRs still at their reviewed commit, in plan order. If e2e is `local`: follow
   `local-e2e.md` in the skill folder instead.
4. A deferred PR waiting on a merge: after that merge lands, rebase it (or wait for Dependabot),
   confirm its changes with `inventory.sh`, replace its line with
   `plan.sh lines merge OWNER/REPO N@<the head inventory.sh printed>` output,
   and run steps 1 and 3 again.
5. Re-inventory with `inventory.sh`: new PRs, and skipped ones that changed, need a new review.
6. Report what merged, what was stale or deferred, and base-branch CI on the last merge commit.
