---
description: Update Crucible app documentation to reflect the running app. Takes an app name (e.g. blueprint, player, cite).
argument-hint: <app-name>
---

Invoke the `update-docs` skill for the application named `$1`.

Follow the skill's full workflow:
1. Gather context (read docs fully in main context; Haiku subagent for tests; main agent reads any existing plan)
2. Verify against the running app via Playwright, including a screenshot audit — capture replacements into `plans/img/` for any stale images
3. Write or reconcile `plans/$1-update-plan.md`
4. **Stop and wait for user approval before implementing**
5. Apply the plan directly in the main agent once approved (doc is already loaded)
6. Run `/mnt/data/crucible/crucible-docs/lint-docs.sh` and fix any errors by editing content (not rules)

If `$1` is empty, ask the user which app to target before starting.
