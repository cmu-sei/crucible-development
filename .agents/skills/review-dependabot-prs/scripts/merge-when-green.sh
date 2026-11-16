#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Merges already-reviewed Dependabot PRs one at a time, in the order given. For each PR:
#   1. Reads it. Skips it if it isn't open, conflicts, has changes requested, or is BEHIND a base
#      that requires up-to-date branches (it never runs update-branch: that moves the head, which
#      then needs re-checking; see SKILL.md workflow step 7).
#   2. Waits for its required checks and skips it unless every reported one passed. "No required
#      checks" counts only when gh itself says none are reported; any other error, after retries,
#      skips the PR ("could not query required checks"). It also skips a PR that lacks a required
#      check reported on the last PR merged into the same base: the check never ran on it (the PR
#      predates the workflow), and GitHub would refuse it with "required status checks are expected".
#   3. Tries `gh pr merge` first, with the repo's preferred method (squash > rebase > merge) and
#      --match-head-commit (the locally validated head with --expect-heads, otherwise the head read
#      in step 1), so GitHub refuses a head that moved.
#   4. Approves only if that merge was refused because a review is required, then retries the
#      merge. gh refuses an unapproved PR in a protected repo with "is not mergeable: the base
#      branch policy prohibits the merge" (mergeStateStatus BLOCKED); that counts as a missing
#      review only when GitHub's reviewDecision is REVIEW_REQUIRED, since step 2 already confirmed
#      the checks. A merge refused for any other reason (required checks expected or failing,
#      conflicts, BEHIND, a moved head) is never approved: the PR is skipped with a hint.
# Uses only `gh pr`/`gh repo` (no `gh api`).
#
# Approvals and merges are made as the signed-in gh user. Run this only for PRs the user asked you
# to merge, after reviewing them. --dry-run makes no GitHub writes: it reports what it would do
# ("would merge; would approve first if GitHub requires a review").
#
# Usage: merge-when-green.sh [--dry-run] [--expect-heads STATE_FILE] OWNER/REPO PR_NUMBER [PR_NUMBER ...]
#   --dry-run       read only: check each PR and say what would happen.
#   --expect-heads  local-merge.sh's state file: merge each PR only if its head is still the
#                   commit that was validated locally (`merged=N SHA` lines), and pass that SHA to
#                   `gh pr merge --match-head-commit` so GitHub refuses a head that moved since.
# Exit:  0 if every PR merged (or would merge), 1 if any was skipped, 2 for usage errors.
# Env:   CHECK_TIMEOUT_MIN (default 30) - per-PR wait for required checks
#        CHECK_POLL_SEC    (default 30) - seconds between required-check queries
#        APPROVE_BODY      (default "Reviewed: low-risk dependency bump, CI green.")
#        MWG_RESULTS       if set, append one line per PR to this file:
#                          `merged|would-merge|behind|skipped OWNER/REPO N [reason]` (plan.sh apply)

set -uo pipefail

usage="usage: merge-when-green.sh [--dry-run] [--expect-heads STATE_FILE] OWNER/REPO PR_NUMBER [PR_NUMBER ...]"
dry_run=false heads_file=""
while [[ "${1:-}" == --* ]]; do
  case $1 in
    --dry-run) dry_run=true; shift ;;
    --expect-heads) heads_file=${2:?--expect-heads needs a file}; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
if [[ -n "$heads_file" && ! -r "$heads_file" ]]; then echo "cannot read $heads_file" >&2; exit 2; fi
repo=${1:?$usage}
shift
(($#)) || { echo "no PR numbers given" >&2; exit 2; }
for n in "$@"; do [[ "$n" =~ ^[0-9]+$ ]] || { echo "not a PR number: $n" >&2; exit 2; }; done

timeout_min=${CHECK_TIMEOUT_MIN:-30}
poll_sec=${CHECK_POLL_SEC:-30}
approve_body=${APPROVE_BODY:-"Reviewed: low-risk dependency bump, CI green."}
results=${MWG_RESULTS:-}

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

oneline() { tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//'; }

method=$(ghr repo view "$repo" --json squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed \
  -q 'if .squashMergeAllowed then "squash" elif .rebaseMergeAllowed then "rebase" else "merge" end') ||
  { echo "could not read $repo's merge settings" >&2; exit 1; }
[[ "$method" =~ ^(squash|rebase|merge)$ ]] || { echo "unexpected merge settings for $repo: $method" >&2; exit 1; }
echo "repo $repo: merging with --$method$($dry_run && echo ' (dry run)')"

merged=() skipped=()

record() { if [[ -n "$results" ]]; then printf '%s %s %s %s\n' "$1" "$repo" "$2" "${3:-}" >>"$results"; fi; }
skip() { skipped+=("#$1 ($2)"); record skipped "$1" "$2"; echo "  skipped: $2"; }
behind_steps() { echo "gh pr update-branch $1 -R $repo --rebase, wait for its checks, confirm its changes are the reviewed ones, refresh its plan line, re-run"; }
skip_behind() { skipped+=("#$1 (BEHIND the base, which requires up-to-date branches: $(behind_steps "$1"))"); record behind "$1" "$2"; echo "  skipped: $2; not updating it here"; }

# read_pr N: sets pr_state mergeable review head merge_state base, or pr_err and returns 1.
# GitHub recomputes mergeability after the base moves (e.g. the previous PR's merge), reporting
# UNKNOWN meanwhile, so wait briefly for a settled answer.
read_pr() {
  local out i
  for i in 1 2 3 4 5 6; do
    out=$(ghr pr view "$1" -R "$repo" --json state,mergeable,reviewDecision,headRefOid,mergeStateStatus,baseRefName \
      -q '"\(.state) \(.mergeable) \(if (.reviewDecision // "") == "" then "NONE" else .reviewDecision end) \(.headRefOid) \(.mergeStateStatus) \(.baseRefName)"' 2>"$tmp/err") ||
      { pr_err=$(oneline <"$tmp/err"); pr_err=${pr_err:-gh failed}; return 1; }
    if ! [[ "$out" =~ ^(OPEN|CLOSED|MERGED)\ [A-Z_]+\ [A-Z_]+\ [0-9a-f]{40}\ [A-Z_]+\ [^[:space:]]+$ ]]; then
      pr_err="unexpected output: $(head -c 200 <<<"$out" | oneline)"; return 1
    fi
    read -r pr_state mergeable review head merge_state base <<<"$out"
    if [[ "$pr_state" == OPEN && ( "$mergeable" == UNKNOWN || "$merge_state" == UNKNOWN ) ]] && ((i < 6)); then sleep 5; continue; fi
    return 0
  done
}

# query_checks N: sets checks to the JSON array of the PR's required checks ({name, bucket}).
# Returns 0 if read, 2 if gh says no (required) checks are reported, 1 on any other error (qerr).
query_checks() {
  local rc last
  checks=$(ghr pr checks "$1" -R "$repo" --required --json name,bucket 2>"$tmp/err"); rc=$?
  if ((rc == 0)); then
    jq -e 'type == "array"' <<<"$checks" >/dev/null 2>&1 && return 0
    qerr="unexpected output: $(head -c 200 <<<"$checks" | oneline)"; return 1
  fi
  # gh's exact messages for "nothing reported" (pkg/cmd/pr/checks). Anything else, such as
  # "connect: connection refused", is an error, never "no required checks".
  last=$(awk 'NF { l = $0 } END { print l }' "$tmp/err")
  if [[ "$last" =~ ^no\ (required\ )?checks\ reported\ on\ the\ \'.*\'\ branch$ ]]; then checks="[]"; return 2; fi
  qerr=$(oneline <"$tmp/err"); qerr=${qerr:-"gh exited $rc"}; return 1
}

# reference_checks BASE: sets ref_pr and ref_names (sorted required check names) from the last PR
# merged into BASE, cached per base. Returns 1 (qerr set) if they can't be read.
declare -A ref_pr_cache=() ref_names_cache=()
reference_checks() {
  local b=$1 m qrc
  if [[ -z "${ref_pr_cache[$b]+x}" ]]; then
    m=$(ghr pr list -R "$repo" --state merged --base "$b" -L 1 --json number -q '.[0].number // ""' 2>"$tmp/err") ||
      { qerr="listing merged PRs: $(oneline <"$tmp/err")"; return 1; }
    [[ "$m" =~ ^[0-9]*$ ]] || { qerr="listing merged PRs: unexpected output: $(head -c 200 <<<"$m" | oneline)"; return 1; }
    if [[ -z "$m" ]]; then
      ref_pr_cache[$b]="" ref_names_cache[$b]=""
    else
      query_checks "$m"; qrc=$?
      ((qrc == 1)) && { qerr="#$m (reference): $qerr"; return 1; }
      ref_pr_cache[$b]=$m ref_names_cache[$b]=$(jq -r '.[].name' <<<"$checks" | LC_ALL=C sort -u)
    fi
  fi
  ref_pr=${ref_pr_cache[$b]} ref_names=${ref_names_cache[$b]}
}

# refusal OUTPUT: classifies a failed `gh pr merge`. Anything that isn't plainly about a review
# is checked first, so a message naming both a review and expected checks is never approved.
refusal() {
  if grep -qiE 'status checks? (are|is) expected|required status check|checks? (are|is) (failing|pending|in progress)' <<<"$1"; then echo checks
  elif grep -qiE 'not up to date|up-to-date|BEHIND' <<<"$1"; then echo behind
  elif grep -qiE 'conflict|cannot be cleanly created|DIRTY' <<<"$1"; then echo conflict
  elif grep -qiE 'head (branch|commit|sha|oid)|expected head|match-head-commit|was modified' <<<"$1"; then echo head
  elif grep -qiE 'approving reviews? (is|are) required|reviews? (is|are) required|review required' <<<"$1"; then echo review
  elif grep -qF 'the base branch policy prohibits the merge' <<<"$1"; then echo policy
  else echo other
  fi
}

# skip_refused N KIND OUTPUT: skip a PR whose merge GitHub refused, with the next step.
skip_refused() {
  case $2 in
    checks) skip "$1" "merge refused: required checks not satisfied ($3); if they never ran on this PR (it predates them): gh pr update-branch $1 -R $repo --rebase, wait for its checks, confirm its changes, refresh its plan line, re-run" ;;
    behind) skip_behind "$1" "merge refused: behind the base ($3)" ;;
    conflict) skip "$1" "merge refused: conflicts ($3); comment '@dependabot rebase' and re-run later" ;;
    head) skip "$1" "merge refused: the head moved since it was checked ($3); re-review it" ;;
    *) skip "$1" "merge failed: $3" ;;
  esac
}

for n in "$@"; do
  echo
  echo "=== #$n $(date +%T)"
  read_pr "$n" || { skip "$n" "could not read PR: $pr_err"; continue; }

  if [[ "$pr_state" != "OPEN" ]]; then skip "$n" "$pr_state"; continue; fi

  expected=""
  if [[ -n "$heads_file" ]]; then
    expected=$(awk -v n="$n" '$1 == "merged=" n { print $2; exit }' "$heads_file")
    if [[ -z "$expected" ]]; then skip "$n" "not validated locally: not in $heads_file as merged"; continue; fi
    if [[ "$head" != "$expected" ]]; then
      skip "$n" "head moved since local validation: ${expected:0:7} -> ${head:0:7}; not merging untested code"; continue
    fi
  fi

  if [[ "$merge_state" == "BEHIND" ]]; then skip_behind "$n" "behind the base, which requires up-to-date branches"; continue; fi
  if [[ "$mergeable" == "CONFLICTING" || "$merge_state" == "DIRTY" ]]; then
    skip "$n" "conflicts; comment '@dependabot rebase' and re-run later"; continue
  fi
  if [[ "$review" == "CHANGES_REQUESTED" ]]; then skip "$n" "a reviewer requested changes; not overriding"; continue; fi

  # Wait on required checks only: some statuses (e.g. Dependabot's own ".github/dependabot.yml")
  # can stay pending forever without blocking a merge. A failed query never counts as success.
  deadline=$((SECONDS + timeout_min * 60)) errors=0
  while :; do
    query_checks "$n"; qrc=$?
    if ((qrc == 1)); then
      echo "  required-checks query failed: $qerr"
      ((++errors >= 2)) && break   # each ghr call already retried for about a minute
    else
      errors=0
      ((qrc == 2)) && break
      (($(jq '[.[] | select(.bucket == "pending")] | length' <<<"$checks") == 0)) && break
    fi
    ((SECONDS >= deadline)) && break
    sleep "$poll_sec"
  done
  if ((qrc == 1)); then skip "$n" "could not query required checks: $qerr"; continue; fi

  required=$(jq 'length' <<<"$checks")
  names=$(jq -r '.[].name' <<<"$checks" | LC_ALL=C sort -u)
  failing=$(jq -r '[.[] | select(.bucket == "fail" or .bucket == "cancel") | .name] | join(", ")' <<<"$checks")
  pending=$(jq -r '[.[] | select(.bucket == "pending") | .name] | join(", ")' <<<"$checks")
  if [[ -n "$failing" ]]; then skip "$n" "required checks failing: $failing"; continue; fi
  if [[ -n "$pending" ]]; then skip "$n" "required checks still pending after ${timeout_min}m: $pending"; continue; fi

  # Required checks that never ran on this PR aren't reported at all, so compare with a PR that
  # was merged into the same base. (reference_checks reuses $checks; this PR's are in $names.)
  if ! reference_checks "$base"; then skip "$n" "could not query required checks: $qerr"; continue; fi
  missing=$(LC_ALL=C comm -23 <(awk NF <<<"$ref_names") <(awk NF <<<"$names") | paste -sd, - | sed 's/,/, /g')
  if [[ -n "$missing" ]]; then
    skip "$n" "required checks never ran on this PR: $missing (reported on #$ref_pr, merged into $base), so it probably predates them: gh pr update-branch $n -R $repo --rebase, wait for its checks, confirm its changes, refresh its plan line, re-run"
    continue
  fi
  if ((required == 0)); then
    echo "  note: no required checks reported on this PR, or on $([[ -n "$ref_pr" ]] && echo "#$ref_pr, the last PR merged into $base" || echo "any PR merged into $base (none found)")"
  else
    echo "  required checks green ($required)"
  fi

  if $dry_run; then
    if [[ "$review" == "APPROVED" ]]; then echo "  would merge --$method (already approved)"
    else echo "  would merge --$method; would approve first if GitHub requires a review (reviewDecision: $review)"; fi
    merged+=("#$n"); record would-merge "$n"; continue
  fi

  match=${expected:-$head}
  if out=$(ghr pr merge "$n" -R "$repo" "--$method" --match-head-commit "$match" 2>&1); then
    merged+=("#$n"); record merged "$n"; echo "  MERGED"; continue
  fi
  out=$(oneline <<<"$out")
  echo "  merge refused: $out"
  kind=$(refusal "$out")
  if [[ "$kind" != review && "$kind" != policy ]]; then skip_refused "$n" "$kind" "$out"; continue; fi
  # Re-read before approving: never approve a head other than the one checked above.
  if ! read_pr "$n"; then skip "$n" "merge refused ($out) and could not re-read the PR: $pr_err"; continue; fi
  if [[ "$head" != "$match" ]]; then skip "$n" "head moved since it was checked (${match:0:7} -> ${head:0:7}); not approving: re-review it"; continue; fi
  # "Policy prohibits" (BLOCKED) with the checks confirmed above is a missing review only if
  # GitHub says a review is required.
  if [[ "$kind" == policy && "$review" != "REVIEW_REQUIRED" ]]; then
    skip "$n" "merge refused by the base branch policy, not for a missing review (reviewDecision: $review): $out"; continue
  fi

  echo "  a review is required: approving"
  if ! aout=$(ghr pr review "$n" -R "$repo" --approve -b "$approve_body" 2>&1); then
    skip "$n" "approve failed: $(oneline <<<"$aout")"; continue
  fi
  # GitHub can take a moment to count the approval, so retry while the refusal is still the review.
  ok=false
  for attempt in 1 2 3; do
    if out=$(ghr pr merge "$n" -R "$repo" "--$method" --match-head-commit "$match" 2>&1); then ok=true; break; fi
    out=$(oneline <<<"$out"); kind=$(refusal "$out")
    echo "  merge after approval, attempt $attempt, refused: $out"
    [[ "$kind" == review || "$kind" == policy ]] || break
    ((attempt < 3)) && sleep 10
  done
  if $ok; then merged+=("#$n"); record merged "$n"; echo "  MERGED"
  elif [[ "$kind" == review || "$kind" == policy ]]; then skip "$n" "approved, but the merge is still refused: $out"
  else skip_refused "$n" "$kind" "$out"; fi
done

echo
echo "$($dry_run && echo 'would merge' || echo 'merged'): ${merged[*]:-none}"
echo "skipped:"
if ((${#skipped[@]})); then printf '  %s\n' "${skipped[@]}"; else echo "  none"; fi
((${#skipped[@]} == 0))
