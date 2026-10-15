#!/usr/bin/env bash
# CI and main-sync check for the test branches (orchestration/RULES.md, Delivery: "green").
#
# GitHub's pull_request checks do not test the branch alone: they test refs/pull/<n>/merge, the
# branch merged with main as it is when the run starts. verify.sh tests the branch alone, so a
# branch can be ready and still go red the moment main moves. This script answers, per repo:
# is the branch level with main, does it merge cleanly, and did every check pass on its latest push.
#
#   ci-check.sh status [<worktree>...]
#       one verdict line per repo, then details for anything not GREEN. Verdicts, first match wins:
#         CONFLICT  origin/<branch> does not merge cleanly with origin/main (files listed)
#         BEHIND    origin/main has commits the branch lacks (commits listed)
#         PENDING   a check on the PR head is queued or running
#         RED       a check on the PR head failed (names listed; see `failures`)
#         GREEN     level with main, merges cleanly, every check on the head passed or skipped
#         MERGED    the branch's PR is merged (checked first; counts as done)
#       Also flags UNPUSHED (local HEAD differs from origin/<branch>) and DIRTY (uncommitted files).
#       Default worktrees: every directory in /mnt/data/crucible/.worktrees. Exit 1 unless all GREEN.
#   ci-check.sh failures <worktree>
#       for each failed check on the PR head: the run, the main it was tested against versus main
#       now, and the failing tests with their first error lines from the job log.
#   ci-check.sh local <worktree>
#       runs the CI test command on what CI would test after the next push: the worktree (HEAD plus
#       uncommitted and untracked changes) merged with the current origin/main, in a throwaway
#       worktree under /tmp/ci-check. Commits nothing and leaves the worktree untouched; removes the
#       throwaway worktree afterwards. UIs: npm run test:coverage. APIs: the dotnet test line of
#       .github/workflows/build-and-test.yml, with the proxy variables unset (CI has none).
#
# Read-only toward the repos: git fetch, git merge-tree, gh queries, and the throwaway worktree.
set -uo pipefail

ROOT=/mnt/data/crucible/.worktrees

strip() { sed 's/\x1b\[[0-9;]*m//g; s/\^\[\[[0-9;]*m//g'; }

status_one() {
  local w app br pr json verdict="" details=""; w=$(cd "$1" && pwd) || return 1
  app=$(basename "$w"); br=$(git -C "$w" branch --show-current)
  git -C "$w" fetch -q origin main "$br" 2>/dev/null
  local head remote dirty behind
  head=$(git -C "$w" rev-parse HEAD); remote=$(git -C "$w" rev-parse "origin/$br")
  dirty=$(git -C "$w" status --porcelain | grep -c .)
  behind=$(git -C "$w" rev-list --count "origin/$br..origin/main")
  local mt
  if ! mt=$(git -C "$w" merge-tree --write-tree --name-only "origin/$br" origin/main 2>&1); then
    verdict=CONFLICT
    details=$(sed -n '2,/^$/p' <<<"$mt" | grep . | sed 's/^/    conflict: /')
  elif (( behind > 0 )); then
    verdict=BEHIND
    details=$(git -C "$w" log --format='    main: %h %ad %s' --date=format:'%m-%d %H:%M' "origin/$br..origin/main")
  fi
  json=$(cd "$w" && gh pr view "$br" --json number,state,mergedAt,headRefOid,mergeStateStatus,statusCheckRollup 2>/dev/null)
  if [[ -z "$json" ]]; then
    printf '%-16s %-9s no open PR for %s\n' "$app" "${verdict:-?}" "$br"; return 1
  fi
  pr=$(jq -r .number <<<"$json")
  if [[ "$(jq -r .state <<<"$json")" == MERGED ]]; then
    printf '%-16s %-9s #%-4s merged %s; main contains it\n' "$app" MERGED "$pr" "$(jq -r .mergedAt <<<"$json")"; return 0
  fi
  local checks pending failed passed
  checks=$(jq -r '.statusCheckRollup[] | [(.name // .context), (.status // "COMPLETED"), (.conclusion // .state)] | @tsv' <<<"$json")
  pending=$(awk -F'\t' '$2!="COMPLETED" || $3=="PENDING" || $3=="EXPECTED"' <<<"$checks" | grep -c .)
  failed=$(awk -F'\t' '$2=="COMPLETED" && $3!="SUCCESS" && $3!="SKIPPED" && $3!="NEUTRAL" && $3!="PENDING" && $3!="EXPECTED"' <<<"$checks")
  passed=$(awk -F'\t' '$3=="SUCCESS" || $3=="SKIPPED" || $3=="NEUTRAL"' <<<"$checks" | grep -c .)
  if [[ -z "$verdict" ]]; then
    if (( pending > 0 )); then verdict=PENDING
    elif [[ -n "$failed" ]]; then verdict=RED
    else verdict=GREEN; fi
  fi
  [[ -n "$failed" ]] && details+=$'\n'$(awk -F'\t' '{print "    failed: " $1 " (" $3 ")"}' <<<"$failed")
  local flags=""
  [[ "$head" != "$remote" ]] && flags+=" UNPUSHED"
  (( dirty > 0 )) && flags+=" DIRTY($dirty)"
  printf '%-16s %-9s #%-4s head %s  checks: %d passed, %d failed, %d pending  behind main: %d%s\n' \
    "$app" "$verdict" "$pr" "${remote:0:7}" "$passed" "$(grep -c . <<<"$failed")" "$pending" "$behind" "$flags"
  [[ -n "${details//[$'\n ']/}" ]] && grep . <<<"$details"
  [[ "$verdict" == GREEN ]]
}

cmd_status() {
  local ws=("$@") rc=0
  (( ${#ws[@]} )) || ws=("$ROOT"/*/)
  for w in "${ws[@]}"; do status_one "${w%/}" || rc=1; done
  return $rc
}

cmd_failures() {
  local w br pr; w=$(cd "${1:?worktree}" && pwd) || return 1
  br=$(git -C "$w" branch --show-current); git -C "$w" fetch -q origin main
  pr=$(cd "$w" && gh pr view "$br" --json number -q .number)
  local links
  links=$(cd "$w" && gh pr checks "$pr" --json name,bucket,link -q '.[] | select(.bucket=="fail") | "\(.name)\t\(.link)"')
  [[ -z "$links" ]] && { echo "$(basename "$w") #$pr: no failed checks on the head"; return 0; }
  while IFS=$'\t' read -r name link; do
    local run=${link#*/actions/runs/}; run=${run%%/*}
    echo "== $(basename "$w") #$pr  $name  run $run"
    [[ "$run" =~ ^[0-9]+$ ]] || { echo "   (not an Actions run: $link)"; continue; }
    local log mergesha base now
    log=$(cd "$w" && gh run view "$run" --log-failed 2>&1 | strip)
    mergesha=$(grep -oE '\+[0-9a-f]{40}:refs/remotes/pull/[0-9]+/merge' <<<"$log" | head -1 | cut -c2-41)
    if [[ -z "$mergesha" ]]; then
      mergesha=$(cd "$w" && gh run view "$run" --log 2>/dev/null | grep -oE '\+[0-9a-f]{40}:refs/remotes/pull/[0-9]+/merge' | head -1 | cut -c2-41)
    fi
    now=$(git -C "$w" rev-parse origin/main)
    if [[ -n "$mergesha" ]]; then
      git -C "$w" fetch -q origin "$mergesha" 2>/dev/null
      base=$(git -C "$w" rev-parse -q --verify "$mergesha^1" 2>/dev/null)
      if [[ -n "$base" && "$base" != "$now" ]]; then
        echo "   tested against main ${base:0:7}; main is now ${now:0:7}:"
        git -C "$w" log --format='     %h %s' "$base..$now"
      elif [[ -n "$base" ]]; then
        echo "   tested against current main ${now:0:7}"
      fi
    fi
    grep -E 'FAIL .*>|^\s*×|AssertionError|TypeError|Error:|error (CS|xUnit|NG)[0-9]+|^\s*Failed [A-Za-z_.]+|Test Files|Tests  |Failed!|Total tests' <<<"$log" \
      | sed 's/^[^\t]*\t[^\t]*\t//; s/^[0-9T:.-]*Z //' | awk '!seen[$0]++' | head -40 | sed 's/^/   /'
  done <<<"$links"
}

cmd_local() {
  local w=${1:?worktree} app br s tree
  w=$(cd "$w" && pwd) || return 1; app=$(basename "$w"); br=$(git -C "$w" branch --show-current)
  git -C "$w" fetch -q origin main
  s=/tmp/ci-check/$app-$$; mkdir -p /tmp/ci-check
  if ! tree=$(git -C "$w" merge-tree --write-tree HEAD origin/main 2>&1); then
    echo "CONFLICT  $app: HEAD does not merge cleanly with origin/main"; sed -n '2,/^$/p' <<<"$tree" | grep . | sed 's/^/   /'; return 1
  fi
  tree=$(head -1 <<<"$tree")
  git -C "$w" worktree add -q --detach "$s" HEAD || return 1
  trap 'rm -f "$s/node_modules"; git -C "$w" worktree remove --force "$s" 2>/dev/null' RETURN
  git -C "$s" read-tree -u --reset "$tree"
  if ! git -C "$w" diff HEAD --binary | git -C "$s" apply --3way --binary --whitespace=nowarn 2>/tmp/ci-check/$app.apply; then
    echo "CONFLICT  $app: the uncommitted changes do not apply on top of main"; sed 's/^/   /' /tmp/ci-check/$app.apply; return 1
  fi
  (cd "$w" && git ls-files -o --exclude-standard -z | xargs -0 -r cp --parents -t "$s")
  echo "local     $app: testing HEAD ${br}@$(git -C "$w" rev-parse --short HEAD) + $(git -C "$w" status --porcelain | grep -c .) uncommitted file(s), merged with origin/main $(git -C "$w" rev-parse --short origin/main)"
  local out rc
  if [[ "$app" == *.ui ]]; then
    ln -s "$w/node_modules" "$s/node_modules"
    out=$(cd "$s" && npm run test:coverage 2>&1 | strip); rc=$?
    grep -E '^\s*×|FAIL .*>|Test Files|^\s*Tests |ERROR|threshold' <<<"$out" | awk '!seen[$0]++' | head -40 | sed 's/^/   /'
  else
    local proj
    proj=$(grep -oE 'dotnet test [^ ]+' "$s/.github/workflows/build-and-test.yml" | head -1 | cut -d' ' -f3)
    out=$(cd "$s" && env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy dotnet test "$proj" 2>&1 | strip); rc=$?
    grep -E 'error [A-Z]+[0-9]+|^\s*Failed [A-Za-z_.]+|Failed!|Passed!|Total tests|Test summary' <<<"$out" | awk '!seen[$0]++' | head -40 | sed 's/^/   /'
  fi
  if (( rc == 0 )); then echo "PASS      $app at the merge with current main"; else echo "FAIL      $app at the merge with current main (exit $rc)"; fi
  return $rc
}

case "${1:-}" in
  status) shift; cmd_status "$@" ;;
  failures) shift; cmd_failures "$@" ;;
  local) shift; cmd_local "$@" ;;
  *) sed -n '2,/^set -uo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 2 ;;
esac
