#!/usr/bin/env bash
# Copy the shared Crucible API test files into one or more API repos (or worktrees) and verify they are
# byte-identical to the standard.
#
#   sync.sh [--check] [--test] <repo-path> [<repo-path> ...]
#
#   --check   report drift only; copy nothing
#   --test    run `dotnet test` on each repo's test project after copying (needs Docker)
#
# The test project is the repo's one *.Tests.csproj. Shared files: Support/Shared/*.cs,
# Directory.Build.props, xunit.runner.json and coverlet.runsettings (next to the .csproj), and
# .github/workflows/build-and-test.yml (filled in with the test project's directory and assembly name).
# Checked but never copied: the pinned test packages (test-packages.props) in Directory.Packages.props or
# the test .csproj, the xUnit1004 line in .editorconfig, every template-derived file, and the harness
# shape (check-repo.js harness). App-specific files are never copied; build them from templates/.
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

[ $RUN_TESTS -eq 1 ] && LOG_DIR="$(mktemp -d -t api-sync-test.XXXXXX)" && echo "test logs: $LOG_DIR"
status=0

# Template-derived files every repo must have, relative to the test project directory. <App> files are
# matched by suffix.
REQUIRED=(AssemblyFixtures.cs Support/DatabaseFixture.cs Support/DatabaseTestBase.cs Support/ApiTestBase.cs
  Support/TestConfiguration.cs Support/TestActor.cs Support/TestData.cs Support/ClaimsPrincipalBuilder.cs
  Support/AuthorizationHarness.cs Support/TestMapper.cs Support/DatabaseHarnessTests.cs
  Support/HttpHarnessTests.cs Support/TestActorTests.cs)
REQUIRED_SUFFIX=(Support/*ContextFactory.cs Support/*AppFactory.cs)

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
  [ -d "$REPO" ] || { echo "$REPO: not a directory" >&2; status=1; continue; }
  REPO="$(cd "$REPO" && pwd)"   # absolute, so --test can cd and still write its log
  echo "== $REPO"
  mapfile -t projects < <(cd "$REPO" && find . -name '*.Tests.csproj' -not -path '*/bin/*' -not -path '*/obj/*' -not -path './.worktrees/*' | sed 's|^\./||' | sort)
  if [ ${#projects[@]} -ne 1 ]; then
    echo "  MISSING  exactly one *.Tests.csproj (found ${#projects[@]}: ${projects[*]:-none}); build it from templates/Tests.template.csproj"
    status=1; continue
  fi
  PROJ="${projects[0]}"; TEST_DIR="$(dirname "$PROJ")"; TEST_ASM="$(basename "$PROJ" .csproj)"
  T="$REPO/$TEST_DIR"

  # 1. Shared files, byte for byte.
  for f in "$STANDARD"/Support/Shared/*.cs; do sync_file "$f" "$T/Support/Shared/$(basename "$f")"; done
  for f in "$T"/Support/Shared/*.cs; do
    [ -f "$f" ] && [ ! -f "$STANDARD/Support/Shared/$(basename "$f")" ] && { echo "  UNKNOWN  ${f#$REPO/} (not in the standard; Support/Shared holds shared files only)"; status=1; }
  done
  for f in Directory.Build.props xunit.runner.json coverlet.runsettings; do sync_file "$STANDARD/$f" "$T/$f"; done

  # 2. CI workflow, with the two placeholders filled in.
  expected="$(mktemp)"
  sed -e "s|{{TEST_PROJECT_DIR}}|$TEST_DIR|g" -e "s|{{TEST_ASSEMBLY}}|$TEST_ASM|g" "$STANDARD/build-and-test.yml" >"$expected"
  sync_file "$expected" "$REPO/.github/workflows/build-and-test.yml"
  rm -f "$expected"

  # 3. The xUnit1004 line (a skipped test fails the build).
  if ! grep -qsE '^\s*dotnet_diagnostic\.xUnit1004\.severity\s*=\s*(warning|error)' "$REPO/.editorconfig" "$T/.editorconfig"; then
    echo "  MISSING  .editorconfig line 'dotnet_diagnostic.xUnit1004.severity = warning' (see editorconfig)"; status=1
  fi

  # 4. Template-derived files exist.
  for f in "${REQUIRED[@]}"; do
    [ -f "$T/$f" ] || { echo "  MISSING  $TEST_DIR/$f (app-specific; build it from templates/)"; status=1; }
  done
  for pattern in "${REQUIRED_SUFFIX[@]}"; do
    compgen -G "$T/$pattern" >/dev/null || { echo "  MISSING  $TEST_DIR/$pattern (app-specific; build it from templates/)"; status=1; }
  done

  # 5. Pinned packages, project settings, harness shape.
  node "$STANDARD/check-repo.js" harness "$REPO" "$PROJ" || status=1

  if [ $RUN_TESTS -eq 1 ]; then
    echo "  running dotnet test ..."
    # The log goes outside the repo, so it never shows up as an untracked file.
    TEST_LOG="$LOG_DIR/$(basename "$REPO").log"
    if (cd "$REPO" && dotnet test "$TEST_DIR" -- xUnit.DiagnosticMessages=true >"$TEST_LOG" 2>&1); then
      grep -aE '^(Passed|Failed)!' "$TEST_LOG" | sed 's/^/  /'
    else
      echo "  FAILED   dotnet test (see $TEST_LOG)"; status=1
    fi
  fi
done
[ $status -eq 0 ] && echo "ok: all repos match the standard" || echo "problems found (exit 1)"
exit $status
