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

1. A user who can see a list but cannot perform an action sees the control **disabled with the reason**. For a button the reason is its tooltip (rule 2); any other control shows it as in rule 2. The reason names the missing permission or the blocking fact ("Renaming and deleting a Project need the ManageProjects permission, or ManageProject on this Project"; "In use by 2 MSELs: ..."), and the `aria-label` ends "(not available)". For a disabled control the tooltip carries the reason and the `aria-label` is the name plus "(not available)"; the rule that tooltip and `aria-label` match applies to enabled controls.
2. **A disabled button keeps its tooltip.** Put `matTooltip` on the button itself and set `disabledInteractive`: the button stays focusable, the tooltip opens on hover and on keyboard focus, and `matTooltip` gives the reason as the accessible description. Do not wrap a natively disabled button in a `span` to carry the tooltip: it works for the mouse only.
   Any other control (a `mat-select`, a checkbox, a radio) is disabled normally, and the reason is **visible text** beside it, or a labelled info button (`mdi-information`, `aria-label="Why is <control> unavailable?"`, for example "Why is Role for Jane Doe unavailable?") next to it. A read-only role in a membership list is shown as text, as in [admin-tables.md](admin-tables.md) section 11. Do not rely on a tooltip on these controls: it does not open on keyboard focus.
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
- Without it, the control is disabled, shows the reason (a button: as its tooltip and description; any other control: as visible text or an info button), and **clicking it makes no API call and opens no dialog**.
- For the read-only exception (rule 5), the actions column is absent and the single explanation is shown.

---

## 5. Review checklist

- [ ] Gated actions are disabled with a reason, not absent.
- [ ] Disabled buttons have `matTooltip` and `disabledInteractive` on the button itself; no wrapper `span`.
- [ ] Other disabled controls (select, checkbox, radio) show the reason as visible text or a named info button.
- [ ] Click handlers return early when the action is not allowed.
- [ ] Sections the user cannot open are not offered.
- [ ] Permission info buttons are enabled, labelled and focusable.
- [ ] Specs cover the with and without cases and assert no call is made.
