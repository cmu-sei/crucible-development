# Crucible Design Specification: UI Conventions

**Status:** Draft for review · **Applies to:** All Crucible Angular applications that use Angular Material (Player, Caster, Alloy, Steamfitter, CITE, Gallery, Blueprint). Section 2 and section 7 note where the TopoMojo and Gameboard UIs, which do not use Material, differ. · **Stack assumption:** **Angular 21 + Material Design 3 (M3)**

This spec collects the cross-cutting conventions that are neither tables nor modals: icons, loading indicators, messages, forms, typography, the top bar and permission descriptions. It defers to the other specs and does not restate them:

- Modals and dialogs: [modals.md](modals.md).
- Colors, light and dark mode, the top-bar color: [colors.md](colors.md).
- Admin pages, tables, search, pagination and dates: [admin-tables.md](admin-tables.md).

**Repos should point their `AGENTS.md` / `CLAUDE.md` at `crucible-development/design-specs`**, so that people and coding agents read these specs before changing shared UI.

It was derived from the code on `main` of each app (section 11), not invented. Where the apps agree, the rule records it. Where they disagree, the rule picks the majority or the more accessible behavior and lists the choice in section 12 for review.

**How to read the rules.** Each rule is tagged **[Existing]** (at least one app does this today; the app is named) or **[Target]** (no app does this fully yet; aspirational, not a defect in any page today).

**Accessibility is a requirement.** Crucible is used in U.S. federal and DoD training contexts, so everything here must satisfy **Section 508** (which incorporates **WCAG 2.1 Level AA**). Section 9 collects the requirements.

**Known gaps not covered here.** Responsive layout (CRU-3113), Section 508 conformance work (CRU-2827) and CSS standardization (CRU-2615) are open tickets with no spec yet. Where a rule in this document touches one of them, it says so.

---

## 1. Principles

1. **One mark, one meaning.** An icon means one thing in every app; a thing is shown by one icon in every app.
2. **One icon set.** Icons come from Material Design Icons. No second icon font, no PNG icons in the UI.
3. **Show progress or show results, never both.** An initial or blocking load replaces the empty and results states; it does not sit next to them. A refresh of data already shown is the exception: the rows stay, with a non-blocking indicator on the control that started it (rule 3 in section 3).
4. **Say what happened, in words a user can act on.** Messages name the object, say what went wrong and what to do. They never show a stack trace, a URL or a status line from the framework.
5. **Enter submits a form; Escape cancels it.** The same keys in every form.
6. **Type comes from the theme.** Sizes come from the M3 type scale and relative units, not scattered pixel values.
7. **The shared library owns what is shared.** Dialogs, the classification banner and the theme come from `@cmusei/crucible-common`. There is no shared icon, snackbar or top-bar component yet.

---

## 2. Icons

**What the apps do today (verified).**

- **Set and loading.** **[Existing]** All seven Material apps use Material Design Icons through the `@mdi/font` package, referenced as `<mat-icon fontIcon="mdi-...">` (Blueprint 395 uses, Alloy 80, CITE 173, Gallery 121, Steamfitter 80, Player 35 in the templates I read; no ligature-text icons). The package's whole CSS and font file are loaded at startup (`@use '@mdi/font/scss/materialdesignicons'` in the Caster, Blueprint and Player `styles.scss`; `@import` in Alloy). CITE's package pins `@mdi/font` `^5.9.55`; the others are on 7.x (Caster 7.4.47). CRU-2605 asks to standardize on one set and raises `@mdi/js` (tree-shakeable) as a way to avoid shipping every icon.
- **Other sets.** **[Existing]** `@fortawesome/fontawesome-free` is still imported or listed as a dependency in Alloy, Blueprint, Caster, CITE, Gallery and Steamfitter. I found no Font Awesome class in the Alloy, Blueprint, CITE, Gallery, Player or Steamfitter templates; Caster uses it in one place (`fontSet="fas" fontIcon="fa-file-export"` in `project-navigation-container.component.html`). Player's Administration menu uses PNG images (`assets/img/SP_Icon_*.png`). The TopoMojo and Gameboard UIs do not use Material at all and use `@fortawesome/angular-fontawesome`.
- **Custom SVGs.** **[Existing]** App logos are registered SVG icons, named `ic_crucible_<app>` in Alloy, Caster, Player and Steamfitter and `crucible-icon-<app>` in Blueprint, CITE and Gallery (D1).

Rules:

1. **[Target]** Material Design Icons only, as `<mat-icon fontIcon="mdi-...">`. Remove Font Awesome (the dependency and the one Caster usage) and the PNG menu icons. Whether to move from the `@mdi/font` font to `@mdi/js` is open (D2). Until then every app uses one `@mdi/font` 7.x version.
2. **[Target]** Icon sizes: 24px (`mdi-24px`) for toolbar and action icons, 18px for icons inside text or chips, nothing else. The admin-tables spec fixes row action icons at 24px.
3. **[Target]** A decorative icon next to text is `aria-hidden="true"`. An icon that is the only content of a control gets its name from the control's `aria-label`, never from the icon. An icon that carries a state (a check, a warning) has `role="img"`, an `aria-label` and an explicit `aria-hidden="false"`, plus a tooltip: Material (checked in 21.2.14) sets `aria-hidden="true"` on every `mat-icon` unless the host element has its own `aria-hidden` attribute, so a label alone leaves the state hidden from screen readers.
4. **[Target]** A tooltip on an icon button is `matTooltip`, with the same text as the `aria-label`. Native `title` is not used: it is not shown on keyboard focus.

**Convention table.** **[Existing]** where the apps already agree; **[Target]** where a cell says "Target".

| Meaning | Icon | Tooltip and `aria-label` | Notes |
|---|---|---|---|
| Add | `mdi-plus-circle` | "Add <Thing>" (Caster: "Add New <Thing>") | Existing: Caster, Blueprint, CITE, Gallery, Alloy, Steamfitter, Player. Target: one wording, "Add <Thing>" (D3) |
| Edit / Rename | `mdi-square-edit-outline` | "Edit <name>" / "Rename <name>" | Existing everywhere |
| Delete | `mdi-trash-can-outline` | "Delete <name>" | Existing everywhere; last in a row |
| Upload / Import | `mdi-upload` | "Upload <Thing>" | Existing Blueprint, CITE, Gallery |
| Download / Export | `mdi-download` | "Download <name>" | Existing Blueprint, CITE, Gallery |
| Open in a new tab | `mdi-open-in-new` | "Open <name> in a new tab" | Existing Caster (a real link) |
| Clear search | `mdi-close-circle-outline` | "Clear Search" | Existing everywhere |
| Add a member | `mdi-plus-circle-outline` | "Add <name>" | Existing membership lists |
| Remove a member | `mdi-minus-circle-outline` | "Remove <name>" | Existing membership lists |
| Information | `mdi-information` | "About <thing>", opens on focus | Existing Caster, Player, Steamfitter roles pages |
| Copy an ID to the clipboard | `mdi-content-copy` | "Copy ID of <name>" | See below |
| Duplicate a record | `mdi-content-duplicate` | "Duplicate <name>" | **Target**: see below |
| Back to a list | `mdi-keyboard-return` | "Back to <list>" | Existing Caster |
| Section in the Administration sidebar | `mdi-menu-right` (arrow) | the section name | Existing five apps; Blueprint `mdi-chevron-right`; Player none |

**Copy to the clipboard (CRU-2895: title only).** **[Existing]** The ID-copy button uses `mdi-content-copy` in Alloy, CITE, Gallery, Steamfitter, Player, Blueprint and Caster (51 template uses in the apps I read), with a native `title` such as `Copy:  <id>` and a snackbar "Copied to clipboard" with a "Dismiss" action; Player's team copy says "Copied Team Id to clipboard" with no action and a 2 second duration. **The collision:** Gallery Collections and CITE Evaluations use the same `mdi-content-copy` icon for "make a copy of this record" (tooltip "Copy <name>"). **[Target]** ID copy keeps `mdi-content-copy`, tooltip and `aria-label` "Copy ID of <name>", success message "Copied to clipboard" with "Dismiss". Cloning a record uses `mdi-content-duplicate` (present in `@mdi/font` 7.4.47) and "Duplicate <name>" (D4). A copied value that is not an ID says what it is ("Copied link").

**Delete (CRU-2995).** The ticket reports that Player shows a trash button that Caster does not, for content-developer roles, and says Caster should match. I could not map it to a specific Caster page from the ticket. **[Target]** The same operation has the same row action (`mdi-trash-can-outline`, last in the row) in every app that offers it, and a role that may not use it sees it disabled with the reason, not absent in one app and present in another (admin-tables.md section 8, D1 there).

**Users, Groups and Roles icons.** Defined in [admin-tables.md](admin-tables.md) section 9.

---

## 3. Loading and progress

**What the apps do.**

- **[Existing]** Every app uses indeterminate `mat-progress-spinner`; Blueprint also uses `mat-progress-bar` in five templates and Player in one. Where `diameter` is not set the spinner is Material's 100px default (most Alloy, CITE, Gallery, Steamfitter and Player lists); Caster's standard pages use `diameter="48"`; Blueprint uses 60 in three places.
- **[Existing]** Placement differs: below the table in the table container (Caster standard pages); in an outlined `mat-card` below the table (Alloy Users, Blueprint Units); in place of the table (Gallery Collections; seven Gallery and four CITE templates test `@if (!isLoading)`); inline beside "Loading..." text in a card (Caster Hypervisors).
- **[Existing]** Caster's standard pages never show the empty message while loading, but rows already in the store and the spinner can be visible at once. Alloy and Blueprint lists show the spinner card and the table together.

CRU-2889 (spinner and progress bar location) and CRU-2900 (don't show a spinner and results at the same time) have titles only.

Rules:

1. **[Target]** Placement. A spinner for a region is **centered in that region**, in the space the results will occupy, not below the content and not in a card. A page or tab that is loading as a whole shows it centered in the content area. A button that starts a request shows progress inside itself (the Caster Hypervisors Refresh button swaps its icon for an 18px spinner) and is disabled.
2. **[Target]** Size. 48px for a region; 18px inside a button or a one-line status. No other sizes; never the 100px default.
3. **[Target]** **Never a spinner and results together.** First load: only the spinner. No rows, no empty message, no error. Refresh with data already shown: keep the data and show progress on the control that started it (a spinning refresh icon or a thin `mat-progress-bar` at the top of the region, not a second spinner over the table). The empty state appears only after a successful load that returned nothing.
4. **[Target]** Empty, loading and error are three different states with three different messages (admin-tables section 13). A failed load is never shown as empty.
5. **[Target]** Progress with a known amount (an upload, an import with a count) uses a determinate `mat-progress-bar` with a text figure ("3 of 12").
6. **[Target]** Announce it. The region gets `aria-busy="true"` while loading, and a visually hidden `role="status"` element says "Loading <Things>". A spinner alone is silent to a screen reader.
7. **[Target]** A spinner that stays longer than a few seconds adds text ("Still loading...") so the user is not left guessing.

---

## 4. Error and success messages

**What the apps do today (verified).**

- **[Existing]** Every app registers a global `ErrorHandler` that shows a **system message dialog** for any unhandled error (`error.service.ts` in each app; Caster `sei-cwd-common/cwd-error/error.service.ts`). The title is the HTTP `statusText`; the body is the API's `error.title`. Blueprint adds `error.detail` and the validation errors; Caster builds HTML from the problem details and the validation errors.
- **[Existing]** Fallbacks put framework text in front of users: when the response has no problem details, the apps show `err.message`, which for an `HttpErrorResponse` is Angular's `Http failure response for <url>: <status> <text>` (the handlers themselves test for that prefix). Caster's handler prints `apiError.message` (the same string) for a response without validation errors and, for a non-HTTP error, `error.message` plus `error.stack` in the dialog. Each handler special-cases the unreachable API (`0 Unknown Error`) and says so in words ("The API could not be reached." in Blueprint).
- **[Existing]** Snackbars: Caster's standard pages use `snackBar.open(message, 'Dismiss', { duration: 5000, verticalPosition: 'top', horizontalPosition: 'center' })` for success and failure (`admin-projects.component.ts`, `vlan-feedback.service.ts`); Gallery uses `'OK'` with 5000; Alloy and Player use 2000 for copy confirmations. Blueprint has one snackbar user.
- **[Existing]** The Caster standard pages build failure text from `problemText(error, fallback)`: the problem's `title` and `detail` joined by `": "`, else the error message, else a fallback such as `Couldn't delete <name>`. Successes are past tense and name the object: `Added Project <name>`.
- **[Existing]** Material's `MatSnackBar` default `politeness` is `polite` (`snack-bar.mjs`), so messages are announced politely.

CRU-3100 ("Standardize error message display across the apps") says only that some apps have started to use snackbar notifications.

Rules:

1. **[Target]** **Where a message goes.** The outcome of an action the user just took, success or failure, is a **snackbar**. A **dialog** is only for an error the user cannot continue past (an unreachable API, an expired session) or one that needs a decision. An error about **one field** is `<mat-error>` on that field. An error about a **form** that is open is shown in the form (`crucible-dialog` `errorMessage`, `role="alert"`), not in a snackbar behind the backdrop (see modals.md, "Errors & status messages").
2. **[Target]** **Wording.** Success: past tense, names the object: "Added Project Range", "Deleted Range". Failure: "Couldn't <verb> <object>" then the reason from the API: "Couldn't delete Range: Conflict: Has Resources". Not "An error occurred" and not "Error".
3. **[Target]** **API problem details.** Show the `title` and the `detail` only for a 4xx response (validation, conflict, not found, forbidden), where the API's text is written for people; list a validation problem's messages under each field's name. For a 5xx or any unexpected failure show the generic message in rule 4 and neither `title` nor `detail`: outside production, Caster and Blueprint put `exception.Message` in the `title` of a 500, which can contain an internal URL, and diagnostics in `detail` (Caster uses `exception.ToString()`, Blueprint and others return the stack trace); production uses `exception.Message`, which is not written for users. The UI does not rewrite a 4xx text and does not append a status code. **[Target, for the APIs]** `title` and `detail` for an unexpected failure never carry exception text, in any environment.
4. **[Target]** **Never shown to a user:** a stack trace, a request URL, the framework's `Http failure response for ...` string, a raw JSON body, an exception class name, or a GUID with no object name. Those go to the console (and Aspire telemetry). When there is no usable message, say "Something went wrong. Try again, and tell your administrator if it keeps happening." Caster's non-HTTP branch must stop printing `error.stack`.
5. **[Target]** **Duration and dismissal.** Successes: 5 seconds, with a "Dismiss" action (the Caster value; Alloy's 2 seconds is too short to read a sentence). Failures: no auto-dismiss, with a "Dismiss" action, so a user who looks away does not lose the reason (WCAG 2.2.1). Confirmations that need no reading ("Copied to clipboard"): 2 seconds is acceptable (D5).
6. **[Target]** **Position and action label.** `top` / `center` (Caster). Action label "Dismiss" (Alloy, Blueprint, CITE, Gallery, Steamfitter, Caster use it; Gallery's `'OK'` for non-copy messages changes).
7. **[Target]** **Live regions.** Success snackbars keep the default `polite` announcement. Failure snackbars set `politeness: 'assertive'` on the snackbar config. A failure shown inside a page region (a failed load) is `role="alert"`. The snackbar action is reachable by keyboard; focus does not move to it.
8. **[Target]** **One service.** A single `NotificationService` per app (a thin wrapper over `MatSnackBar` and the problem-details formatter, as `VlanFeedbackService.report(call, success, failure)` is in Caster) so the wording and timings above live in one place. A shared version in `@cmusei/crucible-common` is a candidate (D6).

---

## 5. Forms

**What the apps do.** **[Existing]** Enter-to-submit works when a dialog is built with `<crucible-dialog [form]="form">`: the library renders one `<form>`, and its `submit` output fires from the form's `ngSubmit` (`crucible-dialog.component.ts` in `Crucible.Common.Ui`). When `form` is not bound, the primary action is a plain click and Enter does nothing. Bound `[form]` in the templates I read: CITE 10 of 11 dialogs, Gallery 9 of 10, Player 8 of 12, Alloy 2 of 5, Blueprint 1 of 32, Steamfitter 1 of 5. Blueprint's inline role editor handles Enter and Escape itself (`(keyup.enter)`, `(keyup.escape)`). CRU-2608 says the apps implement Enter inconsistently and that it is an annoyance for all users and an accessibility issue.

Rules:

1. **[Target]** Every dialog that collects input uses the form mode of `crucible-dialog` (`[form]`), so Enter submits from any field. Submit is disabled while the form is invalid or pristine or a request is in flight, exactly as modals.md defines. Multi-line text areas keep Enter for a new line.
2. **[Target]** Inline editors (a name in a cell or header) use a `<form>`: Enter saves, Escape cancels and returns focus to the control that started the edit; the Save and Cancel icon buttons stay as the pointer path.
3. **[Target]** Required fields use the `required` attribute (or `Validators.required`) so Material shows the asterisk and sets `aria-required`. A fixed legend "* required" appears once on a long form.
4. **[Target]** Validation shows in `<mat-error>` under the field, in words that name the field and the fix ("Name is required", "Enter at least 4 characters"), after the field has been touched or on submit, never on first render. An error summary is not needed for short forms.
5. **[Target]** **Disabled controls say why.** A primary action disabled by validation does not need a tooltip (the errors are visible). A control disabled by permission or state has the reason in a tooltip and "(not available)" in its `aria-label` (admin-tables section 8).
6. **[Target]** Labels are visible `mat-label`s, not placeholders alone (the Blueprint Units search field carries a code comment on this). Search fields are the one exception and carry `aria-label` (admin-tables section 4).
7. **[Target]** Form fields have no per-field density or width overrides inside a dialog; the dialog's width is set when it is opened (modals.md).

---

## 6. Typography

**What the apps do.** **[Existing]** `font-size` is written in every unit. Counts of `font-size:` declarations in each app's stylesheets: Blueprint 86 `px`, 16 `rem`, 13 named sizes (`small`, `large`), 11 `pt`, 3 `%`; CITE 52 `px`, 13 `%`, 6 named; Gallery 20 `px`, 12 `%`; Player 11 `px`, 10 `%`, 9 named; Steamfitter 14 `%`, 5 `px`; Alloy 7 named, 5 `em`, 4 `px`; Caster 22 named, 11 `px`, 6 `rem`, 4 `em`. The M3 type-scale tokens (`font: var(--mat-sys-title-medium)`) appear 36 times in Blueprint, once in Caster, and not at all in the others. CRU-2604 proposes one unit (`em` or `rem`) and a small set of sizes for different purposes.

Rules:

1. **[Target]** Text roles use the M3 type scale: `font: var(--mat-sys-<role>-<size>)` (`title-medium` for a section heading in a card or toolbar, `body-medium` for table and form text, `label-large` for buttons and tabs). The roles come from the theme and change with it.
2. **[Target]** Where a size is needed that the scale does not give, use `rem`. No `px`, `pt`, `em`, `%` or named sizes for font size, and no `!important`.
3. **[Existing]** Exemption: sizes an operator configures (the classification banner text size in `comn-header-bar` settings is applied in px from settings). They are the operator's, and they are not defaults.
4. **[Target]** The Crucible standard font is **Open Sans**. It comes from the theme and the shared font configuration (the `fonts` entry point of `@cmusei/crucible-common`; see modals.md section 4), the theme's typography font name must match a declared `@font-face` family, and a component never sets `font-family`. Remove leftover inline `font-family` declarations that name fonts that no longer exist.
5. **[Target]** Weights are the theme's. Bold for emphasis in running text is `<strong>`, not a class.
6. **[Target]** Do not set `font-size` to fix a layout; fix the layout. A user's browser font-size setting must scale the page (WCAG 1.4.4).

---

## 7. The top bar

**What the apps do (verified from each `topbar.component.html`).**

Common structure, left to right: **[Existing]** a home link with the app's SVG icon, the view title, an optional team selector, a spacer, then a user menu button with `mdi-chevron-down` whose menu holds the page links, Edit User, Logout and a dark-mode `mat-slide-toggle`. The bar's colors come from `--crucible-topbar-background` and `--crucible-topbar-text` set by `crucible-theme` (see colors.md). The classification banner above it is the shared `comn-header-bar` (the only top-of-page piece in `@cmusei/crucible-common`).

Differences found:

| Aspect | What the apps do |
|---|---|
| Home link name | `aria-label` "X home": Caster, Player, Steamfitter, Gallery; `title="Home"` only: Alloy, CITE |
| Title element | `<h1 class="view-text">` in Blueprint, a `<span>` elsewhere |
| Sidebar toggle | In the bar, first control, in Gallery (`mdi-chevron-left` / `mdi-chevron-right`); the other top bars I read have none |
| Team selector | Blueprint `ic_expand_more` (SVG) beside "Team:"; Player `ic_expand_more_white_24px` plus a Users button (`mdi-account-multiple-outline`) and team name; CITE and Gallery `mdi-chevron-down` |
| Inline style on controls | CITE sets `style="outline: none"` on the home link and menu buttons |
| Title text | Gallery capitalizes the title in the template; others display it as given |

CRU-2294 ("UI elements in top bar of crucible apps do not line up and need to be standardized") has only a title.

Rules:

1. **[Target]** Order, left to right: sidebar toggle (if the app has one), home link, title, team selector (if any), spacer, app-specific controls (Player: Users), user menu. The bar's height, vertical alignment and the spacing between items are one set of values in the shared theme, not per-app margins (the alignment problem in CRU-2294).
2. **[Target]** The home link is `<a mat-icon-button [routerLink]="['/']" aria-label="<App> home">`; the bar title is the page's `<h1>`, with the document `<title>` kept in step.
3. **[Target]** The team selector and the user menu both use `mdi-chevron-down` and are `<button mat-button>` with `aria-haspopup="menu"` and a visible name (the team name, the user name), not an icon alone.
4. **[Target]** No inline styles on top-bar controls; no `outline: none` (WCAG 2.4.7). Focus is visible on a colored background, so the focus ring uses `--crucible-topbar-text`.
5. **[Target]** What lives in the top bar: navigation context (home, title, team), the user menu, and the theme toggle inside the user menu. Page actions never live in the top bar.
6. **[Existing]** The classification banner is `comn-header-bar`; apps do not build their own. The Gameboard UI depends on `@cmusei/crucible-common` `^0.8.1`; the TopoMojo UI's `package.json` on `main` does not list it.
7. A shared top-bar component (the structure above with slots for the title and app controls) is not in the library today (D7).

---

## 8. Permission descriptions

The tooltip next to each permission on a Roles page comes from the API, not from a map in the UI, and the info button is a labelled, focusable `mat-icon-button`. The rules and the evidence (CRU-2649) are in [admin-tables.md](admin-tables.md) section 9. Other places that explain a permission (a disabled button's tooltip) use the same wording from the same source where one exists.

---

## 9. Accessibility (Section 508 / WCAG 2.1 AA): summary

- Icons: names come from the control, decorative icons are hidden, state icons are labelled (section 2, rule 3).
- Loading: `aria-busy` and a status message (section 3, rule 6).
- Messages: polite for success, assertive for failure; failures are not auto-dismissed; the action is keyboard reachable (section 4, rules 5 and 7).
- Forms: Enter submits; errors are in `<mat-error>` and named; labels are visible (section 5).
- Typography: relative units that respect the user's font size (section 6, rule 6).
- Top bar: visible focus on the colored bar, named controls (section 7, rules 3 and 4).
- Verify with axe or Lighthouse and a keyboard-only pass, as in modals.md section 9.

---

## 10. How to adopt, and review checklist

**How to adopt.** Take one concern at a time per PR (icons, then loading, then messages), not one page at a time. Start with the changes that remove a wrong thing (the stack trace in Caster's dialog, a PNG menu icon, `outline: none`), then the ones that add a pattern. Add a unit spec for the behavior you changed. Point the repo's `AGENTS.md` / `CLAUDE.md` at `design-specs`.

**Checklist.**

- [ ] Icons are `mat-icon fontIcon="mdi-..."` only; no Font Awesome class, no PNG icon; icon buttons have `aria-label` and `matTooltip` (no `title`).
- [ ] Copy-ID uses `mdi-content-copy` with "Copy ID of <name>"; cloning uses `mdi-content-duplicate`.
- [ ] Spinners are 48px centered in their region (18px in a button); no 100px defaults.
- [ ] An initial or blocking load shows the spinner and no rows, empty message or error; a refresh with rows shown keeps them with a non-blocking indicator; empty, loading and error are distinct; `aria-busy` and a status message are set.
- [ ] Outcomes use a snackbar with "Dismiss"; failures do not auto-dismiss and are assertive; wording names the object.
- [ ] No stack trace, URL, `Http failure response` text or raw JSON is shown anywhere.
- [ ] Dialogs that collect input bind `[form]`; Enter submits; inline editors save on Enter and cancel on Escape.
- [ ] Required fields use `required`; errors are `<mat-error>` text naming field and fix.
- [ ] Font sizes use the M3 type tokens or `rem`; no `px`/`pt`/`em`/`%`/named sizes, no `!important`.
- [ ] The top bar follows the order in section 7; the home link has an accessible name; no `outline: none`.
- [ ] Permission descriptions come from the API.

---

## 11. References: code this spec was derived from

Paths are `repo/path` as of November 2026.

- Icons: `alloy.ui/src/styles/styles.scss`, `blueprint.ui/src/styles/styles.scss`, `caster.ui/src/styles/styles.scss`, `player.ui/src/styles/styles.scss`; `alloy.ui/src/app/app.component.ts` (icon registry); each app's `package.json`; `caster.ui/src/app/project/component/project-details/project-navigation-container/project-navigation-container.component.html`; `player.ui/src/app/components/admin-app/admin-app.component.{html,ts}`; the copy buttons in `*/admin*/**/*-list.component.html`, `gallery.ui/.../admin-collections/`, `cite.ui/.../admin-evaluations/`; `topomojo-ui/package.json`, `gameboard-ui/package.json`.
- Loading: `caster.ui/src/app/admin-app/component/admin-projects/`, `admin-workspaces/active-runs/`, `admin-hypervisors/`; `gallery.ui/.../admin-collections/`; `alloy.ui/.../admin-users/admin-user-list/`; `blueprint.ui/.../admin-units/`.
- Messages: each app's `error.service.ts` (`alloy.ui/src/app/shared/error/`, `blueprint.ui/src/app/services/error/`, `cite.ui`, `gallery.ui`, `player.ui`, `steamfitter.ui` `src/app/services/error/`), `caster.ui/src/app/sei-cwd-common/cwd-error/error.service.ts`, `caster.ui/src/app/admin-app/component/admin-projects/admin-projects.component.ts` (`notify`, `problemText`), `admin-vlans/vlan-feedback.service.ts`, `alloy.ui/.../event-template-edit/`, `player.ui/.../shared/top-bar/topbar.component.ts`; `@angular/material` 21.2.14 `snack-bar.mjs`.
- Forms: `Crucible.Common.Ui/projects/@crucible-common/src/lib/crucible-dialog/components/crucible-dialog/crucible-dialog.component.ts`; `blueprint.ui/.../admin-roles/`; `<crucible-dialog>` templates in each app.
- Typography: `font-size` declarations in each app's `*.scss`; `Crucible.Common.Ui/.../crucible-theme/README.md`; `Crucible.Common.Ui/projects/@crucible-common/header-bar/`.
- Top bar: `*/src/app/components/shared/top-bar/topbar.component.html` in Alloy, Blueprint, CITE, Gallery, Player, Steamfitter; `caster.ui/src/app/shared/components/top-bar/topbar.component.html`.
- Tickets: CRU-2605, CRU-2895, CRU-2995, CRU-2889, CRU-2900, CRU-3100, CRU-2608, CRU-2604, CRU-2294, CRU-2649, CRU-3113, CRU-2827, CRU-2615.

---

## 12. Decisions for review

- **D1. Logo icon names.** Alloy, Caster, Player, Steamfitter register `ic_crucible_<app>`; Blueprint, CITE and Gallery register `crucible-icon-<app>`. Proposal: one scheme, `crucible-icon-<app>` (the form the newer apps use), shipped by the shared library.
- **D2. `@mdi/font` vs `@mdi/js`.** CRU-2605 raises tree-shaking. This spec requires only one set and one version. Whether to move to `@mdi/js` (smaller, needs an icon registry) or Material Symbols is open.
- **D3. Add wording.** "Add New <Thing>" (Caster) vs "Add <Thing>" (Blueprint, CITE, Gallery, Steamfitter). Proposed "Add <Thing>".
- **D4. Duplicate icon.** `mdi-content-duplicate` is proposed; no app uses it. The alternative is to keep `mdi-content-copy` for cloning and change the ID-copy icon (`mdi-identifier`).
- **D5. Message durations.** 5 seconds with Dismiss for success; failures persistent. Alloy and Player use 2 seconds for copy confirmations; Caster and Gallery 5 seconds for everything. The failure rule is new.
- **D6. Shared notification service.** A wrapper over `MatSnackBar` and the problem-details formatter is proposed for `@cmusei/crucible-common`; none exists.
- **D7. Shared top bar and the sidebar toggle.** A shared top-bar component is not in the library today. Only Gallery puts the sidebar toggle in the bar; the order rule puts it first where an app has one.
- **D8. Spinner placement and size.** Centered in the region at 48px (Caster's standard pages use 48 and centered below the table; the others use cards or the 100px default).
- **D9. Type tokens.** M3 type-scale tokens plus `rem`. Blueprint is the only app already using the tokens widely.
- **D10. Enter submits in every dialog.** This requires moving the non-`[form]` dialogs (most of Blueprint and Steamfitter) to the form mode; the cost is per dialog.
