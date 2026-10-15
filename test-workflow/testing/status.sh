#!/usr/bin/env bash
# One row per worktree, for the orchestrator's round file and the start of a session (testing/README.md):
# branch, clean or the number of changed files, level with origin, the last commit, the gates and removed
# summaries (missing, provisional, unaccounted), and whether the verify log describes the current tree.
# Reads only; git fetch is the one write (remote-tracking refs), and only with --fetch.
#
#   status.sh [--fetch] [--no-checks] [<worktree>...]      (default: every worktree under ../../.worktrees)
#
#   --fetch      git fetch origin first, so "level" compares with origin as it is now
#   --no-checks  skip check-repo.js (the gates and removed columns), for a quick look
set -u
TESTING="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The workspace docs (test-work/): on the /mnt/data volume, never in the checkout this script runs from.
DOCS="${CRUCIBLE_ROOT:-/mnt/data/crucible}/agent-docs"
FETCH=0; CHECKS=1; WTS=()
for a in "$@"; do
  case "$a" in
    --fetch) FETCH=1 ;;
    --no-checks) CHECKS=0 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) echo "status.sh: unknown option $a" >&2; exit 2 ;;
    *) WTS+=("${a%/}") ;;
  esac
done
if [ ${#WTS[@]} -eq 0 ]; then
  for d in "$DOCS"/../.worktrees/*/; do [ -e "$d/.git" ] && WTS+=("$(cd "$d" && pwd)"); done
fi
echo "| Repo | Branch | Tree | Origin | Last commit | Gates (missing, provisional) | Removed (unaccounted) | Verify log |"
echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
for w in "${WTS[@]}"; do
  app="$(basename "$w")"
  branch="$(git -C "$w" branch --show-current)"
  [ $FETCH -eq 1 ] && git -C "$w" fetch -q origin 2>/dev/null
  n="$(git -C "$w" status --porcelain=v1 -uall | wc -l | tr -d ' ')"
  tree="clean"; [ "$n" -gt 0 ] && tree="$n changed"
  if git -C "$w" rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
    read -r behind ahead <<<"$(git -C "$w" rev-list --left-right --count "origin/$branch...HEAD")"
    if [ "$behind" = 0 ] && [ "$ahead" = 0 ]; then origin="level"; else origin="${ahead} ahead, ${behind} behind"; fi
  else origin="not on origin"; fi
  last="$(git -C "$w" log -1 --format='%h %cs %s' | cut -c1-60)"
  gates="-"; removed="-"
  if [ $CHECKS -eq 1 ]; then
    if [ -f "$w/angular.json" ]; then
      g="$(node "$TESTING/../ui-testing/check-repo.js" gates "$w" --app "$app" 2>/dev/null | sed -n 's/.*; \([0-9]* missing, [0-9]* provisional\)$/\1/p')"
      rm_="$(node "$TESTING/../ui-testing/check-repo.js" removed "$w" --app "$app" --no-write 2>/dev/null | sed -n 's/.*unaccounted \([0-9]*\)).*/\1/p')"
    else
      g="$(node "$TESTING/../api-testing/check-repo.js" gates "$w" "$app" 2>/dev/null | sed -n 's/.*, \([0-9]* missing, [0-9]* provisional\))$/\1/p')"
      rm_="$(node "$TESTING/../api-testing/check-repo.js" removed "$w" "$app" --no-write 2>/dev/null | sed -n 's/.*, \([0-9]*\) unaccounted (.*/\1/p')"
    fi
    gates="${g:-?}"; removed="${rm_:-?}"
  fi
  t="$("$TESTING/tree-hash.sh" "$w" 2>/dev/null)"
  vlog="$DOCS/test-work/$app/verify-$t.log"
  if [ -f "$vlog" ] && "$TESTING/tree-hash.sh" --check "$vlog" "$w" >/dev/null; then
    if grep -q '^== 0 check(s) failed' "$vlog"; then verify="current, passed"; else verify="current, $(sed -n 's/^== \([0-9]*\) check(s) failed.*/\1 failed/p' "$vlog" | tail -1)"; fi
  elif [ -e "$DOCS/test-work/$app/verify-latest.log" ]; then verify="stale"
  else verify="none"; fi
  echo "| $app | $branch | $tree | $origin | $last | $gates | $removed | $verify |"
done
