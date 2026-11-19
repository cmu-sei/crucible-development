#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Plan/apply for Dependabot reviews, in the spirit of `terraform plan` / `terraform apply`.
# A dry-run review writes a plan document (see plan-template.md) whose ```dependabot-plan block
# lists every reviewed PR with the head commit that was reviewed:
#
#   version 1
#   created 2026-11-13T15:50:00Z
#   e2e none|local
#   merge   OWNER/REPO N SHA
#   defer   OWNER/REPO N SHA  # why it can't merge in this plan
#   skip    OWNER/REPO N SHA
#   upgrade OWNER/REPO N SHA
#
# Verdicts: merge (merge it), defer (passed review but can't merge in this plan, e.g. it conflicts
# with a merge PR above and needs a rebase after that merges, or its required checks never ran and
# it needs update-branch and a re-check), skip (leave open), upgrade (needs a planned upgrade).
# Anything after `#` on a line is a comment; give each defer line its reason there.
#
# ORDER MATTERS: apply merges a repo's `merge` lines in plan order (repos in order of their first
# merge line), one at a time. Put a grouped PR before the single-package PRs it overlaps, and any
# PR that others conflict with before them.
#
# Subcommands:
#   lines VERDICT OWNER/REPO N@SHA [N@SHA ...] [--reason TEXT]
#                                        print block lines for the PRs at the heads that were
#                                        reviewed (SHA: the full `head:` that inventory.sh printed
#                                        for PR N). VERDICT: merge, defer, skip or upgrade; --reason
#                                        adds `# TEXT`, e.g. for defer. A PR that isn't open at that
#                                        SHA gets no line (its head moved after the review); exit 1
#                                        if any PR got no line.
#   check PLAN                            is each `merge` PR still open at the reviewed SHA?
#                                        Exit 1 if any is stale. defer lines are reported as current
#                                        or changed; skip and upgrade lines only when they changed.
#   apply PLAN [--dry-run]                merge the `merge` PRs that are still current, in plan order,
#                                        via merge-when-green.sh --expect-heads (so GitHub refuses a
#                                        head that moved). Never merges defer, skip or upgrade lines.
#                                        Stale PRs are skipped. Ends with a summary: merged, not
#                                        merged (with reasons), BEHIND PRs with their next steps,
#                                        stale, and deferred PRs. Exit 1 if any merge PR didn't
#                                        merge. If the plan says `e2e local`, it stops and prints
#                                        the validation steps instead (exit 3).
#   heads PLAN OWNER/REPO                print "N SHA" for each of the repo's `merge` lines, in plan
#                                        order (local-merge.sh start --plan uses it).
# check, apply and heads exit 2 on a plan they can't read or that is malformed: no
# ```dependabot-plan block, not exactly one `version 1` and one `e2e none|local` line, no verdict
# lines, or a line that isn't a valid verdict line.
# Uses only gh pr/gh repo (no `gh api`).

set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"

usage() { sed -n '/^# Subcommands:/,/^# Uses only/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

# The plan block's lines as written (comments kept), without blank lines.
block_raw() {
  [[ -r "$1" ]] || { echo "cannot read plan $1" >&2; exit 2; }
  awk '/^```dependabot-plan[[:space:]]*$/ { on = 1; next } on && /^```/ { exit } on && NF' "$1"
}

# The plan block's lines, without comments or blanks. Stripping from the first `#` is safe: no
# field (verdict, OWNER/REPO, number, SHA) can contain one.
block() { block_raw "$1" | sed 's/#.*//' | awk 'NF'; }

# Refuse a malformed plan rather than silently ignoring a line (e.g. a misspelled verdict, a
# missing block, or an e2e mode that isn't spelled exactly). Runs in the main shell, so its exit
# ends the script (block_raw's own exit only ends the pipeline's subshell).
validate() {
  local bad
  [[ -f "$1" && -r "$1" ]] || { echo "cannot read plan $1" >&2; exit 2; }
  bad=$(block "$1" | awk '
    $1 == "version" { versions++; if (!(NF == 2 && $2 == "1")) print "bad line (want: version 1): " $0; next }
    $1 == "e2e" { e2es++; if (!(NF == 2 && $2 ~ /^(none|local)$/)) print "bad line (want: e2e none or e2e local): " $0; next }
    $1 == "created" { next }
    $1 ~ /^(merge|defer|skip|upgrade)$/ && NF == 4 && $2 ~ /^[^\/]+\/[^\/]+$/ && $3 ~ /^[0-9]+$/ && $4 ~ /^[0-9a-f]{40}$/ {
      key = tolower($2) " " $3
      if (key in seen) { print "listed twice (" seen[key] ", " $1 "): " $2 " " $3 }
      seen[key] = $1; verdicts++; next }
    { print "bad line: " $0 }
    END {
      if (versions != 1) print "want exactly one \"version 1\" line, found " versions + 0 " (is the dependabot-plan fence exact and unindented?)"
      if (e2es != 1) print "want exactly one \"e2e none\" or \"e2e local\" line, found " e2es + 0
      if (verdicts == 0) print "no merge, defer, skip or upgrade lines"
    }')
  if [[ -n "$bad" ]]; then printf 'plan %s:\n%s\n' "$1" "$(sed 's/^/  /' <<<"$bad")" >&2; exit 2; fi
}

# Prints "STATUS repo n sha current-head" for each `merge` line, in plan order.
# STATUS: current, moved, closed, merged, unreadable.
statuses() {
  local verdict repo n sha info state head
  while read -r verdict repo n sha _; do
    [[ "$verdict" == merge ]] || continue
    if ! info=$(ghr pr view "$n" -R "$repo" --json state,headRefOid -q '"\(.state) \(.headRefOid)"' 2>/dev/null) ||
      ! [[ "$info" =~ ^(OPEN|CLOSED|MERGED)\ [0-9a-f]{40}$ ]]; then
      echo "unreadable $repo $n $sha -"; continue
    fi
    read -r state head <<<"$info"
    case $state in
      MERGED) echo "merged $repo $n $sha $head" ;;
      CLOSED) echo "closed $repo $n $sha $head" ;;
      *) if [[ "$head" == "$sha" ]]; then echo "current $repo $n $sha $head"; else echo "moved $repo $n $sha $head"; fi ;;
    esac
  done < <(block "$1")
}

# The defer lines, as "repo n sha reason" (reason may be empty).
deferred() {
  block_raw "$1" | awk '$1 == "defer" {
    r = ""; i = index($0, "#"); if (i) { r = substr($0, i + 1); sub(/^[[:space:]]+/, "", r); sub(/[[:space:]]+$/, "", r) }
    split(substr($0, 1, i ? i - 1 : length($0)), f, " "); print f[2], f[3], f[4], r }'
}

cmd=${1:-}; shift || true
case $cmd in
  lines)
    verdict=${1:?usage: plan.sh lines merge|defer|skip|upgrade OWNER/REPO N@SHA [N@SHA ...] [--reason TEXT]}; repo=${2:?OWNER/REPO}; shift 2
    [[ "$verdict" =~ ^(merge|defer|skip|upgrade)$ ]] || { echo "verdict must be merge, defer, skip or upgrade" >&2; exit 2; }
    [[ "$repo" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || { echo "not OWNER/REPO: $repo" >&2; exit 2; }
    reason="" prs=()
    while (($#)); do
      case $1 in
        --reason) reason=$(tr '\n' ' ' <<<"${2:?--reason needs text}" | sed 's/  */ /g; s/^ //; s/ $//'); shift 2 ;;
        # The reviewed head is required: the head at the time of writing may not be the one reviewed.
        *) [[ "$1" =~ ^[0-9]+@[0-9a-f]{40}$ ]] || { echo "not N@SHA (PR number @ the full head inventory.sh printed): $1" >&2; exit 2; }
           prs+=("$1"); shift ;;
      esac
    done
    ((${#prs[@]})) || { echo "no PR numbers given" >&2; exit 2; }
    [[ "$verdict" == defer && -z "$reason" ]] && echo "note: give defer lines a reason (--reason TEXT, or edit in '# reason')" >&2
    rc=0
    for pr in "${prs[@]}"; do
      n=${pr%@*} sha=${pr#*@}
      if ! info=$(ghr pr view "$n" -R "$repo" --json state,headRefOid -q '"\(.state) \(.headRefOid)"') ||
        ! [[ "$info" =~ ^(OPEN|CLOSED|MERGED)\ [0-9a-f]{40}$ ]]; then
        echo "# could not read $repo #$n"; echo "could not read $repo #$n" >&2; rc=1; continue
      fi
      read -r state head <<<"$info"
      if [[ "$state" != OPEN ]]; then
        echo "# $repo #$n is $state"; echo "$repo #$n is $state: no line written (a plan lists only open PRs)" >&2; rc=1; continue
      elif [[ "$head" != "$sha" ]]; then
        echo "# $repo #$n moved since review"
        echo "$repo #$n moved since review (${sha:0:7} -> ${head:0:7}): no line written. Run inventory.sh $repo $n: if its dependency changes are the reviewed ones (only rebased), use its new head; otherwise re-review it" >&2
        rc=1; continue
      fi
      printf '%-7s %s %s %s%s\n' "$verdict" "$repo" "$n" "$sha" "${reason:+  # $reason}"
    done
    exit $rc
    ;;

  check)
    plan=${1:?usage: plan.sh check PLAN}
    (($# == 1)) || { echo "usage: plan.sh check PLAN" >&2; exit 2; }
    validate "$plan"
    stale=0
    while read -r status repo n sha head; do
      case $status in
        current) echo "ok      $repo #$n at ${sha:0:7}" ;;
        moved) echo "STALE   $repo #$n moved ${sha:0:7} -> ${head:0:7}: if inventory.sh shows the same dependency changes (only rebased), replace its line with plan.sh lines merge $repo $n@<its new head> output; otherwise remove it and re-review"; stale=1 ;;
        merged) echo "done    $repo #$n already merged" ;;
        closed) echo "STALE   $repo #$n was closed (Dependabot may have superseded it): re-review"; stale=1 ;;
        *) echo "STALE   $repo #$n could not be read"; stale=1 ;;
      esac
    done < <(statuses "$plan")
    # defer, skip and upgrade entries aren't merged, but if they changed (e.g. Dependabot rebased
    # them after another merge), their verdicts may be out of date for the next review.
    while read -r verdict repo n sha _; do
      [[ "$verdict" =~ ^(defer|skip|upgrade)$ ]] || continue
      if ! info=$(ghr pr view "$n" -R "$repo" --json state,headRefOid -q '"\(.state) \(.headRefOid)"' 2>/dev/null) ||
        ! [[ "$info" =~ ^(OPEN|CLOSED|MERGED)\ [0-9a-f]{40}$ ]]; then
        echo "note    $repo #$n ($verdict) could not be read"; continue
      fi
      read -r state head <<<"$info"
      if [[ "$state" != OPEN ]]; then echo "note    $repo #$n ($verdict) is now $state"
      elif [[ "$head" != "$sha" ]]; then echo "note    $repo #$n ($verdict) changed since review (${sha:0:7} -> ${head:0:7}): its verdict may be out of date"
      elif [[ "$verdict" == defer ]]; then echo "note    $repo #$n (defer) current at ${sha:0:7}: re-check it after this plan's merges"; fi
    done < <(block "$plan")
    exit $stale
    ;;

  apply)
    # Any unrecognized argument is refused, so a misspelled --dry-run never becomes a real apply.
    plan="" dry=()
    while (($#)); do
      case $1 in
        --dry-run) dry=(--dry-run); shift ;;
        -*) echo "unknown option: $1 (usage: plan.sh apply PLAN [--dry-run])" >&2; exit 2 ;;
        *) [[ -z "$plan" ]] || { echo "usage: plan.sh apply PLAN [--dry-run]" >&2; exit 2; }; plan=$1; shift ;;
      esac
    done
    [[ -n "$plan" ]] || { echo "usage: plan.sh apply PLAN [--dry-run]" >&2; exit 2; }
    validate "$plan"
    e2e=$(block "$plan" | awk '$1 == "e2e" { print $2; exit }')
    if [[ "$e2e" == local ]]; then
      echo "This plan requires local e2e validation before merging (e2e local)."
      echo "1. bash $here/plan.sh check $plan   (stop and re-review anything stale)"
      echo "2. Follow $(dirname "$here")/local-e2e.md with the plan's merge PRs (not defer lines), per repo, in plan order:"
      echo "   local-merge.sh start OWNER/REPO --clone <clone> --plan $plan N ... merges only the reviewed heads."
      echo "3. Merge with merge-when-green.sh --expect-heads <the clone's dependabot-e2e.state>."
      exit 3
    fi
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    stale=() repos=() current=()
    while read -r status repo n sha head; do
      case $status in
        current)
          key=${repo//\//__}
          [[ -e "$tmp/$key.repo" ]] || { echo "$repo" >"$tmp/$key.repo"; repos+=("$repo"); }
          echo "merged=$n $sha" >>"$tmp/$key.heads"; echo "$n" >>"$tmp/$key.prs"; current+=("$repo $n") ;;
        merged) echo "#$n in $repo is already merged" ;;
        *) stale+=("$repo #$n ($status)") ;;
      esac
    done < <(statuses "$plan")
    ((${#repos[@]})) || echo "nothing current to merge"
    : >"$tmp/results"
    for repo in "${repos[@]}"; do
      key=${repo//\//__}
      mapfile -t prs <"$tmp/$key.prs"
      echo
      MWG_RESULTS="$tmp/results" bash "$here/merge-when-green.sh" "${dry[@]}" --expect-heads "$tmp/$key.heads" "$repo" "${prs[@]}"
    done

    echo
    echo "=== apply summary$( ((${#dry[@]})) && echo ' (dry run: nothing was changed)')"
    done_list=$(awk '$1 == "merged" || $1 == "would-merge" { printf "  %s #%s\n", $2, $3 }' "$tmp/results")
    echo "$( ((${#dry[@]})) && echo 'would merge' || echo 'merged'):"; echo "${done_list:-  none}"
    failed=0
    notmerged=$(awk '$1 == "skipped" { r = $0; sub(/^[^ ]+ [^ ]+ [^ ]+ /, "", r); printf "  %s #%s: %s\n", $2, $3, r }' "$tmp/results")
    for c in "${current[@]}"; do   # merge-when-green stopped before reaching these (see its output)
      read -r repo n <<<"$c"
      awk -v r="$repo" -v n="$n" '$2 == r && $3 == n { f = 1 } END { exit !f }' "$tmp/results" ||
        notmerged+=$'\n'"  $repo #$n: no result (merge-when-green stopped early; see its output above)"
    done
    notmerged=$(awk NF <<<"$notmerged")
    if [[ -n "$notmerged" ]]; then echo "not merged:"; echo "$notmerged"; failed=1; fi
    if grep -q '^behind ' "$tmp/results"; then
      failed=1
      echo "BEHIND the base after an earlier merge (the base requires up-to-date branches); not updated here."
      echo "For each, in order (update-branch moves the head, so the plan line must be refreshed):"
      while read -r _ repo n _; do
        echo "  $repo #$n:"
        echo "    gh pr update-branch $n -R $repo --rebase"
        echo "    # wait for its required checks: gh pr checks $n -R $repo --required --watch"
        echo "    bash $here/inventory.sh $repo $n   # confirm its dependency changes are the reviewed ones; note its head"
        echo "    bash $here/plan.sh lines merge $repo $n@<that head>   # replace its merge line in $plan"
        echo "    bash $here/plan.sh apply $plan"
      done < <(grep '^behind ' "$tmp/results")
    fi
    if ((${#stale[@]})); then
      failed=1
      echo "stale (not merged; re-review with the skill):"
      printf '  %s\n' "${stale[@]}"
    fi
    defers=$(deferred "$plan")
    if [[ -n "$defers" ]]; then
      echo "deferred: re-check after the merges above (rebase, refresh the plan line, re-run apply):"
      while read -r repo n sha reason; do
        echo "  $repo #$n at ${sha:0:7}${reason:+: $reason}"
      done <<<"$defers"
      echo "  For each: rebase it (comment '@dependabot rebase' for a conflict, or"
      echo "  gh pr update-branch N -R OWNER/REPO --rebase for checks that never ran), wait for its checks,"
      echo "  confirm its changes with inventory.sh, then change its line to"
      echo "  \`plan.sh lines merge OWNER/REPO N@<the head inventory.sh printed>\` output and re-run apply."
    fi
    exit $failed
    ;;

  heads)
    plan=${1:-} repo=${2:-}
    [[ -n "$plan" && -n "$repo" && $# -eq 2 ]] || { echo "usage: plan.sh heads PLAN OWNER/REPO" >&2; exit 2; }
    validate "$plan"
    block "$plan" | awk -v r="$(tr '[:upper:]' '[:lower:]' <<<"$repo")" '$1 == "merge" && tolower($2) == r { print $3, $4 }'
    ;;

  *) usage ;;
esac
