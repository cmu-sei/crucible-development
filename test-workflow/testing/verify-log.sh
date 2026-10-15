# Sourced by api-testing/verify.sh and ui-testing/verify.sh: the verify log (testing/README.md, "The verify
# log"). A run writes agent-docs/test-work/<app>/verify-<tree hash>.log, whose first lines say what it ran
# on, and points verify-latest.log at it. A reader compares the log's `tree` line with
# `testing/tree-hash.sh <worktree>`, or runs `testing/tree-hash.sh --check <log> <worktree>`.

VERIFY_LOG_TESTING="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The workspace docs (test-work/): on the /mnt/data volume, never in the checkout this script runs from.
VERIFY_LOG_DOCS="${CRUCIBLE_ROOT:-/mnt/data/crucible}/agent-docs"

# verify_log_start <stack> <app> <worktree> [<log dir>]: writes the header and exports VERIFY_LOG.
verify_log_start() {
  local stack="$1" app="$2" wt="$3" dir="${4:-}" tree version
  [ -n "$dir" ] || dir="$VERIFY_LOG_DOCS/test-work/$app"
  mkdir -p "$dir" || { echo "verify.sh: cannot create $dir" >&2; exit 2; }
  dir="$(cd "$dir" && pwd)"
  tree="$("$VERIFY_LOG_TESTING/tree-hash.sh" "$wt")" || { echo "verify.sh: cannot hash $wt" >&2; exit 2; }
  version="$(sed -n 's/^## \([0-9]\{4\}-[0-9][0-9]-[0-9][0-9]\).*/\1/p' "$VERIFY_LOG_TESTING/CHANGELOG.md" | head -1)"
  export VERIFY_LOG="$dir/verify-$tree.log"
  {
    echo "verify $stack $app"
    echo "tree $tree"
    echo "worktree $wt"
    echo "head $(git -C "$wt" rev-parse HEAD 2>/dev/null) $(git -C "$wt" branch --show-current 2>/dev/null)"
    echo "standard ${version:-unknown}"
    echo "started $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"$VERIFY_LOG"
}

# verify_log_end <worktree> <exit code>: stamps the end, and says so when the tree changed during the run.
verify_log_end() {
  local wt="$1" rc="$2" after before
  before="$(sed -n 's/^tree //p' "$VERIFY_LOG" | head -1)"
  after="$("$VERIFY_LOG_TESTING/tree-hash.sh" "$wt" 2>/dev/null)"
  {
    echo "finished $(date -u +%Y-%m-%dT%H:%M:%SZ) exit $rc"
    [ "$after" = "$before" ] || echo "NOTE  the tree changed during the run (now $after): this log describes neither tree; run verify.sh again"
  } >>"$VERIFY_LOG"
  ln -sfn "$(basename "$VERIFY_LOG")" "$(dirname "$VERIFY_LOG")/verify-latest.log"
  echo "log: $VERIFY_LOG"
}
