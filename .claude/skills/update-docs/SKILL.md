---
name: update-docs
description: Use when the user invokes `/update-docs <app-name>` to update Crucible application documentation to reflect the current state of a running app. Triggers a plan-driven documentation update workflow that browses the live app via Playwright, cross-references existing Playwright tests, produces or refreshes a plan file, waits for user approval, implements the approved plan, and validates linting.
---

# update-docs

## Overview

Crucible documentation in `/mnt/data/crucible/crucible-docs/` drifts from the real apps. This skill runs a disciplined, verified documentation update for one app at a time.

**Arg:** `<app-name>` — lowercase directory name matching both `crucible-docs/docs/<app-name>/` and `crucible-tests/<app-name>/` (e.g. `blueprint`, `player`, `cite`, `gallery`, `steamfitter`, `caster`, `alloy`, `topomojo`, `gameboard`).

**Core contract:**
1. Verify claims against the running app via Playwright. Tests and existing docs are *hints*, not truth.
2. Never implement without a user-approved plan.
3. Lint must pass at the end.

## Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. CONTEXT GATHERING                                        │
│    - Verify app is running via Aspire                       │
│    - Main agent: Read full current docs into context        │
│    - Haiku subagent (parallel): digest tests as hints       │
│    - Main agent: read any existing plan in plans/           │
├─────────────────────────────────────────────────────────────┤
│ 2. LIVE VERIFICATION (main agent)                           │
│    - Playwright: log in, browse every sidebar/nav area      │
│    - For each doc claim + test claim, check against app     │
│    - Audit screenshots; capture replacements into plans/img │
│    - Build a diff list: doc wrong / test wrong / both OK    │
├─────────────────────────────────────────────────────────────┤
│ 3. PLAN (main agent)                                        │
│    - Write plans/<app>-update-plan.md                       │
│    - If plan already existed, reconcile + rewrite           │
│    - Include replacement copy, not just bullet points       │
│    - Ask user to confirm before implementing                │
├─────────────────────────────────────────────────────────────┤
│ 4. IMPLEMENTATION (main agent)                              │
│    - Only after user approval                               │
│    - Apply edits directly; main agent already has doc       │
│    - Match existing doc style and conventions               │
├─────────────────────────────────────────────────────────────┤
│ 5. LINT VALIDATION (main agent)                             │
│    - Run /mnt/data/crucible/crucible-docs/lint-docs.sh      │
│    - Fix errors by editing content, NOT rules               │
│    - Only touch .vale.ini / .markdownlint-cli2.yaml if      │
│      absolutely unavoidable, and tell the user why          │
└─────────────────────────────────────────────────────────────┘
```

## Step 1 — Context gathering

**1a. Confirm the app is running** — call `mcp__aspire__list_resources` and check that the app's API and UI resources are `Running` / `Healthy`. If not, stop and tell the user to start Aspire.

**1b. Read the current docs fully into main context.** Use `Read` on `/mnt/data/crucible/crucible-docs/docs/<app>/index.md` with no offset. Do not summarize via subagent. You will be writing replacement copy that matches the existing style (admonition conventions, heading depth, numbered-step format, table layouts) and citing specific line numbers — a summary loses that fidelity. Typical doc is 1000–2000 lines / ~15–25k tokens, which fits fine.

**1c. Dispatch a Haiku subagent (in parallel with 1b if practical) to digest the tests.** Tests are a *hint source*, not something you edit, so a summary is fine. Prompt template:

> Read the Playwright test plan at `/mnt/data/crucible/crucible-tests/<app>/<app>-test-plan.md` if present, plus the directory structure of `/mnt/data/crucible/crucible-tests/<app>/tests/`. Return a list of feature areas covered and the specific claims each test asserts about the running app (button names, tabs, URL routes, statuses, field names). Under 800 words. Do not editorialize.

**1d. Main agent:** check `plans/<app>-update-plan.md` in `crucible-docs`. If it exists, read it fully. Treat it as one more hint, not truth — it may describe changes already implemented.

**Why this split:** Doc content is the thing you'll edit, so it must be in main context at full fidelity. Test content is just a cross-reference signal, so a subagent summary is enough and keeps the token budget available for live-app verification and plan drafting.

## Step 2 — Live verification

Set up Playwright once per session. For Crucible, the existing seed file is at `/mnt/data/crucible/crucible-tests/seed.spec.ts`. Use `mcp__playwright-test__planner_setup_page` with no arguments (uses default seed), then navigate to the app's UI URL.

Auth is Keycloak at `https://localhost:8443`, user `admin` / password `admin`. See `/mnt/data/crucible/crucible-tests/shared-fixtures.ts` for the shared auth helper if you need it.

For each doc/test claim:
- Open the relevant UI area via `browser_navigate` or `browser_click`.
- Use `browser_snapshot` to inspect the accessibility tree (preferred over screenshots — faster, structured).
- Record: matches / doc wrong / test wrong / both wrong. Note exact button labels, tab names, dropdown options.

**Minimum coverage per app:**
- Login landing page + topbar
- Primary nav (sidebar or top tabs) — every top-level item
- Admin section (if present) — every admin page
- Detail view for at least one representative object
- At least one create/edit form (just open it; don't save)
- Any URL patterns mentioned in docs (copyable URLs, direct-access routes)

**Don't** try to execute destructive flows (delete, push integrations, launch event) unless the user asked for it.

### Screenshot audit

While browsing the app, check every `![...](img/...)` reference in the doc against the live UI.

1. Parse all image references from the doc (step 1b loaded it). Each reference points to a file under `docs/<app>/img/`.
2. For each referenced screenshot, navigate to the matching UI view in Playwright.
3. Visually compare the existing image (use `Read` on the `.png` to view it) against a fresh `mcp__playwright-test__browser_take_screenshot` of the same view. Consider a screenshot stale if **any** of these are true:
   - UI elements shown in the old screenshot no longer exist
   - New elements are present that the old screenshot doesn't show
   - Labels, titles, or wording differs
   - Layout/branding has materially changed (e.g. new topbar, theme overhaul)
4. For each stale screenshot, save a replacement via `browser_take_screenshot` into `/mnt/data/crucible/crucible-docs/plans/img/<same-filename>.png`. Keep the same filename so the eventual swap-in is a straight file replace.
5. Match framing to the original as closely as possible: same viewport (1920×1080 is the Playwright config default), same logical view, same dropdowns/menus open-or-closed. If the original showed an expanded dialog or menu, expand the same one before capturing.
6. Do NOT overwrite files in `docs/<app>/img/` directly — all proposed replacements live under `plans/img/` until the user approves the plan.

If a doc references an image that doesn't exist at all (broken link), flag that in the plan too.

## Step 3 — Plan

Write `/mnt/data/crucible/crucible-docs/plans/<app>-update-plan.md`. Create the `plans/` dir if missing (it's gitignored).

**Plan must contain:**

1. **Header:** target file, branch, app version observed, verification method.
2. **Executive summary:** 3–6 bullet buckets of change.
3. **Section-by-section edits.** For every change:
   - Cite the line numbers or heading the change applies to
   - Provide **replacement copy**, not just "update X"
   - Explain *why* (what the app actually does)
4. **Screenshot updates** — dedicated section listing every stale screenshot found in step 2's audit. For each: the image filename, the doc section/heading that references it, why it's stale (one line), and the path to the proposed replacement under `plans/img/`. Also list any broken image references (referenced file doesn't exist).
5. **Flagged-for-verification list** for any claim you could not confirm in this pass (e.g. integration enabled only in deployed state).
6. **Execution checklist** — unchecked TodoWrite-style list of every concrete edit, including "Replace `img/<filename>.png` with `plans/img/<filename>.png`" entries for each stale screenshot.
7. **Out of scope** section so the user knows what's deliberately untouched.

**Reconciliation rule when a prior plan exists:** re-verify every section of the old plan against the live app. Keep what's still valid, delete what's already implemented, add what's newly out of sync. The final plan is a full rewrite, not a diff.

**Style matching:** before drafting replacement copy, skim 2–3 completed sections in the current docs to match:
- Heading depth conventions
- Step list style (numbered vs. bulleted, "To add a X" vs. imperative)
- Whether tables or lists are used for field inventories
- Admonition style (`!!! note`, `!!! important`)

Once written, present the plan path and a one-paragraph summary to the user and explicitly ask for confirmation before step 4. **Do not start implementing without approval.**

## Step 4 — Implementation

After user approval, apply the plan directly from the main agent using `Edit` (and `Write` only for full rewrites). Reasons to stay in main context:

- The doc is already loaded from step 1b.
- The plan contains verbatim replacement copy — implementation is mechanical, not judgment-heavy.
- It's one file; no parallelism available.
- Step 5 (lint) may require content edits and benefits from main-agent familiarity with the doc.

Work through the plan's Execution Checklist in order. Preserve existing style (heading depth, table/list conventions, admonition usage). Do not make changes outside what the plan prescribes.

**Screenshot replacements:** for each stale screenshot approved in the plan, replace the old file with a versioned copy:

1. Determine the new filename by incrementing the version suffix. If the existing file has no version suffix (e.g. `screenshot.png`), the new name is `screenshot-v2.png`. If it already has a suffix (e.g. `screenshot-v2.png`), increment it (`screenshot-v3.png`).
2. Copy `plans/img/<filename>.png` to `docs/<app>/img/<new-versioned-filename>.png` via Bash `cp`.
3. Delete the old file via Bash `rm`.
4. Update every `![...](img/<old-filename>.png)` reference in the doc to `![...](img/<new-versioned-filename>.png)`.

Leave `plans/img/` intact as an audit trail until the user cleans the plans directory.

## Step 5 — Lint validation

Run the docs repo's lint script:

```bash
cd /mnt/data/crucible/crucible-docs && bash lint-docs.sh
```

This runs `vale` and `markdownlint-cli2`. If either fails:
- Read the errors carefully.
- **Fix by editing content.** Rephrase, break long lines, add alt text, correct heading levels.
- **Do NOT edit `.vale.ini`, `.vale/` styles, or `.markdownlint-cli2.yaml` unless there is no reasonable content fix.** If you absolutely must touch a rule, tell the user why and what you changed before committing.

Re-run until clean. Report final status and the path of the updated doc. **Do not delete the plan document** — leave `plans/<app>-update-plan.md` in place after implementation so it can be referenced later.

## Quick reference — typical discrepancies

| Symptom | Usual cause |
| --- | --- |
| Doc references buttons that don't exist | UI was refactored; doc wasn't updated |
| Doc missing entire sections/tabs | Features added without doc update |
| Doc uses outdated terminology | Rename happened (e.g. "Role" → "Duty") |
| Test asserts specific version string | Test hard-coded a pre-release version |
| Doc has `<!-- TODO -->` stubs | Prior update left unfinished |
| Docs describe Player/Gallery/CITE flows inline | Integration behavior changed; cross-reference |
| Screenshot shows missing tabs or old branding | UI refactor since last capture |

## Common mistakes

- **Implementing without the plan being approved.** Always wait for user confirmation.
- **Trusting the test file.** Tests drift too. Live app wins.
- **Skipping the live verification for "obvious" sections.** Every section must be eyeballed in the real app at least once.
- **Loosening lint rules to avoid fixing content.** Be conservative; content fixes are almost always possible.
- **Dispatching a subagent for implementation.** The main agent already has the doc loaded and the plan is mechanical — editing directly is faster and preserves fidelity.
- **Not reconciling a stale plan file.** Old plans may describe changes already implemented. Re-verify.

## Red flags — stop and re-check

- About to write replacement copy for a section you haven't viewed in the live app: **stop, browse it first.**
- About to claim "matches" for a section based only on doc + test agreement: **stop, verify in app.**
- About to edit `.vale.ini` to silence an error: **stop, try a content fix first.**
- About to skip the lint step because "it was probably fine": **run it anyway.**

## File layout this skill produces

```
/mnt/data/crucible/crucible-docs/
├── plans/                           # gitignored
│   ├── <app>-update-plan.md         # this skill writes/rewrites this
│   └── img/                         # proposed screenshot replacements
│       └── <filename>.png
└── docs/<app>/
    ├── index.md                     # this skill edits this
    └── img/
        └── <filename>.png           # step 4 copies from plans/img/
```
