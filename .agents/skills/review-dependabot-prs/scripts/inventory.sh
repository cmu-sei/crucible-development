#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Summarizes open Dependabot PRs in a GitHub repo for review: the repo's Dependabot auto-merge
# workflow state, each PR's head commit (the one being reviewed: give it to plan.sh lines as
# N@SHA), merge state, review state, required and other checks, files, each dependency's version
# change (with semver delta and dependency type), the non-lockfile diff
# lines (the manifest change that the PR title can hide), and PRs whose changes are identical
# to another's. Read-only; uses only `gh pr`/`gh repo`/`gh workflow` (no `gh api`). For release
# notes per dependency, run release-notes.sh on a PR.
#
# Anything that can't be read prints an ERROR line instead of a plausible empty result, and the
# script then exits 1 (the inventory is incomplete: re-run it).
#
# Usage: inventory.sh OWNER/REPO [PR_NUMBER ...]
#        (no PR numbers = every open PR authored by app/dependabot)

set -uo pipefail

repo=${1:?usage: inventory.sh OWNER/REPO [PR_NUMBER ...]}
shift

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

errors=0
error() { echo "$*"; errors=$((errors + 1)); }

if (($#)); then
  prs=("$@")
else
  list=$(ghr pr list -R "$repo" --author app/dependabot --state open --limit 100 --json number -q '.[].number') || {
    echo "ERROR: could not list open Dependabot PRs in $repo (gh error above); nothing inventoried" >&2
    exit 1
  }
  mapfile -t prs < <(awk NF <<<"$list" | sort -n)
fi

ghr repo view "$repo" --json defaultBranchRef,squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed \
  -q '"repo: \(.defaultBranchRef.name) branch; merge methods: " + ([(select(.squashMergeAllowed)|"squash"), (select(.rebaseMergeAllowed)|"rebase"), (select(.mergeCommitAllowed)|"merge")]|join(", "))' \
  && echo || error "repo: ERROR (could not read repo settings)"

# The Dependabot auto-merge workflow approves and merges bumps up to its update-types once
# checks pass. Every repo is meant to have it active.
automerge=.github/workflows/dependabot-pr-merge.yml
if wf=$(ghr workflow list -R "$repo" --all --json path,state); then
  state=$(jq -r --arg p "$automerge" '[.[] | select(.path == $p) | .state] | first // "missing"' <<<"$wf")
  types=""
  if [[ "$state" != missing ]]; then
    if yaml=$(ghr workflow view "$automerge" -R "$repo" --yaml 2>"$tmp/wf.err"); then
      types=$(sed -nE 's/^[[:space:]]*update-types:[[:space:]]*["\x27]?([^"\x27#[:space:]]+).*/\1/p' <<<"$yaml" | head -1)
      types="; update-types: ${types:-patch (not set; the reusable workflow default)}"
    elif grep -qi 'could not find workflow file' "$tmp/wf.err"; then
      # Registered by a run on another branch (e.g. an open PR adding it), but not on the default branch.
      state="missing (registered as $state, but not on the default branch)"
    else
      cat "$tmp/wf.err" >&2
      types="; update-types: ERROR (could not read the workflow file)"
    fi
  fi
  echo "auto-merge workflow ($automerge): $state$types"
  # Repos on the shared CI (they have build-and-test.yml) must match Alloy's settings; others needn't.
  if [[ "$state" != active ]]; then
    if jq -e 'any(.[]; .path == ".github/workflows/build-and-test.yml")' <<<"$wf" >/dev/null; then
      echo "WARNING: auto-merge workflow not active (settings deviation)"
    else
      echo "  (not required: this repo isn't on the shared CI)"
    fi
  fi
else
  error "auto-merge workflow ($automerge): ERROR (could not query)"
fi

echo
echo "open Dependabot PRs: ${#prs[@]}"
if ((${#prs[@]} == 0)); then
  ((errors)) && { echo "ERRORS: $errors lookup(s) failed (see ERROR lines above)"; exit 1; }
  exit 0
fi

# Files whose diffs are machine-generated; everything else is shown line by line.
lockfiles='(^|/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|packages\.lock\.json|go\.sum|composer\.lock|Chart\.lock|poetry\.lock|Cargo\.lock|Gemfile\.lock|\.?devcontainer-lock\.json)$'
max_manifest_lines=60
fields=number,title,headRefOid,createdAt,mergeable,mergeStateStatus,reviewDecision,files,statusCheckRollup,body,commits

checks_tmp=$tmp/checks
: >"$checks_tmp"
readable=() unreadable=() dups=() nodiff=()
declare -A seen_hash=()

for n in "${prs[@]}"; do
  echo
  if ! json=$(ghr pr view "$n" -R "$repo" --json "$fields") || ! jq -e '.number' >/dev/null 2>&1 <<<"$json"; then
    error "#$n: ERROR: could not read PR (gh error above); not inventoried"
    unreadable+=("$n"); continue
  fi
  # GitHub computes mergeability lazily; the first read is often UNKNOWN.
  mergeable_note=""
  for _ in 1 2 3; do
    [[ $(jq -r .mergeable <<<"$json") == "UNKNOWN" ]] || break
    sleep 5
    if ! again=$(ghr pr view "$n" -R "$repo" --json "$fields") || ! jq -e '.number' >/dev/null 2>&1 <<<"$again"; then
      mergeable_note=" (ERROR: re-query for mergeability failed; showing the first read)"
      errors=$((errors + 1)); break
    fi
    json=$again
  done
  readable+=("$n")

  # Only required checks gate the merge; the rollup below lists every check.
  if required=$(gh_required_checks "$n" "$repo"); then req_ok=true; else req_ok=false; required='[]'; errors=$((errors + 1)); fi

  # The diff: for the manifest lines, to fill versions the PR text truncates, and to spot duplicates.
  diff_ok=true
  ghr pr diff "$n" -R "$repo" >"$tmp/$n.diff" || diff_ok=false
  # The head this inventory shows: its line in the plan must name this commit. A head that moved
  # between the PR read and the diff read means the two can disagree, so neither is trusted.
  pr_head=$(jq -r .headRefOid <<<"$json")
  head_note=""
  if ! now=$(ghr pr view "$n" -R "$repo" --json headRefOid -q .headRefOid) || ! [[ "$now" =~ ^[0-9a-f]{40}$ ]]; then
    head_note="  << ERROR: could not re-read the head after the diff; re-run"; errors=$((errors + 1))
  elif [[ "$now" != "$pr_head" ]]; then
    head_note="  << ERROR: head moved to $now while this PR was read; re-run"; errors=$((errors + 1))
  fi
  if $diff_ok; then
    deps=$(deps_json "$tmp/$n.diff" <<<"$json") || deps=""
  else
    deps=$(deps_json <<<"$json") || deps=""
  fi
  deps_ok=true
  jq -e 'type == "array"' >/dev/null 2>&1 <<<"$deps" || { deps_ok=false; deps='[]'; errors=$((errors + 1)); }

  jq -r --argjson required "$required" --argjson req_ok "$req_ok" --argjson deps "$deps" --argjson deps_ok "$deps_ok" \
    --arg mnote "$mergeable_note" --arg hnote "$head_note" "$JQ_DELTA$JQ_PLATFORM"'
    def bucket: (if ((.conclusion // "") != "") then .conclusion else (.state // .status // "") end) as $s
      | if $s == "SUCCESS" then "pass"
        elif ($s == "SKIPPED" or $s == "NEUTRAL") then "skip"
        elif ($s | IN("FAILURE","ERROR","TIMED_OUT","CANCELLED","ACTION_REQUIRED","STARTUP_FAILURE","STALE")) then "fail"
        else "pending" end;
    def checkname: if .context then .context else ([.workflowName, .name] | map(select(. != null and . != "")) | join(" / ")) end;
    ([.statusCheckRollup[]? | {name: checkname, b: bucket}]) as $checks
    | "#\(.number) \(.title)",
      "  head: \(.headRefOid)\($hnote)",
      "  opened \(.createdAt[0:10]); mergeable: \(.mergeable)\($mnote); merge state: \(.mergeStateStatus); review: \(.reviewDecision // "none")",
      "  required checks: " + (if ($req_ok | not) then "ERROR (could not query)"
                                elif ($required | length) == 0 then "none reported (none configured, or the PR predates them)"
                                else ([$required[] | "\(.name)=\(.bucket)"] | join(", ")) end),
      "  all checks: " + (if ($checks | length) == 0 then "none" else ([$checks | group_by(.b)[] | "\(.[0].b)=\(length)"] | join(" ")) end),
      ([$checks[] | select(.b == "fail") | "    FAIL: \(.name)"] | .[]),
      ([$checks[] | select(.b == "pending") | "    pending: \(.name)"] | .[]),
      "  files: " + ([.files[]?.path] | join(" ")),
      "  deps:" + (if ($deps_ok | not) then " ERROR (could not parse the PR text; read it: gh pr view \(.number))" else "" end),
      ($deps[] | delta(.from; .to) as $d
        | (if ($d == "removed") then "    \(.name): removed  \(.type // "")"
           else "    \(.name): \(.from // "?") -> \(.to)  [\($d)] \(.type // "")\(if .update then " " + .update else "" end)"
             + (if platform_major(.name; $d) then "  << PLATFORM major: out of scope (planned upgrade)" else "" end)
             + (if angular_peer(.name; $d) then "  << check the new version against the repo @angular/core peer range" else "" end) end)
          + (if .conflict then "  << CONFLICT (\(.via | join(", "))): \(.conflict)" else "" end)
          + (if .note then "  (\(.note))" else "" end))
  ' <<<"$json"

  jq -r --arg n "$n" '.statusCheckRollup[]? | (if .context then .context else ([.workflowName, .name] | map(select(. != null and . != "")) | join(" / ")) end) | "\($n)\t\(.)"' <<<"$json" >>"$checks_tmp"

  if ! $diff_ok; then
    error "  non-lockfile changes: ERROR (could not read the diff: gh pr diff $n -R $repo)"
    nodiff+=("#$n"); continue
  fi

  # Identical changes (file names and changed lines, ignoring blob hashes and hunk offsets) mean
  # Dependabot opened the same update twice.
  hash=$(grep -E '^(diff --git |[-+])' "$tmp/$n.diff" | grep -vE '^(\+\+\+|---) ' | sha256sum | cut -c1-16)
  if [[ ! -s "$tmp/$n.diff" ]]; then
    :
  elif [[ -n "${seen_hash[$hash]:-}" ]]; then
    echo "  duplicate of #${seen_hash[$hash]} (identical changes)"
    dups+=("#$n duplicate of #${seen_hash[$hash]}")
  else
    seen_hash[$hash]=$n
  fi

  # The real change: manifest/Dockerfile/workflow lines, not lockfile churn.
  manifest=$(awk -v lock="$lockfiles" '
    /^diff --git /{ f = $NF; sub(/^b\//, "", f); show = (f !~ lock); if (show) print "    " f ":"; next }
    show && /^(\+\+\+|---) / { next }
    show && /^old mode|^new mode/ { print "      " $0; next }
    show && /^[-+]/ { print "      " $0 }' "$tmp/$n.diff")
  if [[ ! -s "$tmp/$n.diff" ]]; then
    echo "  non-lockfile changes: none (the diff is empty)"
  elif [[ -n "$manifest" ]]; then
    echo "  non-lockfile changes:"
    total_lines=$(wc -l <<<"$manifest")
    head -n "$max_manifest_lines" <<<"$manifest"
    ((total_lines > max_manifest_lines)) &&
      echo "    (diff truncated; $((total_lines - max_manifest_lines)) more lines: gh pr diff $n -R $repo)"
  else
    echo "  non-lockfile changes: none (lockfile-only)"
  fi
done

echo
echo "duplicate PRs (identical changes; close the newer one):"
if ((${#dups[@]})); then printf '  %s\n' "${dups[@]}"; else echo "  none"; fi
((${#nodiff[@]} + ${#unreadable[@]})) && echo "  (not compared, unreadable: ${nodiff[*]} $(printf '#%s ' "${unreadable[@]}"))"

# Required checks added to the repo after a PR was opened never ran on that PR,
# and its merge fails with "N of N required status checks are expected".
# Only PRs that were read count: an unreadable PR isn't missing anything.
echo
echo "check names the newest PR has that others lack (stale base? rebase with: gh pr update-branch N --rebase):"
total=${#readable[@]}
# The newest readable PR runs the current workflows: its check names are the reference. Names that
# only older PRs have are old workflows, not missing checks.
newest=$(printf '%s\n' "${readable[@]}" | sort -n | tail -1)
missing=$(awk -F'\t' -v n="$newest" '$1 == n { print $2 }' "$checks_tmp" | sort -u | while IFS= read -r name; do
  for m in "${readable[@]}"; do grep -qxF "$m	$name" "$checks_tmp" || { echo "$name"; break; }; done; done)
if ((total == 0)); then
  echo "  (no PR could be read)"
elif [[ -z "$missing" ]]; then
  echo "  none"
else
  while IFS= read -r name; do
    lacking=$(for n in "${readable[@]}"; do grep -qxF "$n	$name" "$checks_tmp" || printf '#%s ' "$n"; done)
    echo "  \"$name\" missing on: $lacking"
  done <<<"$missing"
fi
((${#unreadable[@]})) && echo "  (not compared: unreadable PRs $(printf '#%s ' "${unreadable[@]}"))"

if ((errors)); then
  echo
  echo "ERRORS: $errors lookup(s) failed (see ERROR lines above); this inventory is incomplete. Re-run it."
  exit 1
fi
exit 0
