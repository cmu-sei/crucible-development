# Crucible Design Specification: UI Conventions

**Applies to:** All Crucible Angular applications that use Angular Material · **Stack assumption:** **Angular 21 + Material Design 3 (M3)**

This spec collects the cross-cutting conventions that are neither tables nor modals: icons, loading indicators, data loading, messages, forms, typography and the top bar. It defers to the other specs and does not restate them:

- Modals and dialogs: [modals.md](modals.md).
- Colors, light and dark mode, the top-bar color: [colors.md](colors.md).
- Admin pages, tables, search and pagination: [admin-tables.md](admin-tables.md).
- Dates and times: [dates.md](dates.md).
- Permission gating and permission descriptions: [permissions.md](permissions.md).

**Accessibility is a requirement.** Crucible is used in U.S. federal and DoD training contexts, so everything here must satisfy **Section 508** (which incorporates WCAG 2.0 Level A and AA) and **WCAG 2.1 Level AA**, which Crucible requires in addition. Section 9 collects the requirements.

---

## 1. Principles

1. **One mark, one meaning.** An icon means one thing in every app; a thing is shown by one icon in every app.
2. **One icon set.** Icons come from Material Design Icons. No second icon font, no PNG icons in the UI.
3. **Show progress or show results, never both.** An initial or blocking load replaces the empty and results states; it does not sit next to them. A refresh of data already shown is the exception: the rows stay, with a non-blocking indicator on the control that started it (section 3, rule 3).
4. **Say what happened, in words a user can act on.** Messages name the object, say what went wrong and what to do. They never show a stack trace, a URL or a status line from the framework.
5. **Enter submits a form; Escape cancels it.** The same keys in every form.
6. **Type comes from the theme.** Sizes come from the M3 type scale and relative units, not scattered pixel values.
7. **The shared library owns what is shared.** Dialogs, the classification banner and the theme come from `@cmusei/crucible-common`. The icon scheme, notification service and top bar below are specified as contracts so they can move into the library unchanged (section 10).

---

## 2. Icons

1. Material Design Icons only, as `<mat-icon fontIcon="mdi-...">`, from one `@mdi/font` 7.x version in every app. No Font Awesome (dependency or class), no PNG menu icons.
2. Icon sizes: 24px (`mdi-24px`) for toolbar and action icons, 18px for icons inside text or chips, nothing else. Row action icons are 24px ([admin-tables.md](admin-tables.md) section 7).
3. A decorative icon next to text is `aria-hidden="true"`. An icon that is the only content of a control gets its name from the control's `aria-label`, never from the icon. An icon that carries a state (a check, a warning) has `role="img"`, an `aria-label` and an explicit `aria-hidden="false"`, plus a tooltip: Material sets `aria-hidden="true"` on every `mat-icon` unless the host has its own `aria-hidden` attribute, so a label alone leaves the state hidden from screen readers.
4. A tooltip on an enabled icon button is `matTooltip`, with the same text as the `aria-label` (a disabled control's tooltip carries the reason instead: [permissions.md](permissions.md)). Native `title` is not used: it is not shown on keyboard focus.
5. App logos are registered SVG icons named `crucible-icon-<app>`.

**Convention table.**

| Meaning | Icon | Tooltip and `aria-label` |
|---|---|---|
| Add | `mdi-plus-circle` | "Add &lt;Thing&gt;" |
| Edit / Rename | `mdi-square-edit-outline` | "Edit &lt;name&gt;" / "Rename &lt;name&gt;" |
| Delete | `mdi-trash-can-outline` | "Delete &lt;name&gt;" (last in a row) |
| Upload / Import | `mdi-upload` | "Upload &lt;Thing&gt;" |
| Download / Export | `mdi-download` | "Download &lt;name&gt;" |
| Open in a new tab | `mdi-open-in-new` | "Open &lt;name&gt; in a new tab" (a real link) |
| Clear search | `mdi-close-circle-outline` | "Clear Search" |
| Add a member | `mdi-plus-circle-outline` | "Add &lt;name&gt;" |
| Remove a member | `mdi-minus-circle-outline` | "Remove &lt;name&gt;" |
| Information | `mdi-information` | "About &lt;thing&gt;", opens on focus |
| Copy an ID to the clipboard | `mdi-content-copy` | "Copy ID of &lt;name&gt;" |
| Duplicate a record | `mdi-content-duplicate` | "Duplicate &lt;name&gt;" |
| Back to a list | `mdi-keyboard-return` | "Back to &lt;list&gt;" |
| Section in the Administration sidebar | `mdi-menu-right` | the section name |

**Copy to the clipboard.** The ID-copy button keeps `mdi-content-copy`, with tooltip and `aria-label` "Copy ID of &lt;name&gt;" and the success message "Copied to clipboard" with a "Dismiss" action. Cloning a record uses `mdi-content-duplicate` and "Duplicate &lt;name&gt;", so the two actions never share an icon. A copied value that is not an ID says what it is ("Copied link").

**Delete.** The same operation has the same row action (`mdi-trash-can-outline`, last in the row) in every app that offers it. A role that may not use it sees it disabled with the reason, not absent in one app and present in another ([permissions.md](permissions.md)).

**Users, Groups and Roles icons** are defined in [admin-tables.md](admin-tables.md) section 8.

---

## 3. Loading and progress

1. **Placement.** A spinner for a region is **centered in that region**, in the space the results will occupy, not below the content and not in a card. A page or tab that is loading as a whole shows it centered in the content area. A button that starts a request shows progress inside itself (its icon swaps for an 18px spinner) and is disabled.
2. **Size.** 48px for a region; 18px inside a button or a one-line status. No other sizes; never the 100px default.
3. **Never a spinner and results together.** First load: only the spinner. No rows, no empty message, no error. Refresh with data already shown: keep the data and show progress on the control that started it (a spinning refresh icon or a thin `mat-progress-bar` at the top of the region, not a second spinner over the table). The empty state appears only after a successful load that returned nothing.
4. Empty, loading and error are three different states with three different messages ([admin-tables.md](admin-tables.md) section 12). A failed load is never shown as empty.
5. Progress with a known amount (an upload, an import with a count) uses a determinate `mat-progress-bar` with a text figure ("3 of 12").
6. **Announce it.** The region gets `aria-busy="true"` while loading, and a visually hidden `role="status"` element says "Loading &lt;Things&gt;". A spinner alone is silent to a screen reader.
7. A spinner that stays longer than a few seconds adds text ("Still loading...") so the user is not left guessing.

---

## 4. Loading data

1. **A list loads a summary.** A page fills a list or table from the summary the list call returns and does not fetch every row's full detail. Detail loads when a row is opened.
2. **A page renders only what the list call returns.** A page never depends on a field the list call does not return. When a column needs a value the list call does not provide, the page asks for it through the list call's existing option, if there is one; it does not load every row's full detail to derive it.
3. **Specs use realistic data.** The page's spec asserts the arguments of the list call and renders a row from a response shaped like the real API's, not from a hand-built object that already has the field. Otherwise a page can read a field the list never returns and its specs still pass.

---

## 5. Error and success messages

1. **Where a message goes.** The outcome of an action the user just took, success or failure, is a **snackbar**. A **dialog** is only for an error the user cannot continue past (an unreachable API, an expired session) or one that needs a decision. An error about **one field** is `<mat-error>` on that field. An error about a **form** that is open is shown in the form (`crucible-dialog` `errorMessage`, `role="alert"`), not in a snackbar behind the backdrop (see modals.md, "Errors & status messages").
2. **Wording.** Success: past tense, names the object: "Added Project Range", "Deleted Range". Failure: "Couldn't &lt;verb&gt; &lt;object&gt;" then the reason from the API: "Couldn't delete Range: Conflict: Has Resources". Not "An error occurred" and not "Error".
3. **Problem details.** Show the `title` and the `detail` only for a 4xx response (validation, conflict, not found, forbidden), where the API's text is written for people; list a validation problem's messages under each field's name. For a 5xx or any unexpected failure show the generic message in rule 4 and neither `title` nor `detail`. The UI does not rewrite a 4xx text and does not append a status code.
4. **Never shown to a user:** a stack trace, a request URL, the framework's `Http failure response for ...` string, a raw JSON body, an exception class name, or a GUID with no object name. Those go to the console (and Aspire telemetry). When there is no usable message, say "Something went wrong. Try again, and tell your administrator if it keeps happening."
5. **Duration and dismissal.** Successes: 5 seconds, with a "Dismiss" action. Failures: no auto-dismiss, with a "Dismiss" action, so a user who looks away does not lose the reason (WCAG 2.2.1). Confirmations that need no reading ("Copied to clipboard"): 2 seconds.
6. **Position and action label.** `top` / `center`. Action label "Dismiss".
7. **Live regions.** Success snackbars keep the default `polite` announcement. Failure snackbars set `politeness: 'assertive'`. A failure shown inside a page region (a failed load) is `role="alert"`. The snackbar action is reachable by keyboard; focus does not move to it.
8. **One service.** A single `NotificationService` (a thin wrapper over `MatSnackBar` and the problem-details formatter, for example `report(call, success, failure)`) holds the wording and timings above in one place. No page calls `MatSnackBar` directly.

---

## 6. Forms

1. Every dialog that collects input uses the form mode of `crucible-dialog` (`[form]`), so Enter submits from any field. Submit is disabled while the form is invalid or pristine or a request is in flight, as modals.md defines. Multi-line text areas keep Enter for a new line.
2. Inline editors (a name in a cell or header) use a `<form>`: Enter saves, Escape cancels and returns focus to the control that started the edit; the Save and Cancel icon buttons stay as the pointer path.
3. Required fields use the `required` attribute (or `Validators.required`) so Material shows the asterisk and sets `aria-required`. A fixed legend "* required" appears once on a long form.
4. Validation shows in `<mat-error>` under the field, in words that name the field and the fix ("Name is required", "Enter at least 4 characters"), after the field has been touched or on submit, never on first render. An error summary is not needed for short forms.
5. **Disabled controls say why.** A primary action disabled by validation does not need a tooltip (the errors are visible). A control disabled by permission or state has the reason in a tooltip and "(not available)" in its `aria-label` ([permissions.md](permissions.md)).
6. Labels are visible `mat-label`s, not placeholders alone. Search fields are the one exception and carry `aria-label` ([admin-tables.md](admin-tables.md) section 4).
7. Form fields have no per-field density or width overrides inside a dialog; the dialog's width is set when it is opened (modals.md).

---

## 7. Typography

1. Text roles use the M3 type scale: `font: var(--mat-sys-<role>-<size>)` (`title-medium` for a section heading in a card or toolbar, `body-medium` for table and form text, `label-large` for buttons and tabs). The roles come from the theme and change with it.
2. Where a size is needed that the scale does not give, use `rem`. No `px`, `pt`, `em`, `%` or named sizes for font size, and no `!important`.
3. Exemption: sizes an operator configures (the classification banner text size in `comn-header-bar` settings). They are the operator's, and they are not defaults.
4. The Crucible standard font is **Open Sans**. It comes from the theme and the shared font configuration (the `fonts` entry point of `@cmusei/crucible-common`; see modals.md section 4), the theme's typography font name must match a declared `@font-face` family, and a component never sets `font-family`.
5. Weights are the theme's. Bold for emphasis in running text is `<strong>`, not a class.
6. Do not set `font-size` to fix a layout; fix the layout. A user's browser font-size setting must scale the page (WCAG 1.4.4).

---

## 8. The top bar

Common structure, left to right: a home link with the app's SVG icon, the view title, an optional team selector, a spacer, then a user menu button with `mdi-chevron-down` whose menu holds the page links, Edit User, Logout and the theme switch. The bar's colors come from `--crucible-topbar-background` and `--crucible-topbar-text` set by `crucible-theme` ([colors.md](colors.md)). The classification banner above it is the shared `comn-header-bar`; apps do not build their own.

1. Order, left to right: sidebar toggle (if the app has one), home link, title, team selector (if any), spacer, app-specific controls, user menu. The bar's height, vertical alignment and the spacing between items are one set of values in the shared theme, not per-app margins.
2. The home link is `<a mat-icon-button [routerLink]="['/']" aria-label="<App> home">`; the bar title is the page's `<h1>`, with the document `<title>` kept in step.
3. The team selector and the user menu both use `mdi-chevron-down` and are `<button mat-button>` with `aria-haspopup="menu"` and a visible name (the team name, the user name), not an icon alone.
4. No inline styles on top-bar controls; no `outline: none` (WCAG 2.4.7). Focus is visible on a colored background, so the focus ring uses `--crucible-topbar-text`.
5. The top bar holds navigation context (home, title, team), the user menu, and the theme switch. The theme switch is a menu item ("Switch to dark mode" / "Switch to light mode"), not a slide toggle: Material menus support only `mat-menu-item` controls for arrow-key navigation, and a toggle inside one is skipped. Page actions never live in the top bar.

---

## 9. Accessibility (Section 508 / WCAG 2.1 AA): summary

- Icons: names come from the control, decorative icons are hidden, state icons are labelled (section 2, rule 3).
- Loading: `aria-busy` and a status message (section 3, rule 6).
- Messages: polite for success, assertive for failure; failures are not auto-dismissed; the action is keyboard reachable (section 5, rules 5 and 7).
- Forms: Enter submits; errors are in `<mat-error>` and named; labels are visible (section 6).
- Typography: relative units that respect the user's font size (section 7, rule 6).
- Top bar: visible focus on the colored bar, named controls (section 8, rules 3 and 4).
- Verify with axe or Lighthouse and a keyboard-only pass, as in modals.md section 9.

---

## 10. Shared components

The notification service (section 5, rule 8), the top bar (section 8) and the logo icon names (section 2, rule 5) are specified here as one contract so they can move into `@cmusei/crucible-common` unchanged. Until the library provides them, each app implements exactly this contract and does not keep a private variant. Once the library provides one, apps replace their copy with it. The date formatter is specified in [dates.md](dates.md) and the table toolbar in [admin-tables.md](admin-tables.md) section 14.

---

## 11. How to adopt, and review checklist

**How to adopt.** Take one concern at a time per PR (icons, then loading, then messages), not one page at a time. Start with the changes that remove a wrong thing (a stack trace in an error dialog, a PNG menu icon, `outline: none`), then the ones that add a pattern. Add a unit spec for the behavior you changed.

**Checklist.**

- [ ] Icons are `mat-icon fontIcon="mdi-..."` only; no Font Awesome class, no PNG icon; icon buttons have `aria-label` and `matTooltip` (no `title`).
- [ ] Copy-ID uses `mdi-content-copy` with "Copy ID of &lt;name&gt;"; cloning uses `mdi-content-duplicate`.
- [ ] Spinners are 48px centered in their region (18px in a button); no 100px defaults.
- [ ] An initial or blocking load shows the spinner and no rows, empty message or error; a refresh with rows shown keeps them with a non-blocking indicator; empty, loading and error are distinct; `aria-busy` and a status message are set.
- [ ] List calls return summaries and every column's value; detail loads on demand.
- [ ] Outcomes use a snackbar with "Dismiss"; failures do not auto-dismiss and are assertive; wording names the object.
- [ ] No stack trace, URL, `Http failure response` text or raw JSON is shown anywhere.
- [ ] Dialogs that collect input bind `[form]`; Enter submits; inline editors save on Enter and cancel on Escape.
- [ ] Required fields use `required`; errors are `<mat-error>` text naming field and fix.
- [ ] Font sizes use the M3 type tokens or `rem`; no `px`/`pt`/`em`/`%`/named sizes, no `!important`.
- [ ] The top bar follows the order in section 8; the home link has an accessible name; no `outline: none`.
