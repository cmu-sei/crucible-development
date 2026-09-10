#!/bin/bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Provision and run PHPUnit inside a running Moodle container, per
# https://moodledev.io/docs/5.1/guides/testing
#
# The plugin source under /mnt/data/crucible/moodle is bind-mounted into the container, so
# tests run against the working tree with no copy step: edit, then re-run.
#
# Usage:
#   scripts/moodle-phpunit.sh --init                    # one-time setup per container
#   scripts/moodle-phpunit.sh mod_topomojo              # run one plugin's suite
#   scripts/moodle-phpunit.sh mod_topomojo --strict     # with the flags CI fails on
#   scripts/moodle-phpunit.sh --rebuild-config          # after adding a new test file
#   scripts/moodle-phpunit.sh -c moodle52 mod_topomojo  # against Moodle 5.2
#   scripts/moodle-phpunit.sh mod_topomojo -- --filter test_add_instance
#
# --init is not part of container startup, deliberately. It installs ~70 composer dev
# packages and builds a full second Moodle install in the phpu_ table prefix, which takes
# minutes; paying that on every F5 is not worth it. Re-run --init after a container rebuild.

set -euo pipefail

CONTAINER="${MOODLE_CONTAINER:-moodle}"
MODE=run
STRICT=0
SUITE=""
PASSTHROUGH=()

usage() {
  cat >&2 <<'EOF'
Usage: moodle-phpunit.sh [-c CONTAINER] [--init | --rebuild-config | <component>] [--strict] [-- phpunit args]

  -c, --container NAME  Moodle container to use (default: moodle, or $MOODLE_CONTAINER)
  -i, --init            Provision the PHPUnit environment in the container, then exit
      --rebuild-config  Regenerate phpunit.xml, needed after adding a test file or plugin
      --strict          Add the --fail-on-* flags moodle-plugin-ci uses in CI
  <component>           Frankenstyle name, e.g. mod_topomojo. Runs its testsuite.
                        Omit to run every suite, which takes a long time.
EOF
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--container) CONTAINER="${2:-}"; [ -n "$CONTAINER" ] || usage; shift 2 ;;
    -i|--init) MODE=init; shift ;;
    --rebuild-config) MODE=rebuild; shift ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage ;;
    --) shift; PASSTHROUGH+=("$@"); break ;;
    -*) PASSTHROUGH+=("$1"); shift ;;
    *) SUITE="$1"; shift ;;
  esac
done

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "No such container: $CONTAINER" >&2
  echo "Start the Moodle resource from the Aspire dashboard first." >&2
  exit 1
fi

# Moodle 5.1 moved the web root into public/, so admin/ and lib/ live one level down there
# while config.php stays at the Moodle root. Detect rather than assume, since the 5.0 and
# 5.2 containers are both in play.
if docker exec "$CONTAINER" test -d /var/www/html/public; then
  DIRROOT=/var/www/html/public
else
  DIRROOT=/var/www/html
fi

case "$MODE" in
init)
  echo "Provisioning PHPUnit in $CONTAINER (dirroot $DIRROOT)"
  # Moodle's own composer.json carries phpunit as a dev dependency. The published image
  # installs with --no-dev, so vendor/bin/phpunit is absent until this runs.
  docker exec -w /var/www/html "$CONTAINER" sh -c '
    set -e
    if [ ! -x vendor/bin/phpunit ]; then
      echo "Installing Moodle dev dependencies..."
      COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --no-progress
    else
      echo "vendor/bin/phpunit already present, skipping composer install"
    fi'

  # phpunit_dataroot must sit outside the real dataroot, and the test run has to be able to
  # write it as the web user. Both settings go in ahead of the setup.php require, which is
  # the last executable line of config.php.
  docker exec "$CONTAINER" sh -c '
    set -e
    cfg=/var/www/html/config.php
    if grep -q phpunit_prefix "$cfg"; then
      echo "config.php already carries the phpunit settings"
    else
      echo "Adding phpunit_prefix and phpunit_dataroot to config.php"
      sed -i "s|^require_once(__DIR__ . ./lib/setup.php.);|\$CFG->phpunit_prefix = '"'"'phpu_'"'"';\n\$CFG->phpunit_dataroot = '"'"'/var/www/phpunitdata'"'"';\n\n&|" "$cfg"
      grep -q phpunit_prefix "$cfg" || { echo "Failed to patch config.php" >&2; exit 1; }
    fi
    mkdir -p /var/www/phpunitdata
    chown -R nobody:nobody /var/www/phpunitdata'

  # Builds the phpu_-prefixed tables alongside the live ones in the same database, and
  # writes phpunit.xml with a testsuite per component.
  #
  # --disable-composer matters twice over. init.php otherwise runs `composer self-update`,
  # which fails outright because HOME is unset in the container and it cannot write
  # /.composer, and then `composer update`, which resolves fresh versions and drifts the
  # container away from Moodle's committed composer.lock. The install above already put the
  # locked dev dependencies in place, so there is nothing here for composer to do.
  docker exec -w /var/www/html "$CONTAINER" \
    php "$DIRROOT/admin/tool/phpunit/cli/init.php" --disable-composer
  echo
  echo "Done. Run a plugin's tests with:"
  echo "  $(basename "$0") -c $CONTAINER mod_topomojo --strict"
  exit 0
  ;;

rebuild)
  # phpunit.xml lists suites and files as they were at init time, so a newly added test
  # file or plugin is invisible until it is regenerated.
  echo "Rebuilding phpunit.xml in $CONTAINER"
  docker exec -w /var/www/html "$CONTAINER" php "$DIRROOT/admin/tool/phpunit/cli/util.php" --buildconfig
  exit 0
  ;;
esac

if ! docker exec "$CONTAINER" test -f /var/www/html/phpunit.xml; then
  echo "No phpunit.xml in $CONTAINER: the test environment is not provisioned." >&2
  echo "Run: $(basename "$0") -c $CONTAINER --init" >&2
  exit 1
fi

ARGS=()
if [ -n "$SUITE" ]; then
  # Moodle names each component's suite <component>_testsuite. Passing the test directory
  # as a path instead silently selects nothing and still exits 0, which looks like a pass.
  suitename="${SUITE}_testsuite"
  if ! docker exec "$CONTAINER" grep -q "\"${suitename}\"" /var/www/html/phpunit.xml; then
    echo "No testsuite '${suitename}' in phpunit.xml." >&2
    echo "If you just added the plugin or its first test, run --rebuild-config." >&2
    exit 1
  fi
  ARGS+=(--testsuite "$suitename")
fi

# The set moodle-plugin-ci uses. Without these, "OK, but there were issues!" exits 0
# locally and 1 in CI, so a local pass is not evidence of a green build.
if [ "$STRICT" -eq 1 ]; then
  ARGS+=(--fail-on-warning --fail-on-notice --fail-on-deprecation
    --fail-on-phpunit-deprecation --fail-on-risky --fail-on-incomplete)
fi

echo "Running phpunit in $CONTAINER: ${ARGS[*]-all suites} ${PASSTHROUGH[*]-}"
exec docker exec -w /var/www/html "$CONTAINER" \
  php vendor/bin/phpunit "${ARGS[@]}" ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}
