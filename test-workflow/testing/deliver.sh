#!/usr/bin/env bash
# Delivery of ready repos (orchestration/RULES.md, Delivery; testing/README.md, "Delivery").
#
#   deliver.sh summary <worktree>...
#       the pre-push summary of one batch, per repo: preflight (identity, gh auth and the workflow scope,
#       level with origin, no production file changed, no forbidden file, a current and passing verify
#       log, 0 missing and 0 provisional gates, 0 unaccounted removals, the commit-message file within the
#       Delivery limits, attribution scan), then the files deleted, the tests added and removed, the
#       unmatched removals, the gates line, the commit message, the PR comment and the regenerated PR
#       sections. Changes nothing but the remote-tracking refs (git fetch). Ends with the batch id.
#   deliver.sh push --batch <id> [--dry-run] <worktree>...
#       only after the user's word on that summary: refuses if any repo changed since the summary (the
#       batch id is computed again). Per repo: attribution scan, commit as the git identity of the person
#       delivering (git config user.name and user.email; gh logged in as their account; a missing one
#       stops the repo) from the commit-message file, push with lease, open the PR for an API branch that has
#       none, regenerate the PR body's "Gate coverage" and "Removed-test accounting" sections, post the
#       2-5 line PR comment, attribution scan again. --dry-run prints each command instead.
#
# Stops a repo at the first failed step and says why; the other repos of the batch go on.
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/deliver.js" "$@"
