# Orchestrating the Crucible test work

For the main session that drives the test agents across the Crucible repos, in Claude Code or Oh My Pi. Read [RULES.md](RULES.md) first; terms are in [../GLOSSARY.md](../GLOSSARY.md). The steps and agent roles are defined in the shared core, [../testing/README.md](../testing/README.md), with the stack-specific parts in each standard's WORKFLOW file; this guide covers what only the orchestrator does.

## Where things are

- **Worktrees:** `/mnt/data/crucible/.worktrees/<repo>`. APIs on branch `api-test-standard`, UIs on `vitest-migration`.
- **Standards:** `agent-docs/api-testing/`, `agent-docs/ui-testing/` (and, from the 2026-10-12 standard version, the shared core in `agent-docs/testing/`).
- **Current round:** the newest file in [rounds/](rounds). It holds the plan, the per-repo state and every state change, appended as it happens.
- **Reviews and decisions:** [reviews/](reviews). Finished rounds' scratch files: [archive/](archive).
- **Scratch:** `/tmp` holds only throwaway output; anything a later session needs goes here.

## Starting a session

1. Read the current round file's plan and its last entries.
2. Check every worktree: branch, clean tree, level with origin (`agent-docs/testing/status.sh`).
3. Before a round that ends in delivery, check identity and auth (RULES.md, Delivery).

## Driving a round

1. **Work list per repo** comes from the checks, never from a summary: `check-repo.js gates|removed|specs` as [../testing/README.md](../testing/README.md) ("Script usage") gives them.
2. **Launch** writers per repo in their worktree, at most seven agents at once. Each task prompt names the worktree, the app, the writer mode, the work list, and these files to read first: RULES.md, GLOSSARY.md, `testing/README.md`, the standard's WORKFLOW.md and CONVENTIONS.md, and the group `AGENTS.md`.
3. **Review** each repo as its writer reports. In audit mode the reviewer reads the diff since the repo's last ready commit plus the check output; the task message gives that commit (from the round file, or `agent-docs/testing/status.sh`) and the writer's verify and break-gate log paths.
4. **Route** reviewer findings: test fixes back to the same writer (resumed, transcript intact); standard flaws to the proposals file for the next standard version. After a repo's second review with blocking findings, take them to the user with a recommendation instead of resuming the writer (RULES.md, Process).
5. **Deliver** ready repos through `deliver.sh` (built in the 2026-10-12 standard version): first run `orchestration/ci-check.sh local <worktree>` on each (the tree merged with current main, as CI will test it; a FAIL blocks the repo), then show the user the pre-push summary per batch and push only on their word.
6. **Confirm green** after every push: launch `ci-watcher` (Claude Code: the agent; Oh My Pi: the same agent, pinned in `.omp/config.yml`), or run `orchestration/ci-check.sh status`, until each PR of the batch is green or every failure is classified. A repo is reported done only when green (RULES.md, Delivery).
7. **When main moves** (a watcher, `ci-check.sh status` BEHIND or CONFLICT): merge it per RULES.md, Delivery ("Keep up with main"), then run a writer round on what it changed.
8. **Log** every state change in the round file as it happens.

## Ending a session

Append to the round file what is running, what is waiting on the user, and the next step, so the next session starts from it alone.
