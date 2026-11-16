---
name: crucible-merge-risk
description: Score the merge risk of a change or PR as low, medium or high with Crucible's rubric, and explain the gaps behind the score. Use when the user asks how risky a PR or change is, how much review it needs, or how much attention a PR deserves, for their own work or a teammate's PR in any Crucible repo.
---

# Crucible merge risk

Gives a human reviewer a quick read on how much attention a change needs, and why. The score is a judgment aid, not a gate. The gaps behind it are the useful part.

## Who scores

- **Someone else's PR:** score it yourself.
- **A change you wrote, or helped write:** have an independent model score it. Authors underrate their own risk. Run the crucible-review skill's `review.sh` with the `risk` lens and the `risk` reviewer from its `reviewers.json`, and present its result.

## What to look at

- the diff against the base (`git diff <base>...<head>`)
- the task or PR description: what the change is meant to do
- the automated tests that ran at the head commit, and their results, when you know them

## Categories

Rate each category **low**, **medium** or **high** risk. Missing evidence counts as the worse rating.

| Category | Weight | Low ✅ | Medium 👀 | High ⚠️ |
| --- | --- | --- | --- | --- |
| Alignment | 1 | Matches the task; assumptions and drive-bys are documented | Minor undocumented assumptions or drive-bys | Does things the task didn't ask for, or misses part of it |
| Impact | 2 | Contained, away from sensitive areas | Touches shared code or a contract other code uses | Large blast radius, or **widens access, weakens validation, or logs sensitive data** |
| Verification | 2 | Automated tests cover the changed behavior and edge cases, and pass | Partial coverage; untested edge cases are documented | Little or no automated coverage of the changed behavior |
| Rollback cost | 1.5 | Easy to undo | Undoing needs coordination, such as config or deploy order | Hard to undo: destructive migration, data rewrite, deleted data |
| Error detection | 1 | Failures surface in logs or errors | Some paths fail quietly | Swallowed exceptions or fallbacks that hide breakage |

Error detection can be **n/a** for config-only or docs-only changes. Leave it out of the score then.

**Verification:**

- Count only automated tests: unit, integration, and crucible-tests Playwright specs.
- If UI files changed, Verification can't be low unless relevant Playwright specs passed.
- Edge cases must be tested or documented. Where they're only documented, link the code so a human can check it.
- If the change could affect performance and there's no benchmark or load test, list that as a gap.

## Score

Rating values: low = 1, medium = 2, high = 3.

Score = Σ(rating × weight) ÷ Σ(weights of the rated categories).

| Score | Tier |
| --- | --- |
| below 1.5 | low |
| 1.5 to below 2.25 | medium |
| 2.25 or above | high |

Then apply these minimums, which a weighted average can hide:

- **At least high:**
  - authorization or authentication changes, or anything that widens access
  - EF migrations or other irreversible data changes
  - Keycloak realm changes
  - Impact and Rollback cost both rated high
- **At least medium:**
  - API contract changes consumed by the UIs, the Terraform provider or other services
  - SignalR hubs
  - dependency changes, including lockfiles
  - Helm charts and default `appsettings`
  - CI workflows and Dockerfiles
  - Impact or Rollback cost rated high

## Output

Show the tier, then each category with its rating and gaps. Don't show the number.

```markdown
**Merge risk: Medium 👀**

**Alignment:** low ✅
**Impact:** medium 👀
- Changes the Environment Set response used by Caster.Ui ([file](…))
**Verification:** medium 👀
- No test for an Environment Set with no inventory connection ([file](…))
**Rollback cost:** low ✅
**Error detection:** low ✅
```

Keep the gaps short and specific, with links to the relevant files. Name any minimum that raised the tier.
