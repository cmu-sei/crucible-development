#!/usr/bin/env bash
# Copy the shared Crucible UI test files into one or more UI repos (or worktrees)
# and verify they are byte-identical to the standard.
#
#   sync.sh [--check] [--test] <repo-path> [<repo-path> ...]
#
#   --check   report drift only; copy nothing
#   --test    run `npm test` in each repo after copying
#
# The two app-specific helpers (default-test-providers.ts and
# mock-permission-data.service.ts) are never copied; check-repo.js compares
# their shape with the templates (every provider and stub member the template
# has, the template's exports, every common-library service the app injects).
# Patches are copied only for packages the repo's package-lock.json contains.
# build_test.yml is compared but not copied, because its node-version must
# match the repo's Dockerfile.
set -u
STANDARD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK=0; RUN_TESTS=0; REPOS=()
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    --test) RUN_TESTS=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) REPOS+=("$arg") ;;
  esac
done
[ ${#REPOS[@]} -gt 0 ] || { echo "usage: sync.sh [--check] [--test] <repo-path>..." >&2; exit 2; }

[ $RUN_TESTS -eq 1 ] && LOG_DIR="$(mktemp -d -t ui-sync-test.XXXXXX)" && echo "test logs: $LOG_DIR"
SHARED_HELPERS=(render-component unstubbed api-stub record-emissions unhandled-rx-errors fake-hub-connection activated-route dialog-refs file-list)
status=0

sync_file() { # src dst
  local src="$1" dst="$2" rel="${2#$REPO/}"
  if [ ! -f "$dst" ]; then
    if [ $CHECK -eq 1 ]; then echo "  MISSING  $rel"; status=1; else mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; echo "  added    $rel"; fi
  elif ! cmp -s "$src" "$dst"; then
    if [ $CHECK -eq 1 ]; then echo "  DRIFT    $rel"; status=1; else cp "$src" "$dst"; echo "  updated  $rel"; fi
  fi
}

for REPO in "${REPOS[@]}"; do
  REPO="${REPO%/}"
  [ -f "$REPO/package.json" ] || { echo "$REPO: no package.json" >&2; status=1; continue; }
  REPO="$(cd "$REPO" && pwd)"   # absolute, so --test can cd and still write its log
  echo "== $REPO"
  sync_file "$STANDARD/vitest.config.ts" "$REPO/vitest.config.ts"
  sync_file "$STANDARD/test-setup.ts" "$REPO/src/test-setup.ts"
  for h in "${SHARED_HELPERS[@]}"; do
    # fake-hub-connection is only needed by apps that use SignalR
    if [ "$h" = fake-hub-connection ] && ! grep -q '"@microsoft/signalr"' "$REPO/package.json"; then continue; fi
    sync_file "$STANDARD/test-utils/$h.ts" "$REPO/src/app/test-utils/$h.ts"
  done
  for patch in "$STANDARD"/patches/*.patch; do
    name="$(basename "$patch")"; pkg="${name%+*}"; pkg="${pkg//+//}"   # @scope+name+ver.patch -> @scope/name
    if grep -q "\"node_modules/$pkg\"" "$REPO/package-lock.json" 2>/dev/null; then
      sync_file "$patch" "$REPO/patches/$name"
    elif [ -f "$REPO/patches/$name" ]; then
      echo "  STALE    patches/$name (package not in lockfile)"; status=1
    fi
  done
  for f in "$REPO/patches/"*.patch; do
    [ -f "$f" ] && [ ! -f "$STANDARD/patches/$(basename "$f")" ] && { echo "  UNKNOWN  patches/$(basename "$f") (not in standard)"; status=1; }
  done
  if [ -f "$REPO/.github/workflows/build_test.yml" ]; then
    if ! diff -q <(grep -v 'node-version' "$STANDARD/build_test.yml") <(grep -v 'node-version' "$REPO/.github/workflows/build_test.yml") >/dev/null; then
      echo "  DRIFT    .github/workflows/build_test.yml (apart from node-version)"; status=1
    fi
  else
    echo "  MISSING  .github/workflows/build_test.yml"; status=1
  fi
  for required in src/app/test-utils/default-test-providers.ts src/app/test-utils/mock-permission-data.service.ts tsconfig.spec.json; do
    [ -f "$REPO/$required" ] || { echo "  MISSING  $required (app-specific; build it from the template)"; status=1; }
  done
  node "$STANDARD/check-repo.js" helpers "$REPO" || status=1
  [ -f "$REPO/src/polyfills.ts" ] && { echo "  DRIFT    src/polyfills.ts exists (zone.js belongs in the polyfills array)"; status=1; }
  # Only the live targets must be on @angular/build; dead lint/e2e targets are a follow-up.
  bad_targets=$(node -e '
const fs=require("fs"),repo=process.argv[1];let parse;try{parse=require(repo+"/node_modules/jsonc-parser").parse}catch(e){parse=s=>JSON.parse(s.replace(/^\s*\/\/.*$/mg,""))}
    const a=parse(fs.readFileSync(repo+"/angular.json","utf8"));
    const want={build:"@angular/build:application",serve:"@angular/build:dev-server","extract-i18n":"@angular/build:extract-i18n",test:"@angular/build:unit-test"};
    const out=[];
    for (const [name,p] of Object.entries(a.projects)) for (const [t,b] of Object.entries(want)) {
      const got=p.architect&&p.architect[t]&&p.architect[t].builder; if (got && got!==b) out.push(name+":"+t+"="+got); }
    console.log(out.join(" "))' "$REPO")
  [ -n "$bad_targets" ] && { echo "  DRIFT    builders: $bad_targets"; status=1; }
  grep -q '"browser": *{' "$REPO/angular.json" && grep -A1 '"browser": *{' "$REPO/angular.json" | grep -q browsers && { echo "  DRIFT    angular.json has a 'browser' test configuration"; status=1; }
  if [ $RUN_TESTS -eq 1 ]; then
    echo "  running npm test ..."
    # The log goes outside the repo, so it never shows up as an untracked file.
    TEST_LOG="$LOG_DIR/$(basename "$REPO").log"
    if (cd "$REPO" && npm test >"$TEST_LOG" 2>&1); then
      sed 's/\x1b\[[0-9;]*m//g' "$TEST_LOG" | grep -aE '^\s*(Test Files|Tests) ' | sed 's/^/  /'
    else
      echo "  FAILED   npm test (see $TEST_LOG)"; status=1
    fi
  fi
done
[ $status -eq 0 ] && echo "ok: all repos match the standard" || echo "problems found (exit 1)"
exit $status
