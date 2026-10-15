# Setting up a UI on the standard

Setup mode of `angular-test-writer` (GLOSSARY.md, "Writer mode"): migrating a Crucible Angular UI from Karma onto the standard, or repairing a broken test setup. Create and audit mode do not read this file. The setup these steps build is described in [README.md](README.md); how specs are written is [CONVENTIONS.md](CONVENTIONS.md); the workflow, the file formats and the scripts are in [../testing/README.md](../testing/README.md). Do every step: each is small, and a skipped one is how repos drift. Run commands from the repo root of the worktree. Packages and `angular.json` change only in setup mode.

The rule above everything here: **tests run the way the app runs**: the same Angular version, the same change detection (every Crucible UI bootstraps with `provideZoneChangeDetection()`, so tests run with zone), the same builders. Angular 21's default for new apps is zoneless; the test environment is never "modernized" past the app.

## 1. Record the setup facts

Check, in this order, and keep the answers for the report (the setup facts, below):

1. **Toolchain versions.** `npm ls @angular/core @angular/cli @angular-devkit/build-angular @angular/build vitest @datorama/akita @cmusei/crucible-common 2>/dev/null`. Note the Node major in the Dockerfile.
2. **Test builder.** `angular.json` `architect.test.builder`: `@angular/build:unit-test` means the setup exists (go to step 13 and repair what verify reports); `@angular-devkit/build-angular:karma` or `@angular/build:karma` means the specs are CLI boilerplate and the migration below applies. No Karma or Jasmine test is added.
3. **Change detection.** `src/main.ts`: `provideZoneChangeDetection` (every Crucible UI today) or `provideZonelessChangeDetection`.
4. **Component style.** NgModule (`standalone: false`, `declarations`) or standalone (`bootstrapApplication`). vm.ui and console.ui are standalone; the rest are NgModule.
5. **Akita.** Which `state/` or `data/` folders exist, and whether the app uses `@datorama/akita-ng-router-store`.

Done when every question has an answer you could quote with its file.

## 2. One Angular version

Every `@angular/*` and `@angular-devkit/*` package, plus `@angular/build`, on one 21.2.x patch: the newer of the CLI's and the framework's current patch, installed at exact versions in one `npm install` command, then checked for what is hoisted (README, "One Angular version per repo"). `@angular/cdk` and `@angular/material` match the patch where it exists, otherwise the same major and minor. If `npm install` fails with ERESOLVE on the exact framework peers, delete the `@angular/*`, `@angular-devkit/*` and `@schematics/*` entries from `package-lock.json` and install again. Never `--legacy-peer-deps` (a repo `.npmrc` that already sets it stays).

Done when `npm ls @angular-devkit/core @angular/core` shows one hoisted version and `node -p "require('@angular/cli/package.json').version"` equals `@angular/core`'s and `@angular/build`'s.

## 3. The build builders

The unit-test builder compiles specs through the app's `build` target and prints "not supported" when that target is `@angular-devkit/build-angular:application`. Change `build` to `@angular/build:application`, `serve` to `@angular/build:dev-server`, `extract-i18n` to `@angular/build:extract-i18n`, keep their options, then remove the `@angular-devkit/build-angular` dependency. A dead `e2e` (protractor) or `lint` (tslint) target that still names it stays (README, "Protractor e2e targets"). Dockerfiles run `npx ng build` and need no change.

Done when `npm run build` passes and `sync.sh --check <worktree>` reports no `DRIFT builders` line.

## 4. Zone through the polyfills

The builder adds zone change detection to the TestBed only when the build target's `polyfills` array holds the literal `"zone.js"`. List `"zone.js"` (and any other polyfill, such as `"@angular/localize/init"`) in that array, delete `src/polyfills.ts` when it is empty, and remove it from `tsconfig.app.json` and `tsconfig.spec.json`. Never a `providersFile` with `provideZoneChangeDetection()`, never `markForCheck()` from a spec, never `ComponentFixtureAutoDetect` (README, "Change detection in specs").

Done when `angular.json`'s build polyfills include `"zone.js"`, no `src/polyfills.ts` exists, and step 13's probe reports a real `NgZone`.

## 5. Dependencies

Add, at the versions the README names: `@angular/build` (step 2), `vitest`, `@vitest/coverage-v8`, `jsdom`, `@testing-library/angular`, `@testing-library/dom`, `@testing-library/jest-dom`, `@testing-library/user-event`, `patch-package`, and `@types/node` at a version Vitest's peer range accepts. Remove `karma*`, `jasmine-core`, `@types/jasmine`, `src/test.ts` and `karma.conf.js`. Keep `jasmine-spec-reporter` and `@types/jasminewd2` only if `e2e/` still references them; Protractor and lint are separate changes, listed as follow-ups. Prettier 2.x moves to 3.x so it can format `satisfies`; a repo without Prettier formats with `npx prettier@3` and does not add it.

Done when `npm ci` succeeds and `npm ls karma jasmine-core` finds nothing.

## 6. Akita and the patches

`@datorama/akita` at `^8.0.1` so the lock resolves 8.0.1 and the standard patch applies unchanged (bumping is the fix, never regenerating the patch). Copy `patches/@datorama+akita+8.0.1.patch`, and `patches/@material+material-color-utilities+0.4.0.patch` only if the lock contains that package (`grep -A2 '"node_modules/@material/material-color-utilities"' package-lock.json`). `patch-package` runs from `vitest.config.ts`, not a `postinstall` script; `server.deps.inline`, `ssr.noExternal` and `optimizeDeps` do not work with this builder.

Done when `sync.sh --check <worktree>` reports no `MISSING`, `STALE` or `UNKNOWN` patch line and `node -p "require('@datorama/akita/package.json').version"` prints 8.0.1 (or the app has no Akita).

## 7. Config files

Copy `vitest.config.ts`, `src/test-setup.ts` and `tsconfig.spec.json` from the standard (`sync.sh <worktree>` copies the first two). In `tsconfig.spec.json`, replace `angularCompilerOptions` with the block from the app's `tsconfig.app.json` and delete the `__comment` key; NgModule apps keep `"files": ["src/app/app.module.ts"]` (without it every `standalone: false` component fails with NG8001), standalone apps delete `files`. Replace the `test` target in `angular.json` with `angular-test-target.json`, thresholds at 0 until step 12. No `browser` configuration unless the browser provider is installed and the task asks for it.

Done when `sync.sh --check <worktree>` reports no line for `vitest.config.ts`, `src/test-setup.ts` or the test target, and `npx ng test --watch=false --list-tests` lists the specs.

## 8. Test helpers

`src/app/test-utils/` from the standard's `test-utils/`: the shared files unchanged (`sync.sh` copies them; `fake-hub-connection.ts` only if the app uses SignalR), and the two app-specific ones from their templates:

- `default-test-providers.ts`: one `unstubbed(...)` per generated API service the client's `api.ts` exports; placeholders for the app's own services (SignalR, error, dialog, system message, xAPI) and for every common-library service the app injects (they are root-provided, so a missing one builds the real service); the common-library auth and settings stubs, dialog and route tokens, `BASE_PATH` if injected, `RouterQuery` only with `akita-ng-router-store`. Stores, queries, data services and `BehaviorSubject` state services are not listed: they stay real (a module-provided one is listed as its real class). A data service whose constructor reads router state gets a placeholder, and its own spec drives a real router. Pass a label to `unstubbed()` when two classes share a name.
- `mock-permission-data.service.ts`: `permissionDataProviders(grants)` provides the app's real permission service over stubbed "my permissions" endpoints; the gate logic is never re-implemented in a stub.

An app-specific fake for something the standard lacks is one of the allowed extras of the README; any other file in `test-utils` fails.

Done when `sync.sh --check <worktree>` is clean (its `check-repo.js helpers` compares the two app-specific files with their templates and checks the extras and `setupFiles`).

## 9. Old specs

Each Angular CLI boilerplate spec ("should create") is replaced by the smoke spec from `templates/component-smoke.spec.template.ts` at the same path; a spec with real assertions is rewritten in the standard's style at the same path; nothing is deleted outright and nothing Jasmine is ported as it is. Every replaced or rewritten test is accounted for (../testing/README.md, "Removed-test accounting").

Done when `check-repo.js gates <worktree> --app <app>` reports no `NOSPEC` line for a component and `check-repo.js removed <worktree> --app <app>` reports 0 unaccounted.

## 10. Scripts

`test`: `ng test --watch=false`; `test:watch`: `ng test`; `test:coverage`: `ng test --watch=false --configuration coverage`, keeping any project-name argument the repo's scripts pass to `ng`.

Done when `npm test` runs the suite once and exits.

## 11. A smoke test of the patches, and CI

Run one throwaway spec that builds a real Akita store and query, to prove the patches load, before real tests are written; delete it afterwards if the state specs cover the same import. Add `.github/workflows/build_test.yml` from the standard with `node-version` set to the Dockerfile's Node major; where the repo already has a workflow that runs `npm ci`, the test step goes there instead.

Done when the throwaway spec passed and is gone, and `sync.sh --check <worktree>` reports no `build_test.yml` line.

## 12. Thresholds

After the specs are written, each `coverageThresholds` value is floor(measured) − 1 from the `npm run test:coverage` run inside `verify.sh` on the final tree, never below the value in `origin/main`'s `angular.json` (README, "Coverage thresholds"). `coverageInclude` stays as the standard has it.

Done when `verify.sh` passes its threshold checks and prints no thresholds NOTE.

## 13. Docs and verify

Replace the README's "Running unit tests" section with the three scripts and a pointer to `src/app/test-utils/`; list the group `AGENTS.md` (outside the repo) in the report for the orchestrator. Then run `/mnt/data/crucible/agent-docs/ui-testing/verify.sh --clean <worktree>`; from here the writer's steps in create mode take over (../testing/README.md, "The workflow").

Done when every check other than `gates` passes and the log is in `agent-docs/test-work/<app>/`.

## The setup facts the writer reports

Under "Mode and version" in the writer's report:

- the toolchain versions as installed (Angular, CLI, `@angular/build`, Vitest, Akita, `@cmusei/crucible-common`) and the Node major used for CI;
- the change detection mode and the component style;
- the builders before and after, and which patches were copied;
- the app-specific helpers and any allowed extra, each with what it fakes;
- the coverage measured and the thresholds set;
- the follow-ups outside the scope: lint and e2e targets, the group `AGENTS.md`.
