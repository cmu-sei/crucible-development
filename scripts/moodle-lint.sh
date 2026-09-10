#!/bin/bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Run the Moodle coding standard over a plugin, matching what `moodle-plugin-ci phpcs`
# checks in each plugin repo's CI.
#
# Usage:
#   scripts/moodle-lint.sh /mnt/data/crucible/moodle/mod/topomojo
#   scripts/moodle-lint.sh mod/topomojo --fix
#   scripts/moodle-lint.sh mod/topomojo --report=source
#
# Options:
#   --fix   run phpcbf instead of phpcs, applying every auto-fixable violation
#
# Anything else is passed straight through to phpcs, so --report=source,
# --sniffs=... and friends work as normal.

set -euo pipefail

MOODLE_ROOT="${MOODLE_ROOT:-/mnt/data/crucible/moodle}"

usage() {
  echo "Usage: $(basename "$0") <plugin-path> [--fix] [phpcs options...]" >&2
  echo "  <plugin-path> is absolute, or relative to ${MOODLE_ROOT}" >&2
  exit 2
}

[ $# -ge 1 ] || usage

target="$1"
shift
[ -d "$target" ] || target="${MOODLE_ROOT}/${target}"
if [ ! -d "$target" ]; then
  echo "Not a directory: $target" >&2
  exit 2
fi

tool=phpcs
args=()
for arg in "$@"; do
  case "$arg" in
    --fix) tool=phpcbf ;;
    *) args+=("$arg") ;;
  esac
done

if ! command -v "$tool" >/dev/null 2>&1; then
  echo "$tool not found. It is installed by .devcontainer/postcreate.sh:" >&2
  echo "  composer global require moodlehq/moodle-cs" >&2
  exit 1
fi

# Lint the files git tracks rather than everything on disk. Several plugins carry a
# gitignored vendor/ and node_modules/ from local composer and npm runs; mod_topomojo's
# alone is 995 extra files. Those are absent from a CI checkout, so including them both
# reports thousands of irrelevant violations and builds an argv large enough that
# proc_open refuses to spawn phpcs at all. Tracked files are exactly what CI sees.
cd "$target"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $target" >&2
  echo "This script scopes the run to tracked files, so it needs one." >&2
  exit 2
fi

count=$(git ls-files -- '*.php' | wc -l)
if [ "$count" -eq 0 ]; then
  echo "No tracked PHP files in $target"
  exit 0
fi
echo "Running $tool with the moodle standard over $count tracked PHP files in $target"

# The runtime-set values mirror moodle-plugin-ci's phpcs command, so the counts here match
# what CI reports. Warnings are informational there and are informational here too.
git ls-files -z -- '*.php' | xargs -0 "$tool" \
  --standard=moodle \
  --extensions=php \
  -s \
  --runtime-set ignore_warnings_on_exit 1 \
  "${args[@]}"
