# Crucible UI unit-test standard

The canonical Vitest setup for every Crucible Angular UI (alloy.ui, blueprint.ui, caster.ui, cite.ui, gallery.ui, steamfitter.ui, player.ui, vm.ui, console.ui). The `angular-test-writer` agent copies these files into a UI repo verbatim, so the setup is identical everywhere. **Change the standard here first, then roll it out to the repos**; never edit a copy in one repo and leave the others behind. Only the `test-standard-maintainer` agent edits this folder, at a standard version. How specs are written (Akita rules, conventions, defect entries, priorities, review criteria) is in [CONVENTIONS.md](CONVENTIONS.md), the shared source for the writer and the reviewer. Setting a repo up is [SETUP.md](SETUP.md), read in setup mode only. Defects the specs find are described in one document per app, `agent-docs/ui-test-bugs/<app>.md`, never in spec comments (CONVENTIONS.md section 3). The workflow, the file formats and the scripts both stacks share are in [../testing/README.md](../testing/README.md); what is particular to this stack is in [WORKFLOW.md](WORKFLOW.md); what changed and how to adopt it is in [CHANGELOG.md](CHANGELOG.md).

| Template | Destination in the UI repo | App-specific? |
| --- | --- | --- |
| `vitest.config.ts` | `vitest.config.ts` | No (mock lifecycle, `testTimeout` 15 s) |
| `test-setup.ts` | `src/test-setup.ts` | No |
| `tsconfig.spec.json` | `tsconfig.spec.json` | `angularCompilerOptions` copied from `tsconfig.app.json`; standalone apps delete `files` (NgModule apps keep it); delete the `__comment` key |
| `angular-test-target.json` | the `test` target in `angular.json` | thresholds: [Coverage thresholds](#coverage-thresholds); `setupFiles` may append an allowed extra after `src/test-setup.ts` ([Helpers](#helpers-shared-app-specific-allowed-extras)) |
| `patches/*.patch` | `patches/` | copy only the patches for packages the lockfile contains |
| `build_test.yml` | `.github/workflows/build_test.yml` | Node major from the Dockerfile |
| `.prettierrc` | (not copied) | the options the shared files are formatted with; every repo's own `.prettierrc` already matches |
| `CONVENTIONS.md` | (not copied) | how specs are written; the review criteria |
| `SETUP.md` | (not copied) | setup mode: migrating a UI onto the standard, step by step, and the setup facts the writer reports |
| `../ui-test-bugs/<app>.md` | (not copied; outside every repo) | one per app: each defect a spec characterizes, the test by spec file and name, its production `file:line`, the fix and the test to flip; written by the writer, checked by the reviewer, read by the triager. Format in [../testing/README.md](../testing/README.md), "Defect documents"; this stack's rules in CONVENTIONS.md section 3 |
| `../ui-test-bugs/<app>.removed-tests-<date>.md`, `<app>.removed-tests-matched.md` | (not copied; outside every repo) | the removed-test accounting: the lines a writer judged, and the lines `check-repo.js removed` writes for the removals it matches itself. Notation in [../testing/README.md](../testing/README.md), "Removed-test accounting" |
| `sync.sh` | (not copied) | copies the shared files into repos and reports drift (`--check`), optionally runs the suites (`--test`) |
| `verify.sh` | (not copied) | the definition of done for one repo, written to the verify log; see WORKFLOW.md, "What verify.sh checks" |
| `check-repo.js` | (not copied) | the structural checks `sync.sh` and `verify.sh` run. `helpers`: app-specific helpers against their templates, no unlisted file in `test-utils`, `setupFiles` order. `specs`: spec patterns the standard replaced, `BUG` in spec comments, unchecked API stubs; NOTE lines for defect entries whose test (spec file and name) is not there. `gates`: a spec beside every component and every service, pipe, directive, guard, resolver, interceptor and selector-bearing Akita query; a denied case for every file that reads a permission and for every input bound from a parent's permission value (`DERIVED`); a denied case that sets up its own denial (`WEAKDENY`); each missing one fails (CONVENTIONS.md section 2, Permissions). `removed`: every test title removed since the merge base with `origin/main`, matched by the script or accounted for (../testing/README.md, "Removed-test accounting"). Output kinds and usage: ../testing/README.md, "Check output" and "Script usage" |
| `fix-unused-imports.js` | (not copied) | removes unused imports from a repo's own specs and test-utils (the NOTE `verify.sh` prints for them) |
| `templates/component-smoke.spec.template.ts` | `x.component.spec.ts` beside each component that has no spec | **Yes**: one per component; replaces CLI boilerplate specs (CONVENTIONS.md section 2) |
| `test-utils/render-component.ts` | `src/app/test-utils/` | No |
| `test-utils/unstubbed.ts` | `src/app/test-utils/` | No |
| `test-utils/api-stub.ts` | `src/app/test-utils/` | No (`ApiStub<S>`, `endpointStub(S, endpoint, fn)`) |
| `test-utils/record-emissions.ts` | `src/app/test-utils/` | No |
| `test-utils/unhandled-rx-errors.ts` | `src/app/test-utils/` | No (`captureUnhandledRxErrors()`, `captureUnhandledRejections()`, `flush()`) |
| `test-utils/fake-hub-connection.ts` | `src/app/test-utils/` | No (only if the app uses SignalR; `mockHubConnectionBuilder()`, `rejectInvokes()`) |
| `test-utils/activated-route.ts` | `src/app/test-utils/` | No |
| `test-utils/dialog-refs.ts` | `src/app/test-utils/` | No (`dialogRefStub(afterClosedResult?)`, `dismissedDialogRefStub()`, `bottomSheetRefStub()`) |
| `test-utils/file-list.ts` | `src/app/test-utils/` | No (jsdom has no `FileList`; for file-input components) |
| `test-utils/default-test-providers.template.ts` | `src/app/test-utils/default-test-providers.ts` | **Yes**: this app's services and settings |
| `test-utils/mock-permission-data.service.template.ts` | `src/app/test-utils/mock-permission-data.service.ts` | **Yes**: this app's permission service and claims |
| `../ui-test-gaps/<app>.json` | (not copied; outside every repo) | one per app, optional: components or gates the harness cannot render, each with its reason; read by `check-repo.js gates --app <app>`, and every entry is named in the PR description (CONVENTIONS.md section 2, Permissions; `../ui-test-gaps/README.md`). An in-repo `gates.allow.json` fails the check |

Pinned versions that the templates assume: `@datorama/akita` 8.0.1 (patch file name), `@material/material-color-utilities` 0.4.0 (patch file name), Vitest 4, `@testing-library/angular` 19.

## One Angular version per repo

The unit-test builder, the CLI and the framework must be on the same 21.2.x patch, or `npm install` fails with ERESOLVE on the exact framework peers and the test build can behave differently from the app build.

- "One version" covers every `@angular/*` and `@angular-devkit/*` package listed in `package.json`, plus `@angular/build`. `@angular/cdk` and `@angular/material` release on their own train: match the patch where it exists and otherwise keep the same major and minor.
- Pick the **newer** of the CLI's and the framework's current patch, so nothing is downgraded.
- Install every Angular package at that **exact** version in **one** `npm install` command (`npm install @angular/core@21.2.10 @angular/cli@21.2.10 ... @angular/build@21.2.10`). With caret ranges and the lock entries deleted, npm floats each package to the newest 21.2.x on different trains instead. Restore the `^` ranges in `package.json` afterwards if the repo uses them.
- Then run `npm ls @angular-devkit/core @angular/core` and make sure a single version is hoisted. `@angular-eslint/*` pulls in `@angular-devkit/*` at its own version; that transitive copy is out of scope, but if npm hoisted it over the CLI's copy, hoist the CLI's entries in the lockfile (`npm dedupe` also works but churns unrelated packages).
- Do not pass `--legacy-peer-deps`. If the repo's own `.npmrc` already sets `legacy-peer-deps=true` for an unrelated dependency (gallery.ui, blueprint.ui), leave it; the Docker build relies on it.

## Helpers: shared, app-specific, allowed extras

The nine shared `test-utils` files are byte-identical in every repo. They are formatted with **Prettier 3** and this folder's `.prettierrc` (the repos use the same options), and written so that every Prettier 3 minor the repos have installed formats them unchanged (3.8.1 and 3.9.9 today, the latest 3.x when this was checked), so a repo-wide `prettier --write` leaves them alone. Where two 3.x minors format a construct differently (a long union, a long `vi.fn(...)` argument), the shared file is rewritten until both agree, rather than pinning one minor. Repos without Prettier format with `npx prettier@3`.

Two files are app-specific by design: `default-test-providers.ts` and `mock-permission-data.service.ts`, built from the templates. Delete the template's "TEMPLATE INSTRUCTIONS" paragraph in the copy; a short comment on what is app-specific may replace it. `sync.sh` (through `check-repo.js`) checks their shape: every provider and stub member the template provides is still there (extra ones are fine), the template's exports exist, and every `*Service` / `*Query` from `@cmusei/crucible-common` that app code injects is listed, because those are `providedIn: 'root'` and a missing one means the real service is built in every spec. A repo may add helpers for things the standard has no equivalent for, next to the shared ones and named for what they fake. The allowed extras, each for the app named (`check-repo.js helpers`, so `sync.sh --check`, fails any other `.ts` file in `src/app/test-utils`):

| File | App | What it fakes |
| --- | --- | --- |
| `fake-wmks.ts`, `clipboard.ts` | console.ui | the VMware WMKS console runtime; the async clipboard API |
| `download-response.ts` | caster.ui | an `HttpResponse<Blob>` with a Content-Disposition header |
| `jsdom-canvas.ts` | caster.ui | `HTMLCanvasElement.getContext()` returning `null` without jsdom's "Not implemented" message, which `@xterm/xterm` triggers at module load; a `setupFiles` entry (below) |
| `match-media.ts` | caster.ui | `window.matchMedia`, which xterm reads when a terminal opens (`mockMatchMedia()`, restored per test) |
| `mat-dialog.ts` | cite.ui | `MatDialog.open` returning a ref whose `componentInstance` has a real `editComplete` emitter (`matDialogStub()`) |
| `msel-load-api-stubs.ts` | blueprint.ui | the generated endpoints a page calls when it opens an MSEL's entity graph, so the real data services fill the real stores |

If a second repo needs one of these, promote it into the standard instead of copying it. A helper that replaces the standard's queries or interactions rather than faking something is not an extra (the alloy.ui `role-and-text.ts` and `user-input.ts` helpers were rejected by the user on 2026-10-09).

`setupFiles` in the `test` target starts with `src/test-setup.ts`. An app may append an allowed extra under `src/app/test-utils/` that must run before any spec's module graph loads: caster.ui's `jsdom-canvas.ts`, because the unit-test builder bundles the specs with esbuild, which does not keep a spec's side-effect import ahead of a shared chunk, so importing the fake from a spec is not reliable. `check-repo.js helpers` fails any other `setupFiles` shape.

## Testing Library with Material in jsdom

- **Role queries are slow on big templates.** `getByRole(role, { name })` computes accessibility for every candidate, and the cold `getComputedStyle` calls dominate: about 0.7 s for one unscoped query over a Material table, 0.1 to 0.5 s scoped, under coverage. A spec that passes `npm test` can time out under `test:coverage`. Scope role queries to the region under test with `within(...)` (`within(screen.getByRole('table')).getAllByRole('row')`), and render once per `it` rather than re-rendering inside a test. The cost is the accessible-name computation more than the scope (alloy.ui, measured warm: a `{ name }` role query about 180 to 250 ms even scoped, the same query without `name` about 4 ms, a label or text query 3 to 6 ms): in large templates prefer `getByLabelText` for fields, a role query without `name` narrowed with `within(...)` and the visible text, and scoping buttons to the dialog's actions block (alloy.ui's dialog tests went from 1.4 to 1.9 s to 0.5 to 0.7 s). A test that takes more than about 2 s alone under coverage is at risk on a loaded host; make it cheaper rather than relying on the timeout.
- **Global styles make every style lookup expensive.** The unit-test build loads the app's global styles from the build target (the Material theme, Bootstrap in cite.ui), so each `getComputedStyle` costs tens of milliseconds on a heavy page. The standard keeps them: visibility (`toBeVisible`, the role queries' hidden filter) depends on that CSS, and a test build without it would not see what the user sees. The costs it adds are the ones these notes work around.
- **user-event clicks check pointer events.** `user.click` (and the click `user.type` starts with) walks `getComputedStyle` up every ancestor to check `pointer-events`, about 0.1 to 0.3 s per click on a large page and more than 1 s on cite.ui's editor pages, while focus plus a key costs about 15 ms. For a text field use `field.focus(); await user.type(field, text, { skipClick: true })`; for a checkbox or toggle focus it and `await user.keyboard(' ')`; `MatCheckboxHarness.with({ ancestor })` is also fast (about 5 ms) where no `interval()` is running. `pointerEventsCheck: PointerEventsCheckLevel.Never` is allowed per spec under the conditions in CONVENTIONS.md section 2 (Queries).
- **Don't trade `hidden` for speed.** `{ hidden: true }` on a query, or `configure({ defaultHidden: true })`, makes queries match elements hidden from the user (`aria-hidden`, `display: none`, closed Material panels), so a test could pass on a control the user cannot see. The standard does not use either.
- **jest-dom and disabled ancestors.** `toBeDisabled`/`toBeEnabled` treat a custom element with a static `disabled` attribute (`<mat-expansion-panel disabled>`, `<mat-checkbox disabled>`) as disabling every descendant, so assert a control's own `.disabled` property inside one (gallery.ui's broken-gate run showed the difference). A disabled Material button has `pointer-events: none`: assert `toBeDisabled()`, never a click followed by `not.toHaveBeenCalled()`.
- **`mat-select`.** A `mat-select` outside a `mat-form-field` does not open from `user.click(combobox)` or Enter, because the listener is on the inner trigger: click `.mat-mdc-select-trigger`, or use `MatSelectHarness`. On a page with a paginator, `MatSelectHarness.with({ ancestor: 'table' })` (or another ancestor), or the paginator's page-size select is the first harness found.
- **Material state set in a microtask.** `ngModel` with `[disabled]` on a Material control (`mat-checkbox`) applies the disabled state in a microtask, and `matTooltip` sets the host's `aria-describedby` in one: `await fixture.whenStable(); fixture.detectChanges()` before asserting either. A `mat-tree` renders its nodes after one more `fixture.detectChanges()` plus `await fixture.whenStable()` after `render`.
- **Overlays.** Material dialog and bottom-sheet containers carry `role="dialog"` (from the CDK dialog config), so `await screen.findByRole('dialog')` finds an opened one; don't query the container's tag name (`mat-bottom-sheet-container`). They render outside the fixture's element, so query through `screen`, then `within(dialog)`.
- **Router links.** A `{ provide: Router, useValue: { navigate } }` stub stops `routerLink` from rendering an `href`. A spec that asserts a link keeps the real router `renderComponent` provides and spies on it instead (`vi.spyOn(TestBed.inject(Router), 'navigate')`).
- **jsdom 28 / cssstyle 6.2 crashes on some CSS.** `getComputedStyle` throws "Cannot create property 'border-width' on string" on a `border: 1px solid var(--x)` shorthand, and "Cannot destructure property 'value' of 'Specificity.max(...)'" on some selectors (blueprint.ui's event-detail-page styles). A role query that touches a matching element throws; use label, text or title queries on that element until jsdom's CSS parser handles it.
- **Icons.** `renderComponent` installs `MatIconTestingModule`, whose fake registry's `addSvgIcon()` and friends take no arguments and record nothing. A spec that asserts icon registrations (an app component that registers its SVG icons) passes the real one in `providers` (`{ provide: MatIconRegistry, useClass: MatIconRegistry }`, which wins over the module's fake) and spies on its `addSvgIcon*` methods. It needs `provideHttpClient()` and `provideHttpClientTesting()` only if the spec renders an icon that has to be fetched.

## The spec build: NgModules, hosts, imports

- **App NgModules are empty in the test build.** The unit-test builder compiles AOT, and an NgModule's `ɵmod` lists no declarations and no exports there (measured on gallery.ui's `AppModule` and caster.ui's `CwdTableModule`, 2026-10-09). Importing an app module in `TestBed` therefore gives a spec none of its components or directives. Declare what a spec-local template uses (or import the standalone pieces); the component under test needs nothing, because its compiled definition already carries its NgModule's template scope.
- **Host components.** A spec-local host declared `standalone: false` fails the AOT build with NG8001 for every app element it uses (it belongs to no NgModule the compiler sees). Use a standalone host with an empty template and set the real one through the TestBed: `@Component({ template: '' }) class Host {}`, then `renderComponent(Host, { configureTestBed: (tb) => tb.overrideTemplate(Host, template), declarations: [...] })`.
- **Circular imports between specs' subjects.** When child components import types from their parent (vm.ui's iso-group from iso-list), the parent's spec imports the parent before the children, or every test fails with "Cannot read properties of undefined (reading 'ɵcmp')".
- **Stubs for `@ViewChild(RealType)`.** A child stub that provides itself as the real type (`providers: [{ provide: RealChild, useExisting: ChildStub }]`) satisfies a parent's `@ViewChild(RealChild)`; read the stub through `fixture.debugElement.query(By.directive(ChildStub))`.

## Known noise in test output

Besides the Akita "Sourcemap ... points to missing source files" lines and Sass deprecation warnings, a run may print the app's own build warnings, because the unit-test builder compiles the app: Browserslist notices from `.browserslistrc`, NG8113 "unused import" warnings, and bundle budget warnings. All of these also appear in `npm run build` and are not test-setup problems. npm 12 adds `npm notice run <script>` banners; `verify.sh` drops those lines one by one before the paragraph check, so a notice cannot hide an error next to it (CI's npm 11 prints none). Anything else on stderr is.

## Coverage thresholds

- **Measured minus one.** Each `coverageThresholds` value is floor(measured) − 1 (but never below the base's value, next point), where measured is the `All files` percentage of the `npm run test:coverage` run inside `verify.sh` on the final tree (93.93 % gives 92). `verify.sh` prints the four measured values and warns when the thresholds differ from that rule. Two runs on nearly the same tree can straddle an integer (93.93 and 94.05); the verify run on the tree being delivered decides.
- **They only ratchet up.** A threshold is never below the value in the base branch's `angular.json` (`origin/main`, through the merge base); `verify.sh` fails a tree whose thresholds are lower. When the measured coverage drops below the base's thresholds, restore the tests that covered it (CONVENTIONS.md section 2, "No test is lost"); never lower the threshold.
- `coverageInclude` (`src/app/**/*.ts`, loaded or not, templates out) is not changed per app, so the numbers stay comparable across apps.

## Protractor e2e targets

Switching the build builders removes `@angular-devkit/build-angular`. Several repos still have an `e2e` target on `@angular-devkit/build-angular:protractor`. In 21.x that builder only threw "Protractor is end-of-life", so the target was already dead; after the removal `ng e2e` fails with "builder's node package not found" instead. Leave the target, keep `jasmine-spec-reporter` and `@types/jasminewd2` if `e2e/` still references them, and list the removal as a follow-up.

Why this setup looks the way it does is explained step by step in [SETUP.md](SETUP.md). The short version: the apps run Angular 21 with zone.js, so tests run under the `@angular/build:unit-test` builder with zone change detection, in jsdom, with Akita patched because the builder cannot inline it.

## Change detection in specs

Tests run with zone change detection, like the apps, and that has a consequence the zoneless default hides: a zone-mode `ComponentFixture` does **not** auto-detect (`ComponentFixtureAutoDetect` is off), so the app's zone turns and `markForCheck()` calls never re-render it. What does re-render it:

- Events sent through Testing Library (`userEvent`, `fireEvent`). `render()` wraps them so every mounted fixture gets `markForCheck()` plus `detectChanges()` afterwards. Prefer these; they are also how the user drives the app.
- `fixture.detectChanges()` after state the test changes itself (`store.set(...)`, `subject.next(...)`, a property assignment). That works for Default components only, because it does not reach an OnPush component that nothing marked dirty.

So an OnPush component has to be driven through its UI (`user.upload(input, file)`, `user.click(...)`) rather than by patching its form or state from the test body. A raw `element.dispatchEvent(...)` does run the handler, but nothing re-renders afterwards. The standard deliberately does not turn `ComponentFixtureAutoDetect` on: it runs change detection when the fixture is created, before a spec sets inputs, and in the player.ui pilot it failed 66 of 69 tests in a four-spec sample and hung the full run.
