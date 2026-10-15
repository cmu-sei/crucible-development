#!/usr/bin/env bash
# The tree hash of a worktree: the git tree id of everything in it, uncommitted and untracked files
# included, ignored files left out. For a clean worktree it equals `git rev-parse HEAD^{tree}`. The verify
# log is stamped with it, and a reader compares it with the worktree's current one (testing/README.md,
# "The verify log").
#
#   tree-hash.sh <worktree>              print the tree hash
#   tree-hash.sh --check <log> <worktree>
#                                        print "current" and exit 0 when the log's `tree` line equals the
#                                        worktree's tree hash, the run finished and the tree did not change
#                                        during it; otherwise print "stale (...)" and exit 1
#
# It reads the worktree through a temporary index outside the repo, so the repo's own index, its files and
# its branches stay as they are; `git add` stores blobs of changed files in the object database, as any
# `git add` does, and nothing references them.
set -u
usage() { echo "usage: tree-hash.sh [--check <log>] <worktree>" >&2; exit 2; }
LOGFILE=""
case "${1:-}" in
  -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  --check) LOGFILE="${2:-}"; shift 2 || usage ;;
esac
WT="${1:-}"
[ -n "$WT" ] && git -C "$WT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || usage
idx="$(mktemp -t tree-hash.XXXXXX)"
trap 'rm -f "$idx" "$idx.lock"' EXIT
(
  export GIT_INDEX_FILE="$idx"
  git -C "$WT" read-tree HEAD &&
  git -C "$WT" add -A . >/dev/null 2>&1 &&
  git -C "$WT" write-tree
) >"$idx.out" 2>/dev/null || { rm -f "$idx.out"; echo "tree-hash.sh: cannot hash $WT" >&2; exit 2; }
hash="$(cat "$idx.out")"; rm -f "$idx.out"
if [ -z "$LOGFILE" ]; then echo "$hash"; exit 0; fi
[ -f "$LOGFILE" ] || { echo "stale (no log $LOGFILE, tree $hash)"; exit 1; }
logged="$(sed -n 's/^tree  *\([0-9a-f]\{40\}\)$/\1/p' "$LOGFILE" | head -1)"
grep -q '^finished ' "$LOGFILE" || { echo "stale (the run did not finish: $LOGFILE)"; exit 1; }
grep -q 'the tree changed during the run' "$LOGFILE" && { echo "stale (the tree changed during that run)"; exit 1; }
if [ "$logged" = "$hash" ]; then echo "current"; exit 0; fi
echo "stale (log ${logged:-none}, tree $hash)"; exit 1
