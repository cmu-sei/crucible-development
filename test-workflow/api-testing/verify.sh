#!/usr/bin/env bash
# Definition of done for a Crucible API test setup. Runs every deterministic check from the standard
# against one API repo (or worktree), and keeps its output as the verify log, stamped with the tree hash:
#
#   verify.sh [--clean] [--app <app>] [--base <ref>] [--log-dir <dir>] <repo-path>
#
#   --clean    delete the test project's bin/ and obj/ and restore first (the CI path)
#   --app      the app whose defect document and gaps list to check (agent-docs/api-test-bugs/<app>.md,
#              agent-docs/api-test-gaps/<app>.txt); defaults to the repo directory's name, which must then
#              be one of the eight Crucible APIs
#   --base     the ref whose merge base the removed-tests check compares with (origin/main)
#   --log-dir  where the log goes (default agent-docs/test-work/<app>/); the log is verify-<tree hash>.log,
#              and verify-latest.log points at the newest (testing/README.md, "The verify log")
#
# Checks: shared files match the standard, pinned packages, project settings and template-derived files
# (sync.sh --check); no defect note in a test comment, no skipped test, no EF InMemory or SQLite in a
# test, harness self-tests present (check-repo.js tests); a test the defect document names carries at most a
# one-line summary (check-repo.js defects); every authorization gate has an allowed case that is not Root
# and a near-miss denied case, or an allow-list reason (check-repo.js gates: missing gates fail, provisional
# ones are WARN lines); every test the merge base with origin/main had and the tree has not is accounted for
# (check-repo.js removed); TreatWarningsAsErrors in force for the test project; `dotnet build` with no
# warning from the test project beyond the NuGet restore codes (application projects' warnings are listed,
# not failed); `dotnet test` passes and prints the PostgreSQL provider banner; the harness self-tests ran
# and passed; coverage produces a cobertura file with the migrations excluded; the CI workflow is present;
# a deliberately failing test fails the run; a skipped test fails the build. NOTE lines (bookkeeping and
# reviewer input) never fail. Needs Docker. The broken-gate check is testing/break-gate.sh.
set -u
STANDARD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEAN=0; REPO=""; APP=""; BASE="origin/main"; LOG_DIR=""; ARGS=("$@"); ORIG_PWD="$PWD"
while [ $# -gt 0 ]; do
  case "$1" in
    --clean) CLEAN=1 ;;
    --app) APP="${2:-}"; shift ;;
    --app=*) APP="${1#--app=}" ;;
    --base) BASE="${2:-}"; shift ;;
    --base=*) BASE="${1#--base=}" ;;
    --log-dir) LOG_DIR="${2:-}"; shift ;;
    --log-dir=*) LOG_DIR="${1#--log-dir=}" ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) REPO="${1%/}" ;;
  esac
  shift
done
[ -n "$REPO" ] && [ -d "$REPO" ] || { echo "usage: verify.sh [--clean] [--app <app>] [--base <ref>] [--log-dir <dir>] <repo-path>" >&2; exit 2; }
case "$LOG_DIR" in ""|/*) ;; *) LOG_DIR="$ORIG_PWD/$LOG_DIR" ;; esac
cd "$REPO" || exit 2
# The verify log (testing/README.md): this run's output, stamped with the tree hash it ran on.
if [ -z "${VERIFY_LOG:-}" ]; then
  . "$STANDARD/../testing/verify-log.sh"
  verify_log_start api "${APP:-$(basename "$PWD")}" "$PWD" "$LOG_DIR"
  (cd "$ORIG_PWD" && VERIFY_LOG="$VERIFY_LOG" "$STANDARD/verify.sh" "${ARGS[@]}") 2>&1 | tee -a "$VERIFY_LOG"; rc=${PIPESTATUS[0]}
  verify_log_end "$PWD" "$rc"
  exit "$rc"
fi
LOG="$(mktemp -d -t api-verify.XXXXXX)"; fails=0; warns=0; notes=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails+1)); }
# WARN lines are provisional gates; NOTE lines are bookkeeping and reviewer input (testing/README.md, "Check
# output"). Both are counted; neither fails the run.
show() { # <log> <tag regex> <limit>: print a check's WARN or NOTE lines, indented, and count them
  local n; n=$(grep -cE "^  ($2)" "$1"); grep -E "^  ($2)" "$1" | sed 's/^/  /' | head -"$3"
  [ "$n" -gt "$3" ] && echo "    ... $n lines in all (see $1)"
  case "$2" in WARN*) warns=$((warns+n)) ;; *) notes=$((notes+n)) ;; esac; return 0
}
# NuGet restore codes that WarningsNotAsErrors keeps as warnings (Directory.Build.props).
ALLOWED_WARNINGS='NU1901|NU1902|NU1903|NU1904|NU1510|NU1701'

echo "== verify $PWD"
mapfile -t projects < <(find . -name '*.Tests.csproj' -not -path '*/bin/*' -not -path '*/obj/*' -not -path './.worktrees/*' | sed 's|^\./||' | sort)
if [ ${#projects[@]} -ne 1 ]; then
  fail "exactly one *.Tests.csproj (found ${#projects[@]})"; echo "== $fails check(s) failed; logs kept in $LOG"; exit 1
fi
PROJ="${projects[0]}"; TEST_DIR="$(dirname "$PROJ")"; TEST_ASM="$(basename "$PROJ" .csproj)"
PROBE_DIR="$TEST_DIR/VerifyProbe"
cleanup_probe() { rm -rf "$PROBE_DIR"; }
trap cleanup_probe EXIT

# 0. clean restore
if [ $CLEAN -eq 1 ]; then
  rm -rf "$TEST_DIR/bin" "$TEST_DIR/obj"
  dotnet restore >"$LOG/restore.log" 2>&1 && pass "dotnet restore (clean)" || fail "dotnet restore (see $LOG/restore.log)"
fi

# 1. shared files, pinned packages, settings, template-derived files
"$STANDARD/sync.sh" --check "$PWD" >"$LOG/sync.log" 2>&1 && pass "shared files and harness match the standard" || { fail "drift (sync.sh --check)"; sed 's/^/      /' "$LOG/sync.log"; }

# 1b. test sources; NOTE lines (an empty-grant denial, a dynamic skip, prose like a defect note) for the reviewer
node "$STANDARD/check-repo.js" tests "$PWD" "$PROJ" >"$LOG/tests.log" 2>&1 && pass "tests: no defect notes in comments, no skips, no EF InMemory or SQLite, self-tests present" || { fail "tests: check-repo.js tests"; grep -vE '^  NOTE' "$LOG/tests.log" | sed 's/^/    /' | head -40; }
show "$LOG/tests.log" NOTE 40

# 1c. the defect document: a test an entry names keeps a one-line summary (fails); every entry's test
# exists by file and name, and the document's format and counts (NOTE lines; testing/fix-docs.js fixes most)
dsum=$(node "$STANDARD/check-repo.js" defects "$PWD" ${APP:+"$APP"} "$PROJ" >"$LOG/defects.log" 2>&1; echo $?)
dline=$(sed -n 's/^  (\(.*\))$/(\1)/p' "$LOG/defects.log" | head -1)
[ "$dsum" = 0 ] && pass "defect document: tests it names carry at most a one-line summary $dline" || { fail "defect document: check-repo.js defects $dline"; grep -vE '^  NOTE' "$LOG/defects.log" | sed 's/^/    /' | head -40; }
show "$LOG/defects.log" NOTE 40

# 1d. every authorization gate against the tests (CONVENTIONS.md section 4, "The gates check"). Missing
# gates and refused allow-list lines fail; ALLOWED lines (allow-listed gates, which the PR body lists by
# name), WARN provisional lines and NOTE lines are printed either way.
node "$STANDARD/check-repo.js" gates "$PWD" ${APP:+"$APP"} "$PROJ" >"$LOG/gates.log" 2>&1; rc=$?
gsum=$(sed -n 's/^  (gates: \(.*\))$/\1/p' "$LOG/gates.log" | head -1)
if [ $rc -eq 0 ]; then
  pass "gates: every authorization gate has an allowed case without Root and a near-miss denied case ($gsum)"
else
  fail "gates: check-repo.js gates ($gsum)"
  grep -E '^  (GATE|ALLOW )' "$LOG/gates.log" | sed 's/^/    /' | head -200
  n=$(grep -cE '^  (GATE|ALLOW )' "$LOG/gates.log"); [ "$n" -gt 200 ] && echo "    ... $n lines in all (see $LOG/gates.log)"
fi
grep -E '^  ALLOWED' "$LOG/gates.log" | sed 's/^/    /' | head -100
show "$LOG/gates.log" 'WARN' 100
show "$LOG/gates.log" NOTE 60

# 1e. no test lost without an account (testing/README.md, "Removed-test accounting"): every [Fact]/[Theory]
# method and [InlineData] row the merge base had and the tree has not is matched by the script or has a
# valid line in agent-docs/api-test-bugs/<app>.removed-tests-<date>.md. verify.sh never writes the
# script's matched file (--no-write); the writer's own `check-repo.js removed` run does.
basearg=(); [ "$BASE" != "origin/main" ] && basearg=(--base "$BASE")
node "$STANDARD/check-repo.js" removed "$PWD" ${APP:+"$APP"} "$PROJ" "${basearg[@]}" --no-write >"$LOG/removed.log" 2>&1; rc=$?
rsum=$(sed -n 's/^  (removed: \(.*\))$/\1/p' "$LOG/removed.log" | head -1)
if [ $rc -eq 0 ]; then pass "removed tests accounted for (${rsum:-no summary; see $LOG/removed.log})"
else
  fail "removed tests not accounted for (${rsum:-see $LOG/removed.log})"
  grep -E '^  REMOVED' "$LOG/removed.log" | sed 's/^/    /' | head -60
  n=$(grep -cE '^  REMOVED' "$LOG/removed.log"); [ "$n" -gt 60 ] && echo "    ... $n REMOVED lines in all (check-repo.js removed $PWD ${APP:-})"
fi
show "$LOG/removed.log" NOTE 40

# 2. warnings are errors in the test project (what enforces xUnit1051's Ct rule and xUnit1004)
twae=$(dotnet msbuild "$PROJ" -nologo -getProperty:TreatWarningsAsErrors 2>/dev/null | tr -d '[:space:]')
[ "$twae" = "true" ] && pass "TreatWarningsAsErrors=true for $TEST_ASM" || fail "TreatWarningsAsErrors is '$twae' for $TEST_ASM"

# 3. build, the test project warning-free apart from the NuGet restore codes
# Building the test project builds the application projects it references, whose warnings are the
# application's business (the standard never changes application code or build files to silence them).
# A warning counts when its origin, the path before "(line,col): warning" or " : warning", lies under the
# test project's directory, the .csproj included. A warning with no path origin ("CSC : warning ...")
# counts when the project in brackets at the end of the line is the test project. The application's
# restore warnings are printed under the test project's brackets but originate at the application's
# .csproj, so the origin decides, not the brackets. Application warnings are listed, never failed.
dotnet build "$PROJ" --no-incremental >"$LOG/build.log" 2>&1; rc=$?
attributed=$(grep -aE 'warning [A-Z]+[0-9]+' "$LOG/build.log" | awk -v dir="$PWD/$TEST_DIR/" -v proj="$PWD/$PROJ" '
  {
    line = $0; sub(/^[ \t]+/, "", line)
    if (!match(line, /warning [A-Z]+[0-9]+/)) next
    code = substr(line, RSTART + 8, RLENGTH - 8)
    origin = line; sub(/(\([0-9,]+\))? *: warning .*/, "", origin)
    bracket = ""; if (match(line, /\[[^]]*\]$/)) bracket = substr(line, RSTART + 1, RLENGTH - 2)
    own = (substr(origin, 1, 1) == "/") ? (index(origin, dir) == 1) : (bracket == proj)
    print (own ? "test" : "app"), code
  }' | sort -u)
others=$(awk '$1 == "test" { print $2 }' <<<"$attributed" | grep -vE "^($ALLOWED_WARNINGS)$" | tr '\n' ' ')
app_codes=$(awk '$1 == "app" { print $2 }' <<<"$attributed" | grep -vE "^($ALLOWED_WARNINGS)$" | tr '\n' ' ')
[ $rc -eq 0 ] && pass "dotnet build" || fail "dotnet build exit $rc (see $LOG/build.log)"
if [ -z "$others" ]; then
  pass "no build warnings from $TEST_ASM beyond NuGet restore codes"
  [ -n "$app_codes" ] && echo "    note: application projects warn (not counted): $app_codes"
else
  fail "build warnings from $TEST_ASM: $others(see $LOG/build.log)"
fi

# 4. the suite, against PostgreSQL
dotnet test "$PROJ" --no-build -- xUnit.DiagnosticMessages=true >"$LOG/test.log" 2>&1; rc=$?
summary=$(grep -aE '^(Passed|Failed)!' "$LOG/test.log" | tail -1 | sed -E 's/^(Passed|Failed)! +- +//; s/, Duration.*//' | xargs)
[ $rc -eq 0 ] && pass "dotnet test ($summary)" || fail "dotnet test exit $rc ($summary) (see $LOG/test.log)"
grep -aqF "[$TEST_ASM] database provider: PostgreSQL" "$LOG/test.log" && pass "PostgreSQL provider banner in the test output" || fail "no '[$TEST_ASM] database provider: PostgreSQL' banner (see $LOG/test.log)"

# 5. the harness self-tests ran and passed
dotnet test "$PROJ" --no-build --logger "console;verbosity=normal" \
  --filter "FullyQualifiedName~.DatabaseHarnessTests|FullyQualifiedName~.HttpHarnessTests|FullyQualifiedName~.TestActorTests" >"$LOG/self.log" 2>&1; rc=$?
missing=""
for cls in DatabaseHarnessTests HttpHarnessTests TestActorTests; do
  grep -aqE "^\s*Passed .*\.$cls\." "$LOG/self.log" || missing="$missing $cls"
done
self="$(grep -acE '^\s*Passed ' "$LOG/self.log") passed, $(grep -acE '^\s*Failed ' "$LOG/self.log") failed"
[ $rc -eq 0 ] && [ -z "$missing" ] && pass "harness self-tests pass ($self)" || fail "harness self-tests: exit $rc, none passed in:${missing:- (none)} (see $LOG/self.log)"

# 6. coverage: a cobertura file, migrations excluded
dotnet test "$PROJ" --no-build --collect:"XPlat Code Coverage" --results-directory "$LOG/coverage" >"$LOG/coverage.log" 2>&1; rc=$?
cobertura=$(find "$LOG/coverage" -name coverage.cobertura.xml 2>/dev/null | head -1)
if [ $rc -eq 0 ] && [ -n "$cobertura" ]; then
  if grep -qE '<package name="[^"]*Migrations|filename="[^"]*/Migrations/' "$cobertura"; then
    fail "coverage includes migrations (see $cobertura)"
  else
    rate=$(grep -m1 -oE '<coverage line-rate="[0-9.]+"' "$cobertura" | sed -E 's/.*="([0-9.]+)"/\1/')
    pass "coverage: cobertura written, migrations excluded (line-rate $rate)"
  fi
else
  fail "coverage run exit $rc, cobertura: ${cobertura:-none} (see $LOG/coverage.log)"
fi

# 7. CI
[ -f .github/workflows/build-and-test.yml ] && pass "CI workflow .github/workflows/build-and-test.yml" || fail "no .github/workflows/build-and-test.yml"

# 8. probes: a failing test fails the run; a skipped test fails the build
mkdir -p "$PROBE_DIR"
cat >"$PROBE_DIR/FailingProbeTests.cs" <<'PROBE'
using Xunit;

namespace VerifyProbe;

public class FailingProbeTests
{
    [Fact]
    public void Fails_on_purpose() => Assert.Fail("intentional");
}
PROBE
if dotnet build "$PROJ" >"$LOG/probe-build.log" 2>&1; then
  dotnet test "$PROJ" --no-build --filter "FullyQualifiedName~VerifyProbe" >"$LOG/probe1.log" 2>&1; rc=$?
  line=$(grep -aE '^(Passed|Failed)!' "$LOG/probe1.log" | tail -1 | sed -E 's/^(Passed|Failed)! +- +//; s/, Duration.*//' | xargs)
  [ $rc -ne 0 ] && echo "$line" | grep -qE 'Failed: +1,' && pass "a failing test fails the run ($line)" || fail "failing-test probe: exit $rc, '$line' (see $LOG/probe1.log)"
else
  fail "failing-test probe did not build (see $LOG/probe-build.log)"
fi
cat >"$PROBE_DIR/FailingProbeTests.cs" <<'PROBE'
using Xunit;

namespace VerifyProbe;

public class SkippedProbeTests
{
    [Fact(Skip = "probe")]
    public void Is_skipped() => Assert.True(true);
}
PROBE
if dotnet build "$PROJ" >"$LOG/probe2.log" 2>&1; then
  fail "a [Fact(Skip = ...)] built (xUnit1004 is not an error)"
else
  grep -q 'xUnit1004' "$LOG/probe2.log" && pass "a skipped test fails the build (xUnit1004)" || fail "skip probe failed for another reason (see $LOG/probe2.log)"
fi
cleanup_probe
dotnet build "$PROJ" >"$LOG/rebuild.log" 2>&1 || fail "rebuild after the probes (see $LOG/rebuild.log)"

# The step logs are kept only when something failed, so /tmp does not fill up with passing runs.
if [ $fails -eq 0 ]; then
  rm -rf "$LOG"
  echo "== 0 check(s) failed, $warns warning(s), $notes note(s); step logs deleted (all checks passed)"
else
  echo "== $fails check(s) failed, $warns warning(s), $notes note(s); step logs kept in $LOG"
fi
[ $fails -eq 0 ]
