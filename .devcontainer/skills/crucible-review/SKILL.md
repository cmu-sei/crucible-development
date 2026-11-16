---
name: crucible-review
description: Get an independent code review from a different model, run through its own CLI. Use when the user wants the review done by someone other than you (a second opinion, an independent or cross-model review, a review by another named model or agent, or a re-check by the reviewer that ran before) for a PR number (including teammates' PRs), a branch, or uncommitted changes in any Crucible repo. Also used by the crucible-pr skill's review steps. Don't use it for a plain request to review or look over a change; do that review yourself. Not for opening PRs or posting GitHub review comments.
---

# Crucible review

Runs a review by a separate model in its own session, so the review isn't anchored on the author's reasoning. Ideally the reviewer is from a different vendor than the author.

## Pick the target

- **A PR** (including a teammate's): review it in a temporary worktree so the user's working tree isn't touched:

  ```bash
  gh pr view <n> --repo <owner/name> --json headRefOid,baseRefName,title,body
  git -C <repo> fetch origin pull/<n>/head <base>
  git -C <repo> worktree add --detach <tmp-dir> <headRefOid>
  ```

  The range is `origin/<base>..<headRefOid>`. Remove the worktree when you're done (`git worktree remove <tmp-dir>`).
- **A branch:** the range is `<base>..<branch>`. The base is the default branch, unless the user names one.
- **Uncommitted changes:** use `uncommitted` as the range.

## Pick the reviewer and lens

- **Reviewer:** [reviewers.json](reviewers.json) maps each profile to a CLI, model and effort. Use the profile the user names. Otherwise use the `ad-hoc` entry for the CLI you're running in, which picks another vendor's model. For a model or effort with no profile, pass `<cli>:<model>:<effort>` instead of a profile name. It needs the full model ID: if the user gives only a name, ask for the ID or confirm a guess based on the existing profiles. A CLI with no adapter in `review.sh` isn't supported.
- **Lens:**
  - `review`, the default: correctness, tests, security, alignment with the task
  - `simplify`, when the user asks for a simplification pass
  - both, if asked; run them as separate reviews

## Write the task statement

Write it to a file: what the change is meant to do and why. For a PR, use its title and description. For your own work, use what the user asked for. Leave out your own opinion of the change, so the reviewer judges it fresh.

## Run it

```bash
scripts/review.sh run <profile> <lens> <repo-or-worktree> <range> <task-file>
```

It prints the run directory, which holds `findings.json` and `meta.json`. Reviews take several minutes, so run them in the background, and run two reviewers in parallel when the user asks for two.

A non-zero exit means the review is **incomplete**: report that, with `stderr.log`, and don't present it as a clean review. Retry only if you can see a recoverable cause.

## Report

List the findings by severity. For each one, give the reviewer and model, the file and line, the failure scenario, and the suggested fix. Then give your own view on each finding, kept separate from the reviewer's: you can check it against the code.

Don't apply fixes or post anything to GitHub unless the user asks.

## Re-check after fixes

When the user wants the same reviewer to confirm fixes, write a prompt file. It says which findings were fixed (with commits) or declined (with reasons), and asks the reviewer to confirm each fix and flag anything new the fixes introduced. Then run:

```bash
scripts/review.sh resume <run-dir> <prompt-file>
```

This resumes the reviewer's own session, so it remembers why it raised each finding.
