# Crucible Design Specification: Application Colors

**Stack assumption:** **Angular 21 + Material Design 3 (M3)**

This spec defines where each Crucible app's colors come from, how they behave in light and dark mode, and who is responsible for accessibility when the colors are changed. It assumes every app is themed with M3 (`mat.theme(...)` and the `--mat-sys-*` system tokens).

**Accessibility is a requirement.** Crucible is used in U.S. federal and DoD training contexts, so the colors each app ships with must meet **Section 508** (which incorporates **WCAG 2.1 Level AA**) in both light and dark mode. That applies to the colors we ship. When an operator overrides them, the operator is responsible for compliance (§5).

---

## 1. Principles

1. **Every app has one brand color.** Each app has one assigned primary color (§2). It identifies the app, and it is the app's default `primary` color and top-bar color.
2. **Shipped defaults are compliant in both modes.** Out of the box, every app meets WCAG 2.1 AA in light mode and in dark mode.
3. **Light mode is the brand color. Dark mode adjusts only when it has to.** Light mode uses the brand color exactly. Dark mode may replace `primary` with a lighter shade of the same hue, and only when the brand color would otherwise fail contrast against dark surfaces. An app can look slightly different between modes. That is expected and acceptable.
4. **Dark-mode shades are chosen ahead of time and shipped as fixed values.** The compliant dark-mode shade is written into the app's default settings. Apps never compute it at runtime.
5. **Operators may override any color. Overrides are used exactly as given.** The app does not adjust, correct, or derive colors from an operator's value. Making overridden colors compliant is the operator's job.

---

## 2. Brand colors

Each app's brand color is its light-mode `primary` and its top-bar background.

| Application | Brand color (light-mode `primary`) | Text on brand color |
|---|---|---|
| Alloy | `#006B6D` | `#FFFFFF` |
| Blueprint | `#007CB5` | `#FFFFFF` |
| Caster | `#AB650F` | `#FFFFFF` |
| CITE | `#E81717` | `#FFFFFF` |
| Gallery | `#008740` | `#FFFFFF` |
| Gameboard | `#877200` | `#FFFFFF` |
| Player (incl. Player VM, Console) | `#3B62A5` | `#FFFFFF` |
| Steamfitter | `#B1282F` | `#FFFFFF` |
| TopoMojo | `#B8558E` | `#000000` |

Rules:

- The brand color is the default for the app's settings **and** the fallback hard-coded in the app's source. A code fallback for a missing setting must be that app's brand color.
- Apps in the same family (Player, Player VM, Console) share one brand color.
- A new app gets its brand color added to this table before it ships. Pick a color that works with white or black text at 4.5:1 or better, and whose dark-mode shade (§3) keeps the same recognizable hue.

---

## 3. Light and dark mode

### 3a. Light mode

Light mode uses the brand pair from §2 unchanged:

- `--mat-sys-primary` = brand color
- `--mat-sys-on-primary` = text-on-brand color
- Top bar background and text = the same pair

### 3b. Dark mode

The **top bar keeps the brand color in both modes.** Its text sits on the brand color rather than on a dark surface, so the §2 pair stays compliant, and users see the same app identity in either mode.

Material's `primary` role also colors text buttons, links, focused outlines, selected states, and action icons that sit **directly on dark surfaces**. Most brand colors were picked to carry white text, so they are too dark for this. In dark mode, `primary` is therefore replaced with a lighter shade of the same hue whenever the brand color fails either of these checks:

| Check | Minimum | WCAG criterion |
|---|---|---|
| `primary` against the dark `surface` (used as text) | 4.5:1 | 1.4.3 Contrast (Minimum) |
| `primary` against the highest dark surface container (used as icons, outlines, and component boundaries) | 3:1 | 1.4.11 Non-text Contrast |
| `on-primary` against the dark-mode `primary` | 4.5:1 | 1.4.3 Contrast (Minimum) |

Every current brand color fails these checks, so every app ships a dark-mode override. These are the defaults:

| Application | Dark-mode `primary` | Dark-mode `on-primary` |
|---|---|---|
| Alloy | `#66A6A7` | `#000000` |
| Blueprint | `#0094D9` | `#000000` |
| Caster | `#CC7812` | `#000000` |
| CITE | `#EF5A5A` | `#000000` |
| Gallery | `#00A34D` | `#000000` |
| Gameboard | `#A68C00` | `#000000` |
| Player (incl. Player VM, Console) | `#6A8DCA` | `#000000` |
| Steamfitter | `#DD676D` | `#000000` |
| TopoMojo | `#C472A1` | `#000000` |

How these values were chosen, so new shades are picked the same way:

- Keep the brand color's hue and saturation, and raise only its lightness until the color passes all three checks with margin: at least **5.5:1** against the dark `surface` and **3.6:1** against the highest surface container. The measurements used the M3 baseline dark surface (`#141218`) and highest dark surface container (`#36343B`). The margin is there because each app's M3 palette tints its surfaces a little differently.
- Choose the `on-primary` value (black or white) that gives the higher contrast. For every shade above, that is black, at more than 6:1.
- `on-primary` only colors text and icons drawn on a filled `primary` background, such as filled buttons, FABs, selected chips, and badges. It does not make dark-mode text black in general. Body text, headings, and labels on dark surfaces keep M3's light `on-surface` colors. Top-bar text keeps the §2 text-on-brand color. Text buttons, links, and action icons use the dark-mode `primary` shade itself.
- If an app's brand color already passes all three checks in dark mode, it does **not** get an override. Dark mode then uses the brand pair unchanged. The dark shade is added only when it is needed.

---

## 4. Settings contract

Colors are set through the app's `settings.json`. The keys are:

| Setting | Meaning | Default |
|---|---|---|
| `AppTopBarHexColor` | Brand color: the top-bar background in both modes, and `primary` in light mode | §2 brand color |
| `AppTopBarHexTextColor` | Text/icon color on the brand color, and `on-primary` in light mode | §2 text-on-brand color |
| `AppDarkModePrimaryHexColor` | `primary` in dark mode | §3b dark-mode `primary` |
| `AppDarkModePrimaryHexTextColor` | `on-primary` in dark mode | §3b dark-mode `on-primary` |

Example (Alloy):

```json
{
  "AppTopBarHexColor": "#006B6D",
  "AppTopBarHexTextColor": "#FFFFFF",
  "AppDarkModePrimaryHexColor": "#66A6A7",
  "AppDarkModePrimaryHexTextColor": "#000000"
}
```

Rules:

- The shipped `settings.json` for every app contains all four keys, filled in with the defaults from §2 and §3b. The defaults belong in the base settings file, so they stay in effect underneath any `settings.shared.json` / `settings.env.json` overlay an operator mounts.
- Each of the four values is resolved independently. If a dark-mode key is missing, dark mode falls back to the matching light-mode value (for example, a missing `AppDarkModePrimaryHexColor` falls back to `AppTopBarHexColor`).
- The resolved colors are applied as CSS custom properties: `--mat-sys-primary` and `--mat-sys-on-primary` for the M3 roles, plus the app's top-bar properties. Components use those tokens, for example `var(--mat-sys-primary)`. They must not hard-code a brand hex value or read the setting directly.

---

## 5. Operator overrides

Operators may override any of the four settings, for example to match an organization's own branding.

- **Overrides are used exactly as given.** The app does not check the contrast of an overridden value, does not correct or clamp it, and does not derive a matching shade for the other mode from it.
- **Apps must not calculate compliant variants.** Do not add runtime lightening, darkening, "auto-contrast," or best-text-color logic to the color pipeline, and do not add opt-in settings that turn such logic on.
- **The operator owns compliance for overridden colors.** An operator who changes a color must make sure the result still meets WCAG 2.1 AA in both modes, using the checks in §2 and §3b. That usually means overriding the dark-mode pair together with the light-mode pair. Otherwise dark mode falls back to the new brand color, which may not be compliant on dark surfaces.
- Operator-facing documentation for each app's color settings must say this: overriding colors moves accessibility responsibility to the operator, and the dark-mode keys usually need to be set along with the brand keys.
