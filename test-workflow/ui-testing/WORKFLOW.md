# Crucible UI testing workflow

The workflow, the agents and their hand-offs, ready, the file formats, the check vocabulary, the severity scale and the usage of every script are shared by both stacks and live in [../testing/README.md](../testing/README.md). This file holds only what is particular to the UI stack.

## Running the suites

- **Packages stay as they are** outside setup mode: `npm ci` once if `node_modules` is missing, nothing else (SETUP.md is the one place packages and `angular.json` change).
- **One run per worktree,** and one agent per worktree.
- **Host load.** `verify.sh` runs the suite three times (tests, probes, coverage), and its timings are load-sensitive. Each Vitest run uses a worker per core: two `verify.sh` runs at once on an 8-core host put the load average at 12 to 17, and all nine repos still passed under the 15 s `testTimeout` (2026-10-09). Run no more than two at once. A FAIL line says how many tests timed out; if every failure is a timeout and the host was loaded, rerun that repo alone before treating it as a regression. A test that is slow alone is a spec to make cheaper (README, "Testing Library with Material in jsdom"), not a flake.
- **One spec, one test.** `npx ng test --watch=false --include <spec>`; `--filter '<regex>'` narrows to matching test names; `npx ng test --help` lists the installed builder's options.

## The work list

The commands a task's work list comes from, and that the writer reruns until they are clean:

```sh
node /mnt/data/crucible/agent-docs/ui-testing/check-repo.js gates   <worktree> --app <app> [--list]
node /mnt/data/crucible/agent-docs/ui-testing/check-repo.js removed <worktree> --app <app>
node /mnt/data/crucible/agent-docs/ui-testing/check-repo.js specs   <worktree> --app <app>
/mnt/data/crucible/agent-docs/ui-testing/sync.sh --check <worktree>
```

`gates --list` prints every gated file with its gates, the test counted as its denied case and where its setup comes from, per gate the denied test that names it, and every derived input; the reviewer reads those (CONVENTIONS section 2, Permissions). `removed` run without `--base` writes the script's own accounting lines (../testing/README.md, "Removed-test accounting"); the reviewer passes `--base <last ready commit>`. `fix-unused-imports.js --write <worktree>` clears the unused imports verify.sh notes.

## What verify.sh checks

`verify.sh [--clean] [--app <app>] [--base <ref>] [--log-dir <dir>] <worktree>`, in order: the shared files, config, builders, polyfills and the two app-specific helpers' shape (`sync.sh --check`); the specs (`check-repo.js specs`: no `HubConnectionBuilder.prototype` spy, `Omit<ApiStub` workaround or `useValue: {}` placeholder, no `BUG` in a spec comment, every generated-service stub checked with `satisfies ApiStub`; NOTE lines for defect entries whose test is not there); the gates (`check-repo.js gates`); the removed tests (`check-repo.js removed`); unused imports or locals in specs and test-utils (`tsc --noUnusedLocals`, a NOTE); the toolchain on one version and Akita at 8.0.1; `"zone.js"` in the polyfills; thresholds set and not below the base branch's; `npm test` with no builder warning and only known stderr noise (README, "Known noise"); a probe that one failing async test stays one failure and that the TestBed has a real `NgZone`; a probe that a type error fails the test build; `npm run build`; `npm run test:coverage` with its thresholds, whose measured values are compared with floor(measured) − 1 (a NOTE when they differ). `--clean` reinstalls first, as Docker and CI do.

## The broken-gate check on a UI

`../testing/break-gate.sh` runs the spec beside each site file (or the `--spec` files) with `ng test --reporters=json` and judges the named tests by title. Break the gate at the component's call site (the `canEdit$` the component builds, or the condition in its template), never inside the permission service. A gate computed at two sites gets a run per site, and the log records which tests failed for each (CONVENTIONS section 5).
