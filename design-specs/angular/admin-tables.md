# Crucible Design Specification: Admin Pages & Tables

**Status:** Draft for review · **Applies to:** The Administration area and every list or membership page built on `mat-table` in the Crucible Angular applications (Player, Caster, Alloy, Steamfitter, CITE, Gallery, Blueprint) · **Stack assumption:** **Angular 21 + Material Design 3 (M3)**

This spec targets **Angular 21** and **Material Design 3**: system tokens (`--mat-sys-*`), `mat-table`, `mat-sort`, `mat-paginator`, `mat-form-field`. It does not apply to the TopoMojo and Gameboard UIs, which do not use Angular Material. It does not restate other specs; it defers to them:

- Modals and dialogs, including confirm dialogs: [modals.md](modals.md).
- Colors, light and dark mode, the top-bar color: [colors.md](colors.md).
- Icons, loading indicators, messages, forms, typography and the top bar: [ui-conventions.md](ui-conventions.md).

**Repos should point their `AGENTS.md` / `CLAUDE.md` at `crucible-development/design-specs`**, so that people and coding agents working in an app read these specs before touching an admin page.

Every admin page in every Crucible app currently looks and behaves a little differently: a different toolbar, a different action order, different empty states, different keyboard behavior. This spec fixes one contract. It was derived from the code on `main` of each app (see section 19), not invented. Where the apps agree, the rule records it. Where they disagree, the rule picks the majority or the more accessible behavior, and the choice is listed in section 20 for review.

**How to read the rules.** Each rule is tagged:

- **[Existing]**: describes behavior at least one app already implements. The tag names where.
- **[Target]**: not implemented by any app yet, or implemented by only part of one. These are aspirational and are not a defect in any page today.

The reference implementation is the set of Caster Administration pages that were moved onto the "standard admin layout": Workspaces, Projects, VLANs and Hypervisors. When this spec says "the Caster standard pages" it means those.

**Accessibility is a requirement.** Crucible is used in U.S. federal and DoD training contexts. Every admin page must satisfy **Section 508** (which incorporates **WCAG 2.1 Level AA**). Section 15 is normative.

---

## 1. Principles

1. **One page, one shape.** Every admin list is: header, one toolbar row, one table that fills the rest of the page. A user who has seen one admin page can operate every other.
2. **Material's table is the design.** Use `mat-table` with `matSort` and `mat-paginator` as shipped. Do not hand-roll `div` tables or restyle cells. Density is Material's default, and no app overrides it today.
3. **Say why, don't hide.** An action the user may not perform is shown disabled with the reason, not removed. Whole pages the user may not open are not offered at all.
4. **Everything a mouse can do, a keyboard can do.** Expanding a row, copying an ID, clearing a search, and every row action can be reached and operated from the keyboard: each is a real button in the tab order, except that the expand control may instead be the row itself (section 10 rule 6, D8).
5. **Show what you filter.** Search matches the text the user sees, including formatted dates.
6. **Do not load what is not shown.** A list loads the summary the table needs; detail loads when a row is opened.
7. **Reuse the shared library; do not respecify it.** Dialogs come from `crucible-dialog`, colors from `crucible-theme`. There is no shared table, toolbar or date component yet (section 6, section 7).

---

## 2. Page structure and header

**[Existing]** (Caster `bdbfb0d`, #620; the Alloy, CITE, Gallery, Steamfitter, Player and Blueprint admin containers follow the same pattern.) The Administration area is a `mat-sidenav-container`:

- **Sidebar header.** A `mat-toolbar` with the app icon and the text "Administration". It is the way out: its title is "Exit Administration" and it links to `/` with `routerLink` (not a click handler), so middle-click and "open in new tab" work. Caster, Alloy, CITE, Gallery, Player and Blueprint have this; the Steamfitter container has a `sidenav-header` toolbar without the "Exit Administration" title.
- **Sidebar items.** One item per section: a leading section icon, the section name, a trailing arrow. Items appear only when the user holds the view permission for that section (Caster `admin-container.component.html` wraps each item in `@if (permissions.includes(...))`; Player filters `sectionItems` by `permission`).
- **Top bar.** Shows the current section name as the page title (Caster passes `[title]="showStatus"` to `cas-topbar`).
- **Content.** Exactly one section component is shown (`.admin-content`).

Rules:

1. **[Existing]** The page title is the section name in the top bar and the sidebar item. The page body does not repeat it as a heading. Caster's Workspaces and Projects pages have no title element; the toolbar icon (section 3) carries the identity.
2. **[Existing]** The section icon in the sidebar item and the icon in the toolbar row are the same icon (Caster: Projects `mdi-notebook`, Workspaces `mdi-briefcase`, VLANs `mdi-lan`, in both places).
3. **[Existing]** Sections the user cannot view are not rendered in the sidebar or the content area (Caster tests each section's permission in both places in `admin-container.component.html`).
4. **[Existing]** The sidebar arrow is the Material Design Icons `mdi-menu-right` (Caster, Alloy, CITE, Gallery, Steamfitter). Blueprint uses `mdi-chevron-right`; Player's admin menu uses PNG images and has no arrow (CRU-2886, CRU-2885: both tickets have only a title, no description). **[Target]** All apps use `mdi-menu-right`.
5. **[Existing]** The page host is a flex column filling the content area (`:host { display: flex; flex-direction: column; flex: 1; min-height: 0; }` in the Caster active-runs and pool lists; `height: 100%` in Projects). The page does not add its own outer scrollbar; only `.table-container` scrolls (section 6).
6. **[Target]** Sidebar order groups by purpose: the app's own data sections first, then Users, Roles, Groups. Caster's order today is Projects, Workspaces, VLANs, Modules, Users, Roles, Connections, Environment Sets, Project Groups, Groups (`admin-container.component.html`), so it does not follow this yet.

---

## 3. The toolbar row

**[Existing]** Caster Projects and Workspaces, and the lists in Blueprint, Player, Alloy, CITE and Gallery, put one flex row above the table. In Caster `.toolbar` is `display: flex; align-items: center; gap: 8px; flex-shrink: 0; padding-right: 16px`.

Order, left to right:

1. **Section icon**: a 24px `mat-icon` colored `var(--mat-sys-primary)`, with `role="img"` and an `aria-label` naming the section, and a tooltip that explains the list in one sentence (Caster Projects: "Every Project in Caster. Click a Project to see and change its memberships.").
2. **Search field** (section 4), 300px wide.
3. **Paginator** (section 5).
4. **Spacer**, then **page-level content**: status text or a control that is about the whole page, not one row (Caster Workspaces projects a "locking status" control here with `<ng-content />`).

Rules:

1. **[Existing]** Page-level buttons that add, upload or download rows do not live in the toolbar row. They live in the header cell of the actions column (section 8): Blueprint Units and Competency Frameworks, Gallery Collections, Caster Projects. The only extra thing in a toolbar row on `main` is Blueprint Competency Frameworks' inline import-error text. **[Target]** No buttons in the toolbar row.
2. **[Existing]** The paginator is transparent (`background: transparent`) and does not shrink (Caster standard pages).
3. **[Target]** The paginator sits immediately after the search field (Caster standard pages; Player's `button-end` is `margin-left: 100px`). Blueprint Units pushes it to the right edge with `margin-left: auto`; see D3.
4. **[Existing]** Membership lists (section 12) use a `mat-toolbar` with two rows instead: a title row, then a search-and-paginator row.

---

## 4. Search fields

**[Existing]** Every admin list has exactly one search field per table. These rules describe the Caster standard pages unless another app is named.

1. **No leading search icon.** **[Existing]** Caster Workspaces, Projects, VLANs; Blueprint, Alloy, CITE, Gallery, Steamfitter and Player lists have none. **[Existing leftovers, non-conforming]** Caster still renders `<mat-icon matPrefix svgIcon="ic_magnify_search">` in `admin-groups-member-list`, `admin-groups-membership-list`, `assignment-checklist`, `project-groups-list`, `inventory-panel`, `editor/module-list`, `editor/version-list` and `sei-cwd-common/cwd-table`; Player's `add-remove-users-dialog` has two. These are to be removed. The section icon (section 3) sits to the left of the field instead.
2. **Wording.** **[Existing]** `placeholder="Search"` plus `aria-label="Search"` (Caster standard pages; Blueprint Units has the `aria-label` with a code comment explaining why a placeholder alone is not an accessible name). The Groups pages say "Search Groups" (Caster, Blueprint); see D4. A placeholder is not a label: the `aria-label` is required.
3. **Appearance and size.** **[Existing]** The default `mat-form-field` appearance, 300px wide, `subscriptSizing="dynamic"` (Caster) so the field does not reserve space for hint text. No app sets `MAT_FORM_FIELD_DEFAULT_OPTIONS`; Blueprint, Gallery and Player lower form-field density in a few component styles; **[Target]** no density override inside the toolbar row.
4. **Clear Search.** **[Existing]** A suffix `mat-icon-button` with `mdi-close-circle-outline`, shown only while the field has text, with `aria-label="Clear Search"` and `matTooltip="Clear Search"` (Caster standard pages). Blueprint Units and Competency Frameworks use `title="Clear Search"` only; Player User Search has both; Caster Groups and Blueprint Groups use `aria-label="Clear"`, and VLAN Pools `aria-label` and tooltip "Clear". **[Target]** `Clear Search` everywhere, as both `aria-label` and `matTooltip`, and the button stays in the tab order. After activation, focus returns to the input.
5. **What it matches.** **[Existing]** A `filterPredicate` that lower-cases the filter and matches as a **substring**, case-insensitively, against the **text the user sees**: Caster Projects joins name, description and the formatted created date (so typing "EST" matches); Workspaces joins workspace, project, type, status, started-by and more (`active-runs.component.ts`). **[Target]** The columns searched are named in a comment next to the `filterPredicate` and in the page's spec (section 16). Do not rely on the default `MatTableDataSource` predicate, which tests each property of the row separately (`Object.values(data).some(...)`, checked in 21.2.14), including IDs and other values the user cannot see, so a search can match something that is not on screen.
6. **When it applies.** **[Existing]** On every change, with no debounce, for client-side tables (Caster binds `(keyup)`; Blueprint Units and Groups use `(ngModelChange)`; Alloy's template list debounces 250 ms). **[Target]** Bind to value changes (`ngModelChange` or `valueChanges`), not `keyup`, because `keyup` misses paste and cut by mouse. No debounce for client-side filtering; 250 ms debounce for server-side filtering (section 5).
7. **Paginator reset.** **[Target]** A new search term returns the paginator to the first page. Today `MatTableDataSource` only clamps the page index back into range when the filtered list becomes shorter (verified in `@angular/material` 21.2.14 `table.mjs`, `_updatePaginator`); the apps that call `paginator.firstPage()` after filtering are the exception (Steamfitter History, Player's add-remove dialog).
8. **Persistence.** **[Existing]** None. No admin table persists its search term or page size across navigation or reload. CITE and Gallery keep a `uiState` object in `localStorage`; the fields read in CITE hold expanded items and evaluation selections, not table filters. **[Target]** None either: a search term is local to the visit. A page opened later starts unfiltered.
9. **No results.** The empty-result state is in section 13.
10. **Nested tables and membership lists.** **[Existing]** Each has its own field, same wording, same Clear Search, and its own paginator (Blueprint Competency Frameworks; Caster membership lists). Rules 2, 4 to 7 apply to each. Field labels in a two-list page say which list they search (section 12).
11. **Keyboard and screen readers.** The field is reachable by Tab, has an accessible name (rule 2), and the result count changes are announced by the paginator's `role="status"` range label (Material provides this).

---

## 5. Pagination and large data

**What the code does today (verified).** Every admin list in the seven apps is paged **in the browser**: the API returns the whole list and `mat-paginator` slices it through `MatTableDataSource`. I found no list endpoint with paging parameters in `caster.api`, `blueprint.api`, `player.api`, `steamfitter.api`, `gallery.api`, `cite.api` or `alloy.api` (searched controllers and request classes for `skip`, `take`, `offset`, `pageSize`, `pageNumber`, `continuation` and `limit`). The only caps are Caster's optional `Limit` on the run lists (`Runs/Requests/GetAll.cs`, `GetByWorkspace.cs`) and Blueprint's `limit` (default 100) on the xAPI feed.

**Page sizes in use.** Page-level admin tables: `[pageSize]="20"` with options `[5, 10, 15, 20, 25, 50, 100, 200]` (Caster standard pages, Blueprint admin lists, Player user search, Alloy). Membership lists and nested lists: options `[10, 25, 50, 100]`. Some lists default to 10 or 100 (Gallery admin collections 10, Gallery team users 100, Steamfitter History 10), and some CITE and Gallery lists set no `pageSize`, in which case Material starts at the first option (5, or 10 for the shorter list); `@angular/material` 21.2.14 `paginator.mjs`.

Rules:

1. **[Existing]** Client-side paging is the pattern, and it is acceptable only while the list is **bounded and light** (rule 2).
2. **[Target]** "Light" means: at most **1,000 rows** returned by the list call, and a summary payload per row (the fields the table shows plus the ID), about **2 KB** or less. Both numbers are proposals (D5). A list over either limit moves to server-side paging (rule 4).
3. **[Existing]** A list that loads heavy per-row detail up front must not. Caster already does it right for Modules: the admin Modules page calls `load(false, true)`, which asks `GET modules` with `IncludeVersions=false` and `IncludeVersionCount=true` (`caster.ui` `module.service.ts`, `caster.api` `Modules/Requests/GetAll.cs`); versions load when a module is opened. **[Target]** Every list does this: summary for the table; detail on expand, or through an `include...` query flag defaulting to false.
4. **[Target]** Lists that can grow without bound (users, workspaces, runs, events, exercises, submissions and similar) use server-side paging, sorting and search. Proposed contract (D6): query `skip`, `take`, `sort`, `sortDirection`, `search`; response `{ items: [...], totalCount: n }`; a stable default sort with the ID as the final tie-breaker so pages do not shuffle. The UI binds `mat-paginator`'s `length` to `totalCount`, sends `sort`/`sortDirection` from `matSort`, and debounces `search` 250 ms (section 4, rule 6). No API implements this today, so no page breaks this rule yet.
5. **[Existing]** Default page size is **20** and the options are `[5, 10, 15, 20, 25, 50, 100, 200]` for page-level tables. **[Target]** `[10, 25, 50, 100]` with default 10 for membership lists and any list nested in an expanded row; Blueprint's nested lists use default 10.
6. **[Existing]** The page size and page index are not persisted (section 4, rule 8). Returning to a page starts at page 1 of the default size.
7. **[Existing]** The paginator is in the toolbar row (section 3). **[Target]** Give each paginator an `aria-label` naming its list ("Page of Projects"). Caster's two membership paginators both say "Select page of members", including the list of users who are not members.
8. **[Existing]** A nested table in a row detail has its own paginator, search and sort (Blueprint Competency Frameworks: page size 10, options `[10, 20, 50, 100]`). Nested paginators are never shared with the parent.
9. **[Target]** The call that fills a table returns every value a column of that table shows. A page never depends on a field the list endpoint does not return. When a column needs a value that is costly to compute (a module's latest version, a count), the list call takes an option to include it, and the page asks for it; it does not load every row's full detail to derive it. The page's spec asserts the arguments of the list call and renders a row from a response shaped like the real API's, not from a hand-built object that already has the field. (A page once showed "No version" for every module because it read `versions` from a list call that never returns them, and its specs passed because the test data had the field.)

---

## 6. The table

**Layout.**

1. **[Existing]** The table fills the content area: `.table-container { flex: 1; overflow: auto; padding-bottom: 20px; }` and `table { width: 100%; }`. The header row is sticky (`*matHeaderRowDef="columns; sticky: true"`) on page-level tables, so headers stay visible while the container scrolls. Membership lists in cards (section 12) are not sticky.
2. **[Existing]** Density is Material's default. **[Target]** Do not override `--mat-table-row-item-container-height` or the density in component styles.
3. **[Existing]** Cells: `padding-right: 10px; vertical-align: middle` (Caster standard pages).
4. **[Existing]** Real table markup: `<table mat-table>` with `<th mat-header-cell>` and `<td mat-cell>` (Caster standard pages, Blueprint Units and Groups). Blueprint Competency Frameworks puts `<mat-header-cell>`/`<mat-cell>` custom elements inside a native `<table>`, which is not valid table markup. **[Target]** `th`/`td` only, so the browser's table semantics apply (section 15).

**Row outlines (CRU-2763).** **[Existing]** The pages disagree on whether the last row has a bottom border. The cause is in the styles: tables with `multiTemplateDataRows` zero the bottom border on the data row (`.element-row td { border-bottom-width: 0 }`, in Caster and in Blueprint, Alloy, CITE and Gallery component styles) and rely on the zero-height detail row to draw the divider; several Blueprint styles also zero the detail cell's border (`.detail-row .mat-mdc-cell.expanded-detail-cell { border-bottom-width: 0 }`), which removes the divider under the last row. CRU-2763 is a one-line ticket naming the symptom. **[Target]** Every table, with or without row expansion, shows a divider under **every** row, the last included, using Material's default row divider (D7).

**Columns.**

1. **[Existing]** Column order: actions first (section 8), then identity (Name), then descriptive columns, then dates last. Caster Projects: `actions, name, description, dateCreated`.
2. **[Existing]** On the Caster standard pages every column is sortable (`mat-sort-header`) except the actions column and counts that are not loaded yet (VLAN pool "Partitions" and "VLANs In Use"). A default sort is set when the data has a natural order (`matSortActive="name" matSortDirection="asc"` on Caster Projects). Sorting is case-insensitive for text and by underlying value for dates and numbers (section 7).
3. **[Existing]** Header cells explain the column in a `matTooltip` (Caster standard pages: "The Project's name", "When the Project was created, in your time zone"). Other apps use `title`. **[Target]** `matTooltip`. A native `title` is not shown on keyboard focus.
4. **[Existing]** Column header text is Title Case nouns ("Started By", "Created"). A date column is headed by the event ("Created", "Started"), not "Date".
5. **[Existing]** Status columns show text; where an icon helps, the icon is `mat-icon` with an `aria-label` and `matTooltip` that state the meaning (VLAN pools "Default": `mdi-check-circle`, `aria-label="Contains the Default Partition"`, `aria-hidden="false"`). **[Target]** Never color or an icon alone: the text or the label carries the meaning (WCAG 1.4.1).
6. **[Target]** If a cell truncates text, the full text is available as a tooltip and to assistive technology; nothing is silently cut.
7. **No value in a cell (any column, not only dates).** **[Existing]** The apps do all of these: a blank cell (Caster's date formatters return `''`), a dash `-` with a tooltip while a count has not loaded (VLAN pools), and words ("No version" in red for a Module with no versions; "No Modules yet" for an empty source). **[Target]** (a) A cell with no value is **empty**: not `-`, `N/A` or `None`. (b) A value that is **not loaded yet** is different from no value: show `-` with a tooltip that says why (the VLAN pool pattern), never a blank that looks like "none". (c) Where the absence changes what the user can do or means something happened or did not ("Never synced"; a Module with no versions cannot be inserted), write words, in muted text. Red is for errors, not for an empty value (D10).
8. **A status and a time do not repeat each other.** **[Target]** A status column holds the state as an icon and a short word. A time appears once, in its own column; the status cell carries no time. Detail about a problem (an error, a warning) is a muted second line in the status cell, without a time in it. A tooltip may carry a time when it explains a state ("showing data from ..."). **[Existing]** Alloy's event list does this: the Status cell holds the status word (and an error icon), and "Status Date" is its own column, a different fact (when the status last changed). The Caster Modules sources table once showed "Updated <time>" in the status line and the same time in a Last Updated column; the Connections page, with a status word and a Last Updated column, is the pattern.

**Copy-ID convention.** **[Existing]** Alloy, Player, Steamfitter, CITE, Gallery, Blueprint and Caster share one: a leading `mat-icon-button` in the Name or ID cell using `ngxClipboard` with `[cbContent]="id"`, icon `mdi-content-copy`, tooltip `Copy:  <id>` (native `title`), `aria-label="Copy ID of <name>"` where present (Caster, Player), `(click)="$event.stopPropagation()"`, and on success `snackBar.open('Copied to clipboard', 'Dismiss')` (Player's team copy uses its own message). It appears where an operator needs to paste an ID into another system: Users and Groups lists, membership lists, Alloy event and template lists, Caster Modules. **[Target]** Same behavior, `matTooltip`, and the `aria-label` everywhere. The icon collides with "duplicate this record" (Gallery Collections and CITE Evaluations use `mdi-content-copy` for a clone): see [ui-conventions.md](ui-conventions.md) section 2.

**Shared library.** `@cmusei/crucible-common` (main) has `crucible-dialog`, `comn-header-bar` (the classification banner), `crucible-theme`, `crucible-landing-background`, `comn-auth` and `comn-settings`. It has **no** table, toolbar, search, paginator or date component. Caster carries its own `sei-cwd-common/cwd-table` and `cwd-toolbar`; none of the standard admin pages use them. **[Target]** A shared table toolbar and a shared date formatter are candidates for the library (D12). Until then, copy the pattern in this spec, not a private variant.

---

## 7. Dates and times

**The rule (Crucible-wide, CRU-3099, CRU-2576, CRU-2544).** **[Target]** Every date and time shown to a user is in the **viewer's local time zone** with a **short zone name**, for example `6:45 PM EST`. Never raw UTC, never an ISO string, never a time without its zone. CRU-3099 notes this matters when scenarios are designed with partners in other time zones, and CRU-2544 asks for a better display of time zones in all apps. CRU-2576 has only an image attached.

**What the apps do.**

- **[Existing, conforming]** Caster's standard pages format with one pattern: `new Date(value).toLocaleString(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', timeZoneName: 'short' })`, giving `Nov 6, 2026, 4:40 PM EST`. It is written out four times (`formatCreated` in Projects, `formatStarted` in Workspaces, `readTime` in Hypervisors, `syncTime` in Modules) and each returns `''` for a missing value.
- **[Existing, not conforming]** Everywhere else uses Angular's `DatePipe` with a fixed pattern and no zone: `yyyy-MM-dd HH:mm` (Alloy, CITE, Gallery, Steamfitter, older Caster), `dd MMM yyyy HH:mm` (Blueprint, CITE, Gallery), `yyyy/MM/dd HH:mm:ss` (Steamfitter), `MM/dd/yyyy HH:mm` (Player), `short` and `medium` (a few). All 24-hour, none with a zone.
- **[Existing, partial]** The zone abbreviation exists as separate copies: `getTimezoneAbbr` in Blueprint (`utilities/timezone-abbr.ts`), a `timeZoneAbbr` pipe in Player (`pipes/time-zone-abbr.pipe.ts`), and private copies in the CITE move and evaluation edit dialogs and the Gallery article edit dialog. Each derives the abbreviation from **the date being shown**, not today, so a November date reads `EST` even in October.

Rules:

1. **[Target]** One format: month-name date plus 12-hour time plus short zone: `Nov 6, 2026, 4:40 PM EST`. The formatter sets `hour12: true`; without it the viewer's locale decides, and a viewer in `en-GB` or `de-DE` sees `22:40`. (Caster's four existing formatters omit `hour12`, so they rely on an `en-US` browser; they should add it.) A date-only column (a value with no time of day) shows `Nov 6, 2026`. A time-only value shows `4:40 PM EST`.
2. **[Target]** The zone name comes from `Intl.DateTimeFormat` with `timeZoneName: 'short'`, for the date shown. For a zone with no short name the result is an offset such as `GMT+8` (verified in `en-US` for several zones that have no short name); that is acceptable and is never replaced with an invented abbreviation.
3. **[Target]** API timestamps are UTC and the UI must parse them as UTC. A string without a zone designator is read by `new Date()` as **local** time, which silently shifts every value. The caster.api models store `DateTime.UtcNow`; I could not confirm from code that every endpoint of every app serializes the trailing `Z`. Each app confirms this for its own endpoints, and the shared formatter treats a zone-less ISO string as UTC (D9).
4. **[Target]** Sort by the underlying value, never by the formatted text, and compare it as a number or a `Date` (`Date.parse(value)`), not as a raw ISO string: strings with different fractional-second precision mis-order (`2026-11-06T21:40:00.5Z` sorts before `2026-11-06T21:40:00Z` although it is later). Caster Projects' `sortingDataAccessor` returns `dateCreated` raw, which has that flaw.
5. **[Target]** Search matches the formatted text (section 4, rule 5).
6. **[Existing]** A missing value shows nothing in Caster's four formatters (`''`). Pool counts not yet loaded show `-` with a tooltip that explains why. **[Target]** The "no value" convention for every column applies to dates (section 6, Columns rule 7): an empty cell. A value that means "has not happened" (for example, never synced) is written in words by the page ("Never synced"), not as a blank (D10).
7. **[Existing]** I found no admin page that shows relative times ("3 minutes ago"). **[Target]** If a page needs one, the absolute time with its zone is the tooltip and the `aria-label`.
8. **[Existing]** Date column headers name the event ("Created", "Started") and the header tooltip says the time is "in your time zone" (Caster Projects and Workspaces). **[Target]** Every date column does this.
9. **[Target]** Durations and intervals are not dates: show them as `1 h 30 min`, never as clock times. No admin table I read shows one, so no existing pattern is recorded.
10. **[Target]** One shared formatter, in `@cmusei/crucible-common`, with the three outputs of rule 1 and the UTC rule of rule 3, replaces the nine separate implementations above (four Caster formatters, Blueprint, Player, two CITE dialogs, one Gallery dialog) (D12). Until it exists, the Caster pattern above is the reference.
11. **[Existing]** The locale is the browser's in the Caster formatters (`undefined`). Player's pipe uses Angular's `LOCALE_ID`, which is `en-US` unless the app provides another; it is not the browser's. Blueprint's abbreviation helper hard-codes `en-US` (D11).
12. **[Existing]** A user preference for the time zone does not exist. CRU-3099 raises it as something to consider; it is out of scope here.
13. **Tests.** **[Existing]** Caster's specs fix the zone with `vi.stubEnv('TZ', 'UTC')` and assert the exact string (`Oct 14, 2026, 12:30 PM UTC`) (`admin-projects.component.spec.ts`). **[Target]** Every spec that asserts a rendered date pins the zone (or passes the zone to the formatter) and the locale, so it does not depend on the machine.

---

## 8. The actions column and permissions

**Position and contents.**

1. **[Existing]** The actions column is **first**. Its **header cell** holds the page-level actions: Add, and where they apply Import, Upload, Download (Caster Projects "Add New Project"; Blueprint Units Add, Upload, Download; Gallery Collections Add and Upload; Alloy Users Add). Its **row cells** hold that row's actions. Membership lists are the exception: the actions column is last, and holds one button (Add or Remove).
2. **[Existing]** All actions are icon buttons: `mat-icon-button` with a 24px icon in the header cell and a 24px icon in the row (Caster standard pages, Player); Blueprint Units and Frameworks and Gallery Collections use 24px in the header and 18px in rows. **[Target]** 24px in both, so the touch target and the icon scale together.
3. **[Existing]** Row action order, where the apps agree: **Open** or **View**, **Edit** (`mdi-square-edit-outline`), **Copy** (clone, see below), **Download** (`mdi-download`), **Delete** (`mdi-trash-can-outline`) last. Gallery Exhibits and Collections: Edit, Copy, Download, Delete. CITE Evaluations: Edit, Copy, Download, Delete. Caster Projects: Open, Rename, Delete. The Caster Groups and VLAN Pools put Delete before Edit/Rename; **[Target]** Delete last.
4. **[Existing]** "Open in a new tab" is a real link (`<a mat-icon-button [routerLink] target="_blank">`, icon `mdi-open-in-new`, tooltip "Open <name> in a new tab"), not a button with a click handler.
5. **[Existing]** Add is `mdi-plus-circle`, the tooltip and `aria-label` are "Add New <Thing>" (Caster) or "Add <Thing>" (others); Import/Upload `mdi-upload`; Export/Download `mdi-download`. Icon conventions are in [ui-conventions.md](ui-conventions.md) section 2.
6. **[Existing]** An information button next to the Add button (`mdi-information`, `matTooltipShowDelay="0"`) explains something about the whole list (Groups, Roles, VLAN Pools). In Caster Groups and Blueprint Groups the button is `disabled`, so a keyboard user cannot reach the text. **[Target]** The info button is enabled, keyboard-focusable, labelled ("About groups") and its tooltip opens on focus.

**Accessible names.** **[Existing]** Caster standard pages: every icon button has `aria-label` that names the action **and the row** ("Rename Range", "Delete Range") and a matching `matTooltip`. Alloy, CITE, Gallery and Blueprint rows use `title` only ("Edit Name"); Caster Groups' row buttons have an `aria-label` that names the action but not the row ("Rename"), and Blueprint Groups have a tooltip only. **[Target]** `aria-label` and `matTooltip`, both naming the row.

**Row-click tables.** **[Existing]** In a table whose rows are clickable (expandable rows), every control inside a row calls `$event.stopPropagation()` on `click`, so the click does not also toggle the row (Caster Projects, VLAN pools, Gallery, CITE, Blueprint). The VLAN pool list additionally stops `keydown` on the action group, so Enter and Space on a button do not expand the row. **[Target]** Do both.

**Permission gating (D1).** What the apps do:

| Behavior | Where |
|---|---|
| Disabled, with the reason in a tooltip and "(not available)" in the `aria-label` | Caster Projects (`CreateProjects`, `ManageProjects`, `ManageProject`); Caster Workspaces "Open" |
| Disabled, no reason | Alloy, CITE, Gallery, Steamfitter lists; Caster VLANs and Groups; Blueprint Users, Roles checkboxes |
| Hidden (`@if (canEdit)`) | Blueprint Units, Frameworks, Add Role; Caster membership lists omit the whole actions column when read-only |
| Disabled with a computed reason | Blueprint Frameworks Delete ("In use by 2 MSEL(s): ...") |

**[Target]** Rules:

1. A user who can see a list but cannot perform an action sees the control **disabled with the reason**: the tooltip names the missing permission or the blocking fact ("Renaming and deleting a Project need the ManageProjects permission, or ManageProject on this Project"), and the `aria-label` ends "(not available)".
2. A natively disabled button receives no mouse or focus events, so it shows no tooltip. Caster's standard pages wrap it in a `span` that carries the tooltip (`.disabled-action { display: inline-block }`, with a code comment); that works for the mouse only, because the tooltip watches its own host and a focused child button does not open it. **[Target]** Put `matTooltip` on the button itself and set `disabledInteractive` (the Material paginator buttons use it): the button stays focusable, the tooltip opens on hover and on keyboard focus, and `matTooltip` adds the reason as the button's accessible description (`aria-describedby`). The wrapper `span` is then unnecessary. `disabledInteractive` removes the native `disabled` attribute from a button, and Material (checked in 21.2.14) stops the click only for anchors, not for buttons, so the control's click handler must itself return when the action is not allowed (`if (!canEdit()) { return; }`) or the dialog opens and the API call is made anyway. A page's spec asserts that clicking a disabled control makes no call (section 16, item 6).
3. Navigation to a section or page the user cannot open at all is **hidden** (section 2), not disabled.
4. A read-only list may omit the whole actions column when every row action in it would be disabled for the same reason and there is no page-level action either. The reason is then stated once, in the toolbar tooltip.
5. The permission is checked in the UI for explanation only. The API is the authority; the UI never assumes the API will allow what it enabled.

---

## 9. Users, Groups and Roles pages

**Icons (CRU-2581, CRU-2892).** The sidebar item icons for the three pages differ between apps:

| App (sidebar item) | Users | Groups | Roles |
|---|---|---|---|
| Caster | `mdi-account-multiple` | `mdi-account-group` | `mdi-lock` |
| Alloy | `mdi-account-multiple` | `mdi-account-group` | `mdi-lock` |
| CITE, Gallery, Steamfitter | `mdi-account` | `mdi-account-group` | `mdi-lock` |
| Blueprint | `mdi-account` | `mdi-account-multiple` | `mdi-shield-account` |
| Player | PNG image (Users); toolbar `mdi-account-multiple` | no Groups page | PNG image (Roles) |

CRU-2581 and CRU-2892 have only titles. **[Target]** (D2) Users `mdi-account-multiple`, Groups `mdi-account-group`, Roles `mdi-lock`, in the sidebar item **and** the toolbar row, in every app. One person is `mdi-account`, used for a single user in a cell or a menu, not for the list.

**Groups pages match the membership pages (CRU-2581).** **[Existing]** The membership pages in CITE (Evaluation Members), Gallery (Collection Members), Alloy (Event Members), Steamfitter (Scenario Members) and Caster (Project Members) title the two lists with an icon and a noun: the available list `mdi-account-group` "Users/Groups", the member list `mdi-account-multiple` "<Thing> Members". The Groups admin pages in CITE, Gallery, Alloy, Steamfitter, Blueprint and Caster show the same two lists with **no icon** and the titles "Users" and "Group Members". **[Target]** The Groups detail uses the same icon and title structure as the membership pages (section 12).

**Roles pages: permission tooltips (CRU-2649).** CITE, Gallery, Blueprint, Steamfitter, Alloy and Caster keep a hard-coded `permissionMap` (or `permissionDescriptions`) in the UI for the tooltip beside each permission (`cite.ui` `SystemRolesModel.SystemPermissions`; `blueprint.ui` `admin-roles.component.ts`; `caster.ui` `system-roles.models.ts`). Player reads `permission.description` from the API (`player.ui` `roles.component.html`, `[matTooltip]="permission.description"`), except the synthetic "All" permission, which has a literal string. The ticket's description names the first four apps; the same pattern is also present in Alloy and Caster.

**[Target]** Rules:

1. The permission description comes from the API, one source for every UI. A UI never ships its own copy of permission descriptions (they drift from the API as permissions are added).
2. The info button is a `mat-icon-button` with `mdi-information`, `aria-label="About <permission>"` (Caster, Player, Steamfitter do this) and `matTooltipShowDelay="0"`, enabled and focusable.
3. The synthetic "All" permission has a single description kept in one shared constant: "Gives permission to perform any action" (the text Player and Blueprint already use).
4. The roles page is a permission matrix (roles as columns), not a row table; it follows rules 1 to 3 here and section 15, and nothing else in this spec's row sections.

---

## 10. Row expansion

**When to use it.** Use an expandable row when a row owns a small amount of **related, editable detail** the user opens one at a time: the members of a group, the partitions of a VLAN pool, the competencies of a framework, the members of a Project. Do not use it to show more columns of the same record (add a column or a dialog). Do not nest a third level.

**What exists.** `mat-table` with `multiTemplateDataRows`: a data row per record (`class="element-row"`, `(click)="toggle(row)"`) and a second row per record that renders an `expandedDetail` column spanning every column (`[attr.colspan]="displayedColumns.length"`), with `tr.detail-row { height: 0 }`. Used by Caster Projects, VLAN Pools, Workspaces (active runs), Groups; Blueprint Units, Frameworks, Groups; Gallery Collections; CITE Evaluations; Alloy Groups.

Rules:

1. **[Existing]** One row open at a time (`expandedId` is a single value). **[Target]** Keep that.
2. **[Existing]** The detail is rendered only while open (`@if (isExpanded(row))`), so a closed row has no focusable content, runs no queries, and a heavy child (a terminal, a member list) is created on demand.
3. **[Existing]** Detail content stops click propagation (`(click)="$event.stopPropagation()"`) so working in the detail does not collapse it.
4. **[Existing]** The expanded row gets a class (`expanded`/`expanded-row`) for the visual state.
5. **[Existing, partial]** The VLAN pool list is the only page that does keyboard right: its data row has `tabindex="0"`, `aria-expanded`, and `(keydown.enter)` and `(keydown.space)` (with `preventDefault`) toggling; the detail has `role="region"` and `aria-label="<name> partitions"`. Caster Projects sets `aria-expanded` on the row but gives it no `tabindex` or key handling. Every other merged expandable table, in every app, has click only; the unmerged Connections page uses a button (rule 6).
6. **[Target, decided: D8]** The expand control must be keyboard-operable and expose its state (WCAG 2.1.1 and 4.1.2). WCAG does not require a chevron icon or a separate button; it requires that a user who cannot use a mouse can open and close the row, and that assistive technology is told whether it is open. Two patterns meet that, and this spec adopts pattern A, the chevron button (D8). Both are used today: the VLAN pool list makes the row itself the control (pattern B), and the Connections page uses a button (pattern A). Whichever is chosen, the rules in this item about the state, the detail and the focus apply. Pattern A, a **real `<button>`** in the actions column's first position:
   - `aria-expanded="true|false"`, `aria-controls` pointing at the detail container's `id`, `aria-label="Show details for <name>"` or `"Hide details for <name>"` (or one label with the state carried by `aria-expanded`).
   - Icon `mdi-chevron-down`, rotated to point up when expanded (no merged page shows an expand indicator on its rows today; the reworked Connections page, not yet merged, shows this chevron button; CRU-2885 and CRU-2886 have only titles and I read them as about the sidebar arrow, section 2, rule 4, so this icon is my proposal) (D8).
   - `type="button"`, in the tab order, activated by Enter and Space.
   - Clicking the row still toggles it (a mouse convenience); the button is the keyboard and assistive-technology path. Remove `aria-expanded` and the `tabindex` hack from the `tr` once the button exists. Why a button: a visible chevron shows at a glance which rows expand and which one is open, which helps a user keep their place in a long table, and it gives keyboard and assistive-technology users a named control; it also leaves the `tr` as a plain table row for assistive technology. These are usability reasons, not WCAG requirements.
   - Pattern B (meets the WCAG requirement but not this standard; a page that has not been converted may keep it): the row is the control: `tabindex="0"`, `aria-expanded`, `aria-controls`, Enter and Space toggle it (with `preventDefault`), and the row has a visible focus style. It meets 2.1.1 and 4.1.2 with no extra control, but nothing visible tells a user the row expands, and a role on a `tr` can change how a screen reader announces the row.
7. **[Target]** The detail container has the `id` the button points to, `role="region"`, and an `aria-label` naming it ("Range memberships"), as in the VLAN pool list.
8. **[Target]** Focus stays on the expand control (the button, or the row when the row is the control) when the row opens or closes. Opening does not move focus into the detail; Tab reaches the detail's first control after the remaining focusable controls in the data row (focus order is DOM order, section 15). If a user deletes the record while its detail is open, focus moves to the next row's expand control (or the Add button if none).
9. **[Existing]** Animation: Angular `@detailExpand` trigger, `225ms cubic-bezier(0.4, 0.0, 0.2, 1)`, between `height: '0px'` and `'*'` (VLAN pools, Groups, Blueprint). Caster Workspaces turns it off, with the reason in a code comment ("the terminal sizes itself when it opens"). **[Target]** Use the 225 ms transition for ordinary detail; turn it off for a detail that sizes itself; and respect `prefers-reduced-motion` (WCAG 2.3.3): no app does today.
10. **[Existing]** A nested table in the detail follows sections 4, 5 and 6 in full: its own search, sort and paginator (Blueprint Competency Frameworks: Work Roles and Competencies, each in a `mat-expansion-panel`, each with its own table, search, filter and paginator). **[Target]** Nested expansion panels use Material's `mat-expansion-panel`, whose header is already a button with `aria-expanded`; nested tables inside them are not themselves row-expandable except the one level Blueprint already has.
11. **[Existing]** Detail loads by itself: the detail component takes an ID and loads what it needs (`<cas-project-memberships [projectId]>`, `<app-admin-groups-detail [groupId]>`).

---

## 11. Master/detail and tabs

1. **[Existing]** A page that has two peer lists of the same kind uses **tabs**: Caster VLANs (Pools, Projects) and Roles (Roles, Project Roles) use `mat-tab-group` with `matTabContent` (lazy tab bodies). **[Target]** Tabs for peers; row expansion for children (section 10); a separate routed page for a record with its own sub-pages (Caster Project > Memberships).
2. **[Existing]** Tabs are lazy (`<ng-template matTabContent>`), so a hidden tab loads nothing.
3. **[Target]** A detail page reached from a list has a Back button: an icon button `mdi-keyboard-return` with `aria-label` and tooltip "Back to <list>" (Caster `project-memberships` has one, `returnLabel()`). The list the user came from is restored in the same state of expansion; the search term is not restored (section 4, rule 8).
4. **[Target]** Each tab body that holds a list has its own toolbar row, as the VLAN Pools tab does.
5. **[Existing]** The Hypervisors page is a read-only inventory of cards, each with its own header, a Refresh icon button with a spinner while it runs, and plain `<table>`s with `<th scope="col">` for hosts and datastores. A table inside a card needs no search, sort or paginator while it is a fixed-size inventory. **[Target]** The card shell keeps the state patterns of section 13.

---

## 12. Two-list membership pages

**[Existing]** Caster Groups detail, Caster Project Memberships, and the Group, Collection, Exhibit, Evaluation, Event and Scenario membership pages in Blueprint, CITE, Gallery, Alloy and Steamfitter show **two lists side by side**, `d-flex gap-5 justify-content-center`: the **available** list on the left, the **members** list on the right. Each list is a `mat-elevation-z8` card with a `mat-toolbar`: a title row, then a row with its own Search field and its own paginator `[10, 25, 50, 100]`, over a `mat-table` with default sort by name.

| | Left: available | Right: members |
|---|---|---|
| Title row | icon `mdi-account-group` + "Users/Groups" (Caster Groups detail: "Users", no icon) | icon `mdi-account-multiple` + "<Thing> Members" (Caster Groups detail: "Group Members", no icon) |
| Columns | Name (with the copy-ID button), Type if mixed users and groups, actions | Name, Type, Role (a `mat-select` when editable, text when read-only), actions |
| Row action | Add: `mdi-plus-circle-outline`, "Add <name>" | Remove: `mdi-minus-circle-outline`, "Remove <name>" |
| Empty | "No data matching the filter ..." when a filter is set (Caster Project Memberships); no empty row otherwise | "This <Thing> currently has no members" |
| Read-only | action column omitted (Caster) or buttons disabled | role shown as text; action column omitted (Caster) or disabled |

Rules:

1. **[Existing]** Adding moves the user from the left list to the right; removing moves it back. The lists are two views of the same set and update together. In Caster Groups the signed-in user is marked with a "current user" badge in both lists (`cas-current-user-badge`).
2. **[Existing]** Row actions need no `stopPropagation` (the rows are not clickable) and carry `aria-label="Add <name>"` / `"Remove <name>"`.
3. **[Target]** Titles and icons follow the table above for every Groups detail (CRU-2581, section 9).
4. **[Target]** Each list's Search field has its own `aria-label` that names the list ("Search users", "Search members"), and each paginator has its own `aria-label` ("Page of users", "Page of members"). Caster uses the same "Select page of members" label on both paginators.
5. **[Target]** The empty state of the left list when there is nobody left to add and no filter is "Everyone is already a member", not blank. Today the left list has no empty row without a filter.
6. **[Target]** When the whole page is read-only, say so once above the lists ("You can view members but not change them") rather than a column of disabled buttons (section 8, rule 4).
7. **[Target]** On narrow screens the lists stack, available above members. Responsive layout is not yet specified (CRU-3113).

---

## 13. Empty, loading and error states

**Empty.** **[Existing]** `*matNoDataRow` renders a row spanning every column (`[attr.colspan]="displayedColumns.length"`), padded 16px, in `var(--mat-sys-on-surface-variant)`. The text is different for "nothing exists" and "nothing matches":

- Nothing exists: `There are no Projects yet`, `No runs are queued, planning or applying right now`.
- Nothing matches: `No Projects match "<term>"`.

The older lists say `No data matching the filter "<term>"` or `There are currently no Pools`, or have no empty row at all (Caster Groups, Blueprint Groups, Alloy and CITE user lists). **[Target]** Every table has a `*matNoDataRow` with the two messages, in the first form above (D13). A table is never silently blank.

**Loading.** **[Existing]** Caster standard pages keep a `loading` signal that starts `true` and is cleared in `finalize`. A `mat-progress-spinner` (diameter 48, indeterminate) is centered below the table in `.table-container`, and the empty row is suppressed while it runs (`@if (!loading())`). Alloy Users and Blueprint Units put a spinner in a `mat-card appearance="outlined"` below the table; other pages replace the table with it (Gallery Collections: `@if (!isLoading) { table } @if (isLoading) { spinner }`, CITE in four files, Gallery in seven). The Hypervisors cards use an 18px spinner and "Loading..." inside the card.

**[Target]** Placement and the "never a spinner and results together" rule (CRU-2889, CRU-2900; both tickets have only titles) are in [ui-conventions.md](ui-conventions.md) section 3. For tables: on first load show only the spinner and no empty message; on refresh with rows already shown, keep the rows and show a non-blocking indicator.

**Error.** **[Existing]** On load failure the Caster standard pages clear the loading flag, show a snackbar with the API's problem title and detail (`problemText(error, "Couldn't load the Projects")`), and leave the table empty, so the empty row then says "There are no Projects yet" for a list that failed to load (the empty row only checks `!loading()`). The Hypervisors page shows the message in an outlined card with an information icon. Other apps rely on the global error dialog. **[Target]** A failed load shows an inline error state in the table area, with the reason and a **Retry** button, in addition to the snackbar; an empty "nothing exists" message must not appear for a failed load, because it says the wrong thing. Message wording is in [ui-conventions.md](ui-conventions.md) section 4.

---

## 14. Dialogs, forms and theming

1. **Dialogs.** Add, edit and confirm flows open `crucible-dialog` and follow [modals.md](modals.md) in full. Caster's standard pages confirm Delete with the shared service: `confirmService.confirm({ title: 'Delete Project', message: 'Are you sure that you want to delete <name>?', confirmText: 'Delete' })`. This spec adds only: the confirm names the record, and the destructive button's label repeats the verb.
2. **Forms in cells.** **[Existing]** Inline editing in a cell is rare: a role `mat-select` in membership lists; Blueprint Roles edits a role name in the header cell with Enter to save and Escape to cancel. **[Target]** Inline edit follows [ui-conventions.md](ui-conventions.md) section 5.
3. **Theming and colors.** **[Existing]** Use theme tokens only (`var(--mat-sys-primary)`, `--mat-sys-on-surface-variant`, `--mat-sys-error-container`); no literal hex colors, as in [colors.md](colors.md). The section icon is `--mat-sys-primary`. A page-level warning (Caster "Workspace operations are disabled") is a `role="status"` block in `--mat-sys-error-container` / `--mat-sys-on-error-container`.

---

## 15. Accessibility (Section 508 / WCAG 2.1 AA): normative

**Table semantics (WCAG 1.3.1, 4.1.2).**

- Use `<table mat-table>` with `<th mat-header-cell>`/`<td mat-cell>`; Material sets the roles. Do not use `<mat-header-cell>`/`<mat-cell>` elements inside a `<table>`, and do not add `role` to a Material table.
- The table has an accessible name: `aria-label="Projects"` on the `<table>` (Caster's standard pages do not set one yet; **[Target]**).
- Plain `<table>` blocks (Hypervisors) use `<th scope="col">`.
- Detail rows are regions (section 10, rule 7).

**Expand control (WCAG 4.1.2, 2.1.1).** Keyboard-operable, with `aria-expanded` and `aria-controls`, either as a `<button>` or as the row itself (section 10, rule 6; D8). A clickable `tr` with no keyboard path is a failure of 2.1.1.

**Names for icon buttons (WCAG 4.1.2, 2.5.3).** Every icon button has an `aria-label` naming the action and, in a row, the record. The `matTooltip` text matches the `aria-label`. A native `title` is not a substitute: it is not shown on keyboard focus.

**Sort (WCAG 4.1.2).** `mat-sort-header` sets `aria-sort` on the header and a described action; keep it and do not wrap header text in a second button. **[Target]** Material sets `aria-sort` but makes no live announcement when the sort changes, and most screen readers do not announce an attribute change, so announce it: update a visually hidden `aria-live="polite"` region (or use `LiveAnnouncer` from `@angular/cdk/a11y`) on `matSortChange` with "Sorted by <column>, ascending", "Sorted by <column>, descending", or, for the third activation, when Material's default cycle returns the table to its source order (`direction` is `''`; set `matSortDisableClear` to remove that state), "Sorting removed".

**Focus (WCAG 2.4.3, 2.4.7).** The order is DOM order; no positive `tabindex`; no `outline: none` on any control (Blueprint Units and others set `style="outline: none"` on row buttons; remove it). Focus returns to the invoking control after a dialog closes (Material does this).

**Disabled controls (WCAG 1.4.1, 3.3.2).** Disabled with a reason (section 8). A disabled control is not the only place the reason appears for a keyboard user (`disabledInteractive`).

**Status and errors (WCAG 4.1.3, 3.3.1).** The paginator range label has `role="status"`. Snackbars announce politely by default. A load error uses `role="alert"` in the table area. Loading is announced with `aria-busy` on the container or an offscreen "Loading" status.

**Color and icons (WCAG 1.4.1, 1.4.11).** Meaning is never by color or icon alone (section 6, column rule 5). Icon contrast follows [colors.md](colors.md).

**Motion (WCAG 2.3.3).** Respect `prefers-reduced-motion` on the expand animation (section 10, rule 9).

**Verify, don't assume.** Run axe or Lighthouse on each admin page, then do a keyboard-only pass (Tab, Shift-Tab, Enter, Space, Escape reach and operate search, sort, paginator, every action, expand), and a screen-reader spot check.

---

## 16. Testing expectations

A page's spec, in the app's unit-test framework, covers:

1. **Structure:** the toolbar row has the section icon, Search, paginator, and nothing else but page-level content; the table has the expected columns in order.
2. **Rows:** rows render with data; the empty message for "nothing exists"; the empty message for "nothing matches".
3. **Search:** a term filters; the **match columns** are asserted (a term in a searched column matches, a term only in a hidden field does not); Clear Search resets and restores focus; the paginator returns to page 1 (once implemented).
4. **Sort:** each sortable header sorts; dates sort by value not text.
5. **Dates:** exact formatted string with the zone pinned (section 7, rule 13); the null case.
6. **Permissions:** with and without each permission, an ordinary permission-gated control is disabled with the reason (not absent), and the API call is not made when it is disabled. For the permitted read-only exception (an actions column omitted because every action would be disabled for the same reason, section 8 rule 4 and section 12 rule 6), assert that the column is absent and that the single explanation is shown.
7. **Actions:** each row action calls its handler with the right row; `stopPropagation` (a click on an action does not toggle the row); the confirm dialog names the record.
8. **Expansion:** one row open at a time; the detail renders only when open; keyboard (Enter and Space on the expand control, whether button or row); `aria-expanded` and `aria-controls`.
9. **States:** the first load shows the spinner and neither the empty message nor rows; a refresh while rows are shown keeps the rows and shows a non-blocking indicator (section 13); a load failure shows the error and not "nothing exists".
10. **Accessibility:** accessible names on icon buttons; axe passes.

The Caster specs are the model: each test states "Verifies / Interacts with / Data" in a leading comment, uses real stores and stub APIs, and fixes `TZ`. End-to-end coverage for the same behaviors belongs in `crucible-tests` (light and dark themes: CRU-2952).

---

## 17. How to adopt

1. Read this spec and [modals.md](modals.md); pick **one** admin page and bring it fully onto the rules; ship it as its own PR (Caster did this one page per PR: Workspaces #699, Projects #702, VLANs #700, Hypervisors #687).
2. Start with the safe changes: toolbar order, search field (section 4), empty and loading states, action `aria-label`s. Then the semantic changes: a keyboard-operable expand control, disabled-with-reason, dates.
3. Replace private date and zone helpers with the Caster pattern (section 7) until the shared formatter exists.
4. Add or update the page's unit spec against section 16.
5. Pages that need server-side paging wait on an API change; mark them with a comment that points to section 5, rule 4, and keep them client-side meanwhile.
6. Point the repo's `AGENTS.md` / `CLAUDE.md` at `design-specs`.

---

## 18. Per-page review checklist

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
- [ ] Dates: viewer-local, 12-hour, short zone; header tooltip says "in your time zone".
- [ ] Row detail and per-row data loads on demand; the list call returns a summary.

Actions:

- [ ] Actions column first; header cell holds Add and bulk actions; row order Open, Edit, Copy, Download, Delete.
- [ ] Every icon button has `aria-label` and `matTooltip` naming the row.
- [ ] Controls in clickable rows call `stopPropagation` on click (and key events).
- [ ] No-permission actions are disabled with a reason; sections the user cannot open are not shown.

Expansion:

- [ ] The expand control is a chevron `<button>`, first in the actions column, with `aria-expanded` and `aria-controls` (D8); detail has `id`, `role="region"`, `aria-label`; one row open at a time; detail rendered only when open.
- [ ] Nested table has its own search, sort, paginator.

States:

- [ ] `*matNoDataRow` with "nothing exists" and "nothing matches" messages.
- [ ] Spinner only, no rows or empty message, on first load; error state with Retry on failure.

Membership pages:

- [ ] Available on the left, members on the right; titles and icons as section 12; each list has named Search and paginator.

Accessibility and tests:

- [ ] No `outline: none`; no positive `tabindex`; axe passes; keyboard-only pass done.
- [ ] Spec covers section 16.

---

## 19. References: code this spec was derived from

Paths are `repo/path` as of November 2026. "main" is each repo's default branch.

- `caster.ui/src/app/admin-app/component/admin-workspaces/` (`admin-workspaces.component.html`, `active-runs/active-runs.component.{html,scss,ts}`, `locking-status/`), `admin-projects/`, `admin-vlans/` (`vlans.component.html`, `pool-list/`, `pools/`, `vlan-feedback.service.ts`), `admin-hypervisors/`, `admin-modules/`, `admin-groups/` (`admin-groups.component.html`, `admin-groups-detail/`, `admin-groups-member-list/`, `admin-groups-membership-list/`), `admin-roles/system-roles/`, `admin-container/`.
- `caster.ui/src/app/project/component/project-memberships/` (`project-memberships/`, `project-member-list/`, `project-membership-list/`).
- `caster.ui` commits: #620 (header and layout standard), #687 (Hypervisors), #699 (Workspaces), #700 (VLANs), #702 (Projects).
- `caster.api/src/Caster.Api/Features/Modules/Requests/GetAll.cs`, `Features/Runs/Requests/GetAll.cs`, `GetByWorkspace.cs`; `Domain/Models/Project.cs`, `Run.cs`.
- `blueprint.ui/src/app/components/admin/` (`admin-competency-frameworks/`, `admin-groups/`, `admin-roles/`, `admin-users/`, `admin-units/`, `admin-unit-users/`, `admin-container/`); `blueprint.ui/src/app/utilities/timezone-abbr.ts`.
- `player.ui/src/app/components/admin-app/` (`admin-app.component.{html,ts}`, `admin-user-search/`, `admin-view-search/`, `admin-app-template-search/`, `admin-roles/roles/`); `player.ui/src/app/pipes/time-zone-abbr.pipe.ts`.
- `steamfitter.ui/src/app/components/admin/` and `scenarios/`, `scenario-templates/` membership lists.
- `gallery.ui/src/app/components/admin/` (`admin-collections/`, `admin-exhibits/`, `admin-groups/`, `admin-users/`, `admin-roles/`), `collections/collection-memberships/`, `exhibits/exhibit-memberships/`.
- `cite.ui/src/app/components/admin/` (`admin-evaluations/`, `admin-scoring-models/`, `admin-groups/`, `admin-roles/`, `admin-evaluation-memberships/`), `data/ui/ui-data.service.ts`.
- `alloy.ui/src/app/components/admin-app/` (`admin-app.component.html`, `events/`, `event-templates/`, `admin-groups/`, `admin-users/`, `admin-roles/`).
- `Crucible.Common.Ui/projects/@crucible-common/src/lib/` (`crucible-dialog`, `comn-header-bar`, `crucible-theme`, `comn-settings`, `comn-auth`, `crucible-landing-background`).
- `@angular/material` 21.2.14 `fesm2022/table.mjs` (`_updatePaginator`), `snack-bar.mjs` (`politeness` default `polite`), `paginator.mjs` (`disabledInteractive` on its buttons).
- Tickets: CRU-2763, CRU-2885, CRU-2886, CRU-2581, CRU-2892, CRU-2649, CRU-3099, CRU-2576, CRU-2544, CRU-2889, CRU-2900, CRU-2952.

---

## 20. Decisions for review

These are the places where the apps disagree, or where this spec proposes a number that no app implements. Each is a choice for the reviewer.

- **D1. Disabled with a reason vs hidden.** Chosen: disabled with the reason for actions on a visible list; hidden only for sections the user cannot open at all. Basis: Caster Projects, Alloy, CITE, Gallery, Steamfitter and Caster VLANs/Groups disable; Blueprint Units, Frameworks and Add Role hide; Caster membership lists omit the column. Alternative: hide, which is quieter but leaves users unable to learn why an action is missing.
- **D2. Users, Groups, Roles icons.** Chosen `mdi-account-multiple`, `mdi-account-group`, `mdi-lock`. Basis: Users: Caster and Alloy (and Player's page toolbar) use `account-multiple`, CITE, Gallery, Steamfitter and Blueprint use `account`; Roles: five apps use `lock`, Blueprint `shield-account`; Groups: Blueprint uses `account-multiple`, all others `account-group`. Alternative: `mdi-account` for Users (4 apps).
- **D3. Paginator placement.** Chosen: right after the search field. Basis: Caster standard pages and Player. Alternative: right edge (`margin-left: auto`: Blueprint Units, Alloy and CITE lists via `button-end`).
- **D4. Search wording.** Chosen: "Search" everywhere; the Groups pages' "Search Groups" is dropped. Alternative: keep object-specific labels.
- **D5. "Light" client-side list threshold.** Proposed 1,000 rows and about 2 KB per row. Not derived from measurements; the reviewer sets the numbers.
- **D6. Server-side paging contract.** Proposed `skip`, `take`, `sort`, `sortDirection`, `search`; response `{ items, totalCount }`; stable default sort ending in ID. No API implements it. Alternatives: `pageIndex`/`pageSize` (matches `mat-paginator`), or a `Link`/`X-Total-Count` header instead of an envelope.
- **D7. Last-row bottom border.** Chosen: every row has one, the last included (Material default). Alternative: no border under the last row, which needs a style rule on every table.
- **D8. Expand control and icon.** **Decided: pattern A.** A chevron `<button>` placed first (leftmost) in the actions column, `mdi-chevron-down` rotating to up when open (the Connections page does this), because a visible chevron shows which rows expand and which one is open, which helps users keep their place in a table. Alternatives not chosen: `mdi-chevron-right` rotating to down (Blueprint's sidebar uses chevron-right), and pattern B, the row itself as the control with `tabindex`, Enter and Space and `aria-expanded` (the VLAN pool list does this); B also meets WCAG 2.1.1 and 4.1.2 and stays acceptable on a page not yet converted.
- **D9. Zone-less API timestamps.** Chosen: treated as UTC by the shared formatter. This needs each API to confirm whether it emits `Z`; I could not confirm it from code for all seven.
- **D10. "No value" in any cell.** Chosen: an empty cell; `-` with a tooltip for a value not loaded yet; words in muted text where the absence changes what the user can do ("Never synced", "No version"); never red. Alternatives: an em dash for every empty value; "None" or "N/A" as cell text.
- **D11. Locale.** Chosen: the browser's locale, as the Caster formatters do. Alternative: fix `en-US` so every viewer sees the same layout (Blueprint's abbreviation helper does this).
- **D12. Shared pieces.** Proposed: a shared date formatter and a shared table toolbar in `@cmusei/crucible-common`. Today there are eight copies of date formatting and zone logic and none of the toolbar.
- **D13. Empty-state wording.** Chosen: `There are no <Things> yet` and `No <Things> match "<term>"` (Caster standard pages). Alternative: the older `No data matching the filter "<term>"` still on Caster Groups, VLAN pools and the membership lists.
- **D14. Action order and Delete last.** Chosen Open, Edit, Copy, Download, Delete. Alternative: Delete first (Caster Groups, VLAN pools).
- **D15. Row icon size.** Chosen: 24px in header and rows. Alternative: 18px in rows (Blueprint, CITE, Gallery).
- **D16. Tooltips.** Chosen: `matTooltip` plus `aria-label`; `title` is retired. Basis: `title` is not shown on keyboard focus.
