#!/usr/bin/env bash
# Keep the review record for the current branch. Run from inside the repo (or worktree).
#
#   record.sh init <base-branch> <author-cli>     start a fresh record (author-cli: the CLI you're running in)
#   record.sh add-run <pass> <run-dir>            add a completed review.sh run (pass: simplify|risk|review|recheck)
#   record.sh dispose <run-dir> <id> fixed|applied <commit>
#   record.sh dispose <run-dir> <id> declined "<reason>"
#   record.sh tests "<command>" pass|fail         record an automated test run at HEAD
#   record.sh finalize                            pin the record to the current HEAD and merge base
#   record.sh check                               exit non-zero, listing problems, unless the record is complete
#   record.sh summary                             print the PR body's Risk & review section
#   record.sh path                                print the record's path
#
# The record lives in the repo's git dir, so it's never committed and works in linked worktrees.
set -euo pipefail

SKILL_DIR=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
REVIEWERS="$SKILL_DIR/../crucible-review/reviewers.json"

die() { echo "record.sh: $*" >&2; exit 2; }

branch=$(git symbolic-ref --short -q HEAD) || die "not on a branch"
dir=$(git rev-parse --git-path crucible-pr)
[[ $dir = /* ]] || dir="$PWD/$dir"
mkdir -p "$dir"
rec="$dir/$(jq -rn --arg b "$branch" '$b | @uri').json"

upd() { local tmp; tmp=$(mktemp); jq "$@" "$rec" >"$tmp" && mv "$tmp" "$rec"; }
need() { [[ -f $rec ]] || die "no record for $branch; run: record.sh init <base> <author-cli>"; }
base_ref() { local b; b=$(jq -r .base "$rec"); git rev-parse -q --verify "origin/$b" >/dev/null && echo "origin/$b" || echo "$b"; }

cmd=${1:-}; shift || true
case $cmd in
  init)
    [[ $# -eq 2 ]] || die "usage: record.sh init <base-branch> <author-cli>"
    jq -e --arg a "$2" '.tiers.low | has($a)' "$REVIEWERS" >/dev/null || die "no tiers for author CLI '$2' in reviewers.json"
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner </dev/null)
    # The branch name, as gh pr create --base takes it (origin/main -> main).
    jq -n --arg repo "$repo" --arg base "${1#origin/}" --arg head "$branch" --arg author "$2" \
      '{version: 1, repo: $repo, base: $base, head_branch: $head, author_cli: $author,
        tier: null, risk: null, runs: [], findings: [], tests: [], final: null}' >"$rec"
    echo "$rec"
    ;;

  add-run)
    [[ $# -eq 2 ]] || die "usage: record.sh add-run <pass> <run-dir>"
    need; pass=$1; run=$(cd "$2" && pwd)
    [[ $pass =~ ^(simplify|risk|review|recheck)$ ]] || die "unknown pass '$pass'"
    jq -e '.status == "complete"' "$run/meta.json" >/dev/null || die "run $run is incomplete; an incomplete review can't be recorded"
    want=$pass; [[ $pass == recheck ]] && want=review
    lens=$(jq -r .lens "$run/meta.json")
    [[ $lens == "$want" ]] || die "a $pass pass needs a run with the $want lens; this run used $lens"
    upd --arg pass "$pass" --arg d "$run" --slurpfile m "$run/meta.json" --slurpfile o "$run/findings.json" '
      def rank: {"low": 1, "medium": 2, "high": 3}[.];
      .runs += [{pass: $pass, run_dir: $d} + ($m[0] | {profile, cli, model, effort, lens, session_id, range, head})]
      | if $pass == "risk" then
          .risk = $o[0]
          | .tier = (if .tier == null or ($o[0].tier | rank) > (.tier | rank) then $o[0].tier else .tier end)
        else . end
      # Verification gaps from the scorer are findings too: add the test, or decline with a reason.
      | (if $pass == "risk" then [$o[0].categories.verification.gaps // [] | to_entries[]
           | {id: "verification-\(.key + 1)", severity: "minor", category: "verification", file: null, line: null, summary: .value}]
         else $o[0].findings // [] end) as $new
      | .findings += [$new[] | {run_dir: $d, pass: $pass, id, severity, category, file, line, summary,
                                disposition: null, commit: null, reason: null}]'
    jq -r --arg d "$run" '"tier: \(.tier // "not scored")  open findings from this run: \([.findings[] | select(.run_dir == $d and .disposition == null)] | length)"' "$rec"
    ;;

  dispose)
    [[ $# -eq 4 ]] || die "usage: record.sh dispose <run-dir> <id> fixed|applied <commit> | declined <reason>"
    need; run=$(cd "$1" && pwd); id=$2; disp=$3; val=$4
    [[ $disp =~ ^(fixed|applied|declined)$ ]] || die "disposition must be fixed, applied or declined"
    [[ -n $val ]] || die "a $disp disposition needs a ${disp/declined/reason}"
    jq -e --arg d "$run" --arg id "$id" 'any(.findings[]; .run_dir == $d and .id == $id)' "$rec" >/dev/null || die "no finding $id from $run"
    upd --arg d "$run" --arg id "$id" --arg disp "$disp" --arg v "$val" '
      (.findings[] | select(.run_dir == $d and .id == $id)) |= . + {disposition: $disp}
        + (if $disp == "declined" then {reason: $v} else {commit: $v} end)'
    ;;

  tests)
    [[ $# -eq 2 && $2 =~ ^(pass|fail)$ ]] || die "usage: record.sh tests \"<command>\" pass|fail"
    need; upd --arg c "$1" --arg r "$2" --arg h "$(git rev-parse HEAD)" '.tests += [{command: $c, result: $r, commit: $h}]'
    ;;

  finalize)
    need; upd --arg h "$(git rev-parse HEAD)" --arg mb "$(git merge-base "$(base_ref)" HEAD)" '.final = {head: $h, merge_base: $mb}'
    ;;

  check)
    need
    problems=$(jq -r --arg h "$(git rev-parse HEAD)" --arg mb "$(git merge-base "$(base_ref)" HEAD)" --slurpfile rv "$REVIEWERS" '
      . as $r
      | ($rv[0].tiers[$r.tier // "high"][$r.author_cli] // []) as $required
      # Only the latest score counts; gaps from earlier scores are superseded.
      | ([$r.runs[] | select(.pass == "risk")] | last | .run_dir) as $latest_risk
      | [ (if $r.final == null then "not finalized (record.sh finalize)" else empty end),
          (if $r.final != null and $r.final.head != $h then "HEAD has moved since the record was finalized" else empty end),
          (if $r.final != null and $r.final.merge_base != $mb then "the base has changed since the record was finalized" else empty end),
          (if any($r.runs[]; .pass == "simplify") then empty else "no simplify pass" end),
          (if $r.tier == null then "no risk score" else empty end),
          ($required[] as $p | if any($r.runs[]; .pass == "review" and .profile == $p) then empty
                               else "missing the \($p) review the \($r.tier) tier requires" end),
          (if ([$r.runs[] | select(.pass == "risk")] | last | .head) == $h then empty
           else "the latest risk score does not cover HEAD; resume the scorer" end),
          (if $r.tier == "low" then empty else
            ($required[] as $p | [$r.runs[] | select((.pass == "review" or .pass == "recheck") and .profile == $p)] | last
             | if . == null or .head == $h then empty
               else "the \($p) reviewer has not seen HEAD; resume it to re-check the fixes" end) end),
          ($r.findings[] | select(.disposition == null and (.pass != "risk" or .run_dir == $latest_risk)) | "finding \(.id) from \(.pass) (\(.run_dir | split("/") | last)) has no disposition"),
          (if any($r.tests[]; .commit == $h) then empty else "no automated test run recorded at HEAD" end)
        ] | .[]' "$rec")
    if [[ -n $problems ]]; then echo "$problems" >&2; exit 1; fi
    echo "record complete: tier $(jq -r .tier "$rec")"
    ;;

  summary)
    # The Risk & review section for the PR body. Its collapsed header carries the tier and review status.
    need
    jq -r --arg h "$(git rev-parse HEAD)" '
      def mark: {"low": "✅", "medium": "👀", "high": "⚠️", "n/a": ""}[.] // "";
      def cap: (.[0:1] | ascii_upcase) + .[1:];
      def name: {"alignment": "Alignment", "impact": "Impact", "verification": "Verification",
                 "rollback_cost": "Rollback cost", "error_detection": "Error detection"}[.];
      def count($n; $word): "\($n) \($word)\(if $n == 1 then "" else "s" end)";
      . as $r
      | ([$r.runs[] | select(.pass == "risk")] | last | .run_dir) as $latest_risk
      | [$r.findings[] | select(.disposition == "declined" and (.pass != "risk" or .run_dir == $latest_risk))] as $declined_all
      # Show the latest score. The record keeps the highest tier only to decide which reviews are required.
      | ($r.risk.tier // $r.tier) as $tier
      | ([$r.findings[] | select(.pass == "review" or .pass == "recheck")]) as $rf
      | ([$rf[] | select(.disposition == "fixed")] | length) as $fixed
      | ([$rf[] | select(.disposition == "declined")] | length) as $declined
      | ([$r.runs[] | select(.pass == "review") | .profile] | unique | join(" + ")) as $who
      | ([$r.runs[] | select(.pass == "review" or .pass == "recheck")] | last | .head // "") as $seen
      | "<details>",
        "<summary>Risk & review: \($tier | cap) \($tier | mark) · reviewed by \($who) at \($seen[0:7])"
          + (if $seen != $h then ", later commits not re-reviewed" else "" end) + " · "
          + (if ($rf | length) == 0 then "no findings"
             else count($fixed; "finding") + " fixed, \($declined) declined" end)
          + "</summary>",
        ($r.risk.categories | to_entries[]
          | "", "**\(.key | name):** \(.value.rating) \(.value.rating | mark)", (.value.gaps[] | "- \(.)")),
        (if ($r.risk.minimums_applied | length) > 0 then "", "Minimum tier: \($r.risk.minimums_applied | join("; "))" else empty end),
        "",
        "| Pass | Reviewer | Findings | Outcome |",
        "| --- | --- | --- | --- |",
        ($r.runs[] | select(.pass != "risk") | . as $run
          | [$r.findings[] | select(.run_dir == $run.run_dir)] as $f
          | "| \($run.pass | cap) | \($run.profile) | \($f | length) | "
            + (if ($f | length) == 0 then "none" else
                ([$f | group_by(.disposition)[] | "\(length) \(.[0].disposition)"] | join(", ")) end) + " |"),
        (if ($declined_all | length) > 0 then
          "", "**Declined:**", ($declined_all[] | "- *\(.summary)*: \(.reason)")
         else empty end),
        "</details>",
        "",
        "<!-- crucible-pr: head=\($h) -->"' "$rec"
    ;;

  path) echo "$rec" ;;
  *) die "usage: record.sh init|add-run|dispose|tests|finalize|check|summary|path ..." ;;
esac
