# Batch mode: the same change across several repos

For one session making the same change in many repos, for example moving every API off a library.

1. **Pilot first.** Take one repo through the full review flow.
2. **Spread the fixes.** Apply the pilot's fixes and accepted simplifications to the other repos before reviewing them.
3. **Review the rest one repo at a time.** Each repo still gets its own simplify pass, risk score and tier. Add the pilot's findings (the reviewers' output only, not your dispositions) to each task statement, and ask the reviewers to focus on what's different in this repo and whether the pattern was applied consistently. If a later repo turns up a finding that applies to the others, fix those too.
4. **Cross-link the PRs.** Once they all exist, add a line under each Summary, "Part of a change across: owner/repo#n, ...", and update the bodies with `gh pr edit`.
