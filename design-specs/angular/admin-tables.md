# Crucible Design Specification: Admin Pages & Tables

**Applies to:** The Administration area and every list or membership page built on `mat-table` in the Crucible Angular applications · **Stack assumption:** **Angular 21 + Material Design 3 (M3)**

This spec uses Angular Material's system tokens (`--mat-sys-*`), `mat-table`, `mat-sort`, `mat-paginator` and `mat-form-field`. It does not apply to UIs that do not use Angular Material. It defers to the other specs and does not restate them:

- Modals and dialogs, including confirm dialogs: [modals.md](modals.md).
- Colors, light and dark mode, the top-bar color: [colors.md](colors.md).
- Icons, loading indicators, messages, forms, typography, the top bar and data loading: [ui-conventions.md](ui-conventions.md).
- Dates and times: [dates.md](dates.md).
- Permission gating and permission descriptions: [permissions.md](permissions.md).

The aim is one contract: every admin page has the same toolbar, action order, empty states and keyboard behavior.

**Accessibility is a requirement.** Crucible is used in U.S. federal and DoD training contexts. Every admin page must satisfy **Section 508** (which incorporates **WCAG 2.1 Level AA**). Section 13 is normative.

---

## 1. Principles

1. **One page, one shape.** Every admin list is: header, one toolbar row, one table that fills the rest of the page. A user who has seen one admin page can operate every other.
2. **Material's table is the design.** Use `mat-table` with `matSort` and `mat-paginator` as shipped. Do not hand-roll `div` tables or restyle cells. Density is Material's default.
3. **Say why, don't hide.** An action the user may not perform is shown disabled with the reason ([permissions.md](permissions.md)).
4. **Everything a mouse can do, a keyboard can do.** Expanding a row, copying an ID, clearing a search and every row action are real buttons in the tab order.
5. **Show what you filter.** Search matches the text the user sees, including formatted dates.
6. **Do not load what is not shown.** A list loads the summary the table needs; detail loads when a row is opened ([ui-conventions.md](ui-conventions.md) section 4).
7. **Use shared components.** Dialogs come from `crucible-dialog`, colors from `crucible-theme`. The table toolbar follows section 14.

---

## 2. Page structure and header

The Administration area is a `mat-sidenav-container`:

- **Sidebar header.** A `mat-toolbar` with the app icon and the text "Administration". It is the way out: its title is "Exit Administration" and it links to `/` with `routerLink` (not a click handler), so middle-click and "open in new tab" work.
- **Sidebar items.** One item per section: a leading section icon, the section name, a trailing `mdi-menu-right` arrow. An item appears only when the user holds the view permission for that section.
- **Top bar.** Shows the current section name as the page title.
- **Content.** Exactly one section component is shown (`.admin-content`).

Rules:

1. The page title is the section name in the top bar and the sidebar item. The page body does not repeat it as a heading; the toolbar icon (section 3) carries the identity.
2. The section icon in the sidebar item and the icon in the toolbar row are the same icon.
3. Sections the user cannot view are not rendered in the sidebar or the content area.
4. The sidebar arrow is `mdi-menu-right` in every app.
5. The page host is a flex column filling the content area (`:host { display: flex; flex-direction: column; flex: 1; min-height: 0; }`). The page adds no outer scrollbar; only `.table-container` scrolls (section 6).
6. Sidebar order groups by purpose: the app's own data sections first, then Users, Roles, Groups.

---

## 3. The toolbar row

One flex row above the table: `display: flex; align-items: center; gap: 8px; flex-shrink: 0; padding-right: 16px`.

Order, left to right:

1. **Section icon**: a 24px `mat-icon` colored `var(--mat-sys-primary)`, with `role="img"`, an `aria-label` naming the section, and a tooltip that explains the list in one sentence ("Every Project in Caster. Click a Project to see and change its memberships.").
2. **Search field** (section 4), 300px wide.
3. **Paginator** (section 5), immediately after the search field. Paginating from the top of the page saves vertical space.
4. **Spacer**, then **page-level content**: status text or a control that is about the whole page, not one row.

Rules:

1. Page-level buttons that add, upload or download rows do not live in the toolbar row. They live in the header cell of the actions column (section 7). No buttons in the toolbar row.
2. The paginator is transparent (`background: transparent`) and does not shrink.
3. Membership lists (section 11) use a `mat-toolbar` with two rows instead: a title row, then a search-and-paginator row.

---

## 4. Search fields

Every admin list has exactly one search field per table.

1. **No leading search icon.** The section icon (section 3) sits to the left of the field instead.
2. **Wording.** `placeholder="Search"` and `aria-label="Search"` on every field, including Groups pages. A placeholder is not a label: the `aria-label` is required.
3. **Appearance and size.** The default `mat-form-field` appearance, 300px wide, `subscriptSizing="dynamic"` so the field does not reserve space for hint text. No density override inside the toolbar row.
4. **Clear Search.** A suffix `mat-icon-button` with `mdi-close-circle-outline`, shown only while the field has text, with `aria-label="Clear Search"` and `matTooltip="Clear Search"`. It stays in the tab order. After activation, focus returns to the input.
5. **What it matches.** A `filterPredicate` that lower-cases the filter and matches as a **substring**, case-insensitively, against the **text the user sees** (the formatted date included, so typing "EST" matches). Name the searched columns in a comment next to the `filterPredicate` and in the page's spec. Do not rely on the default `MatTableDataSource` predicate: it tests each property of the row separately, including IDs and other values the user cannot see.
6. **When it applies.** On every change, with no debounce. Bind to value changes (`ngModelChange` or `valueChanges`), not `keyup`, which misses paste and cut by mouse.
7. **Paginator reset.** A new search term returns the paginator to the first page (`paginator.firstPage()`). `MatTableDataSource` only clamps the page index back into range when the filtered list becomes shorter.
8. **No persistence.** A search term is local to the visit. A page opened later starts unfiltered.
9. **No results.** The empty-result state is in section 12.
10. **Nested tables and membership lists.** Each has its own field, same wording, same Clear Search, and its own paginator. Rules 2 and 4 to 7 apply to each. Field labels in a two-list page say which list they search (section 11).
11. **Screen readers.** The field is reachable by Tab and has an accessible name (rule 2). Changes to the result count are announced by the paginator's `role="status"` range label (Material provides this).

---

## 5. Pagination

1. Lists page in the browser: `mat-paginator` slices the list through `MatTableDataSource`.
2. Default page size is **20** with options `[5, 10, 15, 20, 25, 50, 100, 200]` for page-level tables. Membership lists and any list nested in an expanded row use default **10** with options `[10, 25, 50, 100]`.
3. Page size and page index are not persisted. Returning to a page starts at page 1 of the default size.
4. The paginator is in the toolbar row (section 3).
5. Every paginator has an `aria-label` naming its list ("Page of Projects"). Two paginators on one page never share a label.
6. A nested table in a row detail has its own paginator, search and sort. Nested paginators are never shared with the parent.
7. What a list call returns, and when detail loads, is in [ui-conventions.md](ui-conventions.md) section 4.

---

## 6. The table

**Layout.**

1. The table fills the content area: `.table-container { flex: 1; overflow: auto; padding-bottom: 20px; }` and `table { width: 100%; }`. The header row is sticky (`*matHeaderRowDef="columns; sticky: true"`) on page-level tables, so headers stay visible while the container scrolls. Membership lists in cards (section 11) are not sticky.
2. Density is Material's default. Do not override `--mat-table-row-item-container-height` or the density in component styles.
3. Cells: `padding-right: 10px; vertical-align: middle`.
4. Real table markup: `<table mat-table>` with `<th mat-header-cell>` and `<td mat-cell>`. Never `<mat-header-cell>`/`<mat-cell>` elements inside a native `<table>`. The browser's table semantics then apply (section 13).

**Row outlines.** Every table, with or without row expansion, shows a divider under **every** row, the last included, using Material's default row divider. A table with `multiTemplateDataRows` does not zero the bottom border of the data row or of the detail cell (`border-bottom-width: 0`): that removes the divider under the last row.

**Columns.**

1. Column order: actions first (section 7), then identity (Name), then descriptive columns, then dates last.
2. Every column is sortable (`mat-sort-header`) except the actions column and counts that are not loaded yet. Set a default sort when the data has a natural order (`matSortActive="name" matSortDirection="asc"`). Sorting is case-insensitive for text and by underlying value for dates and numbers ([dates.md](dates.md)).
3. Header cells explain the column in a `matTooltip` ("The Project's name", "When the Project was created, in your time zone"). Never a native `title`, which is not shown on keyboard focus.
4. Column header text is Title Case nouns ("Started By", "Created"). A date column is headed by the event ("Created", "Started"), not "Date".
5. Status columns show text. Where an icon helps, it is a `mat-icon` with `role="img"`, an `aria-label`, `aria-hidden="false"` and a `matTooltip` that state the meaning. Never color or an icon alone: the text or the label carries the meaning (WCAG 1.4.1).
6. If a cell truncates text, the full text is available as a tooltip and to assistive technology. Nothing is silently cut.
7. **No value in a cell (any column).**
   - A cell with no value is **empty**: not `-`, `N/A` or `None`.
   - A value that is **not loaded yet** is different from no value: show `-` with a tooltip that says why, never a blank that looks like "none".
   - Where the absence changes what the user can do or means something happened or did not ("Never synced"; a Module with no versions cannot be inserted), write words, in muted text. Red is for errors, not for an empty value.
8. **A status and a time do not repeat each other.** A status column holds the state as an icon and a short word. A time appears once, in its own column; the status cell carries no time. Detail about a problem (an error, a warning) is a muted second line in the status cell, without a time in it. A tooltip may carry a time when it explains a state ("showing data from ...").

**Copy-ID.** Where an operator needs to paste an ID into another system (Users and Groups lists, membership lists, any list of records with IDs), the Name or ID cell has a leading `mat-icon-button` using `ngxClipboard` with `[cbContent]="id"`, icon `mdi-content-copy`, `matTooltip` and `aria-label="Copy ID of <name>"`, `(click)="$event.stopPropagation()"`, and on success `snackBar.open('Copied to clipboard', 'Dismiss')`. Cloning a record uses a different icon ([ui-conventions.md](ui-conventions.md) section 2).

---

## 7. The actions column

**Position and contents.**

1. The actions column is **first**. Its **header cell** holds the page-level actions: Add, and where they apply Import, Upload, Download. Its **row cells** hold that row's actions. Membership lists are the exception: the actions column is last, and holds one button (Add or Remove).
2. All actions are icon buttons: `mat-icon-button` with a **24px** icon in the header cell and in the row.
3. Row action order: **Open** or **View**, **Edit** (`mdi-square-edit-outline`), **Copy** (clone), **Download** (`mdi-download`), **Delete** (`mdi-trash-can-outline`) last.
4. "Open in a new tab" is a real link (`<a mat-icon-button [routerLink]="..." target="_blank">`, icon `mdi-open-in-new`, tooltip "Open <name> in a new tab"), not a button with a click handler.
5. Add is `mdi-plus-circle` with tooltip and `aria-label` "Add <Thing>"; Import/Upload `mdi-upload`; Export/Download `mdi-download`. Icon conventions are in [ui-conventions.md](ui-conventions.md) section 2.
6. An information button next to the Add button (`mdi-information`, `matTooltipShowDelay="0"`) explains something about the whole list. It is enabled, keyboard-focusable, labelled ("About groups"), and its tooltip opens on focus.

**Accessible names.** Every icon button has an `aria-label` that names the action **and the row** ("Rename Range", "Delete Range") and a matching `matTooltip`.

**Row-click tables.** In a table whose rows are clickable (expandable rows), every control inside a row calls `$event.stopPropagation()` on `click`, so the click does not also toggle the row. A button group also stops `keydown`, so Enter and Space on a button do not expand the row.

**Permissions.** An action the user may not perform is disabled with the reason ([permissions.md](permissions.md)).

---

## 8. Users, Groups and Roles pages

**Icons.** The same icons in the sidebar item **and** the toolbar row, in every app:

| Page | Icon |
|---|---|
| Users | `mdi-account-multiple` |
| Groups | `mdi-account-group` |
| Roles | `mdi-lock` |

One person is `mdi-account`, used for a single user in a cell or a menu, not for the list.

**Groups pages match the membership pages.** The Groups detail uses the same icon and title structure as the membership pages (section 11): the available list `mdi-account-group` "Users/Groups", the member list `mdi-account-multiple` "Group Members".

**Roles pages** follow the permission-description rules in [permissions.md](permissions.md) section 3.

---

## 9. Row expansion

**When to use it.** Use an expandable row when a row owns a small amount of **related, editable detail** the user opens one at a time: the members of a group, the partitions of a VLAN pool, the competencies of a framework, the members of a Project. Do not use it to show more columns of the same record (add a column or a dialog). Do not nest a third level.

**Structure.** `mat-table` with `multiTemplateDataRows`: a data row per record (`class="element-row"`, `(click)="toggle(row)"`) and a second row per record that renders an `expandedDetail` column spanning every column (`[attr.colspan]="displayedColumns.length"`), with `tr.detail-row { height: 0 }`.

Rules:

1. One row open at a time (`expandedId` is a single value).
2. The detail is rendered only while open (`@if (isExpanded(row))`), so a closed row has no focusable content, runs no queries, and a heavy child (a terminal, a member list) is created on demand.
3. Detail content stops click propagation (`(click)="$event.stopPropagation()"`) so working in the detail does not collapse it.
4. The expanded row gets a class (`expanded`) for the visual state.
5. **The expand control is a chevron button, first in the actions column.** It is a real `<button type="button">` in the tab order, activated by Enter and Space, with:
   - `aria-expanded="true|false"`, `aria-controls` pointing at the detail container's `id`, and `aria-label="Show details for <name>"` or `"Hide details for <name>"` (or one label with the state carried by `aria-expanded`).
   - Icon `mdi-chevron-down`, rotated to point up when expanded.
   - Clicking the row still toggles it (a mouse convenience); the button is the keyboard and assistive-technology path. The `tr` carries no `aria-expanded` and no `tabindex`.
   - Why a button: a visible chevron shows at a glance which rows expand and which one is open, and it gives keyboard and assistive-technology users a named control.
6. The detail container has the `id` the button points to, `role="region"`, and an `aria-label` naming it ("Range memberships").
7. Focus stays on the expand button when the row opens or closes. Opening does not move focus into the detail; Tab reaches the detail's first control after the remaining focusable controls in the data row. If a user deletes the record while its detail is open, focus moves to the next row's expand button (or the Add button if none).
8. Animation: Angular `@detailExpand` trigger, `225ms cubic-bezier(0.4, 0.0, 0.2, 1)`, between `height: '0px'` and `'*'`. Turn it off for a detail that sizes itself (a terminal), with the reason in a code comment. Respect `prefers-reduced-motion` (WCAG 2.3.3).
9. A nested table in the detail follows sections 4, 5 and 6 in full: its own search, sort and paginator. Nested expansion panels use Material's `mat-expansion-panel`, whose header is already a button with `aria-expanded`. Nested tables inside them are not themselves row-expandable except for one level.
10. The detail loads by itself: the detail component takes an ID and loads what it needs (`<cas-project-memberships [projectId]>`).

---

## 10. Master/detail and tabs

1. A page that has two peer lists of the same kind uses **tabs** (`mat-tab-group` with `matTabContent`, so tab bodies are lazy and a hidden tab loads nothing). Tabs for peers; row expansion for children (section 9); a separate routed page for a record with its own sub-pages.
2. A detail page reached from a list has a Back button: an icon button `mdi-keyboard-return` with `aria-label` and tooltip "Back to <list>". The list the user came from is restored in the same state of expansion; the search term is not restored.
3. Each tab body that holds a list has its own toolbar row.
4. A read-only inventory of cards (for example Hypervisors) with plain `<table>`s uses `<th scope="col">`. A table inside a card needs no search, sort or paginator while it is a fixed-size inventory. The card shell follows the state patterns of section 12.

---

## 11. Two-list membership pages

Membership pages show **two lists side by side** (`d-flex gap-5 justify-content-center`): the **available** list on the left, the **members** list on the right. Each list is a `mat-elevation-z8` card with a `mat-toolbar`: a title row, then a row with its own Search field and its own paginator `[10, 25, 50, 100]`, over a `mat-table` with default sort by name.

| | Left: available | Right: members |
|---|---|---|
| Title row | icon `mdi-account-group` + "Users/Groups" | icon `mdi-account-multiple` + "<Thing> Members" |
| Columns | Name (with the copy-ID button), Type if mixed users and groups, actions | Name, Type, Role (a `mat-select` when editable, text when read-only), actions |
| Row action | Add: `mdi-plus-circle-outline`, "Add <name>" | Remove: `mdi-minus-circle-outline`, "Remove <name>" |
| Empty | "Everyone is already a member" when nobody is left to add and no filter is set | "This <Thing> currently has no members" |
| Read-only | action column omitted | role shown as text; action column omitted |

Rules:

1. Adding moves the user from the left list to the right; removing moves it back. The lists are two views of the same set and update together. The signed-in user is marked with a "current user" badge in both lists.
2. Row actions need no `stopPropagation` (the rows are not clickable) and carry `aria-label="Add <name>"` / `"Remove <name>"`.
3. Each list's Search field has its own `aria-label` that names the list ("Search users", "Search members"), and each paginator has its own `aria-label` ("Page of users", "Page of members").
4. When the whole page is read-only, say so once above the lists ("You can view members but not change them") rather than a column of disabled buttons ([permissions.md](permissions.md) section 2, rule 5).
5. On narrow screens the lists stack, available above members.

---

## 12. Empty, loading and error states

**Empty.** `*matNoDataRow` renders a row spanning every column (`[attr.colspan]="displayedColumns.length"`), padded 16px, in `var(--mat-sys-on-surface-variant)`. The text is different for "nothing exists" and "nothing matches":

- Nothing exists: `There are no Projects yet`.
- Nothing matches: `No Projects match "<term>"`.

Every table has a `*matNoDataRow` with these two messages. A table is never silently blank.

**Loading.** Keep a `loading` signal that starts `true` and is cleared in `finalize`. Spinner size, placement and the "never a spinner and results together" rule are in [ui-conventions.md](ui-conventions.md) section 3. For tables: on first load show only the spinner and no empty message; on refresh with rows already shown, keep the rows and show a non-blocking indicator.

**Error.** A failed load shows an inline error state in the table area, with the reason and a **Retry** button, in addition to the snackbar. The "nothing exists" message never appears for a failed load, because it says the wrong thing. Message wording is in [ui-conventions.md](ui-conventions.md) section 5.

---

## 13. Accessibility (Section 508 / WCAG 2.1 AA): normative

**Table semantics (WCAG 1.3.1, 4.1.2).**

- Use `<table mat-table>` with `<th mat-header-cell>`/`<td mat-cell>`; Material sets the roles. Do not add `role` to a Material table.
- The table has an accessible name: `aria-label="Projects"` on the `<table>`.
- Plain `<table>` blocks use `<th scope="col">`.
- Detail rows are regions (section 9, rule 6).

**Expand control (WCAG 4.1.2, 2.1.1).** A `<button>` with `aria-expanded` and `aria-controls` (section 9, rule 5). A clickable `tr` with no keyboard path fails 2.1.1.

**Names for icon buttons (WCAG 4.1.2, 2.5.3).** Every icon button has an `aria-label` naming the action and, in a row, the record. The `matTooltip` text matches the `aria-label`. A native `title` is not a substitute.

**Sort (WCAG 4.1.2, 4.1.3).** `mat-sort-header` sets `aria-sort` on the header; keep it and do not wrap header text in a second button. Material makes no live announcement when the sort changes, so announce it: use `LiveAnnouncer` from `@angular/cdk/a11y` (or a visually hidden `aria-live="polite"` region) on `matSortChange` with "Sorted by <column>, ascending", "Sorted by <column>, descending", or "Sorting removed" when the direction is `''` (set `matSortDisableClear` to remove that state).

**Focus (WCAG 2.4.3, 2.4.7).** The order is DOM order; no positive `tabindex`; no `outline: none` on any control. Focus returns to the invoking control after a dialog closes (Material does this).

**Disabled controls (WCAG 1.4.1, 3.3.2).** Disabled with a reason, reachable by keyboard ([permissions.md](permissions.md)).

**Status and errors (WCAG 4.1.3, 3.3.1).** The paginator range label has `role="status"`. Snackbars announce politely by default. A load error uses `role="alert"` in the table area. Loading is announced with `aria-busy` on the container or an offscreen "Loading" status.

**Color and icons (WCAG 1.4.1, 1.4.11).** Meaning is never by color or icon alone. Icon contrast follows [colors.md](colors.md).

**Motion (WCAG 2.3.3).** Respect `prefers-reduced-motion` on the expand animation.

**Verify, don't assume.** Run axe or Lighthouse on each admin page, then do a keyboard-only pass (Tab, Shift-Tab, Enter, Space, Escape reach and operate search, sort, paginator, every action, expand), and a screen-reader spot check.

---

## 14. Dialogs, forms, theming and shared components

1. **Dialogs.** Add, edit and confirm flows open `crucible-dialog` and follow [modals.md](modals.md). Delete is confirmed with the shared confirm service: title "Delete Project", message "Are you sure that you want to delete <name>?", confirm text "Delete". The confirm names the record, and the destructive button's label repeats the verb.
2. **Forms in cells.** Inline edit follows [ui-conventions.md](ui-conventions.md) section 6.
3. **Theming.** Use theme tokens only (`var(--mat-sys-primary)`, `--mat-sys-on-surface-variant`, `--mat-sys-error-container`); no literal hex colors ([colors.md](colors.md)). A page-level warning is a `role="status"` block in `--mat-sys-error-container` / `--mat-sys-on-error-container`.
4. **Shared components.** The table toolbar (section icon, Search with Clear Search, paginator, spacer, page-level content), the date formatter ([dates.md](dates.md)) and the notification service ([ui-conventions.md](ui-conventions.md) section 5) are specified here as one contract so they can move into `@cmusei/crucible-common` unchanged. Until the library provides them, each app implements exactly this contract and does not keep a private variant. Once the library provides one, apps replace their copy with it.

---

## 15. Testing expectations

A page's spec, in the app's unit-test framework, covers:

1. **Structure:** the toolbar row has the section icon, Search, paginator, and nothing else but page-level content; the table has the expected columns in order.
2. **Rows:** rows render with data; the empty message for "nothing exists"; the empty message for "nothing matches".
3. **Search:** a term filters; the **match columns** are asserted (a term in a searched column matches, a term only in a hidden field does not); Clear Search resets and restores focus; the paginator returns to page 1.
4. **Sort:** each sortable header sorts; dates sort by value, not text.
5. **Dates:** see [dates.md](dates.md) section 3.
6. **Permissions:** see [permissions.md](permissions.md) section 4.
7. **Actions:** each row action calls its handler with the right row; a click on an action does not toggle the row; the confirm dialog names the record.
8. **Expansion:** one row open at a time; the detail renders only when open; Enter and Space on the expand button; `aria-expanded` and `aria-controls`.
9. **States:** the first load shows the spinner and neither the empty message nor rows; a refresh while rows are shown keeps the rows and shows a non-blocking indicator; a load failure shows the error and not "nothing exists".
10. **List calls:** the spec asserts the arguments of the list call and renders a row from a response shaped like the real API's, not from a hand-built object that already has the field ([ui-conventions.md](ui-conventions.md) section 4).
11. **Accessibility:** accessible names on icon buttons; axe passes.

End-to-end coverage for the same behaviors belongs in `crucible-tests`.

---

## 16. How to adopt

1. Read this spec and [modals.md](modals.md); pick **one** admin page and bring it fully onto the rules; ship it as its own PR.
2. Start with the safe changes: toolbar order, search field (section 4), empty and loading states, action `aria-label`s. Then the semantic changes: a keyboard-operable expand control, disabled-with-reason, dates.
3. Add or update the page's unit spec against section 15.

---

## 17. Per-page review checklist

Page and header:

- [ ] Sidebar item has the section icon, section name, `mdi-menu-right`; shown only with the view permission.
- [ ] Page host fills the content area; only `.table-container` scrolls.

Toolbar and search:

- [ ] Order: section icon (`role="img"`, labelled, tooltip), Search, paginator, spacer, page-level content only.
- [ ] Search has `placeholder="Search"`, `aria-label="Search"`, no leading icon; Clear Search has `aria-label` and `matTooltip`, shown only with text.
- [ ] Filter matches the visible text, documented columns; resets to page 1.

Table:

- [ ] `th`/`td`, `matSort` with a default sort, sticky header, `width: 100%`, accessible name.
- [ ] Divider under every row including the last.
- [ ] Paginator default 20 with `[5, 10, 15, 20, 25, 50, 100, 200]` (nested and membership: 10 and `[10, 25, 50, 100]`); paginator has an `aria-label`.
- [ ] Dates follow [dates.md](dates.md).
- [ ] Row detail and per-row data load on demand; the list call returns a summary.

Actions:

- [ ] Actions column first; header cell holds Add and bulk actions; row order Open, Edit, Copy, Download, Delete; 24px icons.
- [ ] Every icon button has `aria-label` and `matTooltip` naming the row.
- [ ] Controls in clickable rows call `stopPropagation` on click (and key events).
- [ ] No-permission actions are disabled with a reason ([permissions.md](permissions.md)).

Expansion:

- [ ] The expand control is a chevron `<button>`, first in the actions column, with `aria-expanded` and `aria-controls`; detail has `id`, `role="region"`, `aria-label`; one row open at a time; detail rendered only when open.
- [ ] Nested table has its own search, sort, paginator.

States:

- [ ] `*matNoDataRow` with "nothing exists" and "nothing matches" messages.
- [ ] Spinner only, no rows or empty message, on first load; error state with Retry on failure.

Membership pages:

- [ ] Available on the left, members on the right; titles and icons as section 11; each list has named Search and paginator.

Accessibility and tests:

- [ ] No `outline: none`; no positive `tabindex`; axe passes; keyboard-only pass done.
- [ ] Spec covers section 15.
