# Crucible Design Specification: Permissions in the UI

**Applies to:** Every control, page and section in the Crucible Angular applications that depends on a user's permissions · **Stack assumption:** **Angular 21 + Material Design 3 (M3)**

It defers to:

- Admin pages and tables: [admin-tables.md](admin-tables.md).
- Other conventions: [ui-conventions.md](ui-conventions.md).

---

## 1. Principle

Say why; don't hide. An action the user may not perform is shown **disabled with the reason**, not removed. A section or page the user may not open at all is not offered.

The UI checks permissions only to explain and to save a round trip. The API is the authority; the UI never assumes the API will allow what it enabled.

---

## 2. Gating rules

1. A user who can see a list but cannot perform an action sees the control **disabled with the reason**. The tooltip names the missing permission or the blocking fact ("Renaming and deleting a Project need the ManageProjects permission, or ManageProject on this Project"; "In use by 2 MSELs: ..."), and the `aria-label` ends "(not available)". For a disabled control the tooltip carries the reason and the `aria-label` is the name plus "(not available)"; the rule that tooltip and `aria-label` match applies to enabled controls.
2. **Put the tooltip on the control itself and set `disabledInteractive`** (buttons, checkboxes, radios, slide toggles and inputs support it; `mat-select` does not). The button stays focusable, the tooltip opens on hover and on keyboard focus, and `matTooltip` gives the reason as the accessible description. Do not wrap a natively disabled button in a `span` to carry the tooltip: it works for the mouse only.
   For a control without `disabledInteractive` (a `mat-select`), do not disable it: leave it focusable with `aria-disabled="true"`, put the reason in `matTooltip`, and ignore changes in its handler. Or show the value as text with the reason beside it.
3. **`disabledInteractive` does not stop a click on a button.** It removes the native `disabled` attribute, so the control's click handler must itself return when the action is not allowed (`if (!canEdit()) { return; }`), or the dialog opens and the API call is made anyway.
4. A section or page the user cannot open is **hidden** (navigation items, routes), not disabled.
5. A read-only list may omit the whole actions column only when every row action would be disabled for the same reason and there is no page-level action. The reason is then stated once, in the toolbar tooltip or above the list ("You can view members but not change them").

---

## 3. Permission descriptions (Roles pages)

Each permission on a Roles page has a description tooltip beside it.

1. The info button is a `mat-icon-button` with `mdi-information`, `aria-label="About <permission>"` and `matTooltipShowDelay="0"`. It is enabled and keyboard-focusable, and its tooltip opens on focus.
2. The synthetic "All" permission has one description, kept in one shared constant: "Gives permission to perform any action".
3. The roles page is a permission matrix (roles as columns), not a row table. It follows rules 1 and 2 here and the accessibility rules in admin-tables.md section 13, and nothing else in the table sections.
4. Any other place that explains a permission (a disabled button's tooltip) uses the same wording as the Roles page.

---

## 4. Testing

For each gated control, a spec runs with and without the permission and asserts:

- With the permission, the control is enabled and the action runs.
- Without it, the control is disabled, carries the reason as its description, and **clicking it makes no API call and opens no dialog**.
- For the read-only exception (rule 5), the actions column is absent and the single explanation is shown.

---

## 5. Review checklist

- [ ] Gated actions are disabled with a reason, not absent.
- [ ] `matTooltip` and `disabledInteractive` are on the control; no wrapper `span`.
- [ ] Click handlers return early when the action is not allowed.
- [ ] Sections the user cannot open are not offered.
- [ ] Permission info buttons are enabled, labelled and focusable.
- [ ] Specs cover the with and without cases and assert no call is made.
