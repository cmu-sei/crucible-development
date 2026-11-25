# Crucible Design Specification: Dates and Times

**Applies to:** Every date and time shown to a user in the Crucible Angular applications · **Stack assumption:** **Angular 21**

Scenarios are designed and run with partners in different time zones, so every date and time a user reads must say which zone it is in. This spec fixes one format, one way to read API timestamps, and one formatter.

It defers to:

- Tables, search and sort: [admin-tables.md](admin-tables.md).
- Messages and other conventions: [ui-conventions.md](ui-conventions.md).

---

## 1. Rules

1. **Viewer's local time, with a zone.** Every date and time is shown in the viewer's local time zone with a short zone name, for example `6:45 PM EST`. Never raw UTC, never an ISO string, never a time without its zone.
2. **One format.** Month-name date, 12-hour time, short zone: `Nov 6, 2026, 4:40 PM EST`. The formatter sets `hour12: true`; without it the viewer's locale decides, and a viewer in `en-GB` or `de-DE` sees `22:40`.
   - A value with no time of day shows the date only: `Nov 6, 2026`.
   - A time-only value shows `4:40 PM EST`.
3. **The zone name comes from `Intl.DateTimeFormat`** with `timeZoneName: 'short'`, computed for the date shown, not today, so a November date reads `EST` even in October. A zone with no short name shows an offset such as `GMT+8`. Never replace it with an invented abbreviation.
4. **The locale is the browser's.** Pass `undefined` as the locale and set `hour12` explicitly.
5. **API timestamps are UTC.** A string with no zone designator is read by `new Date()` as local time, which silently shifts every value. The formatter treats a timestamp with no zone designator as UTC.
6. **Sort by value, not text.** Sort by the underlying value, compared as a number or `Date` (`Date.parse(value)`), never as a raw ISO string: strings with different fractional-second precision mis-order (`2026-11-06T21:40:00.5Z` sorts before `2026-11-06T21:40:00Z` although it is later).
7. **Search matches the formatted text** the user sees (admin-tables.md section 4).
8. **A missing value is an empty cell.** A value that means "has not happened" is written in words by the page ("Never synced"), not as a blank. The general "no value" rule is in admin-tables.md section 6.
9. **Relative times** ("3 minutes ago") always carry the absolute time with its zone as the tooltip and the `aria-label`.
10. **Date column headers name the event** ("Created", "Started"), not "Date", and the header tooltip says the time is "in your time zone".
11. **Durations are not dates.** Show them as `1 h 30 min`, never as clock times.

---

## 2. The shared formatter

All Crucible apps use one formatter, so the rules above are implemented once. It belongs in `@cmusei/crucible-common`. Each app implements exactly this contract until the library provides it, so the move is a change of import and nothing else.

- `formatDateTime(value)`: `Nov 6, 2026, 4:40 PM EST`.
- `formatDate(value)`: `Nov 6, 2026`.
- `formatTime(value)`: `4:40 PM EST`.
- Each accepts a string, a `Date`, `null` or `undefined`, and returns `''` for a missing or invalid value.
- Each applies rules 2 to 5 above.
- A pipe wraps each function for templates.

An app does not keep a private formatter, a private zone-abbreviation helper, or a `DatePipe` with a fixed pattern for a value shown to a user.

---

## 3. Testing

A spec that asserts a rendered date pins the time zone and the locale (for example `vi.stubEnv('TZ', 'UTC')`, or the formatter's zone parameter) and asserts the exact string, including the zone name (`Oct 14, 2026, 12:30 PM UTC`), so it does not depend on the machine. It also covers the missing-value case.

---

## 4. Review checklist

- [ ] Every date and time is viewer-local, 12-hour, with a short zone name.
- [ ] Values come from the shared formatter; no `DatePipe` pattern, no private helper.
- [ ] Zone-less API timestamps are read as UTC.
- [ ] Date columns sort by value, and their headers name the event with an "in your time zone" tooltip.
- [ ] A missing value is an empty cell, or words where "has not happened" matters.
- [ ] Specs pin the zone and locale.
