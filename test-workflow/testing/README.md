# Crucible test workflow: the shared core

What the API standard ([../api-testing/](../api-testing/README.md)) and the UI standard ([../ui-testing/](../ui-testing/README.md)) share: the workflow and its hand-offs, the formats of every file the agents and scripts exchange, the check vocabulary, the reviewer's severity scale, and the usage of every script. How tests are written is in each stack's `CONVENTIONS.md`; the harness and its files are in each stack's `README.md`; setting a repo up is in each stack's `SETUP.md`. The user's standing rules are [../orchestration/RULES.md](../orchestration/RULES.md) and the vocabulary is [../GLOSSARY.md](../GLOSSARY.md); this file links to both instead of restating them. Only `test-standard-maintainer` edits this folder, and only at a standard version ([CHANGELOG.md](CHANGELOG.md)). Paths below are under `/mnt/data/crucible/agent-docs/` unless absolute; `<app>` is the repo folder's name (`vm.api`, `player.ui`), `<stack>` is `api` or `ui`.

## The agents

Seven agents, defined once in `/mnt/data/crucible/.claude/agents/` for both harnesses ([Harnesses](#harnesses)). Each has a task message from the orchestrator (the main session) and ends with a report the orchestrator acts on; agents cannot start agents.

| Agent | Does | Hands to |
| --- | --- | --- |
| `dotnet-test-writer`, `angular-test-writer` | the tests of one repo, in one writer mode (setup, create or audit), until it can be [ready](../GLOSSARY.md); edits tests, the app's defect doc, accounting and allow-list, and its [writer files](#the-writers-files) | its report, the verify log, the break-gate log and the commit-message file, to the reviewer |
| `api-test-reviewer`, `ui-test-reviewer` | judges one repo's tests in scope against the stack's CONVENTIONS; reads only | a verdict, ready or not ready, with findings by [severity](#reviewer-severity), to the orchestrator |
| `test-bug-triager` | groups and rates the defects in the defect docs of the repos in scope; reads only, writes a triage doc | the triage doc, to the user |
| `jira-ticket-writer` | one findings document (defect doc, triage doc or proposals file) into paste-ready Jira tickets | `jira/<source>.md`, to the user |
| `test-standard-maintainer` | the standard: this folder, `api-testing/`, `ui-testing/`; runs alone, at a version boundary | a CHANGELOG entry with each repo's adoption steps, to the orchestrator |

## The workflow

Both stacks run the same steps. The orchestrator's own duties (sessions, the round file, batches) are in [../orchestration/ORCHESTRATOR.md](../orchestration/ORCHESTRATOR.md).

1. **Standard version.** `test-standard-maintainer` applies the queued proposals at a version boundary only, proves the version on pilot worktrees and writes the CHANGELOG entries: this folder's for what both stacks share, each stack's for its own, each with the adoption per repo (synced files only, or a writer audit with its steps). No writer or reviewer runs meanwhile.
2. **Write.** One writer per repo, in its own worktree, with the writer mode and the work list: the output of the checks the task names (`check-repo.js gates`, `removed`, and the stack's other modes), plus in audit mode the adoption steps of the version's CHANGELOG entry. Setup mode follows the stack's `SETUP.md`. The writer covers each listed gate, characterizes each defect it meets ([Defect documents](#defect-documents)), runs `check-repo.js removed` and judges the removals it did not match ([Removed-test accounting](#removed-test-accounting)), runs `break-gate.sh` on every gate it covered ([The broken-gate check](#the-broken-gate-check)), runs the stack's `verify.sh` on its final tree ([The verify log](#the-verify-log)) and leaves the [commit-message file](#the-commit-message-file). A writer short of budget checkpoints to its [notes file](#the-notes-file) and asks to be resumed; the scope never shrinks.
3. **Review.** One reviewer per repo, read-only. In audit mode it reads the diff since the repo's last ready commit, plus untracked files and the check output; in setup and create mode the whole branch against its merge base with `origin/main`. It reads the writer's verify log and runs `verify.sh` again only when the log is stale, reads the break-gate log and names extra gates only when the selection is weak, and returns ready or not ready.
4. **Loop.** Blocking findings go back to the same writer, resumed with its transcript and told which gates to break; then the reviewer again. After a second review with blocking findings the orchestrator brings them to the user with a recommendation (RULES, Process). Findings about the standard itself go to a proposals file ([Proposals](#proposals)), never into the repo.
5. **Deliver.** For a batch of ready repos, `deliver.sh summary` prints the pre-push summary; the orchestrator shows it to the user, and only after the user's word runs `deliver.sh push` with that summary's batch id ([Delivery](#delivery)).
6. **Defects.** `test-bug-triager` over the defect docs of the repos reviewed; the user approves the triage doc; `jira-ticket-writer` turns approved documents into tickets. A defect fix is product work, outside this workflow (RULES, Scope).

**Ready** is defined once, in [../GLOSSARY.md](../GLOSSARY.md): the verify run passes with no missing gate, no provisional gate and no unaccounted removed test; the review has no blocking finding; the broken-gate check passed. Bookkeeping notes never block it. The verify log shows the first part, the reviewer's verdict the second, the break-gate log the third.

### Hand-offs

| From | To | What |
| --- | --- | --- |
| orchestrator | writer | worktree, app, writer mode, standard version, work list (check output), and on a resume the reviewer's findings, the gates to break and the notes file |
| writer | reviewer (through the orchestrator) | its report; the verify log path and tree hash; the break-gate log; the accounting file; the commit-message file |
| orchestrator | reviewer | worktree, app, writer mode, the base (the last ready commit in audit mode, from the round file or `status.sh`), the writer's report |
| reviewer | orchestrator | verdict, findings (`path:line`, severity, the CONVENTIONS rule, the fix), extra gates to break, items for the proposals file |
| orchestrator | user | the `deliver.sh summary` of a batch; open findings after a second review; the triage doc |

## Reviewer severity

| Severity | Meaning | Blocks ready |
| --- | --- | --- |
| **blocker** | Keeps the repo from ready: a verify FAIL; a missing or provisional gate, including a credit that does not hold, an allow-list reason the harness could meet, or a permission value with no allowed case holding exactly it; a broken-gate run whose near misses passed, or an extra gate the reviewer named; an unaccounted removal, a narrowed replacement, a D reason that names no unreachable branch. Also a test that would hide a regression: pinned to the fixed behaviour of a defect entry, faked authorization, a substitute or stub where the real component, store or service runs, EF InMemory or SQLite. | yes |
| **should-fix** | A weakness that leaves every gate covered and every behaviour asserted: a tautology no gate credit relies on, a missing error path, an assertion on stale state. | no |
| **note** | Bookkeeping: line pointers, counts, accounting or document format. | never (RULES, Process) |

The verdict is ready when no blocker remains. The questions a reviewer asks beyond the rules are the last section of each stack's CONVENTIONS (API section 6, UI section 6).

## Check output

Every check (`check-repo.js`, `sync.sh`, `verify.sh`) prints three kinds of line:

- **Failures**, a tag in capitals (`GATE`, `ALLOW`, `REMOVED`, `PIN`, `NOSPEC`, `DRIFT`, ...): the check fails and `verify.sh` prints a `FAIL` line.
- **`WARN provisional`**: a [provisional gate](../GLOSSARY.md), refused by a check tightened in this standard version. It does not fail the run in this version and is a missing gate from the next; for ready it already counts (`--strict` fails it now).
- **`NOTE`**: bookkeeping (a line pointer, a count, a format) and input for the reviewer (an unrouted or uninventoried gate, a dynamic skip, prose that reads like a defect note). It never fails anything. [fix-docs.js](#bookkeeping-fixes) fixes most bookkeeping NOTEs.

Both gates checks report in the glossary's terms. A gate is covered, allow-listed, provisional or missing; the summary line ends with the missing and provisional counts, which ready needs at 0:

| | API (`check-repo.js gates`) | UI (`check-repo.js gates`) |
| --- | --- | --- |
| missing gate (fails) | `GATE     missing: <gate id> ...` | `NOSPEC   missing:`, `UNTESTED missing:`, `NODENIED missing:`, `WEAKDENY missing:`, `DERIVED  missing:` |
| provisional gate | `WARN     provisional: <gate id> ...` | `WARN     provisional: <TAG> ...` |
| allow-listed gate | `ALLOWED  <gate id> ... Reason: ...` | `NOTE     allowed <file> ...: <reason>` |
| refused allow-list line (fails) | `ALLOW    ...` | `ALLOW    ...` |
| summary | `(gates: N call sites in M members, C covered, A allow-listed, X missing, P provisional)` | `SUMMARY  components ...; derived inputs ...; other units ...; X missing, P provisional` |

## Files outside the repos

Workspace docs never enter a repo (RULES, Scope). Per app:

| File | Written by | Read by |
| --- | --- | --- |
| `<stack>-test-bugs/<app>.md`, the defect doc | writer | reviewer, triager, Jira writer, `check-repo.js` |
| `<stack>-test-bugs/<app>.removed-tests-<date>.md`, the judged accounting | writer | reviewer, `check-repo.js removed` |
| `<stack>-test-bugs/<app>.removed-tests-matched.md`, the script's accounting | `check-repo.js removed` (never edited by hand) | reviewer, `deliver.sh` |
| `api-test-gaps/<app>.txt`, `ui-test-gaps/<app>.json`, the allow-list | writer | reviewer (every line), `check-repo.js gates`, `deliver.sh` (the PR body) |
| `test-work/<app>/NOTES.md`, the notes file | writer | the same writer when resumed |
| `test-work/<app>/COMMIT_MSG`, the commit-message file | writer | `deliver.sh` |
| `test-work/<app>/verify-<tree hash>.log`, `verify-latest.log` | `verify.sh` | reviewer, `deliver.sh`, `status.sh` |
| `test-work/<app>/break-gate.log` | `break-gate.sh` | reviewer |
| `test-work/<app>/deliver.log`, `test-work/<app>/deliver/` | `deliver.sh` | orchestrator |

## Defect documents

One file per app, `<stack>-test-bugs/<app>.md`. A defect a test finds is characterized by an ordinary passing test of the current behaviour; the description lives only here (RULES, Scope). The stack's CONVENTIONS section 3 adds what is stack-specific (how the test reads, which comments it may carry, the recurring defects to look for).

**The document**, in this order:

1. `# <app>: defects found while writing the unit tests`, then one intro line: the branch and date the entries were collected from; that each entry names the test that characterizes the current behaviour (it passes today and fails once the defect is fixed), the production file and line, and the expected behaviour; that paths are relative to the repo root; and the number of entries, ending `N entries.`
2. A summary table (`| | Count | Entries |`) with rows labelled exactly `Entries`, `Cross-repo entries` (naming the repo), `Latent entries`, and one `Recipe X: <pattern>` row per recipe.
3. `## Shared fix recipes`, one `### Recipe A: <pattern>` (B, C, ...) per fix several entries share: the code shape, the fix with a code sample, caveats, and how the entries' tests flip. Left out when no fix is shared.
4. One `## <test file path>` section per test file, in path order, holding its `### <test name>` entries in file order.
5. Optional closing sections, not counted as entries, named exactly: `## Needs a decision` (behaviour a test characterizes that may be intended; items in the entry shape), `## Found without a test` (a defect read in production that no test covers) and `## Gaps noticed`.

**An entry:**

```markdown
## <test file path>

### <test name>

Test: `<test file path>` `<test name>`

<What the production code does, with its production `file:line`; what the caller or user sees;
`Expected:` what should happen.>

**Fix:** <the change with its production `file:line`, or `Recipe A.` plus what is specific to this entry>

**Test to flip:** `<test name>` (<what its expectation becomes>; any other test the fix flips, with its file)
```

- The test is cited by file and test name, never by line: the heading is the exact test name (the C# method name, or the exact string passed to `it`, with an `it.each` template's `%s` or `$label`), so `grep -F` finds it, and the `Test:` line names the test file and the test. A code span holding a backtick uses double backticks. A trailing note after the two spans is allowed (`(rows: ...)`). A UI typing note (`### (typing note on <stub>, not a test)`) names the spec file only.
- The description starts with a capital, a path or code; every production reference is `<file>:<line>` (or `:<from>-<to>`). The entry is self-contained: it never points at text in a test.
- **Cross-repo.** `**Fix:**` starts `Cross-repo; <repo> first.` when the fix needs another repo (naming its file and line, and what this repo does so its consumers do not break: accept both shapes, or ship together), or `Cross-repo; regenerate <client> after.` when the fix is here but changes what a consumer sees.
- **Latent.** `(latent: no caller)` when nothing calls the defective code; `(latent: unreachable input)` when its callers cannot reach the faulty input (name them and what stops them). The Latent row counts both.
- **One defect, one entry**, entered once per app; a recurring pattern gets one recipe and one entry per instance (or one entry over a table test).
- **A "Needs a decision" item** has the entry shape; its `**Fix:**` starts `Decision needed: <option A> / <option B>`, each option with the change it implies, and `**Test to flip:**` names per option the test that changes, or "none".
- **A "Found without a test" item** is `### <title>`, a `Reason:` line saying why the harness cannot characterize it (no observable effect, a path no in-process host reaches), then the defect, `**Fix:**` and `**Test to flip:**` (the test to add with the fix, or "none"). An instance of a pattern whose siblings have tests is an entry.
- **Who touches it.** The writer adds, updates and removes its entries, and updates an entry in the same change that moves or renames its test. The reviewer marks each entry in scope confirmed, refuted or cross-repo. A fix that lands flips the named test and removes the entry.

**What the scripts check.** `check-repo.js defects` (API) and `check-repo.js specs` (UI) confirm that each entry's test exists by file and test name; one that does not is a NOTE (renamed or removed: update the entry). The document's sections, order, counts and lines are NOTEs too. `fix-docs.js` rewrites an old `file:line` pointer, follows a rename the accounting records with an A line, and recounts the API summary table. What does fail is defect text in code (RULES, Scope), checked per stack in CONVENTIONS section 3.

## Removed-test accounting

No test behaviour is lost (RULES, Test quality): every test the branch removed is matched to where its behaviour is still asserted, or its removal is explained. The narrowing rule (what a successor must keep asserting) is in each stack's CONVENTIONS section 2. `check-repo.js removed` compares the tree, uncommitted and untracked files included, with the merge base of `origin/main` (or `--base <ref>`): every API `[Fact]`/`[Theory]` method and `[InlineData]` row, every UI `it`/`test` title and literal `it.each` row, that the base had and the tree has not.

**What the script accounts for itself.** A removal it can match mechanically needs no line from anyone:

- **moved**: the same test in its renamed file; the same class and method anywhere (API); the same title with an identical body in a spec the base did not have, or in a new spec of the same name (UI);
- **renamed with an identical body**: a new name in the same class (API) or the same spec and `describe` (UI) whose body, comments and formatting aside, is the old one's;
- **rows merged**: the rows a theory or `it.each` lost are rows of another one of the class or spec with an identical body; or (API) each lost row is still a row of the theory with arguments added after its own.

Run without `--base`, it writes these lines to `<stack>-test-bugs/<app>.removed-tests-matched.md`, regenerated on every such run (and deleted when nothing matches), so nobody edits that file; with `--base`, or `--no-write` (as `verify.sh` and `deliver.sh` run it), it only prints them.

**What a writer judges.** Every other removal needs a line in `<stack>-test-bugs/<app>.removed-tests-<date>.md`, under a heading naming the old test file (or naming it in the line), in one notation for both stacks:

```markdown
## <old test file path>

- `<old test>` -> A -> `<new test>`    renamed or rewritten
- `<old test>` -> B -> `<new test>`    merged into another test
- `<old test>` -> C -> `<new test>`    replaced by a behaviour test (the old one asserted a call, a field or a stub)
- `<old test>` -> D -> <reason>        dropped: the unreachable branch or dead code it tested, read in production
- `<old test>` -> E -> `<deleted production file>`   removed with the production code it tested
```

The old test may be `Class.Method` (API) or `describe > title` (UI); a note may follow in parentheses. A, B and C name a test that exists in the tree; E names a production file the base had and the tree has not. A D reason names the branch or dead code read in production (UI: in the component and template; a behaviour jsdom cannot express names its e2e home); budget, time, "trivial" and a follow-up are never reasons. A narrowed successor is restored, or the dropped observable gets its own D line.

**What fails.** A removal with no line, or whose line names no test that exists, names no deleted file or gives a rejected D reason: `REMOVED` lines, and `verify.sh` fails. A line's format (a D row without its letter, a missing arrow) is a NOTE. The summary line counts removed, matched by the script, accounted per letter and unaccounted; ready needs 0 unaccounted.

## The writer's files

Both live in `test-work/<app>/`, outside every repo; nothing in a worktree is a working file of the workflow, and `deliver.sh` refuses a `NOTES.md` inside one.

### The commit-message file

`test-work/<app>/COMMIT_MSG`, plain text, describing the final tree:

```text
<subject: imperative, under 72 characters>

<at most four short lines: what changed and why (areas, gates covered, tests restored)>
```

No trailer of any kind, no `Tests:` or `Gates:` line, and nothing a scan for attribution would find (RULES, Delivery). `deliver.sh` appends two lines from the checks, `Tests: <N> passing; this push adds <a> and removes <r>, every removal accounted for.` and `Gates: <summary>.`, which keeps the body within RULES' six lines and the numbers exact. It refuses a file that breaks these limits.

### The notes file

`test-work/<app>/NOTES.md`, the writer's checkpoint, rewritten (not appended) after each test file it finishes and before it reports unfinished:

```markdown
Status: unfinished | done
Mode: setup | create | audit, standard version <date>
Covered: <gates covered so far, by id or file>
Still listed: <gates and removals the checks still report>
Next: <the file being worked on>
Pending: <reviewer findings not yet addressed>
```

The orchestrator names it in the resume message; the reviewer does not read it.

## The verify log

Each stack's `verify.sh` writes its whole output to `test-work/<app>/verify-<tree hash>.log` (`--log-dir` overrides the folder) and points `test-work/<app>/verify-latest.log` at it. The log opens with what it ran on:

```text
verify <stack> <app>
tree <tree hash>
worktree <path>
head <commit> <branch>
standard <version date>
started <UTC time>
```

and ends with the summary line (`== N check(s) failed, W warning(s), K note(s); ...`) and `finished <UTC time> exit <code>`. The **tree hash** is the git tree id of everything in the worktree, uncommitted and untracked files included and ignored files left out; for a clean worktree it is `git rev-parse HEAD^{tree}`. `testing/tree-hash.sh <worktree>` prints it.

**Comparing.** `testing/tree-hash.sh --check test-work/<app>/verify-latest.log <worktree>` prints `current` when the log's `tree` line equals the worktree's tree hash, the run finished and the tree did not change during it, and `stale (...)` otherwise. A current log is the verify result for that tree: nobody runs `verify.sh` on it again. When only workspace docs changed (an allow-list line, a defect entry, an accounting line), the tree hash stays and the reader runs the cheap `check-repo.js` modes, not `verify.sh`.

## The broken-gate check

`testing/break-gate.sh` is the [broken-gate check](../GLOSSARY.md) for both stacks. The edit that breaks each shape of gate (a short-circuit with `true ||`, a two-tier gate's deciding operand, a gate assigned to a variable, a data gate, a hub mapping, a gate computed at two sites) is in section 5 of the stack's CONVENTIONS; the script makes it, runs the tests and restores.

```sh
testing/break-gate.sh [--app <app>] [--gate <id>] <worktree> \
  --site <file>:<line> --replace '<old>' '<new>' [--replace ...] [--site ... --replace ...]... \
  --near-miss <test> [--near-miss <test>]... [--allowed <test>]... [--spec <spec file>]...
```

- `--site` is a production line (path from the worktree root); every copy of a repeated check, and each site of a gate computed twice, goes in the same run. `--replace` replaces the one occurrence of `<old>` on that line; a line that holds it zero or several times is refused, and so is a test file or a file with uncommitted changes.
- `--near-miss` names a test that must fail with the gate broken (API `Class.Method`; UI the test title); `--allowed` one that must still pass, which catches an edit that refuses everyone. UI runs the spec beside each site file unless `--spec` names others.
- API example: `testing/break-gate.sh /mnt/data/crucible/.worktrees/player.api --gate 'Player.Api/Features/Views/Requests/Edit.cs#Edit.Handler.Authorize' --site Player.Api/Features/Views/Requests/Edit.cs:59 --replace 'await authorizationService' 'true || await authorizationService' --near-miss ViewRequestTests.Edit_is_forbidden_for_a_view_member_without_ManageView`.
- UI example: `testing/break-gate.sh /mnt/data/crucible/.worktrees/gallery.ui --site src/app/components/admin/admin-articles/admin-articles.component.ts:113 --replace 'this.canEdit = ' 'this.canEdit = true || ' --near-miss 'disables article editing without EditCollection on the collection'`.

It copies each file aside first and restores it byte for byte however the run ends, checks that `git status` is as before, and rebuilds an API afterwards so no binary keeps the broken gate. It appends to `test-work/<app>/break-gate.log`: the time and tree hash, the gate and sites, the edit as a diff, each near miss and allowed case with its outcome and first failure line, `restored: yes|no`, and `result: PASS|FAIL (n of m near misses failed)`. Exit 0 means every near miss failed, every allowed case passed and the files were restored. A near miss that still passes means its test is wrong; the reviewer reads the log and the failure lines (a near miss must fail because the request got through, not on a new exception).

## Delivery

`testing/deliver.sh` follows RULES, Delivery; nothing else commits or pushes.

```sh
testing/deliver.sh summary <worktree>...                    # the pre-push summary of one batch
testing/deliver.sh push --batch <id> [--dry-run] <worktree>...   # only after the user's word on it
```

**Summary**, per repo: the preflight, each line `ok` or `STOP` (git identity: `git config user.name` and `user.email` both set, the person delivering being the author; gh logged in as that person's account, with the `workflow` scope when the push touches `.github/workflows`; level with `origin/<branch>`; only test files changed; no `NOTES.md`, `untested-gates.txt` or `gates.allow.json` in the tree; a current verify log with 0 failed checks; 0 missing and 0 provisional gates; 0 unaccounted removals; the commit-message file within its limits; the attribution scan of everything the push will write), then the files deleted, the tests added and removed by this push and the unmatched removals, the gates line, the commit message as it will be committed, the PR comment, and the regenerated PR sections. It ends with the batch id and the push command. It changes nothing but remote-tracking refs (`git fetch`).

**Push** computes every repo's id again and refuses the batch if anything changed since the summary the user saw. Per repo: commits all changes as the configured identity with hooks off, from the commit-message file plus the two lines it adds, and checks the commit's tree is the verified tree; scans every commit to push (author, committer, message); pushes with `--force-with-lease` against the `origin/<branch>` it summarized (it never rebases: a branch someone else pushed to stops in the summary); opens the PR for an API branch that has none; replaces the PR body's `## Gate coverage` and `## Removed-test accounting` sections (appending them where absent); posts the 2-5 line PR comment; and scans the PR author, body, commits and comments again. Both scans use the pattern in RULES, Delivery. A failed step stops that repo and says why; it is logged in `test-work/<app>/deliver.log`. `--dry-run` prints each command instead of running it.

The generated sections:

```markdown
## Gate coverage

`<gates summary line>`

Tests: <N> passing.

Allow-listed gates (each is still an untested gate):
- `<gate id or file>`: <reason>

Accepted gaps: none.

## Removed-test accounting

`<removed summary line>`

Dropped tests (D lines), each with the reason it was let go:
- `<old test>` -> D -> <reason>
```

## Script usage

| Script | Usage |
| --- | --- |
| `api-testing/sync.sh`, `ui-testing/sync.sh` | `sync.sh [--check] [--test] <worktree>...`: copy the shared files into the repos (`--check`: report drift only; `--test`: run the suite after) |
| `api-testing/verify.sh` | `verify.sh [--clean] [--app <app>] [--base <ref>] [--log-dir <dir>] <worktree>`: every deterministic check of the API standard, including three suite runs; needs Docker; writes [the verify log](#the-verify-log) |
| `ui-testing/verify.sh` | `verify.sh [--clean] [--app <app>] [--base <ref>] [--log-dir <dir>] <worktree>`: every deterministic check of the UI standard, including three suite runs, a build and coverage; writes [the verify log](#the-verify-log) |
| `api-testing/check-repo.js` | `harness <repo>` (run by sync.sh); `tests <repo>`; `defects <repo> <app>`; `gates <repo> <app> [--covered] [--strict]` (`--covered`: the tests credited per gate); `removed <repo> <app> [--base <ref>] [--no-write] [--d-lines]` (`--d-lines`: the D line accounting for each dropped test) |
| `ui-testing/check-repo.js` | `helpers <repo>` (run by sync.sh); `specs <repo> --app <app>`; `gates <repo> --app <app> [--list] [--strict]` (`--list`: every gated file, its gates and the denied test naming each); `removed <repo> --app <app> [--base <ref>] [--no-write] [--d-lines]` |
| `testing/break-gate.sh` | [The broken-gate check](#the-broken-gate-check) |
| `testing/deliver.sh` | [Delivery](#delivery) |
| `testing/status.sh` | `status.sh [--fetch] [--no-checks] [<worktree>...]`: one row per worktree (default: all under `/mnt/data/crucible/.worktrees`): branch, clean, level with origin, last commit, gates (missing, provisional), removed (unaccounted), and whether the verify log is current |
| `testing/tree-hash.sh` | `tree-hash.sh <worktree>`, `tree-hash.sh --check <log> <worktree>`: [The verify log](#the-verify-log) |
| `testing/fix-docs.js` | `fix-docs.js [--write] [--app <app>]...`: [Bookkeeping fixes](#bookkeeping-fixes) |
| `ui-testing/fix-unused-imports.js` | `fix-unused-imports.js [--write] <worktree>`: removes unused imports from a UI repo's own specs and test-utils (`verify.sh` reports them as a NOTE); lists unused locals for the writer |

`<repo>` and `<worktree>` are paths; `<app>` defaults to the folder's name, so pass it for a copy named otherwise.

### Bookkeeping fixes

`testing/fix-docs.js` does the bookkeeping no agent run is spent on (RULES, Process). Without `--write` it prints what it would change; it is idempotent. In defect docs it turns a `Test:`/`Spec:` line pointer into the file-and-name form, follows a rename recorded by an A line, gives the UI's closing sections their shared names, moves a UI "Needs a decision." entry to `## Needs a decision`, and recounts the API intro and summary table. In accountings it turns a rename map into A lines, expands a "renamed-in-place" appendix whose writer claimed every rename that kept its attribute line (pairing old and new signatures in the same diff hunk), writes `-> D -> <reason>`, and names the test behind "`it.each` (first case) in `X`" and "into the same test". It reads worktrees with read-only git.

## Harnesses

The agents, these docs and RULES are the same in Claude Code and Oh My Pi; what differs is how agents are launched, messaged and resumed (RULES, Agents and models). Details and model pins: [../omp/README.md](../omp/README.md).

| Step | Claude Code | Oh My Pi |
| --- | --- | --- |
| Launch an agent | the Agent tool with the agent's name | one `task` call: `{ context, tasks: [{ agent, task }] }` |
| Resume an agent with its transcript | SendMessage to its id | `write agent://<id>` |
| An agent hands back its report | SubagentHandback | `yield` |
| A command longer than the tool's limit (`verify.sh` takes 5 to 15 minutes) | Bash `timeout` up to 600000 ms, or `run_in_background` and wait for it | bash `timeout` up to 3600 s; after 60 s it becomes a background job collected with `wait` |
| Load the workspace and group guides | read from the cwd | name `/mnt/data/crucible/AGENTS.md` and the group `AGENTS.md` in the task's `context` |

One agent per worktree at a time (two builds in one tree race); at most seven agents at once, the maintainer alone (RULES, Running agents). After a provider outage, resume rather than relaunch, and check the worktrees for production files left modified (`status.sh` shows a tree that is not clean; `break-gate.sh` restores its own files even when interrupted).

## Proposals

A flaw in the standard found by a writer (Drift), a reviewer (For the standard) or after ready goes the same day into a proposals file: `api-testing-proposals-<date>.md` or `ui-testing-proposals-<date>.md` for one stack, `testing-proposals-<date>.md` for the shared core, naming the agent or check responsible and the evidence (repo, test or gate, round). The maintainer applies proposals only at a version boundary; a new check needs evidence that it would have caught a real lost test or missing gate (RULES, Process). The standard is frozen from the 2026-10-12 version until the 17 test branches merge.
