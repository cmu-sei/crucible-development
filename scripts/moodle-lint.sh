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
#   --fix        run phpcbf instead of phpcs, applying every auto-fixable violation, then copy the
#                changes back into the plugin checkout
#   --summary    count violations by sniff (phpcs --report=source) instead of listing them
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

install_ci() {
  # Same command the workflow runs; ^4 is the current major.
  rm -rf "$CI_LINT"
  composer create-project -n --no-dev --prefer-dist moodlehq/moodle-plugin-ci "$CI_LINT" ^4
}

[ $# -ge 1 ] || usage

if [ "$1" = "--update-ci" ]; then
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

if [ ! -x "${CI_LINT}/bin/moodle-plugin-ci" ]; then
  echo "Installing moodle-plugin-ci into ${CI_LINT} (one time)..."
  install_ci
fi

# The plugin's directory inside the Moodle tree comes from its component name.
component=$(sed -n "s/.*\$plugin->component *= *['\"]\([a-z0-9_]*\)['\"].*/\1/p" "${target}/version.php" | head -1)
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
  *)
    echo "Unknown plugin type '${type}' for ${component}; add it to the case in $(basename "$0")" >&2
    exit 2
    ;;
esac
dest="${MOODLE_TREE}/${base}/${name}"
mkdir -p "$(dirname "$dest")"
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
rm -rf "$aside"
if [ -e "$dest" ]; then
  mv "$dest" "$aside"
fi
trap restore EXIT

# Lint exactly the tracked files, which is what a CI checkout contains. Several checkouts carry a
# gitignored vendor/ or node_modules/ that CI never sees.
mkdir -p "$dest"
git -C "$target" ls-files -z | rsync -a --from0 --files-from=- "$target/" "$dest/"
count=$(git -C "$target" ls-files -- '*.php' | wc -l)
echo "Running moodle-plugin-ci ${mode} (moodle-cs $(sed -n '/"name": "moodlehq\/moodle-cs"/{n;s/.*"version": "\(.*\)".*/\1/p}' "${CI_LINT}/composer.lock" | head -1)) over ${count} PHP files for ${component} in ${MOODLE_TREE}"

export MOODLE_DIR="$MOODLE_TREE"
status=0
if [ "$summary" -eq 1 ]; then
  (cd "$dest" && "${CI_LINT}/vendor/bin/phpcs" --standard=moodle --extensions=php -s --report=source \
    --runtime-set ignore_warnings_on_exit 1 .) || status=$?
else
  "${CI_LINT}/bin/moodle-plugin-ci" "$mode" "$dest" || status=$?
fi

if [ "$mode" = "phpcbf" ]; then
  # Copy back only files that git tracks, so a stray file in the Moodle tree never lands in the plugin.
  git -C "$target" ls-files -z | rsync -a --from0 --files-from=- "$dest/" "$target/"
  echo "Applied fixes to ${target}. Review with: git -C ${target} diff --stat"
  # phpcbf exits non-zero when it fixed something; that is not a failure here.
  status=0
fi

exit "$status"
