# Dependabot plan: <repos>, <YYYY-MM-DD>

<!-- Written by the review-dependabot-prs skill in dry-run mode. An agent can apply it
     without redoing the review: see "How to apply". Keep this file out of git. -->

Reviewed <UTC timestamp> by <agent>, at the user's request. Nothing was changed on GitHub.
E2e validation for apply: <none | local (suites: ...)>.

## Will merge

- **OWNER/REPO #N** <title>: <evidence: breaking changes checked and why they don't apply,
  license, requirements, CI>. If it also bumps a package that a skipped PR below is about (common
  in grouped PRs), say why this bump is fine when that one isn't.

## Deferred (passes review; not merged by this plan)

- **OWNER/REPO #N** <title>: <evidence>. First: <what has to happen, e.g. rebase after #M merges>.

## Will not merge (skipped)

- **OWNER/REPO #N** <title>: <the note, requirement or failing check>.

## Needs a planned upgrade

- **OWNER/REPO #N** <title>: <platform and target major>.

## Plan data

Generated with `plan.sh lines`. Don't edit the SHAs by hand: they are the commits that were
reviewed, and apply refuses any PR whose head has moved since.

```dependabot-plan
version 1
created <UTC timestamp>
e2e <none|local>
<output of: plan.sh lines merge OWNER/REPO N ...>   (in merge order: grouped PRs first)
<output of: plan.sh lines defer OWNER/REPO N --reason "..." >
<output of: plan.sh lines skip OWNER/REPO N ...>
<output of: plan.sh lines upgrade OWNER/REPO N ...>
```

## How to apply

Scripts: `/workspaces/crucible-development/.agents/skills/review-dependabot-prs/scripts/`.

1. `bash <scripts>/plan.sh check <this file>`. Any `STALE` PR changed after review: leave it out
   and re-review it with the review-dependabot-prs skill. Don't merge it from this plan.
2. If e2e is `none`: `bash <scripts>/plan.sh apply <this file>` (in the background; add
   `--dry-run` to preview). It merges only the PRs still at their reviewed commit, one at a time in
   plan order, approving as the signed-in gh user only when GitHub requires a review. It exits
   non-zero if any PR didn't merge, and the summary says what to do for each. A PR reported
   `BEHIND` (the base requires up-to-date branches) needs `gh pr update-branch`, a check that its
   changes are the reviewed ones, and a refreshed plan line before re-running.
   If e2e is `local`: follow `local-e2e.md` in the skill for the "Will merge" PRs, then merge with
   `merge-when-green.sh --expect-heads <state file>` as it describes.
3. Re-inventory (`inventory.sh`): merges make Dependabot open, close and rebase PRs. New PRs, and
   skipped ones that `check` reports as changed, need a fresh review; this plan doesn't cover them.
4. Report what merged, what was stale, and base-branch CI on the last merge commit.
