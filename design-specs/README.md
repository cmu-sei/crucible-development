# Crucible Design Specifications

Use this folder to define design specifications that all Crucible applications should follow. Subdirectories house specifications for specific languages/frameworks.

Repositories should point their `AGENTS.md` / `CLAUDE.md` at this folder, so people and coding agents read the relevant specification before changing shared UI.

## Angular

1. [colors.md](angular/colors.md) - Specification for application colors: each app's brand color, accessible light/dark mode defaults, and operator overrides.
1. [modals.md](angular/modals.md) - Specification for a Crucible Common modal. This was used when creating the [crucible-dialog for Crucible.Common.Ui](https://github.com/cmu-sei/Crucible.Common.Ui/tree/main/projects/%40crucible-common/src/lib/crucible-dialog).
1. [admin-tables.md](angular/admin-tables.md) - Specification for admin pages and tables: page and toolbar layout, search fields, pagination, dates and times, the actions column and permission gating, row expansion, two-list membership pages, and empty/loading/error states.
1. [ui-conventions.md](angular/ui-conventions.md) - Specification for cross-cutting UI conventions: icons, loading indicators, error and success messages, forms, typography, the top bar, and permission descriptions.

## Not yet covered

These are known gaps with no specification yet. Each is tracked in Jira:

- Responsive UIs, including mobile: CRU-3113.
- Section 508 compliance across the apps (the specs above cover accessibility only for what they define): CRU-2827.
- CSS standardization (utility classes vs component-scoped CSS): CRU-2615.
- Light and dark mode test coverage in crucible-tests: CRU-2952.
- Modal testing in crucible-tests: CRU-2951.
