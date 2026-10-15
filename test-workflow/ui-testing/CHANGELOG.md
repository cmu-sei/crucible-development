# Changelog of the UI test standard

Newest first. Each entry says what repos must do to adopt it: **re-sync only** (run `sync.sh`), or **re-sync and update specs** with the spec change named.

## 2026-10-12 — the shared core; defects cited by name; script-first accounting; the 2026-10-09 WARNs fall due

The shared part of this version is in [../testing/CHANGELOG.md](../testing/CHANGELOG.md), entry 2026-10-12: read it first. What is particular to the UI stack:

### What changed

- **`check-repo.js specs`**: SPECLINE is gone. Each defect entry's test is looked up by spec file and title (`Test:` line; the old `Spec:` form is read and noted); one that is not there is a NOTE. `BUG` in a spec comment still fails.
- **`check-repo.js gates`**: units without a spec, `DERIVED` inputs and `WEAKDENY` files, WARN lines since 2026-10-09, are missing gates now (`NOSPEC missing:`, `DERIVED  missing:`, `WEAKDENY missing:`, alongside `UNTESTED missing:` and `NODENIED missing:`); a check tightened in a later version reports `WARN provisional: <TAG>` for that version (none now). The `SUMMARY` line counts derived inputs and ends `X missing, P provisional`. An allow-list entry that matches nothing is a `stale` NOTE.
- **`check-repo.js removed`** accounts itself for a title moved to a new spec with an identical body, a title renamed in its spec and `describe` with an identical body, and `it.each` rows merged into an identical `it.each` (git rename detection now follows a moved spec too); writes them to `<app>.removed-tests-matched.md` when run without `--base` (`--no-write` prints only); fails every removed title without a valid line (`REMOVED`; a line naming no test, no deleted file or a rejected D reason is no line); a D table row without its letter and a count below the base are NOTEs; `--d-lines` prints the D line behind each dropped test.
- **`verify.sh`** writes the verify log (`--log-dir`), fails the removed-tests check, prints the 2026-10-09 checks as failures or NOTEs (unused imports or locals, and thresholds that differ from floor(measured) − 1, are NOTEs), and counts NOTE lines.
- **`fix-unused-imports.js`**, new: removes unused imports from a repo's own specs and test-utils; lists unused locals for the writer.
- **Docs:** `SETUP.md` (setup mode, from the archived writer text, each step with its done-when); WORKFLOW.md reduced to the stack's own (suites and host load, the work-list commands, what `verify.sh` checks, break-gate on a UI); README file table; CONVENTIONS section 2 (the accounting points at the shared notation; units, `DERIVED` and `WEAKDENY` fail), section 3 (the format points at the shared one; `(latent: unreachable input)` replaces `(latent: unreachable)`, unused in any document; "Needs a decision" items go under `## Needs a decision`), section 5 (`break-gate.sh`), and a new **section 6, the review criteria beyond the rules**, which takes the tautology list from the `ui-test-reviewer` definition.

### Breaking: what fails until a repo acts

The missing gates and unaccounted removals below; nothing else. No shared helper, config, patch or workflow changed.

### Adoption per repo

Synced files: none. A repo listed with work gets `angular-test-writer` in audit mode with these steps, then `ui-test-reviewer` (audit mode: the diff since its last ready commit). Each spec added for a unit is a behaviour spec of the class at the path the `NOSPEC` line names (CONVENTIONS section 2, "Every unit has a spec beside it"), or, for pure DI wiring, a whole-file allow-list entry saying so; every new gate test gets a `break-gate.sh` run.

- **player.ui** (audit):
  1. Specs for `services/permissions/roles.service.ts` and `services/permissions/team-permission-scopes.service.ts`.
  2. A real loss check of the three migration lines that name no test (`player.ui.removed-tests-migration-2026-10-08.md:119`, `:121`, `:123`: the Roles, Subscriptions and Users nav items hidden for a near miss): find the tests that assert them today and name them, or restore them.
  3. `player.ui.removed-tests-2026-10-08.md:143`: the A line for `downloadFile opens image/pdf files in the browser (no download attribute)` names no test; name its successor or restore it.
  4. `player.ui.removed-tests-2026-10-08.md:359`: the D reason for `name getter returns the name form control` ("trivial getter ...") is rejected; name the branch that cannot be reached, or restore the assertion.
- **blueprint.ui** (audit): specs for `data/group/group-membership-data.service.ts`, `data/msel/msel.query.ts`, `data/user/user.query.ts`, `utilities/plain-text-pipe.ts`, `utilities/sort-by-pipe.ts`; a denied case that sets its own denial in `event-detail-page.component.spec.ts` and `team-edit-dialog.component.spec.ts` (`WEAKDENY`).
- **caster.ui** (audit): behaviour specs at the paths of the three deleted `cwd-table/directives/*.directive.spec.ts` (`table-action`, `table-item-action`, `table-item-content`).
- **gallery.ui** (audit): specs for `data/user/user.query.ts`, `services/xapi/xapi.service.ts`, `utilities/sort-by-pipe.ts`; denied cases in `wall.component` for the inputs `showAdminButton` and `showAdvanceButton` (bound in `home-app.component`).
- **vm.ui** (audit): specs for `state/vm-teams/vm-teams.service.ts`, `state/vm-users/vm-users.query.ts`, `state/vm-users/vm-users.service.ts`. Bookkeeping, no blocker: `fix-unused-imports.js --write` for the unused imports `verify.sh` notes (three imports or locals on 2026-10-09).
- **steamfitter.ui** (audit): specs for `data/scenario/scenario-role.service.ts` and `services/new-task/new-task.service.ts`.
- **cite.ui** (audit): a spec for `data/team/group-team-data.service.ts`; a denied case in `evaluation-info.component` for `showAdminButton` (bound in `home-app.component`).
- **console.ui** (audit): a spec for `state/user/user.query.ts`; a denied case in `console.component` for `allowReadOnlyToggle` (bound in `console-page.component`).
- **alloy.ui**: nothing.

blueprint.ui and caster.ui: `fix-unused-imports.js --write` for the unused import `verify.sh` notes (one each on 2026-10-09). Their accounting lines that named an `it.each` by position or "the same test" were rewritten by the conversion.

## 2026-10-09 — gates-check fixes, WARN checks for units, derived gates and removed tests, threshold ratchet

From `agent-docs/ui-testing-proposals-2026-10-07.md` (every item now carries a disposition there) and the orchestrator's playbook note in `.claude/agents/ui-testing-proposals-2026-10-07.md`. Adopt: **re-sync only** now (`vitest.config.ts` is the one shared file that changed; no spec has to change for `verify.sh` to pass, and all nine pass). **Re-sync and update specs in the next audit:** every check added here as a WARN becomes a FAIL in the next round, so each repo clears the WARN items listed under Adoption (`angular-test-writer` in audit mode, one per repo).

### Breaking: coverage thresholds

- **Measured minus one is defined.** Each threshold is floor(measured) − 1, where measured is the `All files` percentage of the `npm run test:coverage` run inside `verify.sh` on the final tree (93.93 gives 92). `verify.sh` prints the measured values and WARNs when the thresholds differ from that rule. README, "Coverage thresholds".
- **Thresholds only ratchet up.** `verify.sh` FAILs a tree whose thresholds are lower than those in the `angular.json` at its merge base with `--base` (default `origin/main`). The expected value is max(floor(measured) − 1, base). No worktree is affected: only player.ui's `main` has thresholds (78/74/74/81), and the branch's are 92/85/93/92.
- `coverageInclude` and the console.error guard are unchanged.

### Shared file (re-sync)

- `vitest.config.ts`: `testTimeout: 15_000` (Vitest's default is 5 s). Large Material specs crossed 5 s on loaded hosts with no code change (cite, gallery, blueprint, alloy, caster), and a timed-out test kept running into the next one. Proved on gallery.ui: a 6 s test passes with the new file and fails with "Test timed out in 5000ms" with the old one, so the builder honours the runner config. Type-checked with `tsc --noEmit` (a string value fails TS2769). Prettier-stable under 3.8.1 and 3.9.9.

### check-repo.js gates: fixes (which files pass is unchanged except where the gate inventory shrank)

- **SUMMARY arithmetic.** Both clauses now add up: `components N (with a spec, allowed, missing)` and `gated files N (with a denied case, allowed, missing)`. A whole-file allow-list entry for an ungated component used to be subtracted from the gated files ("1 allowed, -1 missing" in gallery.ui and blueprint.ui); it now counts as allowed under components. gallery.ui: `components 48 (47 with a spec, 1 allowed, 0 missing); gated files 29 (29 with a denied case, 0 allowed, 0 missing)`, and blueprint.ui likewise. SUMMARY also reports `gates named by a denied test` and `other units (... without: WARN)`. PR descriptions quote the new line.
- **Which denied case is named.** Qualifying tests are ranked: (1) the test's own text sets up the denial (a grant, a `*Permission.Member`, the gate set false, a factory called with `false`), (2) a `PermissionGrants` key in its own text, or a grant only in its factory, `beforeEach` or a constant, (3) a match only through a gate word elsewhere (a factory default `canManageRoles = true`, an allowed-side `canUploadView: true`); denial words in the name break ties. `--list` prints the counted test and its rank, and under each file every gate with the denied test whose own text names it. player.ui add-remove-users-dialog now names `hides the Role column and CSV import when canManageRoles is false` (was `lists a team member without a name by id`). Also improved: cite.ui scoresheet, gallery.ui article-teams, steamfitter.ui scenario-list, vm.ui iso-upload-dialog and vm-list. Still a heuristic (vm.ui new-map now names a data test with the same grant). I tried demoting candidates whose grant matches an allowed test, and it was rejected after measurement because near misses share the permission on another resource.
- **`--app` handling.** One parser for every mode: `--app <x>` or `--app=x`, `--base`, `--list`, `--strict`; a missing value, an unknown option or a second positional argument exits 2 with usage (before, `--app` with no value silently fell back to the folder name, and options before the repo path were taken as the repo). `specs` uses the same app name for its PIN message. Without `--app`, a NOTE says when `ui-test-bugs/<folder>.md` does not exist (a scratch copy). `verify.sh` takes `--app` and `--base` and passes them on.
- **Gate inventory.** Not gates any more: a `can*` method that neither the class (outside its own body) nor the template calls (alloy.ui admin-app `canCreateEventTemplates`, `canCreateEvents`; event-template-list `canCreateEvents`; blueprint.ui msel-contributors `canViewMsel`, msel-list `canEditMsel`). Lambda parameters, destructured names and locals, unless the same name is also read as a member (`data.canEdit`); a local's right-hand side now counts through the other patterns (cite.ui scoresheet shows `TeamPermission.EditTeamScore`/`SubmitTeamScore` instead of the locals `canModify`/`canSubmit`; vm.ui loses `canDelete`, `canDeleteView`, `canUploadView`, `canManage`, `canControl`, `canViewViews`; player.ui topbar loses the destructured `canManageTeam`, `canEditView`; blueprint.ui loses the local `canAddOptions`). A `can*` field that is only ever a boolean literal, is not an input and that no other file sets (cite.ui `canAccessAdminSection`, `canIncrementMove`; blueprint.ui scenario-event-edit-dialog `canDoAnything`). A field another file assigns (`dialogRef.componentInstance.canManageRoles = ...`) or binds (`[canX]`) stays a gate. Every gated file still has its denied case in all nine repos; no allow-list entry broke.

### New WARN checks (FAIL from the next round)

`verify.sh` prints `WARN` lines that do not change its exit code, and ends with `N check(s) failed, M warning(s)`. `check-repo.js --strict` makes them fatal.

- **Units without a spec** (`check-repo.js gates`, `WARN NOSPEC`): every `@Injectable` service, pipe, directive, guard (class or `CanActivateFn`), resolver, interceptor and Akita query that declares selectors of its own needs `x.spec.ts` beside it. Akita stores, and queries whose members only pass their arguments to Akita, are wiring. A pure-wiring unit may take a whole-file allow-list entry. CONVENTIONS section 2, "Every unit has a spec beside it".
- **Derived gates** (`gates`, `WARN DERIVED`): a child input bound from the parent's permission value under another name (`[showAdminButton]="canViewAdministration"`, `[readOnly]="!canEdit"`) whose spec has no denied case naming it.
- **Weak denied cases** (`gates`, `WARN WEAKDENY`): a gated file whose only qualifying tests match through a gate word outside their own text.
- **Removed tests** (`check-repo.js removed <repo> [--base origin/main] [--app <app>]`, verify.sh step 1d): diffs `it`/`test` titles and literal `it.each` rows from the merge base to the working tree (uncommitted and untracked included; deleted spec files count; a move to a same-named new spec does not). Every removed title needs a line in `agent-docs/ui-test-bugs/<app>.removed-tests-*.md`: `A`, `B` or `C` with a new title that exists in the tree, `D` with a reason that is not time, budget or "trivial", or the new `E` (removed with the production file it tested; the file must be gone). The parser takes the existing files' list, table and heading forms. It also warns on a static test count below the base's while anything is unaccounted. CONVENTIONS section 2, "No test is lost".
- **Defect `Spec:` lines** (`check-repo.js specs`, `WARN SPECLINE`): the line must be inside the test its heading names and not on the `it(` line.
- **Unused imports and locals** (verify.sh step 1e): `tsc -p tsconfig.spec.json --noEmit --noUnusedLocals`, reported for spec and test-utils files only (about 3.5 s).
- **Thresholds differ from floor(measured) − 1** (verify.sh step 7, above).

### check-repo.js helpers (FAIL, through sync.sh --check)

- No `.ts` file in `src/app/test-utils` besides the nine shared helpers, the two app-specific ones and the allowed extras for that app (README table: `fake-wmks.ts`, `clipboard.ts` for console.ui; `download-response.ts`, `jsdom-canvas.ts`, `match-media.ts` for caster.ui; `mat-dialog.ts` for cite.ui; `msel-load-api-stubs.ts` for blueprint.ui).
- The test target's `setupFiles` starts with `src/test-setup.ts`; any further entry is an allowed extra under `src/app/test-utils/` (caster.ui's `jsdom-canvas.ts`). All nine pass.

### verify.sh

- npm 12's `npm notice run <script>` lines are dropped one by one before the stderr paragraph check, so a notice cannot hide an error beside it. The pilot passed without `npm_config_loglevel`.
- FAIL lines of `npm test` and coverage give the number of tests that timed out, and WORKFLOW says to rerun a timeout-only failure alone before calling it a regression.

### Documents

- **README:** file table (`removed-tests` files, `check-repo.js` modes, `verify.sh` options and WARN); allowed-extras table and the `setupFiles` rule; "Testing Library with Material in jsdom" gains the name-computation cost, global styles (kept, for fidelity), user-event pointer cost and `skipClick`/keyboard, the jest-dom disabled-ancestor rule, `mat-select`, Material state set in a microtask, overlays (`findByRole('dialog')`), router links, the jsdom 28 CSS crash; new "The spec build: NgModules, hosts, imports" (app NgModules' `ɵmod` is empty in the test build, measured on gallery.ui's `AppModule`; standalone hosts with `overrideTemplate`; circular imports; `useExisting` stubs); "Known noise" names npm notices; new "Coverage thresholds".
- **CONVENTIONS:** section 1, `combineQueries` and `auditTime(0)`, seeding a store with `provideEnvironmentInitializer`. Section 2:
  - `Pick<>` for partial common-library overrides; the dialog `componentInstance` assignment form;
  - services that open a Material overlay are tested with the real overlay and rendered assertions, using the AOT scope rather than a declaration;
  - Queries: stock queries only (the user's 2026-10-09 rejection), title-named icon buttons, tooltip descriptions, disabled controls and the jest-dom ancestor rule, the conditions for `pointerEventsCheck: Never`;
  - Async: `findBy*` allowed, `NgZone.run` for a `setTimeout`-deferred open;
  - an `output()` error is logged twice; lifecycle hooks that throw; pinned NG0100;
  - Permissions: drag selection ruling, a denied case per gate, per-value permission coverage plus one render per pattern gate, derived inputs, whole-file entries only for files that cannot compile or render, the gate-inventory exclusions and the ranking;
  - every unit has a spec; the smoke spec carries no behaviour assertions; "No test is lost" (A to E, narrowing, assertions inside fakes count).

  Section 3: `(latent: unreachable)`, fixtures that survive the fix, one requirement per endpoint in gate entries, API analysis in `## API gaps noticed`, "Needs a decision." entries with `**Test to flip:** none yet`, the `Spec:` line check, two recurring bugs (a mutating control with no permission read; `ngOnDestroy` unsubscribing a `takeUntil` subject). Section 5: one gate computed at two sites.
- **WORKFLOW:** verify.sh description (removed tests, ratchet, measured-minus-one, options); WARN semantics; "Host load" (two runs at once on 8 cores reached load 12 to 17 and passed; run no more than two); step 3's done condition includes the removed-tests check; playbook B.2/B.3/B.5/C route removed-test and permission-coverage findings and carry the removed-test totals and D lines into the PR; a process defect found after "ready" is written back into the responsible definition the same day.
- **`agent-docs/ui-test-gaps/README.md`:** whole-file entries also excuse the smoke spec and are only for files that cannot compile or render; pure-wiring units.
- **`.claude/agents/angular-test-writer.md`** (step 12 thresholds; accounting format A to E and `check-repo.js removed`) and **`.claude/agents/ui-test-reviewer.md`** (step 7 quotes `check-repo.js removed`). **Start a new session before launching either agent.**

### Proof

- Pilot gallery.ui, after `sync.sh`: `verify.sh` `== 0 check(s) failed, 1 warning(s)`: `npm test (Tests 552 passed (552))`; gates `components 48 (47 with a spec, 1 allowed, 0 missing); gated files 29 (29 with a denied case, 0 allowed, 0 missing)`; `every removed test is accounted for (... removed 43 (accounted 43: A 0, B 40, C 0, D 3, E 0; unaccounted 0))`; `thresholds are floor(measured) - 1 (measured 82.25 63.13 83.41 81.44)`; build and coverage PASS. The WARN is 3 units and 2 derived inputs.
- Broken-gate check on the pilot: `admin-articles.component.ts:113` forced to `this.canEdit = true`; 4 denied tests failed (the three near-miss `it.each` rows and `disables article editing without EditCollection on the collection`); the file was restored and `git status` showed only `vitest.config.ts`.
- `removed` mutation on the pilot: renaming one test reported `WARN REMOVED` for the old title (`--base HEAD`) and `WARN ACCOUNT` for the B line that named it (`origin/main`), and `--strict` exited 1; restored.
- `helpers` mutation: a stray `test-utils/stray.ts` in gallery.ui, and caster.ui checked as `--app gallery.ui`, both reported DRIFT; restored.
- player.ui (read-only): `removed` accounts for all 322 titles removed since origin/main across both accounting files (A 73, B 50, C 178, D 21) with 5 WARNs: three B lines and one A line that name no test, and the D reason "trivial getter".
- `verify.sh` on all nine worktrees after the sync, two at a time: every one `0 check(s) failed`, no test timed out. alloy 439 tests, blueprint 921, caster 724, cite 726, console 370, gallery 552, player 622, steamfitter 438, vm 346. In every repo the thresholds equal floor(measured) − 1.
- `check-repo.js` is Prettier-stable under 3.8.1 and 3.9.9 (the two minors give identical output).

### Adoption: WARN items to clear in the next audit

| Repo | Units without a spec | DERIVED / WEAKDENY | Removed-test lines | SPECLINE | Unused |
| --- | --- | --- | --- | --- | --- |
| alloy.ui | none | none | none | none | none |
| blueprint.ui | `data/group/group-membership-data.service.ts`, `data/msel/msel.query.ts`, `data/user/user.query.ts`, `utilities/plain-text-pipe.ts`, `utilities/sort-by-pipe.ts` | WEAKDENY event-detail-page, team-edit-dialog | 6 B lines naming "`it.each` (first case)" instead of a title | none | assessor-page spec `vi` |
| caster.ui | the three `cwd-table/directives/*.directive.ts` (specs deleted, merged elsewhere: restore behaviour specs at the same paths) | none | 1 (line 34, no title named) | none | `test-utils/mock-permission-data.service.ts` `inject` |
| cite.ui | `data/team/group-team-data.service.ts` | DERIVED evaluation-info `showAdminButton` | none | 9 | none |
| console.ui | `state/user/user.query.ts` | DERIVED console `allowReadOnlyToggle` | none | 21 (mostly the `it(` line) | none |
| gallery.ui | `data/user/user.query.ts`, `services/xapi/xapi.service.ts`, `utilities/sort-by-pipe.ts` | DERIVED wall `showAdminButton`, `showAdvanceButton` | none | none | none |
| player.ui | `services/permissions/roles.service.ts`, `services/permissions/team-permission-scopes.service.ts` | none | 5 (4 lines naming no test, 1 "trivial" D reason) | none | none |
| steamfitter.ui | `data/scenario/scenario-role.service.ts`, `services/new-task/new-task.service.ts` | none | none | none | none |
| vm.ui | `state/vm-teams/vm-teams.service.ts`, `state/vm-users/vm-users.query.ts`, `state/vm-users/vm-users.service.ts` | none | none | 4 | 3 |

### Not adopted

Deferred (each with the missing decision or evidence in the proposals file): promoting `mat-dialog.ts`, `msel-load-api-stubs.ts`, `match-media.ts`, `routerQueryStub`, `dialogComponent`, and a `componentInstance` parameter on `dialogRefStub`; Prettier for repo specs (user decision); a slow-test WARN; a spec-comment prose check; MSEL-role gate patterns; ng-mocks or Spectator versus the hand-rolled helpers (user decision, both options recorded). Rejected: `role-and-text.ts`/`user-input.ts` (user decision); a `styles: []` test build; pattern changes for `canPostArticles` and `canSortByTeams$` (per-gate allow-list entries instead); a shared `getContext` fake; the vm.ui Dockerfile item (not a standard change).

## 2026-10-08 — correct the reason given for the console.error guard

Adopt: **re-sync only** (`src/test-setup.ts` and `src/app/test-utils/unhandled-rx-errors.ts` change in comments; no behaviour change, no spec change).

- `test-setup.ts`: the first paragraph of the guard's comment said every unhandled promise rejection under zone.js is reported through `console.error`, so Vitest would let the test pass. That holds only outside Angular's zone. It now says: TestBed rethrows application errors (`rethrowApplicationErrors` defaults to true), so an unhandled rejection or a throw inside a subscribe that runs in Angular's zone surfaces as a Vitest "Uncaught Exception" that fails the run while the test still shows as passed; the guard covers what that path misses, a direct `console.error` from app code or Angular's runtime checks and a rejection outside Angular's zone, which zone.js logs as `console.error(reason)`. The guard code, its `beforeEach` teardown, the opt-out and `restoreMocks` are unchanged.
- `test-utils/unhandled-rx-errors.ts`: the doc comment on `captureUnhandledRejections()` made the same unqualified claim. It now says the helper collects rejections outside Angular's zone (a service called from the test body, a hub invoke that rejects there), which zone.js logs as `console.error(reason)` once the microtask queue drains, and that a rejection inside Angular's zone (a lifecycle hook, a template event handler) never reaches it, because TestBed rethrows it as a Vitest "Uncaught Exception". The usage guidance (`flush()`, assert on the whole array, pair with `rejectInvokes()`, a `vi.fn` rejection counts as handled) is unchanged. `captureUnhandledRxErrors()`'s comment was already accurate (rxjs 7.8's `reportUnhandledError` hands the error to `config.onUnhandledError` inside its `setTimeout` before anything is thrown, so the zone makes no difference) and is unchanged.
- `CONVENTIONS.md` section 2, "Console errors fail tests": the same narrowing, plus one sentence: a Vitest summary with an `Errors` line while every test passed is a failure of the test Vitest names under "This error originated in ...", to be fixed, never treated as a flake.
- Verified 2026-10-08 on the gallery.ui worktree (Angular 21.2.10, zone.js 0.15.1, Vitest 4.1.11, `@angular/build:unit-test`, `@testing-library/angular` 19.5.0), with a throwaway spec of three standalone components, not kept in the repo. `Promise.reject(...)` in `ngOnInit` with the guard opted out: the test passed, Vitest reported a run-level "Uncaught Exception", exit code 1, and `console.error` was never called. `of(1).subscribe(() => { throw ... })` in `ngOnInit`: the same. `console.error(...)` in `ngOnInit` with the guard on: the test failed with "console.error was called 1 time(s) during this test: ...". The rejection outside Angular's zone was confirmed by the existing `src/app/services/signalr.service.spec.ts` in gallery.ui (35 passed), whose rejected hub calls are seen by `captureUnhandledRejections()` as `[new Error(...)]`. alloy.ui's `event-template-info.component.spec.ts` already records that a rejection dropped inside NgZone is rethrown by TestBed and not logged.

## 2026-10-08 — allow node's NO_COLOR warning in verify.sh

Adopt: **nothing to do** (`verify.sh` is run from `agent-docs`, not copied into repos).

- `verify.sh`'s `ALLOWED_STDERR` gains `NO_COLOR`. Under Oh My Pi the embedded bash sets `NO_COLOR=1`; with the devcontainer's `FORCE_COLOR=3` every node process prints `Warning: The 'NO_COLOR' env is ignored due to the 'FORCE_COLOR' env being set` on stderr, which the "unexpected stderr" check counted as a failure (seen 2026-10-07 on `player.ui`, where the check already failed for other reasons; on a clean repo it would have been a spurious FAIL). Found by the omp pilot; see `agent-docs/omp/README.md`.

## 2026-10-07 (round 5) — an untested permission gate is a blocker

Decided by the user on 2026-10-07, after the adoption round ended with most permission-gated components untested and the CLI boilerplate specs deleted outright, while every step reported done: `verify.sh` gated only on the coverage baseline, the writer stopped "where reached", the reviewer's "ready" meant only that the existing specs were sound, and the orchestrator delivered on "ready". Adopt: **re-sync, then add specs** in eight of the nine repos (`angular-test-writer`, one per repo; counts below). No shared file that `sync.sh` copies changed, so `sync.sh` alone passes, but `verify.sh` now fails until the specs exist.

### What changed

- **New check, `check-repo.js gates <repo> [--app <app>] [--list]`, run by `verify.sh` as step 1c (FAIL), with `--app` set to the repo folder's name.** It inventories every `@Component` under `src/app` (generated and test-utils excluded), plus any directive or guard that reads a permission, and fails on: `NOSPEC` (a component with no `x.component.spec.ts` beside it), `UNTESTED` (a file that reads a permission and has no spec), `NODENIED` (its spec has no denied case), `ALLOW` (an allow-list entry with no reason, a time or budget reason, a path that matches nothing, or a gate the check does not find; or a `gates.allow.json` anywhere under the repo's `src`). It prints a `SUMMARY` line (components, how many have a spec, gated files with a denied case, allowed, missing, gates found and gates in files with a denied case) and, with `--list`, every gated file with its gates and the test it counts as the denied case. The definition is three documented tables at the top of the check's gates section, built from the nine repos' real code:
  - **Gate patterns:** `can*` names in the class or template (`canEdit`, `canEdit$ | async`, `canEdit` inputs, `canEvent(...)`; not `canActivate`/`canDeactivate`/`canMatch`/`canLoad` or WMKS `canFullScreen`, and not a `canX()` method whose body reads no permission, such as caster's object-type `canRename`); a `*Permission.Member` value tested on any `...permission...` list (`permissions.includes(SystemPermission.ViewUsers)`, `scenarioPermissions?.some(...)`, `permissionValues.includes(TeamPermission.ManageTeam)`), but not a role editor's `role.permissions.some(x => x === permission)`; member reads on the app's permission service (`PermissionService`, `PermissionDataService`, `UserPermissionsService` imported from app code, never `generated/`), except `load*`. A derived flag counts once (`canEdit$ = this.permissionService.canEditProject(id)` is the gate `canEdit$`).
  - **Permission setup** in a test (its name, `it.each` table, body, surrounding `beforeEach`, the constants it names, and a local render factory it calls with arguments): `permissionDataProviders`/`permissionApiStubs`, a `PermissionGrants` value or key (read from the repo's `mock-permission-data.service.ts`), a `*Permission.Member`, or the component's own gate name (`canEdit: false`).
  - **Denied shapes:** `not.toBeInTheDocument()` / `not.toBeVisible()`, `toBeDisabled()` / `not.toBeEnabled()`, `toHaveAttribute('disabled' | 'aria-disabled')`, `toBeNull()` / `toBeFalsy()` / `toBe(false)` on a query, stub input or `can*` value, `.disabled`/`.hidden` `toBe(true)`, `toEqual([])` / `toHaveLength(0)` on a rendered list, an exact rendered list after a `canX: false` input, an `it.each` with false or `[]` rows compared with the row value, and an `it.each` matrix of grants against the exact rendered list. The test must also say it is the denied side (a false or `[]` value, or a denial word such as without, lacks, hides, read-only, near miss). `.skip`/`.todo` tests never count.
  - It recognizes the shape, not the quality; near misses and the broken-gate check stay with the reviewer and the writer.
- **Allow-list, outside the repos (user decision, 2026-10-07):** `/mnt/data/crucible/agent-docs/ui-test-gaps/<app>.json` (new folder with a README), named like `ui-test-bugs/<app>.md`, an array of `{ "path", "gates"?, "reason" }`. `--app <app>` picks the file (default: the repo folder's name, the same rule the defect-document check uses). The check never reads an in-repo allow-list and fails if a `gates.allow.json` exists under `src`, so none is committed by habit. Only for what the harness cannot render; a whole-file entry excuses the file, a `gates` entry only the named gates. Allowed entries print as `NOTE` lines, and the PR description names every allow-listed gate with its reason. The writer edits its app's file (the second file outside its worktree, after the defect document); the reviewer judges the reasons and edits nothing.
- **New template `templates/component-smoke.spec.template.ts`:** renders the component with `renderComponent` and the default providers and asserts it mounts. NgModule components may pass `schemas: [CUSTOM_ELEMENTS_SCHEMA]` instead of child stubs (an unknown child is an NG0304 `console.error`, which fails the test); never `NO_ERRORS_SCHEMA`. An `unstubbed()` or NG0201 error names what to stub.
- **CONVENTIONS.md section 2:** "Every component has a spec beside it": a CLI boilerplate spec is replaced by the smoke spec, never deleted outright; a spec with real assertions is rewritten at the same path. The Permissions rule gains "Every gated file has a denied case" and "The allow-list is for what the harness cannot render". Section 4, item 2: every gated file, and an untested gate is a blocker.
- **WORKFLOW.md:** step 3 is done when the gates check reports nothing missing, or every remaining item is allow-listed with a harness reason; budget never shrinks scope (checkpoint to `NOTES.md` at the worktree root, never committed, and ask to be resumed). Step 5's "ready" requires sound specs **and** a clean gates check, otherwise "not finished" with the missing list. Step 7 and playbook C: deliver only on that "ready"; a list of untested gates is a blocker; a gap the user accepts is listed gate by gate in the PR description; every PR description carries the gates-check summary (the `SUMMARY` line, the `NOTE` lines, accepted gaps). B.5: "not finished" goes back to the writer; a writer stopped for budget is resumed, not delivered.
- **`.claude/agents/angular-test-writer.md`:** the completion criterion above; section 4 step 8 replaces boilerplate specs with smoke specs instead of deleting them; section 6 lists the gates check in `verify.sh` and says to work from `check-repo.js gates --list`; the report's "Untested" became a mandatory "Untested gates" section that quotes the check's output and is "none" or one reason per line. **`.claude/agents/ui-test-reviewer.md`:** runs and quotes `check-repo.js gates --list`, judges allow-list reasons, reads the tests the check counts as denied cases; verdicts ready / ready after should-fixes / not finished / not ready, where "ready" needs a clean gates check; an untested gate is a blocker. **Start a new session before launching either agent.**
- README: the file table lists the smoke template and `../ui-test-gaps/<app>.json`; `check-repo.js` describes `gates`. `verify.sh --help` prints the longer header.

### Proof

- The allow-list location, on the real worktrees, read-only: with `agent-docs/ui-test-gaps/player.ui.json` holding one entry with a harness reason, `check-repo.js gates .worktrees/player.ui --app player.ui` prints it as a `NOTE` and drops that file from the missing list; a reasonless entry there fails; a `gates.allow.json` under `src` fails with the in-repo message (proved on a scratch copy of caster.ui, since the worktrees are not edited). The trial entries were removed afterwards; no `ui-test-gaps/<app>.json` exists yet.
- The check, run read-only on the nine worktrees under `.worktrees/*.ui` (summary lines under Adoption). caster's `admin-app/component/admin-container` is found with its seven permission reads (`canViewGroups$` and `SystemPermission.ManageProjects`, `ViewWorkspaces`, `ViewVlans`, `ViewModules`, `ViewUsers`, `ViewRoles`); role editors (`role.permissions.some`), components that only call `load*()` on the permission service, and object-type `canRename`/`canEnable`/`canEdit(item)` methods are not flagged as gates. console.ui is clean. Every file the check passes names a real denied case of its own spec (`--list`).
- Mutation tests on a scratch copy of caster.ui: removing every absence assertion from `topbar.component.spec.ts` turns it from ok to `NODENIED`; a new `canEdit`-input spec is `NODENIED` with an allowed case only, ok once a `canEdit: false` test asserts the button absent, `NODENIED` again when that test is `it.skip` or when the absence assertion has no permission setup; an allow-list entry with no reason, with "ran out of budget, follow-up", with a path that matches nothing, or naming an unknown gate fails; reasoned entries print as notes, and a file whose gates are all allowed still needs its smoke spec.
- The smoke template type-checks (`tsc --noEmit` in the scratch copy) and runs: caster `admin-workspaces` (children, `CUSTOM_ELEMENTS_SCHEMA`, typed stubs for the members `unstubbed` named) and `locking-status` pass, and without the schema the first fails on NG0304; vm.ui standalone `page-not-found` and `system-message` (with `bottomSheetRefStub()`) pass. `verify.sh` on the scratch copy: every check PASS (`npm test` 510 passed, build, coverage) except the new step 1c. `check-repo.js` and the template are Prettier-stable under 3.8.1 and 3.9.9.

### Adoption (every repo: re-sync, run the check, then write specs until it is clean)

Each repo runs `node agent-docs/ui-testing/check-repo.js gates <worktree> --app <app> --list`, adds the smoke spec beside every `NOSPEC` component (restoring the deleted boilerplate specs as smoke specs), writes allowed and denied cases for every `UNTESTED` and `NODENIED` file, and allow-lists only what the harness cannot render, in `agent-docs/ui-test-gaps/<app>.json`, never in the repo. Counts on 2026-10-07:

| Repo | NOSPEC | UNTESTED | NODENIED | Summary |
| --- | --- | --- | --- | --- |
| alloy.ui | 12 | 17 | 0 | components 33 (4 with a spec); gated files 21 (4 with a denied case); gates 41 found, 12 in files with a denied case |
| blueprint.ui | 34 | 50 | 0 | components 87 (3 with a spec); gated files 53 (3 with a denied case); gates 117 found, 34 in files with a denied case |
| caster.ui | 35 | 32 | 0 | components 69 (2 with a spec); gated files 33 (1 with a denied case); gates 59 found, 2 in files with a denied case |
| cite.ui | 15 | 33 | 0 | components 53 (5 with a spec); gated files 38 (5 with a denied case); gates 61 found, 18 in files with a denied case |
| console.ui | 0 | 0 | 0 | components 16 (16 with a spec); gated files 3 (3 with a denied case); gates 8 found, 8 in files with a denied case. Nothing to do |
| gallery.ui | 18 | 28 | 0 | components 48 (2 with a spec); gated files 30 (2 with a denied case); gates 48 found, 9 in files with a denied case |
| player.ui | 0 | 0 | 2 | components 38 (38 with a spec); gated files 11 (9 with a denied case); gates 21 found, 16 in files with a denied case. `user-presence.component.spec.ts` (ViewPermission.ViewView/ManageView, TeamPermission.ViewTeam/ManageTeam) and `add-remove-users-dialog.component.spec.ts` (`@if (canManageRoles)`, only a direct `canManageRoles = false` poke today) need denied cases |
| steamfitter.ui | 25 | 13 | 0 | components 43 (5 with a spec); gated files 18 (5 with a denied case); gates 34 found, 19 in files with a denied case |
| vm.ui | 16 | 6 | 0 | components 26 (4 with a spec); gated files 9 (3 with a denied case); gates 49 found, 28 in files with a denied case |

The gated-file counts are higher than the round's own tally (caster 16, blueprint 28) because child components that gate on a `canEdit`-style input count too: that input is where the gated button lives, and its denied case is a render with the input false.

## 2026-10-03 (round 4) — defect notes move out of the code

Decided by the user on 2026-10-03. Adopt: **re-sync only**. The nine worktrees already have every `// BUG:` block removed from their specs (the tests still assert current behavior), and the nine defect documents exist. Two shared helpers change in comments only, and the new spec check passes on all nine.

### Shared files (re-sync)

- `api-stub.ts`: the doc comment no longer says `// BUG:`. A member whose generated type is wrong goes next to the checked block "under a plain comment that names the API endpoint; record the defect in agent-docs/ui-test-bugs/<app>.md".
- `unhandled-rx-errors.ts`: the `captureUnhandledRxErrors()` doc says CONVENTIONS.md says when the pattern "is a defect" (was "a `// BUG:`").
- Both are comment-only changes, Prettier-stable under 3.8.1 and 3.9.9. Neither file contains the word BUG any more.

### Convention (CONVENTIONS.md section 3, rewritten)

- A defect is still pinned by a passing test of the current behavior, but the spec carries no defect description and no word `BUG` in any comment. A plain comment may state the current behavior and point at the document, nothing more.
- The defect, its production `file:line`, the expected behavior, the proposed fix, the test to flip, and the latent (`(latent: no caller)`) and cross-repo (`Cross-repo; <api repo> first.`) markers go in `agent-docs/ui-test-bugs/<app>.md`, as a `### <test name>` entry under a `## <spec path>` heading.
- One defect, one entry. A recurring pattern is still one `it.each` per service file, with one entry that lists each method and line. Cross-references between tests are plain comments.
- Wrong generated types get a `### (typing note on <stub>, not a test)` entry. The near-miss, latent, ErrorHandler and hub-payload rules are unchanged in substance. The canonical "subscribe() with no error callback" example now shows the spec and its entry.
- New: the document's format (title and intro line; a summary table counting entries, cross-repo, latent and per-recipe entries; `## Shared fix recipes`; per-spec sections; optional `## Found without a spec` and `## API gaps noticed`), and who touches it: the writer writes it, the reviewer confirms entries, the triager reads it, and a landed fix removes its entry.
- Section 2's typed-stub and hub-payload rules point at the document instead of a `// BUG:`. Section 5: the reviewer names the gates to break and the writer runs them.

### New check (passes on all nine worktrees)

- `check-repo.js specs` (so `verify.sh` step 1b) fails a `*.spec.ts` under `src/app` with `BUG` as a word in a comment (`//.*\bBUG\b` or `\*.*\bBUG\b`), as `PIN <file>:<line>`, pointing at `agent-docs/ui-test-bugs/<app>.md`. `check-repo.js helpers` is unchanged: it compares only the two app-specific helpers with their templates, and the shared helpers are compared byte for byte by `sync.sh`.

### Workflow and agent files

- WORKFLOW.md: steps 3, 5 and 6, the Bugs loop and playbook D use the documents instead of pins. A fix flips the test named in **Test to flip:** and removes the entry. The writer may edit its app's document, the only file outside its worktree. The reviewer and triager edit neither repos nor documents.
- The reviewer is read-only and does not attempt the broken-gate edit (the permission classifier denied every reviewer's edit in this round). It names the gates (call site, edit, denied tests expected to fail), and the writer runs them (step 5, playbook B.3 to B.5, the Scripts note, CONVENTIONS.md section 5).
- `.claude/agents/angular-test-writer.md`, `ui-test-reviewer.md`, `ui-bug-triager.md`: every mention of `// BUG:` pins now uses the document convention. The reviewer's step 1 names gates instead of breaking them. The writer runs the reviewer's gates. The triager collects from the documents, not from `grep`. **Start a new session before launching any of them.**
- README: the file list names `agent-docs/ui-test-bugs/<app>.md`. `verify.sh`: step 1b's label names the new check, and `--help` prints the whole header. The two templates never mentioned BUG and are unchanged.

## 2026-10-02 (round 3) — proposals from the second review pass

Adopt: **re-sync, then audit specs** (`angular-test-writer` in audit mode, one per repo). The shared-file changes are backward compatible: every suite passes after `sync.sh` alone. The spec and app-helper changes below are what the new checks in `sync.sh` / `verify.sh` fail on, plus local helper copies that the shared helpers now replace.

### Shared files (re-sync)

- `api-stub.ts`: `ApiStub` rewritten so Prettier 3.8.1 and 3.9.9 format it identically (it used to reformat under 3.9). New `endpointStub(Service, endpoint, fn)` for table-driven rows: the service class fixes the type, so a missing endpoint or a wrong response type fails to compile, also in non-strict repos. Doc: computed keys (`{ [endpoint]: fn }`) check nothing; a member whose generated type is wrong goes next to a spread `satisfies` block under a `// BUG:`.
- `fake-hub-connection.ts`: `invoke`/`send`/`stream` typed with named signatures (`vi.fn<HubInvoke>(...)`), stable under both Prettier minors. New `rejectInvokes(hub, reason, methods?)`: replaces `invoke` with a plain rejecting function (a `vi.fn` marks its own rejections handled) and returns `[method, ...args]` per call; `reason` may be a function of the method name. `onBuild(connection, index)` now receives the build index. Doc for `invoke.mockImplementation` keyed on the method name.
- `unhandled-rx-errors.ts`: new `captureUnhandledRejections()`: spies on `console.error` (zone logs an unhandled rejection as `console.error(reason)`, no prefix) and returns a live array of every logged argument; assert with `toEqual([...])`.
- `dialog-refs.ts`: new `dismissedDialogRefStub<T, R>()` (`afterClosed()` emits `undefined`, then completes). Both dialog stubs now return a `keydown` subject that feeds `keydownEvents()` (it was `EMPTY`), and the result type is exported as `DialogRefStubResult`.
- README names the Prettier major (3) and says shared files must be stable under every 3.x minor the repos use (3.8.1 and 3.9.9 checked).

### Templates (comments only; no repo's live code must change because of them)

- `default-test-providers.template.ts`: the header is marked "TEMPLATE INSTRUCTIONS: delete in the repo copy". Slot 1 says non-Akita `BehaviorSubject` state services stay real, module-provided state services are listed as their real class, router-reading data services are a typed stub in component specs, and runtime wrappers (hub, WMKS) are edges. Slot 5 says every root-provided common-library service the app injects must be listed, or the real one leaks into specs.
- `mock-permission-data.service.template.ts`: the same header marking; how to test a component that triggers the permission load itself (no factory, the `permissionApiStubs` services plus the plain class).

### New checks (they fail until the repo adopts)

- `sync.sh` (and so `verify.sh` step 1) runs `check-repo.js helpers`: `default-test-providers.ts` must still have every provider and stub member the template provides, both app helpers must keep the template's exports, and every `*Service` / `*Query` from `@cmusei/crucible-common` that app code injects (constructor or `inject()`) must be listed in `default-test-providers.ts`.
- `verify.sh` runs `check-repo.js specs` and fails on: `HubConnectionBuilder.prototype` in a spec; `Omit<ApiStub` in a spec; `{ provide: XService|XQuery|XStore, useValue: {} }` in a spec (use `unstubbed(X)`); a generated-service stub (`provide:` a class imported from `generated/`) whose value is not checked with `satisfies ApiStub<...>` or typed `ApiStub<...>`. An object that spreads a checked block plus extra members passes (the wrong-generated-type exception).

### Script fixes

- `sync.sh --test` with relative repo paths failed every suite ("No such file or directory" for the log after the `cd`); repo paths are now made absolute. The test log moved from `<repo>/.sync-test.log` (an untracked file the reviewer's `git status -uall` would now pick up) to a `mktemp` directory that the run prints. Delete any stray `.sync-test.log` in a repo.

### New documents and agent files

- New `CONVENTIONS.md`: sections 5-7 of `angular-test-writer.md` (Akita rules, spec conventions, priorities, recurring bugs) moved here, plus these new rules: denied cases are near misses, never empty grants; every `*$` gate passed to a child stub gets allowed and denied assertions on the stub input; assertions on text a stubbed child would render prove nothing; gated actions are triggered through the rendered UI; hub events use the payload the API's SignalR handler sends; every defect comment starts with `// BUG:`, one defect one pin, cross-references as plain comments; recurring patterns are one `it.each` per service file with one row per method; latent instances are pinned with `(latent: no caller)`; when "subscribe() with no error callback" is a bug (stuck loading, or no provided global `ErrorHandler`), with a canonical example; one `it` per case, no mid-test `TestBed.resetTestingModule()`; `activatedRouteStub()` and a `satisfies Pick<Router, ...>` Router stub are the defaults; `unstubbed(X)`, never `useValue: {}`; the broken-gate check breaks the gate at the component's call site.
- README: "Testing Library with Material in jsdom" (scope role queries with `within()`, render once per `it`, no `hidden: true` / `defaultHidden`), and the `MatIconTestingModule` note (its fake registry takes no arguments; provide the real `MatIconRegistry` to assert registrations).
- WORKFLOW: the checks above; the bug loop says to make the UI accept both payloads, or ship together, when an API payload fix would break the current UI handler.
- `.claude/agents/angular-test-writer.md`: sections 5-7 replaced by a pointer to CONVENTIONS.md; sections renumbered (Run and verify is 6, Report is 7). `.claude/agents/ui-test-reviewer.md`: scope includes untracked files (`git status --short -uall`); gate severity overlap clarified (only an allowed case: should-fix; a denied case that passes when the gate is broken: blocker). **Start a new session before launching either agent.**

### Spec and app-helper changes per repo (audit mode)

Every repo: audit the specs against the new CONVENTIONS.md rules listed above (near-miss denied cases, gates triggered through the UI, child-stub inputs, `// BUG:` tagging and one pin per defect, `it.each` for cases), and replace any local copy of a shared helper. Known items:

- **alloy.ui:** `default-test-providers.ts` add `unstubbed(CrucibleThemeService)` (injected by `app.component.ts`). `src/app/shared/signalr/signalr.service.spec.ts`: delete the local `captureUnhandledRejections` (use the shared one; it returns an array, not a function: `expect(rejections).toContain(offline)` becomes `toEqual([offline])` where nothing else is logged) and replace `failNextStart`, which wraps `HubConnectionBuilder.prototype.build`, with `mockHubConnectionBuilder({ onBuild: (c, index) => ... })`.
- **blueprint.ui:** `default-test-providers.ts` add `unstubbed(CrucibleDialogService)`; specs that relied on the real one now need a stub (`satisfies Pick<CrucibleDialogService, 'confirm'>`). `useValue: {}` → `unstubbed(...)` in `data/catalog/catalog-data.service.spec.ts:60`, `data/catalog-inject/catalog-inject-data.service.spec.ts:42`, `data/data-value/data-value-data.service.spec.ts:38`. `msel-data.service.spec.ts` (replaceWithXlsxFile beside a spread checked block) already follows the documented exception.
- **caster.ui:** `default-test-providers.ts` add `unstubbed(CrucibleThemeService)`. `src/app/shared/signalr/signalr.service.spec.ts`: delete the local `rejectInvokes` and `captureUnhandledRejections` (shared signatures match: `rejectInvokes(hub, err)` returns the calls; `captureUnhandledRejections()` returns an array instead of a reader function); replace `vi.mocked(signalR.HubConnectionBuilder.prototype.build)` call counts with `builder.connections.length`.
- **cite.ui:** `components/scoresheet/scoresheet.component.spec.ts:163` `{ provide: SubmissionOptionService, useValue: {} }` → `unstubbed(SubmissionOptionService)`. Recurring-pattern pins: one `it.each` per service, one row per method.
- **console.ui:** replace the local `dismissedDialogRef()` in `components/options-bar/options-bar.component.spec.ts`, `components/options-bar2/options-bar2.component.spec.ts` and `components/shared/snapshot-dialog/snapshot-dialog.component.spec.ts` with `dismissedDialogRefStub<unknown, boolean>().dialogRef`; replace the hand-rolled ref in `components/shared/file-upload-progress-dialog/file-upload-progress-dialog.component.spec.ts` with `dialogRefStub()` and its `keydown`. Optionally `captureUnhandledRejections()` in `services/notification/notification.service.spec.ts`.
- **gallery.ui:** `default-test-providers.ts` add `unstubbed(CrucibleDialogService)` (and stub it where specs used the real one). Replace the six local `endpointStub` functions (`data/{card,article,team,team-card,team-user,user-article}/*-data.service.spec.ts`) with the shared `endpointStub(XService, endpoint, fn)`.
- **player.ui:** `default-test-providers.ts` add `unstubbed(CrucibleDialogService)` (and stub it where specs used the real one). `services/notification/notification.service.spec.ts`: replace the local `rejectInvokes` with `rejectInvokes(connection, (m) => new Error(`${m} failed`))` (it returns `[method, ...args]` rows; map `([m]) => m` for the old method list) and `unhandledRejections()` with `captureUnhandledRejections()` (map to `.message` where the old one did).
- **steamfitter.ui:** convention audit only.
- **vm.ui:** `services/signalr/signalr.service.spec.ts` (the LeaveViewUsers case): replace the hand-assigned `hub.invoke = ...` plain function and console.error spy with `rejectInvokes(hub, error, ['LeaveViewUsers'])` and `captureUnhandledRejections()`.

## 2026-10-02 (later) — verify.sh false positives

Adopt: nothing to copy; re-run `verify.sh`.

- `verify.sh`: the builder-warning check matched any "not supported" text, including Browserslist's "ES5 output is not supported"; it now matches the builder's own message. The stderr allow-list is applied per blank-line-separated paragraph (POSIX ERE, awk), so continuation lines of known Sass, Browserslist and esbuild warnings, their code excerpts, and esbuild's stray `null` paragraphs pass; a real error line still fails.
- Process note: these fixes were applied by the orchestrator while nine reviewers were running, which WORKFLOW.md forbids. Two reviewers saw FAIL then PASS on identical logs as a result. Going forward the maintainer makes such changes between rounds.

## 2026-10-02 — consolidation after the nine-repo roll-out

Adopt: re-sync and update specs where noted.

- `test-setup.ts`: the console.error guard runs from a `beforeEach` teardown and skips tests that already failed. **Breaking fix:** the previous `afterEach` version skipped Angular's TestBed cleanup after a failing async test and cascaded failures through the worker. Re-sync only.
- `api-stub.ts`: `EventsOverload` added to the `ApiStub` union for `observe: 'events'` upload calls. Specs that used an `Omit<ApiStub<S>, ...> & {...}` workaround can drop it.
- `fake-hub-connection.ts`: `mockHubConnectionBuilder({ onBuild })` hook; `stream()`; `serverTimeoutInMilliseconds` and `keepAliveIntervalInMilliseconds`; `invoke` typed as `Promise<unknown>` so a result can be stubbed. Specs with a local `onBuild` wrapper can drop it.
- `activated-route.ts`: `queryParams`, `params` and a live `snapshot` getter. Specs that spread a static `snapshot` onto the stub can drop it.
- `dialog-refs.ts`: `dialogRefStub<T, R>(afterClosedResult?)`. Specs that `Object.assign`ed an `afterClosed` can call `dialogRefStub<unknown, boolean>(answer)` instead; the typed result means the old `Object.assign` form no longer compiles against a typed `confirm` stub.
- `default-test-providers.template.ts`: `snapshot.queryParams`/`queryParamMap`; fuller `RouterQuery` stub; `BASE_PATH` slot; common-library service slot; caveat for data services that read router state in their constructor.
- `mock-permission-data.service.template.ts`: note for services built with `inject()` fields.
- `tsconfig.spec.json`: `files: ["src/app/app.module.ts"]` for NgModule apps (standalone apps delete it); note for apps whose tsconfig has no `angularCompilerOptions`.
- `README.md`: "One Angular version per repo" (exact versions, one install command, check hoisting), allowed app-specific helpers, known output noise, Protractor e2e targets, "Change detection in specs".
- New: `sync.sh`, `verify.sh`, `WORKFLOW.md`, this file, `.prettierrc`.

## 2026-10-02 — initial standard

Extracted from player.ui's Vitest setup and the eight Karma-to-Vitest migrations, made app-neutral. Shared: `vitest.config.ts`, `test-setup.ts`, `tsconfig.spec.json`, `angular-test-target.json`, `build_test.yml`, `patches/`, nine `test-utils` helpers. App-specific: `default-test-providers.ts`, `mock-permission-data.service.ts`.
