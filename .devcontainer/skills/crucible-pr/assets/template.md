# PR description template

## Body

Use these sections in this order, in your own words:

```markdown
## ⚠️ Breaking Changes

- <what the operator or user must do when deploying, and why>

## Summary

<2-5 sentences: the problem and what this PR does about it>

## User-facing changes

- <change>

## API changes

- <changed request or response, and what callers see>

## Related

- <links to related public PRs or issues>

<details>
<summary>Technical details</summary>

- <detail>

**Testing**

- <how the change was tested>

</details>

<Risk & review section: the output of record.sh summary, which ends with the crucible-pr marker comment>
```

- **Always present:** Summary, User-facing changes, Risk & review and Technical details. User-facing changes can say "None."; Summary and Technical details always have content.
- Visible sections come first, for release-note readers and operators. The collapsed sections come last, for reviewers.
- If the user asks for an extra section, such as a walkthrough video with a link they provide, put it after the visible sections and before the collapsed ones.
- Paste the `record.sh summary` output as it is, at the very end. Its collapsed header shows the tier and review status; the risk label shows the tier in PR lists.
- **Every other section is left out when it would be empty:** Breaking Changes (as defined below; never write "Breaking Changes: None"), API changes and Related.

## What counts as a breaking change

A change is breaking **only if a user or operator must take action when deploying**. For example:

- a new required setting, or a renamed or removed one
- a migration that needs a manual step, a backup or downtime
- any other manual step, such as re-seeding data or changing deploy order

These are **not** breaking, because nothing has to be done when deploying:

- API contract changes: changed request or response shapes, removed or renamed fields or endpoints, new status codes, newly refused requests (400, 403, 404, 409). List these under **API changes**, so anyone calling the API can find them.
- legacy data that stops working
- a new optional setting with a safe default

Put the last two under User-facing changes if someone using Crucible would notice them, and under Technical details if not.

For each real breaking change, say exactly what to do, for example "Set the new required `Section:Key` setting before upgrading; the API won't start without it."

## Writing rules

- **Describe the code as it ends up.** Don't narrate intermediate versions or the order things were tried in. Approaches that were ruled out, and why, belong in Technical details when they'd save a reviewer from suggesting them.
- **Plain language.** Write the Summary for someone who doesn't already know the problem, in terms a non-developer can follow.
- **Don't overstate.** No alarming wording, no hype. Say plainly what changes.
- **Cross-repo references:** write a PR or issue in another repo as `owner/repo#n` every time it appears, not just the first. A bare `#n` links to this repo.
- **Title:** the outcome in imperative mood, e.g. "Add vSphere ISO storage groups".
  - No conventional-commit prefix or scope.
  - No tool names.
- **User-facing changes:** one bullet per change someone using the UI or running Crucible would notice. New settings go here, with their names and defaults. A change that API callers would notice goes under API changes instead.
- **API changes:** one bullet per contract change: the endpoint, what changed, and what a caller now sees. Internal method signatures that aren't part of the HTTP API go in Technical details.
- **Technical details:** what a reviewer needs and the diff doesn't make obvious: design decisions, anything worth a close look, tests added, whether there's a migration. End with how the change was tested. Check claims against the code before stating them, and don't restate the diff file by file.
