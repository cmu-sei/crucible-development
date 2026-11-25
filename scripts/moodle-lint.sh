#!/bin/bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Run the Moodle coding standard over a plugin exactly the way CI does: `moodle-plugin-ci phpcs`,
# with the plugin placed inside a Moodle tree and the same moodle-cs version CI installs.
#
# Usage:
#   scripts/moodle-lint.sh /mnt/data/crucible/moodle/mod/topomojo
#   scripts/moodle-lint.sh mod/topomojo --fix
#   scripts/moodle-lint.sh mod/topomojo --summary
#   scripts/moodle-lint.sh --update-ci
#
# Options:
#   --fix        apply every auto-fixable violation with phpcbf, copy the changes back into the
#                plugin checkout, then re-run the CI check and exit with its result
#   --summary    count violations by sniff code instead of listing them
#   --update-ci  reinstall moodle-plugin-ci so the local moodle-cs matches what CI installs today
#
# Why not plain phpcs: the sniffs that matter most here only work inside a Moodle tree (lang file
# ordering, the file docblock position, PHPUnit coverage tags, MOODLE_INTERNAL checks), and CI
# installs the newest moodle-cs, which is newer than the one in the devcontainer's composer global.
# A plugin can be clean under the global phpcs and still fail CI. Only errors fail CI; warnings are
# reported and do not change the exit code.
#
# Needs a Moodle tree at $MOODLE_CI_ROOT/moodle (default /mnt/data/crucible/.moodle-ci/moodle,
# created by `moodle-plugin-ci install`). moodle-plugin-ci itself is installed on first use.

set -euo pipefail

MOODLE_ROOT="${MOODLE_ROOT:-/mnt/data/crucible/moodle}"
CI_ROOT="${MOODLE_CI_ROOT:-/mnt/data/crucible/.moodle-ci}"
MOODLE_TREE="${CI_ROOT}/moodle"
CI_LINT="${CI_ROOT}/ci-lint"

usage() {
  echo "Usage: $(basename "$0") <plugin-path> [--fix | --summary]" >&2
  echo "       $(basename "$0") --update-ci" >&2
  echo "  <plugin-path> is absolute, or relative to ${MOODLE_ROOT}" >&2
  exit 2
}

# One run at a time: two runs would trample each other's copy of the plugin, and a reinstall
# would delete moodle-plugin-ci under a running lint.
lock() {
  mkdir -p "$CI_ROOT"
  exec 9>"${CI_ROOT}/.moodle-lint.lock"
  if ! flock -n 9; then
    echo "Another moodle-lint.sh run is in progress (lock ${CI_ROOT}/.moodle-lint.lock)" >&2
    exit 1
  fi
}

install_ci() {
  # Same command the workflow runs; ^4 is the current major. Install beside the old copy and
  # swap on success, so a failed download leaves the working install in place.
  rm -rf "${CI_LINT}.new"
  composer create-project -n --no-dev --prefer-dist moodlehq/moodle-plugin-ci "${CI_LINT}.new" ^4
  rm -rf "$CI_LINT"
  mv "${CI_LINT}.new" "$CI_LINT"
}

# Copy the files tracked by the git checkout $1 from directory $2 into directory $3. Files that are
# deleted in the working tree are skipped; other read errors stay fatal. Submodules are not
# descended into, as in a CI checkout without them.
copy_tracked() {
  git -C "$1" ls-files -z |
    while IFS= read -r -d '' f; do
      if [ -e "$2/$f" ] || [ -L "$2/$f" ]; then printf '%s\0' "$f"; fi
    done |
    tar -C "$2" --null --no-recursion -T - -cf - | tar -C "$3" -xf -
}

[ $# -ge 1 ] || usage

if [ "$1" = "--update-ci" ]; then
  lock
  install_ci
  exit 0
fi

target="$1"
shift
[ -d "$target" ] || target="${MOODLE_ROOT}/${target}"
if [ ! -d "$target" ]; then
  echo "Not a directory: $target" >&2
  exit 2
fi
target="$(cd "$target" && pwd)"

mode=phpcs
summary=0
for arg in "$@"; do
  case "$arg" in
    --fix) mode=phpcbf ;;
    --summary) summary=1 ;;
    *) usage ;;
  esac
done
if [ "$mode" = "phpcbf" ] && [ "$summary" -eq 1 ]; then
  echo "--fix and --summary cannot be combined" >&2
  usage
fi

if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $target" >&2
  echo "This script lints the files git tracks, so it needs one." >&2
  exit 2
fi

if [ ! -f "${MOODLE_TREE}/version.php" ]; then
  echo "No Moodle tree at ${MOODLE_TREE}." >&2
  echo "Create one with moodle-plugin-ci install, or point MOODLE_CI_ROOT at an existing install." >&2
  exit 1
fi

lock
if [ ! -x "${CI_LINT}/bin/moodle-plugin-ci" ]; then
  echo "Installing moodle-plugin-ci into ${CI_LINT} (one time)..."
  install_ci
fi

# The plugin's directory inside the Moodle tree comes from its component name.
component=$(sed -n "s/^[[:space:]]*\$plugin->component *= *['\"]\([a-z0-9_]*\)['\"].*/\1/p" "${target}/version.php" | head -1)
if [ -z "$component" ]; then
  echo "No \$plugin->component in ${target}/version.php" >&2
  exit 2
fi
type="${component%%_*}"
name="${component#*_}"
case "$type" in
  mod) base=mod ;;
  block) base=blocks ;;
  local) base=local ;;
  theme) base=theme ;;
  qbank) base=question/bank ;;
  qtype) base=question/type ;;
  qbehaviour) base=question/behaviour ;;
  tool) base=admin/tool ;;
  aiplacement) base=ai/placement ;;
  aiprovider) base=ai/provider ;;
  format) base=course/format ;;
  gradereport) base=grade/report ;;
  gradeexport) base=grade/export ;;
  gradeimport) base=grade/import ;;
  report) base=report ;;
  auth) base=auth ;;
  enrol) base=enrol ;;
  filter) base=filter ;;
  editor) base=lib/editor ;;
  repository) base=repository ;;
  logstore) base=admin/tool/log/store ;;
  assignsubmission) base=mod/assign/submission ;;
  assignfeedback) base=mod/assign/feedback ;;
  qformat) base=question/format ;;
  *)
    echo "Unknown plugin type '${type}' for ${component}; add it to the case in $(basename "$0")" >&2
    exit 2
    ;;
esac
dest="${MOODLE_TREE}/${base}/${name}"
mkdir -p "$(dirname "$dest")"
if [ "$(realpath -m "$dest")" = "$(realpath "$target")" ]; then
  echo "${target} is the copy inside the Moodle tree; point the script at the plugin's own checkout" >&2
  exit 2
fi
count=$(git -C "$target" ls-files -- '*.php' | wc -l)
if [ "$count" -eq 0 ]; then
  echo "No tracked PHP files in $target"
  exit 0
fi
if [ -L "$dest" ]; then
  echo "${dest} is a symlink; refusing to lint through it" >&2
  exit 1
fi

# The Moodle tree is shared with the PHPUnit runs, which keep plugins (and dependencies of
# plugins) in it. If a copy of this plugin is already there, put it aside and restore it on exit
# so linting never destroys it.
aside="${dest}.pre-lint"
restore() {
  rm -rf "$dest"
  if [ -d "$aside" ]; then
    mv "$aside" "$dest"
  fi
}
# A backup left by a run that was killed holds the original plugin: put it back first.
if [ -d "$aside" ]; then
  rm -rf "$dest"
  mv "$aside" "$dest"
fi
if [ -e "$dest" ]; then
  mv "$dest" "$aside"
fi
trap restore EXIT

# Lint exactly the tracked files, which is what a CI checkout contains. Several checkouts carry a
# gitignored vendor/ or node_modules/ that CI never sees.
mkdir -p "$dest"
copy_tracked "$target" "$target" "$dest"
echo "Running moodle-plugin-ci ${mode} (moodle-cs $(sed -n '/"name": "moodlehq\/moodle-cs"/{n;s/.*"version": "\(.*\)".*/\1/p}' "${CI_LINT}/composer.lock" | head -1)) over ${count} PHP files for ${component} in ${MOODLE_TREE}"

export MOODLE_DIR="$MOODLE_TREE"
ci="${CI_LINT}/bin/moodle-plugin-ci"
status=0
if [ "$mode" = "phpcbf" ]; then
  # moodle-plugin-ci phpcbf always exits 0, so it says nothing about what is left. Fix, copy the
  # changes back, then run the real check and report its result.
  "$ci" phpcbf "$dest" || true
  # Copy back only files that git tracks, so a stray file in the Moodle tree never lands in the plugin.
  copy_tracked "$target" "$dest" "$target"
  echo "Applied fixes to ${target}. Review with: git -C ${target} diff --stat"
  echo "Re-checking what is left:"
  "$ci" phpcs "$dest" || status=$?
elif [ "$summary" -eq 1 ]; then
  # Same run as CI (same files, same options), with the sniff codes from its output counted.
  out=$("$ci" phpcs "$dest" 2>&1) || status=$?
  tally=$(printf '%s\n' "$out" | grep -oE '\([A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+\)$' | tr -d '()' | sort | uniq -c | sort -rn || true)
  if [ -n "$tally" ]; then
    printf '%s\n' "$tally"
  elif [ "$status" -ne 0 ]; then
    # Failed without any sniff results: show why.
    printf '%s\n' "$out" >&2
  fi
else
  "$ci" phpcs "$dest" || status=$?
fi

exit "$status"
