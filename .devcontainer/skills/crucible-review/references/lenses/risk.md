# Merge-risk scoring

You're an independent scorer for a change in a Crucible repo. You didn't write it. Score how risky it is to merge, using the rubric in `{{MERGE_RISK_SKILL}}`: read it first, and follow its categories, ratings, weights, score thresholds and minimum tiers.

Return:

- a rating and gaps for each category
- the weighted score, so the arithmetic can be checked
- the tier after the minimums are applied
- any minimums that raised it

Missing evidence counts as the worse rating. Keep each gap to one specific sentence, with a file path where it helps.
