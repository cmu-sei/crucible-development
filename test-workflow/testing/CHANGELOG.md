# Changelog of the shared test core

Newest first. One entry per standard version. Each stack's CHANGELOG has an entry of the same date for what is particular to it, with that stack's adoption per repo.

## 2026-10-12 — the shared core, script-first bookkeeping, scripted delivery

Builds decisions 11 to 20, 22, 27 and 30 of `orchestration/reviews/2026-10-12-workflow-review/DECISIONS.md` (the facts behind them: `FACTS.md`, sections 2, 3 and 7). The backlog in `agent-docs/*-proposals-*.md` stays queued. From this version the standard is frozen until the 17 test branches merge (RULES, Process).

### What changed

- **A shared core, this folder** (decision 16). `README.md` holds what both stacks share and which used to be written twice, or lived only in briefs: the workflow and its hand-offs for the seven agents, ready (linked to GLOSSARY.md, decision 13), the reviewer severity scale, the check vocabulary, the files outside the repos, the defect-document format, the removed-test accounting notation, the writer's commit-message and notes files, the verify log, and the usage of every script. The two WORKFLOW files shrink to what is particular to each stack; the "Running under Oh My Pi" sections become one harness table here (the rest is in `omp/README.md`).
- **Check vocabulary.** A failure fails; `WARN provisional` is a provisional gate and nothing else; `NOTE` is bookkeeping or reviewer input and never fails anything (decision 5, RULES "Bookkeeping costs no agent run"). Both gates checks report missing and provisional gates in the glossary's terms, and their summaries end `X missing, P provisional`.
- **Defect documents cite tests by file and name** (decision 11): ``Test: `<test file>` `<test name>` ``, one key for both stacks (the UI's `Spec:` is gone). The line-pointer checks are dropped (the API's "`Test:` lands on an assertion", a failure since 2026-10-07, and its blank-line WARN; the UI's six SPECLINE WARNs); a script confirms the named test exists, as a NOTE. Every other document-format check is a NOTE.
- **Removed-test accounting, script first** (decision 12). One notation (A, B, C, D, E) for both stacks: `-> D -> <reason>`, and E means "removed with the production file it tested" (the API's E, "subsumed", was never used; such a removal is B). `check-repo.js removed` accounts itself for moves, renames with an identical body and merged theory or `it.each` rows, and without `--base` writes those lines to `<app>.removed-tests-matched.md`. A removal with no valid line now fails, as the 2026-10-09 entries announced.
- **New scripts:** `tree-hash.sh` and `verify-log.sh` (both stacks' `verify.sh` write `test-work/<app>/verify-<tree hash>.log`; decision 14); `break-gate.sh` (decision 17); `deliver.sh` with `summary` and `push --batch` (decisions 19, 27, 28, 30), following RULES, Delivery, with the 2026-10-12 attribution pattern; `status.sh` (decision 19); `fix-docs.js`, the bookkeeping converter.
- **Writer files outside the repos:** `test-work/<app>/COMMIT_MSG` and `test-work/<app>/NOTES.md`. The UI writer's `NOTES.md` at the worktree root is retired; `deliver.sh` refuses one in a tree.
- **Docs carried no old agent names or contradicted statements**: "eight steps, four agents", "not finished", "ready after should-fixes", "Where you sit", the same-day rule, the reviewer running `verify.sh` on every review (it reads the writer's log and reruns only when the log is stale).

### The conversion (decision 12, decision 5)

`fix-docs.js --write` on 2026-10-12 rewrote 21 files under `api-test-bugs/` and `ui-test-bugs/`: 830 API `Test:` and 313 UI `Spec:` line pointers into the file-and-name form; the UI closing sections `## Found without a spec` and `## API gaps noticed` into `## Found without a test` and `## Gaps noticed` (5 and 2 documents); caster.ui's one "Needs a decision." entry into `## Needs a decision`; vm.api's renamed-in-place map into 14 A lines; blueprint.api's renamed-in-place appendix into 84 A lines (80 paired from the diff hunks, 4 from the appendix table); blueprint.ui's six "`it.each` (first case)" B lines and caster.ui's two "into the same test" rows into named titles. A second run changes nothing, and no document was edited by hand. The documents and the standard as they were before this version are kept in `orchestration/rounds/2026-10-12-standard-version-before.tar.gz` until the final pass is delivered.

WARN lines per repo, before (the 2026-10-09 checks on the old documents) and after (this version's checks on the converted ones). "After" lines are failures unless they say NOTE; every after failure is in the final-pass scope (decision 25), apart from player.ui's two accounting lines strict ready now blocks.

| Repo | Before (WARN) | After: failures | After: NOTE |
| --- | --- | --- | --- |
| alloy.api | 0 | 0 | 6 (reviewer input: anonymous, uninventoried) |
| blueprint.api | 89 (3 `Test:` lines, 1 provisional, 85 REMOVED) | 1 gate | 14 |
| caster.api | 6 (3 `Test:` lines, 3 provisional) | 3 gates | 7 |
| cite.api | 0 | 0 | 10 |
| gallery.api | 0 | 0 | 10 |
| player.api | 5 (1 skip, 2 prose, 1 provisional, 1 covered now) | 1 gate | 21 (skip, 2 prose, covered now, ...) |
| steamfitter.api | 0 | 0 | 5 |
| vm.api | 36 (2 prose, 3 provisional, 31 REMOVED) | 3 gates, 17 removals | 17 |
| alloy.ui | 0 | 0 | 0 |
| blueprint.ui | 13 (5 NOSPEC, 2 WEAKDENY, 6 ACCOUNT) | 5 units, 2 WEAKDENY | 1 |
| caster.ui | 4 (3 NOSPEC, 1 ACCOUNT) | 3 units | 2 |
| cite.ui | 11 (1 NOSPEC, 1 DERIVED, 9 SPECLINE) | 1 unit, 1 DERIVED | 0 |
| console.ui | 23 (1 NOSPEC, 1 DERIVED, 21 SPECLINE) | 1 unit, 1 DERIVED | 0 |
| gallery.ui | 5 (3 NOSPEC, 2 DERIVED) | 3 units, 2 DERIVED | 3 |
| player.ui | 7 (2 NOSPEC, 5 ACCOUNT) | 2 units, 5 removals | 0 |
| steamfitter.ui | 2 (2 NOSPEC) | 2 units | 0 |
| vm.ui | 7 (3 NOSPEC, 4 SPECLINE) | 3 units | 0 |

Before: 208 WARN lines (plus 9 unused-import WARNs from `verify.sh`, now NOTEs). After: 56 failures (25 API, 31 UI), all coverage or loss checks; every bookkeeping line is gone or a NOTE.

### Proof (pilots `.worktrees/vm.api` and `.worktrees/player.ui`; nothing committed)

- `sync.sh` on both: nothing to copy (this version changes no file that is synced into a repo). `sync.sh --check` on the other 15: all match.
- `api-testing/verify.sh` on vm.api: 13 PASS, 2 FAIL, exactly the version's intent: `gates (... 3 missing, 0 provisional)` (the 2026-10-09 provisional gates, missing now) and `removed tests not accounted for (... 17 unaccounted ...)`; `dotnet test (Failed: 0, Passed: 1927, ...)`; log `test-work/vm.api/verify-0c7673f5af847a4c1ae5580e8b98b9f952c17b61.log`, and `tree-hash.sh --check` says `current` (the tree hash equals `HEAD^{tree}`).
- `ui-testing/verify.sh` on player.ui: 19 PASS, 2 FAIL as intended: `missing gates` (2 units without a spec) and `removed tests not accounted for` (5 lines that account for nothing); `npm test (Tests 622 passed (622))`; log `test-work/player.ui/verify-2600d8ef82c526176f02c8c5c7401cbcc147bc97.log`.
- `break-gate.sh` on vm.api `NetworkService.CreateViewNetwork` (`NetworkService.cs:65`, `!await CanManageNetworks(...)` to `!(true || await CanManageNetworks(...))`): the near miss `Create_is_forbidden_for_a_caller_holding_ManageNetworks_only_in_another_view_and_stores_nothing` failed (`Assert.Equal() Failure`), the allowed case passed, `restored: yes`, `result: PASS`. On player.ui `roles-permissions-select.component.html:23` (`"!canEdit"` to `"!(true || canEdit)"`): `disables the role select when editing is not allowed` failed, `keeps the role select enabled by default` passed, `result: PASS`. Probes on scratch logs: a "near miss" that passes gives `WRONG` and exit 1; an edit whose text is not on the line is refused with exit 2 and nothing changed.
- `deliver.sh summary` on each pilot: the preflight passes identity, gh account, level with origin and the attribution scan, and STOPs on the failed verify, the missing gates and the unaccounted removals; it prints the gates line, the PR comment and the regenerated sections (vm.api: "PR to open"; player.ui: PR #739). On scratch clones (deleted): the commit-message limits and the attribution scan stop a bad file; for alloy.api, a passing repo, the summary is all `ok` and `push --batch <id> --dry-run` prints the commit, the push with lease, `gh pr create`, and the comment; a wrong batch id is refused.
- `status.sh` on all 17: one row each, every tree clean and level; the pilots' verify logs `current`.
- `git log` and `git status` in both pilots: HEAD `5f21df3` and `0ec2a49` as at launch, nothing changed.

### Breaking: what fails until a repo acts

- The 2026-10-09 provisional gates are missing gates (API `GATE missing:`; UI units without a spec, `DERIVED`, `WEAKDENY` as `missing:` lines), as that version announced and as GLOSSARY.md defines provisional.
- A removed test with no valid accounting line fails `verify.sh` (API `REMOVED`, UI `REMOVED`); a line naming no existing test, no deleted file, or a rejected D reason counts as no line (strict ready, decision 32).
- `verify.sh` output: three kinds of line and a summary `== N check(s) failed, W warning(s), K note(s)`; the run's output is the verify log.

### Adoption

Synced files: none changed; nothing rides in a repo commit for this version. The new checks and scripts apply as soon as they run. Each stack's CHANGELOG entry lists, per repo, the writer audit its final pass needs (or none). Agent-definition changes for this version are the orchestrator's (the report of the maintainer run).

### Declined or deferred

- The UI's unused-import WARN (2026-10-09, "FAIL next round") becomes a NOTE, with `ui-testing/fix-unused-imports.js` to clear the imports: it is style, not a lost test or missing gate (decision 1; the final-pass plan fixes it by script).
- The API dynamic-skip, prose and empty-grant WARNs become NOTEs for the reviewer: the gates check already refuses an empty-grant near miss.
- A stale allow-list id (API) or an entry that matches nothing (UI) becomes a NOTE: it hides no gate. A reason that is budget or time, or missing, still fails, because it hides a missing gate.
- Positional renames (an old signature replaced in the same diff hunk) with a changed body are not mechanical matches (decision 12 says identical body): `fix-docs.js` used them only where a writer's 2026-10-08 appendix already claimed every such rename (blueprint.api). vm.api's 17 stay for the final pass's real loss check.
