# Crucible test workflow

A shared test standard, with the scripts and agents that write, review and deliver tests for the 17 Crucible-family repos: the eight APIs (alloy, blueprint, caster, cite, gallery, steamfitter, player, vm) on xUnit v3 with Testcontainers PostgreSQL, and the nine Angular UIs (the same eight plus console) on Vitest and Angular Testing Library. Agents in Claude Code or Oh My Pi do the writing and reviewing; scripts do every check that can be scripted (the authorization-gate inventory, the removed-test accounting, the broken-gate check, verify, delivery).

## Method here, state on your volume

The workflow has two halves, kept apart on purpose.

- **The method is in this folder**: the standards and their scripts, the agent definitions, the standing rules, the glossary and the orchestrator guide. It is versioned here and changed by pull request, like the rest of the dev container.
- **The state stays on your `/mnt/data` volume**, under `/mnt/data/crucible/agent-docs/`, and never enters any repo: defect documents (`api-test-bugs/`, `ui-test-bugs/`), allow-lists (`api-test-gaps/`, `ui-test-gaps/`), writers' work files and logs (`test-work/`), triage docs (`*-test-triage/`), Jira drafts (`jira/`), round logs and reviews (`orchestration/rounds/`, `reviews/`, `archive/`) and proposals files (`*-proposals-*.md`).

Why: the Crucible repos are public, and the state describes real defects, security defects among them, found in those apps. They reach the people who fix them through Jira, not through a repo. The rules say the same for test code ([orchestration/RULES.md](orchestration/RULES.md), Scope). The scripts write state only to `/mnt/data/crucible/agent-docs`, whichever checkout they run from, and this folder's `.gitignore` ignores the state names in case anything writes one here.

## Setup

1. In the dev container, with the repos cloned to `/mnt/data/crucible` (`scripts/clone-repos.sh`, run by `postcreate.sh`), run:

   ```sh
   scripts/setup-test-workflow.sh            # or --dry-run first, to see what it would do
   ```

   It links the method into the workspace and creates the empty state folders:

   | In `/mnt/data/crucible` | Links to, in this folder |
   | --- | --- |
   | `agent-docs/testing`, `api-testing`, `ui-testing`, `omp` | `testing/`, `api-testing/`, `ui-testing/`, `omp/` |
   | `agent-docs/GLOSSARY.md` | `GLOSSARY.md` |
   | `agent-docs/orchestration/RULES.md`, `ORCHESTRATOR.md`, `ci-check.sh` | `orchestration/` |
   | `.claude/agents/<agent>.md`, one link per agent | `agents/` |
   | `.omp/config.yml`; `.omp/agents` links to `../.claude/agents` | `dot-omp/config.yml` |

   It is safe to rerun. It never overwrites or deletes anything: a real file or folder (or a link pointing elsewhere) in the way is reported as `SKIP` with what the script would have done. To adopt this folder's copy, move yours aside and rerun. To run it on every container create, add `scripts/setup-test-workflow.sh` to `.devcontainer/postcreate.sh` after `scripts/clone-repos.sh`; the script prints that line.

2. Set your own identity: `git config --global user.name` and `user.email`, and `gh auth login` with the `workflow` scope. You are the author of what you deliver; `deliver.sh` reads both and refuses without them ([RULES](orchestration/RULES.md), Delivery).

3. Make a worktree per repo you work on under `/mnt/data/crucible/.worktrees/<repo>`: APIs on branch `api-test-standard`, UIs on `vitest-migration` (see [ORCHESTRATOR.md](orchestration/ORCHESTRATOR.md)).

4. Start Claude Code or Oh My Pi in `/mnt/data/crucible`, so the agents, the workspace `AGENTS.md` and (for Oh My Pi) `.omp/config.yml` load: `cd /mnt/data/crucible && claude`, or `omp` from the same folder ([omp/README.md](omp/README.md)). That session is the orchestrator. Read [RULES.md](orchestration/RULES.md), [GLOSSARY.md](GLOSSARY.md) and [ORCHESTRATOR.md](orchestration/ORCHESTRATOR.md) first.

## The agents

The orchestrator launches them; agents cannot start agents. One set of files serves both harnesses.

| Agent | Role |
| --- | --- |
| `dotnet-test-writer`, `angular-test-writer` | write the tests of one repo, in its worktree, until it can be ready; never commit |
| `api-test-reviewer`, `ui-test-reviewer` | judge one repo's tests against the stack's CONVENTIONS; read-only; return ready or not ready |
| `test-standard-maintainer` | the only writer of the standards and their scripts; runs alone, at a version boundary |
| `test-bug-triager` | groups and rates the defects the tests characterize, and drafts issue text |
| `jira-ticket-writer` | turns one approved findings document into paste-ready Jira tickets |
| `ci-watcher` | reports whether each test PR is level with main, merges cleanly and passed CI |

## Main commands

Run from `/mnt/data/crucible/agent-docs`; [testing/README.md](testing/README.md) ("Script usage") has every option.

| Command | Does |
| --- | --- |
| `testing/status.sh [--fetch]` | one row per worktree: branch, clean, level with origin, gates, removed tests, whether the verify log is current |
| `api-testing/verify.sh <worktree>`, `ui-testing/verify.sh <worktree>` | every check of the standard plus three suite runs (5 to 15 minutes; the API one needs Docker); writes a log stamped with the tree hash |
| `testing/break-gate.sh <worktree> --site ... --replace ... --near-miss ...` | breaks one gate, proves its near misses fail, restores the file |
| `testing/deliver.sh summary <worktree>...` | the pre-push summary of a batch; changes nothing |
| `testing/deliver.sh push --batch <id> <worktree>...` | commits as you, pushes, opens or updates the PRs; only after the word of the person running the round on that summary |
| `orchestration/ci-check.sh status`, `local <worktree>` | per PR: GREEN, BEHIND, CONFLICT, PENDING or RED; `local` runs CI's tests on the tree merged with current main |
| `omp/check-agents.sh` | checks the agent files after an edit (no model line, matching reasoning levels) |

## Changing the method

Edit this folder and open a pull request. The links mean the agents and scripts in your workspace run this checkout as it is, so an edit (yours, or the `test-standard-maintainer`'s through `agent-docs/`) is live at once and shows up in `git status` here. Standards change only at a standard version, recorded in the stack's `CHANGELOG.md` ([RULES](orchestration/RULES.md), Process). Never copy state into this folder.

## Read more

- [orchestration/RULES.md](orchestration/RULES.md): the standing rules. [GLOSSARY.md](GLOSSARY.md): the terms (gate, near miss, ready, green, round).
- [orchestration/ORCHESTRATOR.md](orchestration/ORCHESTRATOR.md): driving a round.
- [testing/README.md](testing/README.md): the shared core (workflow, hand-offs, file formats, scripts).
- [api-testing/README.md](api-testing/README.md) and [ui-testing/README.md](ui-testing/README.md): each stack's harness, with `CONVENTIONS.md`, `SETUP.md`, `WORKFLOW.md` and `CHANGELOG.md` beside them.
- [omp/README.md](omp/README.md): running the agents under Oh My Pi, and why no agent names a model.
