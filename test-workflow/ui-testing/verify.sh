#!/usr/bin/env bash
# Definition of done for a Crucible UI test setup. Runs every deterministic
# check from the standard against one UI repo (or worktree), and keeps its
# output as the verify log, stamped with the tree hash:
#
#   verify.sh [--clean] [--app <app>] [--base <ref>] [--log-dir <dir>] <repo-path>
#
#   --clean    rm -rf node_modules && npm ci first (the Docker and CI path)
#   --app      the app name for the files outside the repo (agent-docs/ui-test-bugs,
#              agent-docs/ui-test-gaps, agent-docs/test-work); default: the repo folder's name
#   --base     the ref removed tests and thresholds are compared with (default origin/main)
#   --log-dir  where the log goes (default agent-docs/test-work/<app>/); the log is
#              verify-<tree hash>.log, and verify-latest.log points at the newest
#              (testing/README.md, "The verify log")
#
# Checks: shared files match the standard and the app-specific helpers match
# their templates' shape (sync.sh --check); no spec uses a pattern the standard
# replaced, no spec comment says BUG (defects go in agent-docs/ui-test-bugs),
# and every generated-service stub is checked with `satisfies ApiStub`
# (check-repo.js specs); every component and unit has a spec beside it, every
# component, directive or guard that reads a permission has a denied case, and
# so does every input bound from a parent's permission, apart from ones
# allow-listed with a reason in agent-docs/ui-test-gaps/<app>.json
# (check-repo.js gates: missing gates fail, provisional ones are WARN lines);
# every test removed since the merge base is accounted for (check-repo.js
# removed); builders, polyfills and toolchain alignment; thresholds set and not
# below the base's; `npm test` passes with no builder warning and no unexpected
# stderr; a real NgZone in the TestBed; a failing async test does not cascade
# into later tests; a type error in a spec fails the test build; `npm run
# build` passes; `npm run test:coverage` passes. NOTE lines (bookkeeping and
# reviewer input: defect entries whose test is not there, unused imports or
# locals in specs, thresholds that differ from floor(measured) - 1) never fail.
# The broken-gate check is testing/break-gate.sh.
set -u
STANDARD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEAN=0; REPO=""; APP=""; BASE="origin/main"; LOG_DIR=""; ARGS=("$@"); ORIG_PWD="$PWD"
usage() { echo "usage: verify.sh [--clean] [--app <app>] [--base <ref>] [--log-dir <dir>] <repo-path>" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --clean) CLEAN=1 ;;
    --app) [ $# -ge 2 ] || usage; APP="$2"; shift ;;
    --app=*) APP="${1#--app=}" ;;
    --base) [ $# -ge 2 ] || usage; BASE="$2"; shift ;;
    --base=*) BASE="${1#--base=}" ;;
    --log-dir) [ $# -ge 2 ] || usage; LOG_DIR="$2"; shift ;;
    --log-dir=*) LOG_DIR="${1#--log-dir=}" ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    -*) echo "verify.sh: unknown option $1" >&2; usage ;;
    *) REPO="${1%/}" ;;
  esac
  shift
done
[ -n "$REPO" ] && [ -f "$REPO/package.json" ] || usage
case "$LOG_DIR" in ""|/*) ;; *) LOG_DIR="$ORIG_PWD/$LOG_DIR" ;; esac
cd "$REPO" || exit 2
[ -n "$APP" ] || APP="$(basename "$PWD")"
# The verify log (testing/README.md): this run's output, stamped with the tree hash it ran on.
if [ -z "${VERIFY_LOG:-}" ]; then
  . "$STANDARD/../testing/verify-log.sh"
  verify_log_start ui "$APP" "$PWD" "$LOG_DIR"
  (cd "$ORIG_PWD" && VERIFY_LOG="$VERIFY_LOG" "$STANDARD/verify.sh" "${ARGS[@]}") 2>&1 | tee -a "$VERIFY_LOG"; rc=${PIPESTATUS[0]}
  verify_log_end "$PWD" "$rc"
  exit "$rc"
fi
LOG="$(mktemp -d)"; fails=0; warns=0; notes=0
strip() { sed 's/\x1b\[[0-9;]*m//g'; }
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails+1)); }
warn() { echo "WARN  $1"; warns=$((warns+1)); }
# WARN lines are provisional gates; NOTE lines are bookkeeping and reviewer
# input (testing/README.md, "Check output"). Neither fails the run.
note() { echo "NOTE  $1"; notes=$((notes+1)); }
# Vitest's timeout message, counted separately so a load flake is told apart from an assertion.
timeouts() { strip <"$1" | grep -ac 'Test timed out in' || true; }
# Known-noise patterns (POSIX ERE). Applied per paragraph: a blank-line-separated block
# is allowed if any of its lines matches, so continuation lines of a known warning pass.
# npm 12 prints `npm notice run <script>` banners on stderr; those lines are dropped one by one
# (not per paragraph), so a notice next to a real error does not hide it.
DROP_STDERR_LINES='^npm notice '
ALLOWED_STDERR='Sourcemap|NO_COLOR|points to missing source|[Dd]eprecat|Browserslist|browserslist|NG8113|budget|exceeded maximum|@import|angular:styles|angular-sass|WARNING|repetitive|verbose mode|is not ESM|CommonJS|rules skipped|selector errors|Ignored browsers|Unsupported browsers|ES5 output|\.(ts|scss|html|css):[0-9]+:[0-9]+:|│|╵|╷|^[[:space:]]*null[[:space:]]*$'

echo "== verify $REPO"
# 0. clean install
if [ $CLEAN -eq 1 ]; then
  rm -rf node_modules && npm ci >"$LOG/ci.log" 2>&1 && pass "npm ci (clean)" || fail "npm ci (see $LOG/ci.log)"
fi

# 1. shared files and config drift
"$STANDARD/sync.sh" --check "$PWD" >"$LOG/sync.log" 2>&1 && pass "shared files match the standard" || { fail "shared files drift (sync.sh --check)"; sed 's/^/      /' "$LOG/sync.log"; }

# 1b. spec patterns the standard replaced; BUG in spec comments; untyped generated-service stubs;
# NOTE lines for defect entries whose test (spec file and test name) is not there
node "$STANDARD/check-repo.js" specs "$PWD" --app "$APP" >"$LOG/specs.log" 2>&1 && pass "specs use the standard helpers (no stale workarounds, no BUG comments, ApiStub-checked stubs)" || { fail "specs: stale workarounds, BUG comments or unchecked API stubs (check-repo.js specs)"; grep -avE '^  (NOTE|\()' "$LOG/specs.log" | sed 's/^/    /'; }
n=$(grep -ac '^  NOTE' "$LOG/specs.log"); [ "$n" -gt 0 ] && { note "$n defect-document line(s) (check-repo.js specs; testing/fix-docs.js fixes most)"; grep -a '^  NOTE' "$LOG/specs.log" | sed 's/^ *NOTE */    /' | head -40; notes=$((notes+n-1)); }

# 1c. every component and unit has a spec; every permission gate and derived input has a denied case.
# The allow-list is agent-docs/ui-test-gaps/<app>.json, named for the app (as ui-test-bugs/<app>.md).
node "$STANDARD/check-repo.js" gates "$PWD" --app "$APP" >"$LOG/gates.log" 2>&1; rc=$?
gsum=$(grep -a 'SUMMARY' "$LOG/gates.log" | sed 's/^ *SUMMARY *//')
[ $rc -eq 0 ] && pass "every component and unit has a spec and every gate a denied case ($gsum)" || { fail "missing gates (check-repo.js gates; the list is the writer's work list): $gsum"; grep -avE '^  (SUMMARY|WARN|NOTE)' "$LOG/gates.log" | sed 's/^/    /'; }
n=$(grep -ac '^  WARN' "$LOG/gates.log"); [ "$n" -gt 0 ] && { warn "$n provisional gate(s) (check-repo.js gates; missing from the next standard version)"; grep -a '^  WARN' "$LOG/gates.log" | sed 's/^ *WARN */    /'; warns=$((warns+n-1)); }
grep -a '^  NOTE' "$LOG/gates.log" | sed 's/^ *NOTE */    note: /'; notes=$((notes+$(grep -ac '^  NOTE' "$LOG/gates.log")))

# 1d. no test removed since the merge base without an account (testing/README.md, "Removed-test
# accounting"); verify.sh never writes the script's matched file (--no-write), the writer's own run does
node "$STANDARD/check-repo.js" removed "$PWD" --app "$APP" --base "$BASE" --no-write >"$LOG/removed.log" 2>&1; rc=$?
rsum=$(grep -a 'SUMMARY' "$LOG/removed.log" | sed 's/^ *SUMMARY *//')
if [ $rc -ne 0 ]; then fail "removed tests not accounted for (check-repo.js removed): $rsum"; grep -a '^  REMOVED' "$LOG/removed.log" | sed 's/^ *REMOVED */    /'; else pass "every removed test is accounted for ($rsum)"; fi
grep -a '^  NOTE' "$LOG/removed.log" | sed 's/^ *NOTE */    note: /'; notes=$((notes+$(grep -ac '^  NOTE' "$LOG/removed.log")))

# 1e. unused imports and locals in specs and test-utils (tsc --noUnusedLocals, spec program only)
if [ -x node_modules/.bin/tsc ]; then
  node_modules/.bin/tsc -p tsconfig.spec.json --noEmit --noUnusedLocals >"$LOG/unused.log" 2>&1
  unused=$(grep -aE '(\.spec\.ts|/test-utils/[^(]*\.ts)\([0-9]+,[0-9]+\): error TS(6133|6138|6192|6196|6198)' "$LOG/unused.log" || true)
  [ -z "$unused" ] && pass "no unused imports or locals in specs (tsc --noUnusedLocals)" || { note "unused imports or locals in specs (tsc --noUnusedLocals; ui-testing/fix-unused-imports.js removes the imports)"; echo "$unused" | sed 's/^/    /'; }
fi

# 2. toolchain on one version
cli=$(node -p "require('./node_modules/@angular/cli/package.json').version" 2>/dev/null)
core=$(node -p "require('./node_modules/@angular/core/package.json').version" 2>/dev/null)
build=$(node -p "require('./node_modules/@angular/build/package.json').version" 2>/dev/null)
[ -n "$cli" ] && [ "$cli" = "$core" ] && [ "$cli" = "$build" ] && pass "toolchain aligned (cli=core=build=$cli)" || fail "toolchain mixed (cli=$cli core=$core build=$build)"
akita=$(node -p "require('./node_modules/@datorama/akita/package.json').version" 2>/dev/null || echo none)
[ "$akita" = "none" ] || [ "$akita" = "8.0.1" ] && pass "akita $akita" || fail "akita $akita (standard patch is for 8.0.1)"

# 3. zone.js in the polyfills array
node -e '
const fs=require("fs");let parse;try{parse=require(process.cwd()+"/node_modules/jsonc-parser").parse}catch(e){parse=s=>JSON.parse(s.replace(/^\s*\/\/.*$/mg,""))}
const a=parse(fs.readFileSync("angular.json","utf8"));
const p=Object.values(a.projects).find(p=>p.architect&&p.architect.build);
const poly=(p.architect.build.options.polyfills)||[];
process.exit(Array.isArray(poly)&&poly.includes("zone.js")?0:1)' && pass "\"zone.js\" in polyfills array" || fail "\"zone.js\" not in the build target's polyfills array"

# 4. thresholds set, and never below the base's (they only ratchet up)
THRESHOLDS_JS='
const fs=require("fs");let parse;try{parse=require(process.cwd()+"/node_modules/jsonc-parser").parse}catch(e){parse=s=>JSON.parse(s.replace(/^\s*\/\/.*$/mg,""))}
const text=process.argv[1]==="-"?fs.readFileSync(0,"utf8"):fs.readFileSync(process.argv[1],"utf8");
const a=parse(text);
const p=Object.values(a.projects||{}).find(p=>p.architect&&p.architect.test&&p.architect.test.options);
const t=(p&&p.architect.test.options.coverageThresholds)||{};
console.log(["statements","branches","functions","lines"].map(k=>typeof t[k]==="number"?t[k]:"-").join(" "))'
read -r th_s th_b th_f th_l <<<"$(node -e "$THRESHOLDS_JS" angular.json 2>/dev/null)"
case "$th_s $th_b $th_f $th_l" in *-*|"   "|"0 "*|*" 0 "*|*" 0") fail "coverage thresholds missing or zero ($th_s $th_b $th_f $th_l)" ;; *) pass "coverage thresholds set (statements $th_s, branches $th_b, functions $th_f, lines $th_l)" ;; esac
base_rev=$(git merge-base HEAD "$BASE" 2>/dev/null)
if [ -z "$base_rev" ]; then
  note "no merge base with $BASE; thresholds not compared with the base"
else
  read -r b_s b_b b_f b_l <<<"$(git show "$base_rev:angular.json" 2>/dev/null | node -e "$THRESHOLDS_JS" - 2>/dev/null)"
  lower=""
  for k in s b f l; do
    eval "cur=\$th_$k base=\$b_$k"
    [ -n "$base" ] && [ "$base" != "-" ] && [ "$cur" != "-" ] && awk -v c="$cur" -v b="$base" 'BEGIN{exit !(c<b)}' && lower="$lower $k:$cur<$base"
  done
  [ -z "$lower" ] && pass "thresholds not below $BASE's (${b_s:--} ${b_b:--} ${b_f:--} ${b_l:--})" || fail "thresholds below $BASE's angular.json (only ratchet up):$lower"
fi

# 5. npm test: passes, no builder warning, stderr clean
npm test >"$LOG/test.out" 2>"$LOG/test.err"; rc=$?
summary=$(strip <"$LOG/test.out" | grep -aE '^\s*Tests ' | tail -1 | xargs)
to=$(timeouts "$LOG/test.out")
[ $rc -eq 0 ] && pass "npm test ($summary)" || fail "npm test exit $rc ($summary; $to timed out: if only timeouts failed and the host was loaded, rerun alone before treating it as a regression) (see $LOG/test.out)"
grep -qE "buildTarget.*not supported|'unit-test' builder is designed" "$LOG/test.out" "$LOG/test.err" && fail "builder warning: buildTarget not supported" || pass "no builder warning"
unexpected=$(strip <"$LOG/test.err" | grep -avE "$DROP_STDERR_LINES" | awk -v re="$ALLOWED_STDERR" 'BEGIN{RS="";ORS="\n\n"} $0 !~ re && $0 ~ /[^[:space:]]/ {print}' || true)
[ -z "$unexpected" ] && pass "stderr contains only known noise" || { fail "unexpected stderr"; echo "$unexpected" | head -15 | sed 's/^/      /'; }

# 6. probes: real NgZone, no cascade after an async failure, type error fails the build
PROBE_DIR="src/app/verify-probe"; mkdir -p "$PROBE_DIR"
cat >"$PROBE_DIR/cascade.spec.ts" <<'PROBE'
import { describe, expect, it } from 'vitest';
import { NgZone } from '@angular/core';
import { TestBed } from '@angular/core/testing';
describe('verify-probe', () => {
  it('fails on purpose after an await', async () => {
    TestBed.configureTestingModule({});
    await Promise.resolve();
    expect('intentional').toBe('failure');
  });
  it('still runs, with a real NgZone', () => {
    TestBed.configureTestingModule({});
    expect(TestBed.inject(NgZone).constructor.name).toBe('NgZone');
  });
});
PROBE
npm test -- --include="$PROBE_DIR/cascade.spec.ts" >"$LOG/probe1.out" 2>&1
line=$(strip <"$LOG/probe1.out" | grep -aE '^\s*Tests ' | tail -1 | xargs)
echo "$line" | grep -qE '1 failed \| 1 passed' && pass "one async failure stays one failure, real NgZone ($line)" || fail "cascade/zone probe: expected '1 failed | 1 passed', got '$line' (see $LOG/probe1.out)"
rm -f "$PROBE_DIR/cascade.spec.ts"
cat >"$PROBE_DIR/type-error.spec.ts" <<'PROBE'
import { describe, expect, it } from 'vitest';
describe('verify-probe', () => {
  it('must not compile', () => {
    const broken: number = 'not a number';
    expect(broken).toBeDefined();
  });
});
PROBE
if npm test -- --include="$PROBE_DIR/type-error.spec.ts" >"$LOG/probe2.out" 2>&1; then fail "a type error in a spec did not fail the test build"; else grep -q 'TS2322' "$LOG/probe2.out" && pass "type error in a spec fails the test build (TS2322)" || fail "type-error probe failed for another reason (see $LOG/probe2.out)"; fi
rm -rf "$PROBE_DIR"

# 7. build and coverage
npm run build >"$LOG/build.log" 2>&1 && pass "npm run build" || fail "npm run build (see $LOG/build.log)"
npm run test:coverage >"$LOG/cov.log" 2>&1 && pass "npm run test:coverage with thresholds" || { fail "npm run test:coverage ($(timeouts "$LOG/cov.log") timed out) (see $LOG/cov.log)"; strip <"$LOG/cov.log" | grep -a 'does not meet' | sed 's/^/      /'; }
# Measured-minus-one: each threshold is floor(measured) - 1 from this run, on the final tree.
read -r m_s m_b m_f m_l <<<"$(strip <"$LOG/cov.log" | awk -F'|' '/^ *All files *\|/{gsub(/ /,"");print $2,$3,$4,$5;exit}')"
if [ -n "${m_l:-}" ]; then
  # floor(measured) - 1, but never below the base's threshold (the ratchet wins).
  want=$(awk -v s="$m_s" -v b="$m_b" -v f="$m_f" -v l="$m_l" -v bs="${b_s:--}" -v bb="${b_b:--}" -v bf="${b_f:--}" -v bl="${b_l:--}" \
    'function m1(x,base){x=int(x)-1;if(x<0)x=0;if(base!="-"&&x<base+0)x=base+0;return x} BEGIN{print m1(s,bs),m1(b,bb),m1(f,bf),m1(l,bl)}')
  if [ "$want" = "$th_s $th_b $th_f $th_l" ]; then pass "thresholds are floor(measured) - 1 (measured $m_s $m_b $m_f $m_l)"
  else note "thresholds $th_s $th_b $th_f $th_l differ from floor(measured) - 1 = $want (measured $m_s $m_b $m_f $m_l; statements branches functions lines; never below $BASE's): set them from this run"; fi
else
  note "no 'All files' coverage line in $LOG/cov.log; thresholds not compared with the measured coverage"
fi

# The step logs are kept only when something failed, so /tmp does not fill up with passing runs.
if [ $fails -eq 0 ]; then
  rm -rf "$LOG"
  echo "== 0 check(s) failed, $warns warning(s), $notes note(s); step logs deleted (all checks passed)"
else
  echo "== $fails check(s) failed, $warns warning(s), $notes note(s); step logs kept in $LOG"
fi
[ $fails -eq 0 ]
