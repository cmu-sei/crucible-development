# Standing rules for the Crucible test work

The team's rules for every orchestrator and agent working on the Crucible test suites, in any harness. This file is the single source of truth for them: agent definitions, standards and briefs link here instead of restating. Terms are defined in [../GLOSSARY.md](../GLOSSARY.md). The person running the round is whoever drives the orchestrator session; where the standards and agent definitions say "the user", they mean that person. Where a rule's reason is not obvious, it is given in a sentence, so a later reader can judge an edge case.

## Scope

**Tests only.** The work is test files (`*.spec.ts`, the `*.Tests` projects), the test standards, and workspace test docs (defect docs, removed-test accountings, allow-lists, Jira drafts, and the writers' work files in `agent-docs/test-work/<app>/`: notes, commit message, verify and broken-gate logs). Production code stays as it is; the one contact is the writer's broken-gate check, restored and proven with `git status`. Product questions and defect fixes are out of scope: tests pin current behaviour, defects go to the defect docs, and the Jira drafts are how fixes reach humans.

**Workspace docs stay in the workspace.** The workflow's state (defect docs, accountings, allow-lists, writers' work files, Jira drafts, round logs, proposals, triage docs and reviews, all under `agent-docs/`) lives on each person's `/mnt/data` volume, outside every repo, and is never committed to any repo, crucible-development included. The method (the standards, scripts, agents and these rules) is versioned in crucible-development's `test-workflow/` and linked into `agent-docs/` and `.claude/agents/` by `scripts/setup-test-workflow.sh`; no app repo carries either. Allow-lists live in `agent-docs/api-test-gaps/<app>.txt` and `agent-docs/ui-test-gaps/<app>.json`; an in-repo copy fails the check.

**Defects are described in docs, never in repo code.** A test asserts the current behaviour with a neutral comment; the defect, its production location, the expected behaviour, the **Fix** and the **Test to flip** go in `agent-docs/{api,ui}-test-bugs/<app>.md`. Why: the cmu-sei repos are public, and a defect described in code or in a public doc publishes it.

## Test quality

**A missing gate blocks delivery.** A repo is delivered only when [ready](../GLOSSARY.md); a writer's follow-up list of uncovered gates is a blocker, and a gap the person running the round accepts is named in the PR body. Deleted boilerplate specs become smoke specs. Why: a round once shipped with most gated components untested.

**Every permission value has its own allowed case and near miss.** For each value a gate reads, an allowed case holds exactly that value with a non-Root actor, and the denied case is a near miss.

**No test behaviour is lost.** Every removed test has a removed-test accounting line (still asserted elsewhere, or proven unreachable); a narrowed replacement counts as a loss and is restored before delivery. Assertions inside fakes and stubs count. Why: a "ready" verdict once hid hundreds of removed tests in one repo, some of them real losses.

**One generic UI standard.** Every UI copies `agent-docs/ui-testing` verbatim; only `default-test-providers.ts` and `mock-permission-data.service.ts` are app-specific. Describe no UI as the reference implementation. Tests run the way the app runs (Angular 21, `zone.js` in polyfills, `@angular/build`).

**Standard choices already made.** Suites keep their size (no collapsing). Hand-rolled helpers stay; ng-mocks and Spectator are not adopted; no Prettier for specs.

## Delivery

**Commit and push only on the word of the person running the round**, given per repo or per batch, after the pre-push summary.

**A PR is done only when green.** Ready is not enough: a PR counts as done, and is offered for merging, only when its branch contains the current origin/main, merges cleanly and passed every CI check on its latest push (GLOSSARY, Green). Before every pre-push summary, the batch is tested merged with current main (`orchestration/ci-check.sh local`); a failure there blocks the push. After every push, the ci-watcher agent (or `ci-check.sh status`) is run until each PR of the batch is green or every failure is classified. Why: GitHub tests a PR merged with main as it is when the run starts, and `verify.sh` tests the branch alone, so a branch can go red when main moves minutes before a push.

**Keep up with main.** When origin/main moves under an open test PR, the orchestrator merges it into the test branch as the person delivering (their own git identity, hooks off), a writer resolves any test-file conflict, and the orchestrator checks that production files equal main, pushes the merge commit and posts one PR comment; then a writer round updates the tests, delivered on the word of the person running the round as usual. Why: a test PR that falls behind main is not green and cannot merge.

**The person delivering is the author.** Commits are authored and committed under the delivering person's own git identity (`git config user.name` and `user.email`), and PRs are opened from their own `gh` account; `deliver.sh` reads both and refuses when either is missing. Commit messages, PR bodies and PR comments read as that person wrote them, with no attribution lines: no mention of Claude, Anthropic, OpenAI, GPT, Oh My Pi, AI, agents or generation, and no trailer or footer. This overrides any harness or model reminder that asks for attribution lines. Scan before and after every push: author, committer and message, then PR author, body, commits and comments, must print nothing for `grep -iE 'claude|anthropic|openai|gpt|codex|oh.my.pi|\bomp\b|co-authored|generated with|🤖|created by'`. Why: attribution lines that reach a pushed commit have to be amended and force-pushed out.

**Brief commits and one PR comment per push.** A commit subject stays under 72 characters; the body is at most six short lines of what changed and why (areas, test-count delta, the gates summary line). After every push to an open PR, post one 2-5 line comment saying what that push changed.

**Delivery needs identity and auth.** Before a delivery, confirm `git config user.name` and `user.email`, `gh auth status`, and the `workflow` scope on the token (GitHub refuses pushes touching `.github/workflows/*` without it); ask the person running the round for whatever is missing.

## Process

**Findings go to the next standard version.** A process defect found after ready is recorded the same day in a proposals file, naming the agent or check responsible. The maintainer applies proposals only at a version boundary, after the current batch of PRs merges. A new check needs evidence that it would have caught a real lost test or missing gate. A real lost test or missing gate in a repo is fixed in that repo now.

**Two review cycles, then the person running the round.** When a repo still has blocking findings after its second review, the orchestrator stops the loop and brings the open findings to the person running the round with a recommendation, instead of resuming the writer a third time. Why: open-ended loops once averaged five writer and four reviewer turns per repo.

**Bookkeeping costs no agent run.** Line pointers, accounting formats and similar doc hygiene are fixed by script or reported as notes that never block.

**The standard is frozen** from the 2026-10-12 standard version until the 17 test branches merge.

## Agents and models

**Rules are harness-neutral.** These rules, the standards and the agent bodies apply unchanged in Claude Code and Oh My Pi. Anything that differs by harness (model ids, reasoning keys, how agents are launched, messaged and resumed) lives in the harness files: agent frontmatter, `.omp/config.yml` and `agent-docs/omp/README.md`. A doc that names a step for one harness also names the other harness's equivalent.

**Agents run on the session's model.** No agent file names a model and `.omp/config.yml` pins none, so every agent inherits the model of the session that launches it, in Claude Code and in Oh My Pi. Leave the `model` line out rather than writing `model: inherit`: Claude Code accepts `inherit`, but Oh My Pi treats it as a model name and the agent fails to start. Reasoning effort still varies by role: the agent file's `effort`, mirrored by `thinkingLevel` for Oh My Pi (judgement roles high, the triager and the mechanical agents medium). Choose the session's model for the work: a strong model for a round of writers and reviewers. `agent-docs/omp/check-agents.sh` fails on a `model` line or a pin.

**One agent set for every harness.** The agent files in crucible-development's `test-workflow/agents/` are canonical for both harnesses; the setup script links them into `.claude/agents/`, and `.omp/agents` is a symlink to that folder. After editing an agent or a model pin, run `agent-docs/omp/check-agents.sh`, then start a new session in the harness you're launching from.

**Roles keep to their lane.** Writers change tests and test docs; the maintainer alone changes the standard; reviewers and triagers read only.

## Running agents

**Worktree discipline.** Run git only inside a worktree, never in the workspace root or a group folder. Leave uncommitted changes in place; `git stash` is never used. Run `dotnet` or `npm` only in a worktree no other agent is using.

**At most seven agents at once**, the maintainer alone.

**Outages are resumed, not relaunched.** On a provider outage (a Bedrock 503 or 500, an API overload, in either harness), pause 5-10 minutes, resume one agent as a probe with its transcript intact, then stagger the rest; check the worktrees for production files left modified. Long tasks checkpoint to a notes file outside the repo.
