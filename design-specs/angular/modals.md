# Crucible Design Specification: Modals & Dialogs

**Status:** Active · **Applies to:** All Crucible Angular applications (Player, Caster, Alloy, Steamfitter, CITE, Gallery, Blueprint, etc.) · **Stack assumption:** **Angular 21 + Material Design 3 (M3)** (via the `@angular/material` dialog primitives)

This spec targets **Angular 21** and assumes every Crucible app is themed with **Material Design 3 (M3)** — i.e. `mat.theme(...)` with the `--mat-sys-*` system tokens, not the legacy Material 2 (M2) theming APIs. Wherever this document refers to "the M3 theme," "system tokens," `matButton` appearance values, or `mat.dialog-overrides()`, it is describing the Angular 21 + M3 contract. The few notes about M2 (e.g. `color="primary"`, legacy `mat-*-button` directives) exist only to flag what **not** to carry into new code; new shared code targets Angular 21 + M3.

This specification defines one consistent contract for every modal in every Crucible app. A modal is any content presented in a Material dialog (anything opened via `MatDialog.open(...)`), whether the dialog renders a dedicated dialog component or an inline `TemplateRef`.

The goal is that a user moving between Crucible apps — or between two dialogs in the same app — encounters the same structure, typography, spacing, button conventions, and **accessibility behavior** every time. Modals should never look bespoke per feature.

**Accessibility is a requirement, not a nice-to-have.** Crucible is used in U.S. federal and DoD training contexts, so every modal must satisfy **Section 508** (which incorporates **WCAG 2.1 Level AA**). The good news mirrors Principle 2: Material's dialog primitives are accessible by default — they set `role="dialog"`, wire `aria-labelledby`/`aria-describedby`, trap and restore focus, and support Escape. Almost every accessibility defect in Crucible dialogs comes from *fighting* those defaults (positive `tabindex`, content outside the documented wrappers, missing labels), not from a gap in Material. §7 is the normative accessibility contract; it is as binding as the structural rules.

---

## 1. Principles

1. **One structure, no exceptions.** Every modal uses the same three-part Material skeleton: title → content → actions. There is no such thing as a modal that "just" renders a form or a heading floating in the overlay.
2. **Less CSS is the goal. Material's defaults are the design.** A correctly themed M3 Material app already gives every dialog the right font, type scale, padding, and button layout — for free, with zero per-dialog CSS. The dialog problems we see are almost never "missing CSS"; they are **config bugs** (a theme font name that nothing declares) and **structure bugs** (content placed outside `mat-dialog-content`). Fix the config and the structure and the styling falls out automatically. Before adding any CSS rule, you must be able to answer: *why is this needed, and why isn't the Material default good enough here?* If you can't, delete it.
3. **The overlay inherits theme tokens — do not re-assert them.** Material renders dialogs in a CDK overlay, but that overlay is appended under `<html>`, where the M3 theme defines its `--mat-sys-*` tokens. Dialogs inherit font and color from those tokens like any other component. Re-declaring `font-family`, type sizes, or colors on the dialog container is redundant and is exactly the "more CSS to fix CSS" habit we are removing.
4. **Spacing is structural, not decorative.** Padding comes from the standard Material wrappers (`mat-dialog-content`, `mat-dialog-actions`) out of the box. Do not hand-roll margins to fake padding; do not place content directly in the dialog with no wrapper.
5. **One primary action, on the right.** Each modal has exactly one primary (affirmative) action and at most one secondary (dismiss) action. The primary is visually dominant and right-most.
6. **Quiet chrome, not quiet content.** Keep the dialog *chrome* utilitarian: no accent backgrounds, no decorative dividers, no per-modal color theming. The only styled emphasis is the primary button. This is a rule about **decoration, not about content** — it constrains how the shared component frames a dialog, and it does **not** forbid the informational text an individual dialog needs. A warning, a hint, instructions, or a file-size/overwrite note under an upload control belongs in `mat-dialog-content` and does not violate this principle. "Quiet" means *don't decorate*; it does not mean strip out the words a user needs to act safely. When such content genuinely needs to stand out (a destructive-action warning, a server error), convey it with text and the appropriate system token (e.g. `var(--mat-sys-error)` for an error; `var(--mat-sys-on-surface-variant)` for a secondary hint), never with a decorative banner or accent background.

---

## 2. The required structure

Every modal uses the same three-part skeleton: **title → content → actions**. There are two shapes — a confirm (message-only) modal and a form modal. Use the simplest one that fits; do **not** wrap a confirm in a `<form>`.

### 2a. Confirm / message modal (the common case)

Most modals are a prompt plus Yes/No. They have **no `<form>`** — the affirmative button is a plain `type="button"`:

```html
<h2 mat-dialog-title>{{ title }}</h2>

<mat-dialog-content>
  <!-- message text only; this is a <p>, not a heading -->
  <p>{{ message }}</p>
</mat-dialog-content>

<mat-dialog-actions align="end">
  <button matButton="outlined" type="button" (click)="cancel()">Cancel</button>
  <button matButton="filled" type="button" cdkFocusInitial (click)="confirm()">
    Yes
  </button>
</mat-dialog-actions>
```

### 2b. Form modal

When the body collects input, wrap content **and** actions in a single `<form>` so `type="submit"` and Enter-to-submit work:

```html
<h2 mat-dialog-title>{{ title }}</h2>

<form [formGroup]="form" (ngSubmit)="save()">
  <mat-dialog-content>
    <!-- form fields; the first focusable field receives initial focus -->
  </mat-dialog-content>

  <mat-dialog-actions align="end">
    <button matButton="outlined" type="button" (click)="cancel()">Cancel</button>
    <button matButton="filled" type="submit" [disabled]="!form.valid || !form.dirty">
      Save
    </button>
  </mat-dialog-actions>
</form>
```

Rules:

- **Title** is always `<h2 mat-dialog-title>`. Never `<h1>`, never a bare `<h2>`/`<div>` that isn't a dialog title, never an `<h3>` for the main title. The heading *level* is intentionally low-stakes: the dialog is announced via `aria-labelledby` pointing at `mat-dialog-title`, so the title labels the dialog and does **not** participate in the page's heading outline. Pick `<h2>` for consistency, not to slot into a surrounding `<h1>/<h2>/<h3>` hierarchy — that hierarchy doesn't apply inside the overlay.
- **Body** is always inside `<mat-dialog-content>`. This is the element that carries Material's horizontal padding *and* the element Material wires to `aria-describedby`. Content placed outside it will butt against the dialog edge and won't be announced as the dialog's description — this is the single most common cause of the "no padding / clipped text" complaint.
- **Actions** are always inside `<mat-dialog-actions align="end">`. Never lay buttons out with `class="d-flex justify-content-around"`, `fxLayoutAlign="space-around center"`, or any other ad-hoc flex row.
- **Forms** wrap content and actions together so that `type="submit"` and Enter-to-submit work. The `<form>` goes *outside* `mat-dialog-content`/`mat-dialog-actions` and *below* the title.
- **Initial focus** is set declaratively with `cdkFocusInitial` (see §7) — never with a positive `tabindex`.

---

## 3. Buttons

| Role | Style | Position | Label |
|------|-------|----------|-------|
| Primary / affirmative (Save, Create, Export, Import, Delete, OK, Yes) | `matButton="filled"` | **Right-most** | Verb in **Title Case** |
| Secondary / dismiss (Cancel, No, Close) | `matButton="outlined"` | Left of primary | **Title Case** |

> **Do not add `color="primary"` in M3.** The `color` input on buttons is an **M2-only API** (the Angular Material button docs say so explicitly), and every current Crucible app is themed with M3 (`mat.theme(...)`, `--mat-sys-*` tokens). Under M3, `matButton="filled"` *is* the primary-toned (filled) button — it already takes its fill from the theme's primary palette — so adding `color="primary"` does nothing and reads as a copy-paste leftover. Write the primary as `matButton="filled"` with no `color`. (If you are ever working in a legacy M2 app, `color="primary"` still applies there — but new shared code targets M3.)

> **Button syntax — use the current `matButton` attribute, not the legacy directives.** Angular Material's per-style button directives (`mat-flat-button`, `mat-stroked-button`, `mat-raised-button`, `mat-button`) are superseded by a single `matButton` attribute that takes an appearance value. For a **new** component like this shared dialog, write the new syntax from the start so we don't have to migrate it later. The mapping (verified against Angular Material's button API — the appearance value is `outlined`, **not** `outline`):
>
> | Legacy directive | New syntax |
> |---|---|
> | `<button mat-flat-button>` | `<button matButton="filled">` |
> | `<button mat-stroked-button>` | `<button matButton="outlined">` |
> | `<button mat-button>` | `<button matButton>` (or `matButton="text"`, the default) |
> | `<button mat-raised-button>` | `<button matButton="elevated">` — but **don't** use this for dialog actions |
>
> The full appearance set is `text | filled | tonal | outlined | elevated`. Both forms render identically today; the legacy directives still work but should not be used in new code. (On `color`: see the M3 note above — don't add `color="primary"` in M3-themed apps; `matButton="filled"` is already primary-toned.)

Rules:

- Order in DOM: **secondary first, primary last**, with `align="end"` so the primary lands on the right.
- **Exactly one** `matButton="filled"` per modal. Do not give two buttons the filled (primary) styling.
- Do **not** use `matButton="elevated"` (legacy `mat-raised-button`) for dialog actions (legacy elevation look). Use `matButton="filled"` for primary, `matButton="outlined"` for secondary.
- **Labels are Title Case verbs**, never ALL-CAPS (`NO`/`YES` → `No`/`Yes`) and never system-flavored (`Submit` → the actual verb: `Save`, `Export`, `Import`). The label must also be a meaningful, self-describing accessible name (§7) — `OK`/`Yes` is acceptable only when the title makes the action unambiguous.
- **Tab order:** rely on DOM order — secondary first, primary last — and do **not** set positive `tabindex` values on dialog buttons. Positive `tabindex` ( `tabindex="1"`, `"2"`, `"3"`, …) is a **WCAG 2.4.3 (Focus Order) defect**: it pulls elements into a separate, document-wide tab sequence that runs *before* every `tabindex="0"`/natural element, so keyboard users land on the right-most button first and then tab backward to Cancel — the reverse of the visual order. Initial focus is handled by `cdkFocusInitial` (§7), not by tab index. Keep any existing keyboard accelerators (e.g. `hotkeyAction="ENTER"`) on the primary button. *(Migration note: most existing Crucible dialogs carry `tabindex="1"`/`"2"`/`"3"` on their action buttons — remove these as part of adopting this spec.)*
- **Destructive confirms** (delete) still use `matButton="filled"` for the affirmative button per current Crucible convention — the confirmation prompt itself carries the warning, not button color. (If an app already has an established `warn` destructive pattern, keep it; do not introduce a new one.) Color must never be the *only* signal of which action is destructive — the label and prompt text carry that meaning (WCAG 1.4.1, Use of Color).

---

## 4. Typography & font

The app's standard UI font (Crucible standard: **Open Sans**) and the M3 type scale (title size/weight, body size, line-height) apply inside the dialog **automatically** when the theme is configured correctly. You do not size dialog text per component, and you do not re-assert the font on the dialog container — Material derives the title, body, and label fonts from the theme's type tokens, which the dialog inherits.

The font problems we actually have are configuration bugs, not missing dialog CSS. Fix them at the source:

- **Make the theme font name agree with the declared `@font-face`.** The common silent bug: a theme declares `typography: '"Open Sans", sans-serif'` while the app's only `@font-face` rules are named `'open_sansregular'` / `'open_sansbold'`. Material's tokens then resolve to a system fallback because *nothing* declares `'Open Sans'`. Fix by making the names agree (declare an `@font-face` family named `'Open Sans'`, or point the theme at the family that is actually declared) — once, in the theme. Every dialog then inherits the correct font with no dialog CSS.
- **Delete dead inline font declarations.** Remove any `style="font-family: 'open_sansregular', …"` (and similar) scattered on components. They reference fonts that no longer exist and silently fall back to the browser default; deleting them lets the theme take over.
- **Secondary/explanatory text** within content (e.g. a path or hint under a title) uses `var(--mat-sys-on-surface-variant)`; it is plain `<p>`, not another heading. This is a token reference, not a custom size.

If — and only if — the desired title/body sizing genuinely differs from the M3 defaults across the whole app, change it once by overriding the relevant `--mat-sys-*` typography tokens in the theme, never by sizing text on individual dialogs.

---

## 5. Colors, spacing, sizing

- **Colors:** use Material system tokens only — `var(--mat-sys-on-surface)`, `var(--mat-sys-on-surface-variant)`, `var(--mat-sys-outline-variant)`, etc. No literal hex values, no per-modal accent colors. This keeps light/dark themes correct automatically.
- **Padding** is provided by the standard Material wrappers out of the box; individual modals should not set their own title/content/action padding. The "no padding / clipped text" symptom is the structure bug described in §2 (content outside `mat-dialog-content`) — fix it there, not with CSS. For app-wide padding changes, use `dialog-overrides()` tokens (§6).
- **Width:** prefer Material defaults (the M3 dialog is `min-width: 280px`, `max-width: 560px` out of the box). When a specific modal needs different sizing, set it **in the `MatDialog.open()` config**, not in CSS:

  ```ts
  this.dialog.open(NameDialogComponent, { width: '420px', maxWidth: '90vw', data });
  ```

  This is the documented Material API and keeps sizing co-located with the call site. Reserve a CSS `min-width`/`max-width` on a content wrapper for the case where the *content itself* establishes the minimum (e.g. a single form field) and you don't control every call site. Do **not** set width in both places — the dialog-config value and a CSS rule on the container will fight; pick one (config wins for whole-dialog sizing). Never use a fixed pixel width with no `maxWidth`/`max-width`, which breaks on mobile. For an app-wide default size change, use the `container-max-width`/`container-min-width` `dialog-overrides()` tokens (§6).
- **Tall content:** when a modal body can overflow (long lists, many fields), make the *content* scroll, not the whole dialog. `mat-dialog-content` already does this — Material applies `overflow: auto` and caps the dialog to the viewport, so the title and actions stay pinned while the body scrolls. Only add an explicit `max-height: 60vh; overflow-y: auto;` on an inner container if you need a tighter cap than Material's default; do not put it on the whole dialog.
- **Remove layout hacks:** delete negative margins (`margin-top: -20px`), `justify-content-around` button rows, and `.d-flex.justify-content-around { padding-block }` patterns. They are superseded by the standard structure.

---

## 6. Shared styling — fix the theme, not each dialog

Consistency comes from a correct M3 theme plus the standard structure (§2), **not** from a per-app dialog stylesheet. With the theme configured correctly, font, type scale, padding, color, and button layout are all inherited — so the right amount of dialog-specific selector CSS is zero. Any app-wide adjustment goes through `mat.dialog-overrides()` tokens, not hand-written rules.

**Step 1 — get the theme right (this is what actually fixes dialogs).** In the app's theme setup, the typography font name must match a declared `@font-face` family (see §4). For example:

```scss
@use '@angular/material' as mat;

html {
  @include mat.theme((
    color: ( /* … */ ),
    typography: '"Open Sans", sans-serif',  // must match a real @font-face family
  ));
}
```

That single `typography` value generates the `--mat-sys-*` type tokens (headline, body, label) that the dialog inherits. There is nothing to re-declare on the dialog container.

**Step 2 — the dialog CSS you should write is zero.** There is no cosmetic rule "most apps need." Do not reach into Material's internals with raw selector overrides like `.mat-mdc-dialog-container { … }` or `.mat-mdc-dialog-title::before { … }` — those target undocumented implementation details with no public contract and can break silently on a Material upgrade. (For example, `.mat-mdc-dialog-title::before` is a `width: 0`, 40px-tall baseline strut, not "reserved icon space" — there is nothing to reclaim, and `display: none` on it only risks shifting title alignment.) Writing CSS like this is exactly the "more CSS to fix CSS" habit Principle 2 exists to stop.

If an app genuinely needs different dialog padding, sizing, or alignment **app-wide**, use the supported `mat.dialog-overrides()` token API — never a raw selector override:

```scss
@use '@angular/material' as mat;

html {
  @include mat.dialog-overrides((
    // Only set what you actually need to change; omit the rest.
    headline-padding: 20px 24px 12px,
    content-padding: 20px 24px,
    actions-padding: 12px 24px 20px,
    actions-alignment: flex-end,
  ));
}
```

Token names are verified against the installed **Angular Material 21** (`@angular/material/dialog/_m3-dialog.scss`). The override keys are the component tokens with the `dialog-` prefix removed, so the full overridable set is:

- **Padding / layout:** `headline-padding`, `content-padding`, `with-actions-content-padding` (the content padding used when the dialog *also* has actions — note the `with-actions-` prefix; there is **no** `actions-content-padding` token), `actions-padding`, `actions-alignment` (value is a flexbox alignment such as `flex-end`, **not** `end`).
- **Container:** `container-shape`, `container-color`, `container-elevation-shadow`, `container-max-width`, `container-min-width`, `container-small-max-width`.
- **Type / color families:** the `subhead-*` (`-font`, `-size`, `-weight`, `-line-height`, `-tracking`, `-color`) and `supporting-text-*` families.

A misspelled override key fails **silently** — Sass emits nothing and the default stands — which is the same silent-fallback trap §4 warns about for fonts. If you're unsure a key exists, grep the installed `_m3-dialog.scss` rather than guessing. If the change you want isn't expressible as a token, that is a strong signal it shouldn't be changed — Material deliberately doesn't expose it.

Anything you're tempted to add as a raw rule must justify itself against Principle 2: *why is this CSS needed, and why isn't the Material default good enough?* If the answer is "to set the font/size/color/padding," it is redundant — fix the theme (Step 1) or use a `dialog-overrides()` token, and write no selector CSS.

**Where it belongs.** Shared dialog conventions should live in the common `@cmusei/crucible-common` theme, not be copy-pasted into every app's local `_dialogs.scss`. A per-app dialog partial is a smell: it almost always means the same handful of overrides have been duplicated across apps instead of fixed once upstream.

> Older apps not yet on M3 `--mat-sys-*` tokens: migrate the theme to M3 rather than re-creating the token values by hand in a dialog stylesheet. The structure (§2) is identical regardless of theming era.

---

## 6b. The shared `crucible-dialog` component (content projection)

§2 defines the structure every modal must produce. In practice, apps should not hand-write that skeleton per dialog — the structure, button conventions, focus rules, and async/error affordances are implemented **once** in the shared `crucible-dialog` component in `@cmusei/crucible-common`, and feature dialogs use it as their template root. This section is the contract for that component; it is what keeps §2–§7 from being re-implemented (and re-broken) in every app.

The shared component is a **presentational shell** — it does not open itself. A feature still calls `MatDialog.open(MyDialogComponent, …)`; `MyDialogComponent`'s template uses `<crucible-dialog>` as its root and projects content (and optionally actions/title) into it.

**Two shapes, one component.** A `form` input selects the §2b form shape (the component renders the single `<form>` wrapping content + actions); with no `form` bound it renders the §2a content shape. Apps pick a shape by binding `form` or not — they never duplicate the skeleton.

### Content projection rules (these prevent two real, shipped bugs)

- **Re-declare `[formGroup]` on the projected content container.** When a form dialog projects `formControlName` fields into the shared component, the fields are *projected* — so Angular resolves `formControlName` against the **declaring** template's injector, not the `<form [formGroup]>` the shared component renders internally. You **must** repeat `[formGroup]="form"` on the projected container, or the dialog throws `Cannot read properties of null (reading 'addControl')` at open time (it compiles clean; it only fails at runtime):

  ```html
  <crucible-dialog [form]="form" (formSubmit)="save()">
    <!-- REQUIRED: re-declare [formGroup] on the projected container -->
    <div crucibleDialogContent [formGroup]="form">
      <mat-form-field><input matInput formControlName="name" cdkFocusInitial /></mat-form-field>
    </div>
  </crucible-dialog>
  ```

- **Declare each projection slot exactly once in the component template.** If the shared component renders the same `<ng-content select="[…]">` in more than one structural branch (e.g. once in the form branch and once in the no-form branch of an `@if`), Angular binds the projected nodes to the slot in the branch that is **not** rendered — so a confirm dialog can come up with its title only and an empty body / no buttons. Define each `ng-content` once (e.g. in a shared `<ng-template>` rendered by both branches via `ngTemplateOutlet`). This is a rule for whoever maintains the shared component, and it is covered by a regression test there.

### Title: string by default, projected when it needs markup

The common case is a plain string title (`title` input → `<h2 mat-dialog-title>`). Some dialogs need markup in the title bar — most often an icon or an inline close button. For those, the shared component exposes an **optional projected title slot** (e.g. `[crucibleDialogTitle]`) rendered inside the same `<h2 mat-dialog-title>`, so the dialog keeps its single accessible-name element (§7) while allowing an icon affordance. Set **either** the string `title` **or** a projected title — not both. Do not hand-write a `<div mat-dialog-title>` to get an icon in; use the projected slot so the `<h2>`/`aria-labelledby` contract is preserved.

### Keep the shared API minimal

The component's job is to encode §2–§7, not to grow a knob per feature. Favor deletion over options: don't add inputs that merely restate a value the component can derive (e.g. a "button vs submit" flag when the presence of `form` already determines it), and don't widen the confirm service's result beyond a boolean — a confirm that needs an embedded control or a structured result is really a **form modal**, so use `<crucible-dialog>` in form/content mode rather than the confirm service. Every projected slot and input must earn its place; the same "why isn't the default enough?" test from Principle 2 applies to the component's API, not just its CSS.

### What stays bespoke (out of scope for the shared component)

A `TemplateRef` opened directly (`MatDialog.open(myTemplateRef)`) has no component class to host `<crucible-dialog>` as its root, and a stepper/wizard dialog has its own internal structure — these are rare and may keep their own markup, **as long as they still satisfy §2 (title → content → actions) and §7 (accessibility) by hand.** "Bespoke structure" is not a license to skip the skeleton or the a11y contract.

---

## 7. Accessibility (Section 508 / WCAG 2.1 AA) — normative

Every modal MUST meet Section 508, which adopts WCAG 2.1 Level AA. Material's dialog gives you most of this for free; the rules below are the contract, with the WCAG success criteria each one satisfies. Where a rule says "Material default," the requirement is *don't break it*.

### Labeling & roles (WCAG 1.3.1, 4.1.2)

- **Dialog name.** The dialog must have an accessible name. Using `<h2 mat-dialog-title>` (§2) is sufficient: Material sets `role="dialog"`, `aria-modal="true"`, and `aria-labelledby` pointing at the title automatically. If a dialog has **no** visible title (rare, discouraged), pass `ariaLabel` in the `MatDialog.open()` config — never ship an unnamed dialog.
- **Dialog description.** Body content inside `<mat-dialog-content>` is wired to `aria-describedby` automatically. Content placed outside the wrapper is *not* announced as the description — another reason §2's structure is mandatory, not cosmetic.
- **No redundant ARIA.** Do not hand-add `role="dialog"`, `aria-modal`, or `aria-labelledby` — Material owns them. Redundant or conflicting ARIA is itself a 4.1.2 defect.

### Focus management (WCAG 2.4.3, 2.1.2, 2.4.7)

- **Initial focus** is set with **`cdkFocusInitial`** on the appropriate element — never with a positive `tabindex`:
  - *Confirm modal:* put `cdkFocusInitial` on the **primary** button (it's enabled on open).
  - *Form modal:* the primary button is disabled on open (`[disabled]="!form.valid || !form.dirty"`), and a disabled control **cannot receive focus**. So initial focus must go to the **first interactive field** — let Material's default (first tabbable element) stand, or mark the first field `cdkFocusInitial`. Do **not** designate a disabled button as the focus target; focus would silently fall back and the user could land nowhere predictable.
- **Focus trap.** Material traps focus within the open dialog (WCAG 2.1.2, No Keyboard Trap is satisfied *because* Escape/close always provides a way out). Do not disable the focus trap.
- **Focus restoration.** On close, Material returns focus to the element that opened the dialog (WCAG 2.4.3). Don't programmatically move focus elsewhere after close unless you have a specific, documented reason.
- **Visible focus.** Every actionable element must show a visible focus indicator (WCAG 2.4.7). Material buttons and fields do by default — do not remove outlines with `outline: none` or `:focus { outline: 0 }`.
- **Focus order** follows DOM order (secondary then primary). No positive `tabindex` (see §3).

### Keyboard operation (WCAG 2.1.1)

- Everything is operable by keyboard alone. Tab/Shift-Tab moves between controls; **Enter** submits a form modal (the `<form>` + `type="submit"` wiring in §2 is what makes this work); **Escape** dismisses (unless `disableClose`, below).
- Keep existing accelerators (e.g. `hotkeyAction="ENTER"`) on the primary button; they supplement, not replace, native keyboard support.

### Escape / dismiss & guarding work (WCAG 3.3.4)

- **Default: backdrop (click-outside) dismissal is OFF.** The shared dialog component defaults to **not** closing when the user clicks the backdrop outside the dialog box, because an accidental outside-click is an easy way to lose in-progress work without realizing it. Keyboard dismissal via **Escape** stays enabled, and every dialog still has an explicit, keyboard-reachable Cancel/Close button — so there is always a deliberate way out (WCAG 2.1.2). Note that Material's `disableClose: true` suppresses **both** backdrop click *and* Escape; to disable only the backdrop while keeping Escape, set `disableClose: true` and re-enable Escape on the `MatDialogRef`:

  ```ts
  const ref = this.dialog.open(MyDialogComponent, { disableClose: true, data });
  // Keep keyboard dismissal; only the accidental outside-click is suppressed.
  ref.keydownEvents().subscribe(event => {
    if (event.key === 'Escape') { ref.close(); }
  });
  ```

  Bake this behavior into the shared component's default open config so individual call sites get it for free.
- **Fully guarding a dialog (suppress Escape too):** set `disableClose: true` *without* re-enabling Escape **only** on modals that would lose unsaved user input or interrupt an in-flight operation on accidental dismiss (forms with dirty state, multi-step flows, a save in progress). A dialog guarded this way must still offer an explicit, keyboard-reachable Cancel/Close button (so there's always a way out — WCAG 2.1.2).
- **Purely informational or read-only confirm dialogs** still keep Escape (and may also allow backdrop dismissal, since there's no work to lose). The default above only removes the *accidental outside-click*; it does not trap the user. This replaces "keep existing behavior": the rule is the criterion above, not whatever a given dialog happens to do today.

### Color & contrast (WCAG 1.4.1, 1.4.3, 1.4.11)

- **Don't encode meaning in color alone** (1.4.1): the destructive vs. safe action is conveyed by label and prompt text, not button color (§3).
- **Contrast** of text and UI components meets AA automatically when you use M3 system tokens (§5) — `--mat-sys-on-surface`, `--mat-sys-on-surface-variant`, etc. — in both light and dark themes. Literal hex values bypass the themed, contrast-checked palette and are forbidden (§5). Verify the secondary `--mat-sys-on-surface-variant` text still meets 4.5:1 in both themes (it does with the default palette; re-check if a theme overrides surface colors).

### Errors & status messages (WCAG 3.3.1, 3.3.3, 4.1.3)

- **Validation errors** use `<mat-error>` inside the `mat-form-field` (Material associates it via `aria-describedby` and exposes it to assistive tech). Error text must **identify the field and describe the fix** in words, not rely on color or a red border alone (3.3.1/3.3.3).
- **Async status** (saving, success, server error) must be announced, not just shown — see §7b.

### Disabled primary & validation feedback

- A disabled primary button is expected, not an error state. But because a disabled control is **not announced and not focusable**, never make the disabled button the only way a user learns the form is incomplete. Rely on `<mat-error>` messages on the fields for the "why," and ensure those errors are reachable by keyboard/SR.

### Motion (WCAG 2.3.3)

- Rely on Material's default open/close animation; do not add custom animations. Material already honors `prefers-reduced-motion`; custom animations risk violating 2.3.3.

### Wiring & build

- **Module imports:** any NgModule (or standalone component) using `mat-dialog-*` directives must import `MatDialogModule`. Inline `TemplateRef` dialogs frequently miss this — verify it compiles.

---

## 7b. Async, loading, and error states

Real save/create/delete dialogs talk to an API. The "one primary action" rule (§1) must hold while a request is in flight, and the result — success or failure — must be both shown and announced.

- **In-flight:** disable the primary action and reflect progress on it so the user can't double-submit. Show a spinner inside the button:

  ```html
  <button matButton="filled" type="submit"
          [disabled]="!form.valid || !form.dirty || saving()">
    {{ saving() ? 'Saving…' : 'Save' }}
    @if (saving()) {
      <mat-progress-spinner mode="indeterminate" diameter="18" aria-hidden="true"></mat-progress-spinner>
    }
  </button>
  ```

  Use a signal (`saving`) or equivalent for the in-flight flag. Changing the label to `Saving…` gives screen-reader users a state cue; the spinner is `aria-hidden` because the label already conveys state. Keep the **single** primary button — do not add a second "loading" button.

  > **Don't reach for `MatButton.showProgress`.** Newer Angular Material docs describe a built-in `showProgress` input (with a projected `progressIndicator` slot) for an in-button spinner — but it is **not present in Angular Material 21.2.x** (the version Crucible runs); binding `[showProgress]` there fails to compile (`NG8002`). Use the plain `@if (saving()) { <mat-progress-spinner …> }` shown above. Re-evaluate only after a Material upgrade actually ships the input (verify against the installed `@angular/material` version, not just the website docs, which track latest).
- **Guard dismissal during a request:** while a request is in flight, the dialog should not be dismissable out from under it — set `disableClose` for the duration (or keep it set and rely on the disabled actions). On success, close via `MatDialogRef.close(result)`.
- **Server errors** are rendered inside `<mat-dialog-content>` (not a toast that disappears, and not outside the wrapper) and announced to assistive tech with an ARIA live region (WCAG 4.1.3, Status Messages):

  ```html
  <p role="alert" class="dialog-error">{{ errorMessage() }}</p>
  ```

  `role="alert"` (assertive live region) makes the error announced the moment it appears, without moving focus. Use `var(--mat-sys-error)` for its color, never a literal hex, and never rely on color alone — the text states what failed.
- **Don't trap the user on failure:** after an error, re-enable the actions so the user can correct input and retry or Cancel. A failed save must never leave every control disabled.

---

## 8. Anti-patterns (these are exactly what to remove)

| Anti-pattern | Replace with |
|---|---|
| Content/heading rendered with **no** `mat-dialog-content` wrapper | Wrap body in `<mat-dialog-content>` |
| `<h1 mat-dialog-title>` or bare `<h2>`/`<h3>` title | `<h2 mat-dialog-title>` |
| Buttons in `class="d-flex justify-content-around"` or `fxLayoutAlign="space-around center"` | `<mat-dialog-actions align="end">` |
| Positive `tabindex` on action buttons (`tabindex="1"`/`"2"`/`"3"`) | Remove it; use DOM order + `cdkFocusInitial` (§3, §7) |
| `cdkFocusInitial` (or initial focus) on a disabled primary button | Focus the first field instead; only focus the primary when it's enabled on open (§7) |
| Hand-added `role="dialog"` / `aria-modal` / `aria-labelledby` | Delete it; Material sets these from `mat-dialog-title` (§7) |
| Unnamed dialog (no title and no `ariaLabel`) | Add `<h2 mat-dialog-title>` or pass `ariaLabel` (§7) |
| `outline: none` / removing focus rings on dialog controls | Keep Material's visible focus indicator (WCAG 2.4.7) |
| Server error shown only in a transient toast or outside `mat-dialog-content` | Render in content with `role="alert"` (§7b) |
| Backdrop click-outside silently discards in-progress work | Default backdrop dismissal **off** while keeping Escape + an explicit Cancel/Close (§7) |
| Fully suppressing Escape (`disableClose`, no Escape re-enable) on a read-only/info confirm | Only fully guard unsaved work or in-flight requests; keep Escape otherwise (§7) |
| Two outline buttons, no clear primary | One `matButton="filled"` (right) + one `matButton="outlined"` |
| `color="primary"` on a button in an M3-themed app | Drop it; `matButton="filled"` is already primary-toned in M3 (§3) |
| Projecting `formControlName` fields into the shared dialog without re-declaring `[formGroup]` on the projected container | Add `[formGroup]="form"` to the `[crucibleDialogContent]` container (§6b) — else runtime `addControl` crash |
| `[showProgress]` on a dialog button (not in Material 21.2.x) | Plain `@if (saving()) { <mat-progress-spinner …> }` inside the button (§7b) |
| `<div mat-dialog-title>` to fit an icon/close button in the title | Set the string `title`, or project the optional title slot inside the `<h2>` (§6b) |
| Primary on the left, dismiss on the right | Dismiss left, primary right (`align="end"`, primary last in DOM) |
| ALL-CAPS labels (`NO`, `YES`) | Title Case (`No`, `Yes`) |
| `matButton="elevated"` / legacy `mat-raised-button` actions | `matButton="filled"` (primary) / `matButton="outlined"` (secondary) |
| Legacy per-style button directives (`mat-flat-button`, `mat-stroked-button`, `mat-button`) in new code | `matButton="filled"` / `matButton="outlined"` / `matButton` (§3) |
| Inline `style="font-family: 'open_sansregular'…"` | Delete it; the font comes from the theme (§4) |
| Re-declaring font/size/color/padding on `.mat-mdc-dialog-container` | Delete it; the dialog inherits these from the M3 theme tokens |
| Raw overrides of Material internals (`.mat-mdc-dialog-container { … }`, `.mat-mdc-dialog-title::before`) | Delete it; for app-wide padding/sizing use `mat.dialog-overrides()` tokens (§6) |
| Per-app `_dialogs.scss` re-asserting Material defaults | Fix the theme font name; keep shared rules in `@cmusei/crucible-common` |
| `margin-top: -20px`, `margin-bottom: 20px` spacing hacks | Standard wrappers; padding is built in |
| Literal hex colors | `var(--mat-sys-*)` tokens |
| Whole dialog scrolls / title scrolls away | Let `mat-dialog-content` scroll (default); add `max-height` on inner content only if a tighter cap is needed (§5) |

---

## 9. Implementation workflow & references

> This section is about **how to build** modals, not how they should look. It complements the design rules above with the tooling and authoritative sources to use while implementing them.

- **Use the official Angular Material documentation as the source of truth** for component APIs, theming, and best practices: **https://material.angular.dev/**. When a question is about *how a Material primitive works* (dialog config, `MatDialogRef`, theming tokens, `align`/`mat-dialog-*` directives, accessibility behavior), consult it before hand-rolling a workaround. This reinforces Principle 2: most "I need custom CSS" instincts are answered by a documented Material default or API.
- **Use the installed `angular-developer` skill** when writing or modifying modal components. It provides version-aware Angular guidance (signals, forms, dependency injection, accessibility/ARIA, component styling, testing, CLI tooling) and should be invoked for the implementation work — building the dialog component, wiring the form, opening it via `MatDialog` — so the code follows current Angular conventions rather than legacy patterns.
- **Order of operations:** invoke `angular-developer` for the Angular/coding mechanics, and check material.angular.dev for any Material-specific behavior; apply the design rules in §1–§8 of this spec on top — accessibility (§7/§7b) is non-negotiable. If the documentation or skill suggests an approach that conflicts with a design rule here, the design rule wins for appearance/structure — but prefer the documented Material way over custom code or CSS.
- **Verify accessibility, don't assume it.** Section 508 / WCAG conformance (§7) is testable: run an automated checker (axe DevTools or Lighthouse) on each dialog, then do a manual pass — keyboard-only (Tab/Shift-Tab/Enter/Escape reach and operate everything, focus is visible, focus returns to the opener on close) and a screen-reader spot-check (the dialog announces its title and description on open; errors announce when they appear). Automated tools catch roughly half of WCAG issues; the keyboard and SR passes are not optional.

---

## 10. Per-modal migration checklist

For each modal in an app, confirm:

Structure & styling:

- [ ] Title is `<h2 mat-dialog-title>`.
- [ ] All body content is inside `<mat-dialog-content>`.
- [ ] All actions are inside `<mat-dialog-actions align="end">`.
- [ ] Exactly one `matButton="filled"`, right-most; dismiss is `matButton="outlined"`, to its left. New code uses the `matButton` attribute, not the legacy `mat-flat-button`/`mat-stroked-button` directives, and does **not** add `color="primary"` in M3 (§3).
- [ ] If the dialog uses the shared `crucible-dialog` component with a projected form, `[formGroup]` is re-declared on the projected `[crucibleDialogContent]` container; a custom title (icon/close button) uses the projected title slot, not a hand-written `<div mat-dialog-title>` (§6b).
- [ ] Button labels are Title Case verbs; existing hotkeys preserved.
- [ ] No inline `font-family`; no negative-margin or `justify-content-around`/`fxLayoutAlign` hacks; no literal hex colors.
- [ ] No dialog-specific CSS re-asserting font, size, color, or padding (those come from the theme). Any CSS that remains answers Principle 2: *why isn't the Material default good enough here?*
- [ ] Confirm modals have **no** `<form>`; form modals wrap content + actions in `<form>` with working submit.
- [ ] Per-modal sizing (if any) is passed via `MatDialog.open()` config, not duplicated in CSS.
- [ ] Component's module imports `MatDialogModule`; the app builds with no errors.
- [ ] For forms/lists that can overflow, content scrolls while title and actions stay pinned.

Accessibility (Section 508 / WCAG 2.1 AA — §7):

- [ ] **No positive `tabindex`** anywhere in the dialog (remove legacy `tabindex="1"`/`"2"`/`"3"`).
- [ ] Initial focus is correct: `cdkFocusInitial` on the primary for a confirm; first field (never the disabled primary) for a form.
- [ ] Dialog has an accessible name (visible `mat-dialog-title`, or `ariaLabel` if titleless) and its body is inside `mat-dialog-content` (so `aria-describedby` is wired).
- [ ] No hand-added `role="dialog"`/`aria-modal`/`aria-labelledby`; no `outline: none` on dialog controls.
- [ ] Keyboard-only pass: Tab/Shift-Tab/Enter/Escape reach and operate every control; focus is visible; focus returns to the opener on close.
- [ ] Backdrop click-outside dismissal is **off** by default (Escape and an explicit Cancel/Close remain); full `disableClose` (Escape suppressed too) is used **only** to guard unsaved input or an in-flight request — and such dialogs still have an explicit Cancel/Close.
- [ ] Destructive vs. safe action is clear from label/prompt text, not color alone.
- [ ] Async dialogs: primary disables + shows progress while in flight; server errors render in content via `role="alert"`; controls re-enable after failure.
- [ ] Validation errors use `<mat-error>` with text that names the field and the fix.
- [ ] Automated check (axe/Lighthouse) passes; screen-reader spot-check announces title, description, and errors.

App-level (once):

- [ ] Theme typography font name matches a declared `@font-face` family — dialogs render in the app font with no per-dialog CSS (§4).
- [ ] `dialog-overrides()` keys (if used) are verified against the installed Material 21 token names (§6) — a misspelled key fails silently.
- [ ] App builds cleanly; spot-check one simple dialog (confirm) and one form dialog (edit) in light and dark themes, including keyboard and contrast.
