---
name: crucible-pr
description: Open a pull request for Crucible work, with a description written as release notes. Use whenever the user asks to open, create, put up, raise or draft a PR, or to get a branch ready for review, in any Crucible repo (the cmu-sei app repos under /mnt/data/crucible, or crucible-development), even if they don't mention the description. Also use to refresh an existing PR's description after new commits, and for PRs stacked on another PR's branch.
---

# Crucible PR

Opens a draft PR whose description reads like release notes. Operators read these descriptions to learn what they must do when deploying, teammates to learn what changed, and reviewers to decide where to look closely.

## Before opening

- Only open a PR when the user asked for one. Asking for a commit or a push isn't asking for a PR.
- Run the relevant build and tests at the branch tip if they haven't run at this commit. Only the tip, not each commit: PRs are squash-merged.
- The base is the repo's default branch. If the user says the branch is stacked on another PR's branch, the parent branch is the base, so the PR shows only this layer.

## Write the description

Write from what you know from doing the work: why it was needed, what the user asked for, the decisions made, and approaches that were ruled out. Use the diff against the base to confirm what the code ends up as.

Follow [assets/template.md](assets/template.md) for the sections, what counts as a breaking change or an API change, and the writing rules.

These repos are public. Don't reference internal or private material.

## Open it

Push the branch if needed (never force-push unless the user says to), write the body to a temporary file outside the repo, and open it with every target explicit:

```bash
gh pr create --draft --repo <owner/name> --base <base> --head <head> \
  --title "<title>" --body-file <file>
```

Then report the PR URL.

**Stacked PRs:** open each layer's PR this way, with its parent branch as `--base`. Once every layer has a PR, link them, bottom first, using PR numbers:

```bash
gh stack link <bottom-pr> <next-pr> ...
```

Use PR numbers, not branch names: given a branch, `gh stack link` creates a PR for it. For the same reason, don't use `gh stack submit`.

## Keep it current

When later commits change what the description says, rewrite it and update it with `gh pr edit <number> --repo <owner/name> --body-file <file>`. Update the title too if the outcome changed.
