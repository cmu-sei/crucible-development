#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Merges a set of Dependabot PRs together on a throwaway local branch in a repo's
# clone, so the running Aspire app can be e2e-tested on the combined result
# before anything merges on GitHub (see ../local-e2e.md). Never pushes; toward
# GitHub it only fetches and reads (`gh repo view`, `gh pr view`; no `gh api`).
#
# Usage:
#   local-merge.sh start OWNER/REPO --clone PATH [--plan PLAN PR ...]
#       Refuses if the clone has uncommitted or untracked (non-ignored) files, or a
#       previous run's state file. Records the current checkout, creates
#       dependabot-e2e/<UTC timestamp> from origin/<default branch>, and merges each PR
#       in order (--no-ff) at the head commit its `merge` line in PLAN records (the
#       reviewed one). --plan is required when PRs are given. A PR that isn't a `merge`
#       line in PLAN, or whose head on GitHub has moved from that commit, is skipped.
#       A conflict only in npm package-lock.json files is resolved with
#       `npm install --package-lock-only`; any other conflict skips the PR. Ends with merged/skipped PRs and the diff stat against the base.
#       With no PRs it just checks out origin/<default branch> (a baseline run).
#   local-merge.sh status --clone PATH
#   local-merge.sh restore --clone PATH
#       Checks out the recorded original ref, deletes the e2e branch and removes the
#       state file. Refuses if the clone has changes other than build output
#       (BUILD_PATHS_RE); tracked build output on the e2e branch is discarded.
#
# The state file is <clone git dir>/dependabot-e2e.state, so it is never tracked.
# Env: BUILD_PATHS_RE - extended regex for porcelain paths that restore treats as
#      build output (default below).

set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"

BUILD_PATHS_RE=${BUILD_PATHS_RE:-'(^|/)(node_modules|dist|bin|obj|\.angular|out-tsc|coverage|TestResults)(/|$)|\.lscache$|(^|/)package-lock\.json$'}
STATE_NAME=dependabot-e2e.state

usage() {
  sed -n '/^# Usage:/,/^# The state file/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2
  exit 2
}
die() { echo "local-merge: $*" >&2; exit 1; }

# git in the clone, with signing off: these commits are local and never pushed.
g() { git -C "$clone" -c commit.gpgsign=false "$@"; }

resolve_clone() {
  [[ -n "${clone:-}" ]] || die "--clone PATH is required"
  [[ -d "$clone" ]] || die "no such directory: $clone"
  clone=$(git -C "$clone" rev-parse --show-toplevel 2>/dev/null) || die "not a git work tree: $clone"
  state=$(git -C "$clone" rev-parse --absolute-git-dir)/$STATE_NAME
}

state_get() { sed -n "s/^$1=//p" "$state" | head -1; }

# Paths `git status` reports (staged, unstaged, untracked-not-ignored); one porcelain line each.
porcelain() { g status --porcelain=v1; }

in_progress_op() {
  local gd; gd=$(git -C "$clone" rev-parse --absolute-git-dir)
  local f
  for f in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply BISECT_LOG; do
    [[ -e "$gd/$f" ]] && { echo "$f"; return 0; }
  done
  return 1
}

parse_clone_args() {
  clone= plan=
  rest=()
  while (($#)); do
    case "$1" in
      --clone) clone=${2:-}; shift 2 || usage ;;
      --clone=*) clone=${1#--clone=}; shift ;;
      --plan) plan=${2:-}; shift 2 || usage ;;
      --plan=*) plan=${1#--plan=}; shift ;;
      -h|--help) usage ;;
      *) rest+=("$1"); shift ;;
    esac
  done
}

cmd_start() {
  parse_clone_args "$@"
  set -- "${rest[@]}"
  local repo=${1:-}; shift || true
  [[ "$repo" == */* ]] || usage
  local n
  for n in "$@"; do [[ "$n" =~ ^[0-9]+$ ]] || die "not a PR number: $n"; done
  # The reviewed head of each of the repo's merge lines ("N SHA"): only those commits are merged.
  local planned=""
  if (($#)); then
    [[ -n "$plan" ]] || die "--plan PLAN is required when PRs are given (only the plan's reviewed heads are merged)"
    planned=$(bash "$here/plan.sh" heads "$plan" "$repo") || die "could not read the merge lines of $plan"
  fi
  resolve_clone

  [[ -e "$state" ]] && die "a previous run's state file exists ($state). Run: local-merge.sh status --clone $clone, then restore."
  local op; if op=$(in_progress_op); then die "the clone has an operation in progress ($op); finish or abort it first"; fi
  local dirty; dirty=$(porcelain)
  if [[ -n "$dirty" ]]; then
    echo "local-merge: the clone has uncommitted or untracked files; commit, stash or remove them first:" >&2
    printf '%s\n' "$dirty" | sed 's/^/  /' >&2
    exit 1
  fi

  # The clone's origin must be the repo whose PRs we fetch.
  local url want
  url=$(g remote get-url origin 2>/dev/null) || die "the clone has no 'origin' remote"
  want=$(tr '[:upper:]' '[:lower:]' <<<"$repo")
  [[ "$(tr '[:upper:]' '[:lower:]' <<<"$url" | sed -E 's#\.git/?$##; s#/$##')" == *"/$want" || \
     "$(tr '[:upper:]' '[:lower:]' <<<"$url" | sed -E 's#\.git/?$##; s#/$##')" == *":$want" ]] \
    || die "origin ($url) is not $repo"

  local default
  default=$(ghr repo view "$repo" --json defaultBranchRef -q .defaultBranchRef.name) || die "could not read the default branch of $repo"
  [[ -n "$default" ]] || die "no default branch reported for $repo"

  echo "fetching origin..."
  g fetch -q origin || die "git fetch origin failed"
  local base_sha; base_sha=$(g rev-parse --verify -q "refs/remotes/origin/$default") || die "origin/$default not found after fetch"

  local orig_branch orig_sha orig_ref
  orig_sha=$(g rev-parse HEAD)
  if orig_branch=$(g symbolic-ref -q --short HEAD); then orig_ref="branch:$orig_branch"; else orig_ref="detached:$orig_sha"; fi

  local branch="dependabot-e2e/$(date -u +%Y%m%dT%H%M%SZ)"
  g show-ref -q --verify "refs/heads/$branch" && die "branch $branch already exists"

  {
    echo "repo=$repo"
    echo "clone=$clone"
    echo "original_ref=$orig_ref"
    echo "original_sha=$orig_sha"
    echo "default_branch=$default"
    echo "base_sha=$base_sha"
    echo "branch=$branch"
    echo "started=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "requested=$*"
    echo "plan=$plan"
  } >"$state" || die "could not write $state"

  g checkout -q -b "$branch" "$base_sha" || { rm -f "$state"; die "could not create $branch"; }
  echo "on $branch from origin/$default ($(g rev-parse --short "$base_sha")); original checkout: $orig_ref"

  # An interrupted merge would leave conflict markers behind; abort it so restore can run.
  trap 'echo; echo "interrupted"; [[ -e "$(git -C "$clone" rev-parse --absolute-git-dir)/MERGE_HEAD" ]] && git -C "$clone" merge --abort; echo "run: local-merge.sh restore --clone $clone"; exit 130' INT TERM

  local merged=() skipped=()
  for n in "$@"; do
    echo
    echo "=== #$n"
    local info pr_state title head_oid pr_base
    if ! info=$(ghr pr view "$n" -R "$repo" --json state,title,headRefOid,baseRefName \
        -q '[.state, .headRefOid, .baseRefName, .title] | join("\t")'); then
      skipped+=("#$n: could not read PR"); echo "skipped=$n could not read PR" >>"$state"; continue
    fi
    IFS=$'\t' read -r pr_state head_oid pr_base title <<<"$info"
    echo "  $title"
    if [[ "$pr_state" != "OPEN" ]]; then
      skipped+=("#$n: not open ($pr_state)"); echo "skipped=$n not open ($pr_state)" >>"$state"; echo "  not open: $pr_state"; continue
    fi
    [[ "$pr_base" == "$default" ]] || echo "  note: PR targets $pr_base, not $default"
    if ! g fetch -q origin "pull/$n/head"; then
      skipped+=("#$n: fetch of pull/$n/head failed"); echo "skipped=$n fetch failed" >>"$state"; continue
    fi
    local sha; sha=$(g rev-parse FETCH_HEAD)
    local want; want=$(awk -v n="$n" '$1 == n { print $2; exit }' <<<"$planned")
    if [[ -z "$want" ]]; then
      skipped+=("#$n: not a merge line in $plan"); echo "skipped=$n not a merge line in the plan" >>"$state"; echo "  not a merge line in the plan"; continue
    fi
    if [[ "$sha" != "$want" || "$head_oid" != "$want" ]]; then
      skipped+=("#$n: head moved since review (${want:0:7} -> ${sha:0:7}); refresh or re-review it (applying.md)")
      echo "skipped=$n head moved since review" >>"$state"; echo "  head moved since review: ${want:0:7} -> ${sha:0:7}"; continue
    fi

    local msg="Merge #$n: $title"$'\n\n'"Local e2e validation merge of $sha; not for pushing."
    local out
    if out=$(g merge -q --no-ff --no-edit -m "$msg" "$sha" 2>&1); then
      merged+=("#$n"); echo "merged=$n $sha" >>"$state"; echo "  merged ($(g rev-parse --short HEAD))"; continue
    fi

    local conflicted
    conflicted=$(g diff --name-only --diff-filter=U)
    if [[ -z "$conflicted" ]]; then
      [[ -e "$(git -C "$clone" rev-parse --absolute-git-dir)/MERGE_HEAD" ]] && g merge --abort
      local why; why=$(tr '\n' ' ' <<<"$out")
      skipped+=("#$n: merge failed: $why"); echo "skipped=$n merge failed: $why" >>"$state"; echo "  merge failed: $why"; continue
    fi

    echo "  conflicts: $(tr '\n' ' ' <<<"$conflicted")"
    local f only_lock=true
    while IFS= read -r f; do [[ "$(basename "$f")" == package-lock.json ]] || only_lock=false; done <<<"$conflicted"
    if ! $only_lock; then
      g merge --abort
      local files; files=$(tr '\n' ' ' <<<"$conflicted" | sed 's/ $//')
      skipped+=("#$n: conflicts in $files"); echo "skipped=$n conflicts in $files" >>"$state"; continue
    fi

    # Only lockfiles conflict, so every package.json merged cleanly. npm 7+ resolves
    # conflict markers in package-lock.json itself when it reinstalls.
    local ok=true why=
    while IFS= read -r f; do
      local dir; dir=$(dirname "$clone/$f")
      echo "  resolving $f with npm install --package-lock-only"
      if ! out=$(cd "$dir" && npm install --package-lock-only --ignore-scripts --no-audit --no-fund 2>&1); then
        # Keep npm's diagnosis (e.g. the ERESOLVE peer conflict), not its log-file pointers.
        why=$(sed -nE 's/^npm (error|ERR!) ?//p' <<<"$out" | grep -vE '^ *$|^code |_logs/|full report|complete log|^ *node_modules/|--force or --legacy-peer-deps|^Found: |from the root project' | head -n 6 | tr '\n' ' ' | sed 's/  */ /g; s/ $//')
        ok=false; why="npm could not resolve $f: ${why:-$(tail -n 1 <<<"$out")}"; break
      fi
      if grep -qE '^(<<<<<<<|=======|>>>>>>>)( |$)' "$clone/$f"; then ok=false; why="conflict markers remain in $f"; break; fi
      if ! jq empty "$clone/$f" 2>/dev/null; then ok=false; why="$f is not valid JSON after npm"; break; fi
      g add -- "$f"
    done <<<"$conflicted"
    if $ok && [[ -n "$(g diff --name-only --diff-filter=U)" ]]; then ok=false; why="unresolved files remain"; fi
    if $ok && g commit -q --no-edit; then
      merged+=("#$n (lockfile conflict resolved by npm)")
      echo "merged=$n $sha lockfile-resolved" >>"$state"
      echo "  merged with npm-resolved lockfile ($(g rev-parse --short HEAD))"
    else
      g merge --abort
      [[ -n "$why" ]] || why="commit failed"
      skipped+=("#$n: lockfile conflict not resolved ($why)"); echo "skipped=$n lockfile conflict not resolved ($why)" >>"$state"
      echo "  $why"
    fi
  done
  trap - INT TERM

  echo
  echo "merged: ${merged[*]:-none}"
  echo "skipped (not validated; leave them for a later run):"
  if ((${#skipped[@]})); then printf '  %s\n' "${skipped[@]}"; else echo "  none"; fi
  echo
  echo "diff vs origin/$default:"
  g --no-pager diff --stat "$base_sha...HEAD" | sed 's/^/  /'
  echo
  echo "clone $clone is on $branch. Rebuild the affected resources, run the e2e suites, then:"
  echo "  bash $here/local-merge.sh restore --clone $clone"
}

cmd_status() {
  parse_clone_args "$@"
  ((${#rest[@]})) && usage
  resolve_clone
  [[ -e "$state" ]] || { echo "no local-merge run in progress for $clone (no $state)"; return 0; }
  echo "state ($state):"
  sed 's/^/  /' "$state"
  local branch base current
  branch=$(state_get branch); base=$(state_get base_sha)
  current=$(g symbolic-ref -q --short HEAD || echo "detached at $(g rev-parse --short HEAD)")
  echo
  echo "current checkout: $current"
  [[ "$current" == "$branch" ]] || echo "  (not the e2e branch $branch)"
  if g show-ref -q --verify "refs/heads/$branch"; then
    echo "merged commits on $branch:"
    g --no-pager log --first-parent --reverse --format='  %h %s' "$base..$branch"
  else
    echo "branch $branch does not exist"
  fi
  local op; op=$(in_progress_op) && echo "operation in progress: $op"
  local dirty; dirty=$(porcelain)
  [[ -n "$dirty" ]] && { echo "uncommitted changes:"; printf '%s\n' "$dirty" | sed 's/^/  /'; }
  return 0
}

cmd_restore() {
  parse_clone_args "$@"
  ((${#rest[@]})) && usage
  resolve_clone
  [[ -e "$state" ]] || die "no state file ($state); nothing to restore"
  local branch orig_ref orig_sha current
  branch=$(state_get branch); orig_ref=$(state_get original_ref); orig_sha=$(state_get original_sha)
  [[ -n "$branch" && -n "$orig_ref" ]] || die "state file is incomplete: $state"
  current=$(g symbolic-ref -q --short HEAD || true)

  local op
  if op=$(in_progress_op); then
    if [[ "$op" == MERGE_HEAD && "$current" == "$branch" ]]; then
      echo "aborting the interrupted merge on $branch"
      g merge --abort || die "git merge --abort failed"
    else
      die "the clone has an operation in progress ($op); finish or abort it first"
    fi
  fi

  local dirty; dirty=$(porcelain)
  if [[ -n "$dirty" ]]; then
    local line path other=() build_tracked=() build_untracked=()
    while IFS= read -r line; do
      path=${line:3}; path=${path#*" -> "}; path=${path#\"}; path=${path%\"}
      if [[ "$path" =~ $BUILD_PATHS_RE ]]; then
        if [[ "${line:0:2}" == "??" ]]; then build_untracked+=("$path"); else build_tracked+=("$path"); fi
      else
        other+=("$line")
      fi
    done <<<"$dirty"
    if ((${#other[@]})); then
      echo "local-merge: the clone has changes that aren't build output; commit, stash or remove them first:" >&2
      printf '  %s\n' "${other[@]}" >&2
      exit 1
    fi
    if ((${#build_tracked[@]})); then
      [[ "$current" == "$branch" ]] || die "build output changed tracked files, but the clone is not on $branch; not discarding: ${build_tracked[*]}"
      echo "discarding build changes to tracked files on $branch:"
      printf '  %s\n' "${build_tracked[@]}"
      g reset -q -- "${build_tracked[@]}" && g checkout -q -- "${build_tracked[@]}" || die "could not discard build changes"
    fi
    if ((${#build_untracked[@]})); then
      echo "leaving untracked build output in place:"
      printf '  %s\n' "${build_untracked[@]}"
    fi
  fi

  case "$orig_ref" in
    branch:*) g checkout -q "${orig_ref#branch:}" || die "could not check out ${orig_ref#branch:}" ;;
    detached:*) g checkout -q --detach "${orig_ref#detached:}" || die "could not check out ${orig_ref#detached:}" ;;
    *) die "unknown original_ref in state file: $orig_ref" ;;
  esac
  local now; now=$(g rev-parse HEAD)
  [[ "$now" == "$orig_sha" ]] || echo "note: ${orig_ref#*:} is now at $(g rev-parse --short HEAD), not $(git -C "$clone" rev-parse --short "$orig_sha") as at start (it moved meanwhile)"

  if g show-ref -q --verify "refs/heads/$branch"; then g branch -q -D "$branch" || die "could not delete $branch"; fi
  rm -f "$state"
  echo "restored $clone to ${orig_ref/:/ } ($(g rev-parse --short HEAD)); deleted $branch"
  echo
  echo "REMINDER: the running app still serves the e2e build. Reinstall dependencies and rebuild"
  echo "the affected resources again so it serves your code (local-e2e.md, steps 3 and 5)."
}

sub=${1:-}; shift || true
case "$sub" in
  start) cmd_start "$@" ;;
  status) cmd_status "$@" ;;
  restore) cmd_restore "$@" ;;
  *) usage ;;
esac
