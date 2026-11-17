---
name: crucible-pr
description: Open a reviewed pull request for Crucible work. Use whenever the user asks to open, create, put up, raise or draft a PR, or to get a branch ready for review, in any Crucible repo (the cmu-sei app repos under /mnt/data/crucible, or crucible-development), even if they don't mention review or the description. Also use to refresh an existing PR's description after new commits, for PRs stacked on another PR's branch, and for the same change across several repos.
---

# Crucible PR

Opens a PR that has been independently reviewed, with a description that reads like release notes. Operators read these descriptions to learn what they must do when deploying, teammates to learn what changed, and reviewers to decide how much attention the PR needs and where to look.

The review steps use the crucible-review skill's `~/.agents/skills/crucible-review/scripts/review.sh` and `~/.agents/skills/crucible-review/reviewers.json`. `~/.agents/skills/crucible-pr/scripts/record.sh` keeps the review record that the PR gate checks before it lets the PR open; run it from inside the repo. Below, `review.sh` and `record.sh` mean these paths.

## Before reviewing

- Only open a PR when the user asked for one. Asking for a commit or a push isn't asking for a PR.
- Run the relevant build and tests at the branch tip if they haven't run at this commit. Only the tip, not each commit: PRs are squash-merged.
- The base is the repo's default branch. If the user says the branch is stacked on another PR's branch, the parent branch is the base, so only this layer is reviewed and shown.
- Start the record, in the repo: `record.sh init <base> <cli>`, where `<cli>` is the CLI you're running in (a key under `tiers` in `reviewers.json`).
- Write a task statement to a file outside the repo: what the change is for and why, from what the user asked. Leave out your own opinion of the change, so reviewers judge it fresh.
- For the same change across several repos, read [references/batch-mode.md](references/batch-mode.md).

## Review

Run each step with `review.sh run <profile> <lens> <repo> <base>..<head> <task-file>`, taking the profile from the matching tier in `reviewers.json` for your CLI. Record each completed run with `record.sh add-run <pass> <run-dir>`. A run that exits non-zero is incomplete: fix the cause or tell the user, and never treat it as a clean review.

1. **Simplify** (tier `simplify`, lens `simplify`). Apply or decline each suggestion, and record it with `record.sh dispose`. If there's an `approach` finding, rework the change or decline with a reason. A rework starts this step again, so you don't polish code that's about to be replaced.
2. **Risk** (tier `risk`, lens `risk`). Add the tests that ran at the tip, and their results, to the task file. The scorer's tier picks the reviewers.
3. **Review** (the scored tier: `low`, `medium` or `high`; lens `review`). When there are two reviewers, run them in parallel.
4. **Fix.** Check each finding against the code before changing anything. Then fix it, committing the fix, or decline it with a technical reason. Record each one with `record.sh dispose <run-dir> <id> fixed <commit>` or `declined "<reason>"`. A reasoned decline is final.
5. **Re-check.** At medium and high risk, resume each reviewer with `review.sh resume <run-dir> <prompt-file>`. The prompt lists the dispositions and fix commits, and asks the reviewer to confirm each fix and flag anything new. Tell it that declined findings, with their reasons, are settled, so it doesn't raise them again. Record the re-check with pass `recheck`, and handle its findings the same way. After 3 rounds, stop and ask the user whether to keep going, decline what's left with reasons, or open the PR themselves.
6. **Final check.**
   - Run the relevant tests at the final HEAD unless they already ran at this commit, and record each run with `record.sh tests`.
   - If the code or the test evidence changed since the scorer ran, resume it with the new test results and any fix commits, and record it as pass `risk`. The latest score is the one shown in the PR.
   - If the tier went up, run the new tier's additional reviewers and handle their findings the same way.
7. `record.sh finalize`, then `record.sh check`. Fix whatever it lists.

## Write the description

Write from what you know from doing the work: why it was needed, what the user asked for, the decisions made, and approaches that were ruled out. Use the diff against the base to confirm what the code ends up as.

Follow [assets/template.md](assets/template.md) for the sections, what counts as a breaking change or an API change, and the writing rules. `record.sh summary` prints the Risk & review section; place it where the template shows. The risk label carries the tier everywhere else, so there's no separate risk line.

These repos are public. Don't reference internal or private material.

## Open it

Push the branch if needed (never force-push unless the user says to), write the body to a temporary file outside the repo, and open it with every target explicit. Open it as a draft unless the user says otherwise:

```bash
gh pr create --draft --repo <owner/name> --base <base> --head <head> \
  --title "<title>" --body-file <file>
```

Add the risk label, creating it if the repo doesn't have it yet:

```bash
gh label create risk:<tier> --repo <owner/name> --color <0e8a16|fbca04|d93f0b> 2>/dev/null || true
gh pr edit <number> --repo <owner/name> --add-label risk:<tier>
```

The colors are green for low, yellow for medium and red for high. Then report the PR URL.

**Stacked PRs:** review and open each layer this way, with its parent branch as `--base`. Once every layer has a PR, link them, bottom first, using PR numbers:

```bash
gh stack link <bottom-pr> <next-pr> ...
```

Use PR numbers, not branch names: given a branch, `gh stack link` creates an unreviewed PR for it. For the same reason, don't use `gh stack submit`.

## Keep it current

When later commits change what the description says, rewrite the template's sections and keep any section a person added, such as a walkthrough video or screenshots. Update it with `gh pr edit <number> --repo <owner/name> --body-file <file>`. Update the title too if the outcome changed. New commits aren't reviewed yet, so add ", later commits not reviewed" after the commit in the Risk & review header.
