# Applying a plan

How a plan's PRs get merged, for a plan written in this session or a saved one from
`.dependabot-plans/`. When asked to apply a saved plan, don't redo the review: the plan is the
review. Applying merges on GitHub, so the user's request to apply it is the go-ahead.
`scripts/` means this skill's scripts folder, given in full in the plan's "How to apply".

**A moved head: refresh or re-review.** Rebasing a PR (by you, or by Dependabot after another
merge) moves its head without changing its dependency changes. Confirm that with
`bash scripts/inventory.sh OWNER/REPO N`, then replace its line in the same plan with
`plan.sh lines VERDICT OWNER/REPO N@SHA` output, SHA being the `head:` that inventory printed.
Never edit a SHA by hand. A PR whose dependency changes did change (new versions, other
packages) is stale: delete its line from this plan and report it as needing a new review.
Applying doesn't do that review; it's a new run of the skill.

## Steps

1. **Check:** `bash scripts/plan.sh check <plan>`. Handle each `STALE` PR as above. A `note` on a
   defer line is expected after its rebase: refresh it in step 2 or 4. A `note` on a skip or
   upgrade line means that PR changed: report it as needing a new review.
2. **Unblock** each `defer` PR whose reason is a base conflict or checks that never ran, and any
   `merge` PR that has since become blocked:
   - Checks that never ran (its merge fails with "N of N required status checks are expected"):
     `gh pr update-branch N -R OWNER/REPO --rebase`. The same fixes a PR whose merge state is
     `BEHIND` (the base requires up-to-date branches); being behind doesn't block otherwise.
   - A conflict with the base: comment `@dependabot rebase`.

   Once it has rebuilt, refresh it as above with `plan.sh lines merge` and move its entry from
   "Deferred" to "Will merge". Put its line where it belongs in merge order.
3. **Merge:**
   - Plan `e2e none`: `bash scripts/plan.sh apply <plan>`, in the background. It merges, one at a
     time and in plan order, only the `merge` PRs still at their reviewed commit. It approves (as
     the signed-in gh user) only when GitHub refuses the merge for a missing review. It exits
     non-zero if any PR didn't merge, and its summary says why and what to do for each.
   - Plan `e2e local`: follow [local-e2e.md](local-e2e.md) with the plan's `merge` PRs. Its merge
     step uses `merge-when-green.sh`, which approves the same way. On a failure, stop and ask the
     user whether to isolate the culprit.
4. **Deferred PRs waiting on a merge:** once the merge a `defer` PR was waiting for has landed,
   rebase it (or wait for Dependabot to), refresh it and move its entry as in step 2, then run
   `check` and step 3 again. With `e2e local`, PRs refreshed after the batch ran go into the next
   batch's local run, not a run of their own.
5. **Re-inventory:** merges make Dependabot regroup, opening new PRs and closing or rebasing
   others. New PRs, and skipped ones that changed, need their own review into a new plan.
6. **Confirm** that base-branch CI on the last merge commit is green, then report what merged,
   what was stale or deferred, and that CI result.
