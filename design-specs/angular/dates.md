# Crucible Design Specification: Dates and Times

**Applies to:** Every date and time shown to a user in the Crucible Angular applications · **Stack assumption:** **Angular 21**

Scenarios are designed and run with partners in different time zones, so every date and time a user reads must say which zone it is in. This spec fixes one format, one way to read API timestamps, and one formatter.

It defers to:

- Tables, search and sort: [admin-tables.md](admin-tables.md).
- Messages and other conventions: [ui-conventions.md](ui-conventions.md).

---

## 1. Rules

1. **Viewer's local time, with a zone.** Every date and time (every timestamp) is shown in the viewer's local time zone with a short zone name, for example `18:45 EST`. Never raw UTC, never an ISO string, never a time without its zone.
2. **One format.** Two-digit day, month name, year, 24-hour time, short zone: `06 Nov 2026 16:40 EST`. Crucible is used by international, military and government partners, and a 24-hour clock avoids the AM/PM and noon/midnight misreads of a 12-hour one; a month name avoids day/month swaps (`6/5`). The formatter sets `hourCycle: 'h23'` and joins the parts itself (`formatToParts`), so the order is the same whatever the viewer's locale; midnight is `00:00`.
   - A **date-only** value (a calendar date with no time of day, such as `2026-11-06`) shows the date only, `06 Nov 2026`. It is a calendar date, not an instant: format it in UTC (`timeZone: 'UTC'`, no zone name) and never convert it to local time, or a viewer west of UTC sees the previous day.
   - A time-only value shows `16:40 EST`.
3. **The zone name comes from `Intl.DateTimeFormat`** with `timeZoneName: 'short'`, computed for the date shown, not today, so a November date reads `EST` even in October. A zone with no short name shows an offset such as `GMT+8`. Never replace it with an invented abbreviation.
4. **The locale is the browser's** for month and zone names. Pass `undefined` as the locale; the order of the parts and the 24-hour clock are fixed by the formatter, not by the locale.
5. **API timestamps are UTC.** A string with no zone designator is read by `new Date()` as local time, which silently shifts every value. The shared formatter parses a timestamp with no zone designator as UTC, through one parse function (`parseApiDate`).
6. **Sort by value, not text.** Sort by the value `parseApiDate` returns (a number or `Date`), never by the formatted text and never by the raw ISO string (strings with different fractional-second precision mis-order: `2026-11-06T21:40:00.5Z` sorts before `2026-11-06T21:40:00Z` although it is later). Bare `Date.parse` is not used: it reads a zone-less timestamp as local time, so the order would disagree with the displayed time.
7. **Search matches the formatted text** the user sees (admin-tables.md section 4).
8. **A missing value is an empty cell.** A value that means "has not happened" is written in words by the page ("Never synced"), not as a blank. The general "no value" rule is in admin-tables.md section 6.
9. **Relative times** ("3 minutes ago") always carry the absolute time with its zone as the tooltip and the `aria-label`.
10. **Date column headers name the event** ("Created", "Started"), not "Date". For a column with a time of day, the header description says the time is "in your time zone"; a date-only column does not.
11. **Durations are not dates.** Show them as `1 h 30 min`, never as clock times.

---

## 2. The shared formatter

All Crucible apps use one formatter, so the rules above are implemented once. It belongs in `@cmusei/crucible-common`. Each app implements exactly this contract until the library provides it, so the move is a change of import and nothing else.

- `parseApiDate(value)`: the one parser (rule 5), used by the formatters and by sorting.
- `formatDateTime(value)`: `06 Nov 2026 16:40 EST`.
- `formatDate(value)`: `06 Nov 2026`. A date-only value is formatted in UTC (rule 2); a timestamp is shown in the viewer's zone.
- `formatTime(value)`: `16:40 EST`.
- Each accepts a string, a `Date`, `null` or `undefined`, and returns `''` for a missing or invalid value. A `YYYY-MM-DD` string is a date-only value; a `Date` argument is always an instant.
- Each applies rules 2 to 5 above.
- A pipe wraps each function for templates.

An app does not keep a private formatter, a private zone-abbreviation helper, or a `DatePipe` with a fixed pattern for a value shown to a user.

---

## 3. Testing

A spec that asserts a rendered date pins the time zone and the locale (for example `vi.stubEnv('TZ', 'UTC')`, or the formatter's zone parameter) and asserts the exact string, including the zone name (`14 Oct 2026 12:30 UTC`), so it does not depend on the machine. It also covers the missing-value case, a date-only value in a zone west of UTC (it keeps its calendar day), and a zone-less timestamp (parsed as UTC, shown in the viewer's zone, and sorted by that instant).

---

## 4. Review checklist

- [ ] Every timestamp is viewer-local, 24-hour, with a short zone name; date-only values are shown as calendar dates in UTC.
- [ ] Values come from the shared formatter; no `DatePipe` pattern, no private helper.
- [ ] Zone-less API timestamps are read as UTC.
- [ ] Date columns sort by value, and their headers name the event (with "in your time zone" where there is a time of day).
- [ ] A missing value is an empty cell, or words where "has not happened" matters.
- [ ] Specs pin the zone and locale.
