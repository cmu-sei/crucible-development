#!/usr/bin/env bash
# The broken-gate check (GLOSSARY.md), for both stacks: break one gate at its call site so it always
# allows, run the gate's near misses (they must fail) and optionally its allowed cases (they must still
# pass), restore the production file byte for byte, and append the result to the break-gate log. The gate
# shapes and the edit that breaks each are in section 5 of the stack's CONVENTIONS.md.
#
#   break-gate.sh [--app <app>] [--gate <id>] <worktree>
#                 --site <file>:<line> --replace <old> <new> [--replace <old> <new>]...
#                 [--site <file>:<line> --replace <old> <new> ...]...
#                 --near-miss <test> [--near-miss <test>]... [--allowed <test>]...
#                 [--spec <spec file>]... [--log <file>]
#
#   --site       a production line to edit (path from the worktree root, 1-based line); give every copy of a
#                repeated check, and each site of a gate computed twice, in one run
#   --replace    replaces the one occurrence of <old> on the last --site's line with <new> (for example
#                `await authorizationService.Authorize(` -> `true || await authorizationService.Authorize(`,
#                or `canEdit = this.can(` -> `canEdit = true || this.can(`)
#   --near-miss  a test expected to fail with the gate broken: API `Class.Method`, UI the test title
#   --allowed    a test expected to pass with the gate broken (a sanity check of the edit)
#   --spec       UI: a spec file to run (default: the spec beside each site file)
#   --gate       the gate id, for the log (default: the first site)
#   --app        default: the worktree folder's name
#   --log        default: agent-docs/test-work/<app>/break-gate.log
#
# Exit 0 when every near miss failed, every allowed case passed, and every file was restored with
# `git status` as before; 1 otherwise; 2 on a usage error or an edit that could not be made. Needs Docker
# for an API (the test database). Never run it in a worktree another agent is using.
set -u
TESTING="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The workspace docs (test-work/): on the /mnt/data volume, never in the checkout this script runs from.
DOCS="${CRUCIBLE_ROOT:-/mnt/data/crucible}/agent-docs"
usage() { echo "usage: break-gate.sh [--app <app>] [--gate <id>] <worktree> --site <file>:<line> --replace <old> <new> ... --near-miss <test> ... [--allowed <test>] ... [--spec <file>] ... [--log <file>]" >&2; exit 2; }
WT=""; APP=""; GATE=""; LOG=""
SITES=(); EDITS=(); NEAR=(); ALLOWED=(); SPECS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="${2:-}"; shift ;;
    --gate) GATE="${2:-}"; shift ;;
    --log) LOG="${2:-}"; shift ;;
    --site) [ $# -ge 2 ] || usage; SITES+=("$2"); shift ;;
    --replace) [ $# -ge 3 ] && [ ${#SITES[@]} -gt 0 ] || usage; EDITS+=("$((${#SITES[@]} - 1))"$'\x1f'"$2"$'\x1f'"$3"); shift 2 ;;
    --near-miss) [ $# -ge 2 ] || usage; NEAR+=("$2"); shift ;;
    --allowed) [ $# -ge 2 ] || usage; ALLOWED+=("$2"); shift ;;
    --spec) [ $# -ge 2 ] || usage; SPECS+=("$2"); shift ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    -*) echo "break-gate.sh: unknown option $1" >&2; usage ;;
    *) WT="${1%/}" ;;
  esac
  shift
done
[ -n "$WT" ] && [ -d "$WT" ] && [ ${#SITES[@]} -gt 0 ] && [ ${#EDITS[@]} -gt 0 ] && [ ${#NEAR[@]} -gt 0 ] || usage
WT="$(cd "$WT" && pwd)"
[ -n "$APP" ] || APP="$(basename "$WT")"
[ -n "$LOG" ] || { mkdir -p "$DOCS/test-work/$APP"; LOG="$(cd "$DOCS/test-work/$APP" && pwd)/break-gate.log"; }
if [ -f "$WT/angular.json" ]; then STACK=ui; else STACK=api; fi
[ -n "$GATE" ] || GATE="${SITES[0]}"

SCRATCH="$(mktemp -d -t break-gate.XXXXXX)"
STATUS_BEFORE="$(git -C "$WT" status --porcelain=v1 -uall)"
TREE_BEFORE="$("$TESTING/tree-hash.sh" "$WT")"
FILES=()
for s in "${SITES[@]}"; do
  f="${s%:*}"; [[ " ${FILES[*]} " == *" $f "* ]] || FILES+=("$f")
done

restored=no
restore() {
  local ok=yes f
  for k in "${!FILES[@]}"; do
    f="${FILES[$k]}"
    [ -f "$SCRATCH/orig.$k" ] || continue
    cp -p "$SCRATCH/orig.$k" "$WT/$f" && cmp -s "$SCRATCH/orig.$k" "$WT/$f" || ok=no
  done
  [ "$(git -C "$WT" status --porcelain=v1 -uall)" = "$STATUS_BEFORE" ] || ok=no
  restored=$ok
}
cleanup() { [ "$restored" = yes ] || restore; rm -rf "$SCRATCH"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

# 1. Copy each file aside, then make the edits. A site in a test file is refused: the gate is broken in
# production code, at its call site.
for k in "${!FILES[@]}"; do
  f="${FILES[$k]}"
  case "$f" in *.spec.ts|*Tests/*|*Tests.cs|*.Tests/*) echo "break-gate.sh: $f is a test file; break the gate at its production call site" >&2; exit 2 ;; esac
  [ -f "$WT/$f" ] || { echo "break-gate.sh: no file $f in $WT" >&2; exit 2; }
  git -C "$WT" diff --quiet -- "$f" || { echo "break-gate.sh: $f has uncommitted changes; it must be as committed" >&2; exit 2; }
  cp -p "$WT/$f" "$SCRATCH/orig.$k"
done
for e in "${EDITS[@]}"; do
  IFS=$'\x1f' read -r idx old new <<<"$e"
  site="${SITES[$idx]}"; f="${site%:*}"; line="${site##*:}"
  node -e '
    const fs = require("fs");
    const [file, line, from, to] = process.argv.slice(1);
    const lines = fs.readFileSync(file, "utf8").split("\n");
    const i = Number(line) - 1;
    if (!(i >= 0 && i < lines.length)) { console.error(`break-gate.sh: ${file} has no line ${line}`); process.exit(2); }
    const n = lines[i].split(from).length - 1;
    if (n !== 1) { console.error(`break-gate.sh: line ${line} of ${file} holds ${JSON.stringify(from)} ${n} times (exactly once expected): ${lines[i].trim()}`); process.exit(2); }
    lines[i] = lines[i].replace(from, () => to);
    fs.writeFileSync(file, lines.join("\n"));' "$WT/$f" "$line" "$old" "$new" || exit 2
done
DIFF="$(git -C "$WT" diff -U0 -- "${FILES[@]}" | grep -E '^[-+][^-+]')"

# 2. Run the tests.
names=("${NEAR[@]}" "${ALLOWED[@]}")
run_api() {
  local proj filter=""
  proj="$(cd "$WT" && find . -name '*.Tests.csproj' -not -path '*/bin/*' -not -path '*/obj/*' | head -1)"
  for n in "${names[@]}"; do filter="${filter:+$filter|}FullyQualifiedName~.${n}"; done
  if ! (cd "$WT" && dotnet build "$proj" -nologo >"$SCRATCH/build.log" 2>&1); then
    echo "build failed with the gate broken (see the edit; CONVENTIONS.md section 5 gives forms that build):"
    grep -E 'error [A-Z]+[0-9]+' "$SCRATCH/build.log" | sort -u | head -5 | sed 's/^/  /'
    return 1
  fi
  (cd "$WT" && dotnet test "$proj" --no-build --filter "$filter" --results-directory "$SCRATCH/trx" --logger "trx;LogFileName=r.trx" >"$SCRATCH/test.log" 2>&1)
  node -e '
    const fs = require("fs");
    const xml = fs.existsSync(process.argv[1]) ? fs.readFileSync(process.argv[1], "utf8") : "";
    for (const m of xml.matchAll(/<UnitTestResult\b[^>]*?testName="([^"]+)"[^>]*?outcome="(\w+)"[^>]*?(?:\/>|>([\s\S]*?)<\/UnitTestResult>)/g)) {
      const msg = (/<Message>([\s\S]*?)<\/Message>/.exec(m[3] || "") || [])[1] || "";
      console.log([m[1], m[2], msg.replace(/&quot;/g, "\"").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").split("\n")[0].slice(0, 200)].join("\t"));
    }' "$SCRATCH/trx/r.trx" >"$SCRATCH/results.tsv"
}
run_ui() {
  local specs=("${SPECS[@]}") f
  if [ ${#specs[@]} -eq 0 ]; then
    for f in "${FILES[@]}"; do
      f="${f%.html}"; f="${f%.ts}"; [ -f "$WT/$f.spec.ts" ] && specs+=("$f.spec.ts")
    done
  fi
  [ ${#specs[@]} -gt 0 ] || { echo "no spec beside the site files; pass --spec"; return 1; }
  local inc=(); for f in "${specs[@]}"; do inc+=(--include "$f"); done
  (cd "$WT" && npx ng test --watch=false "${inc[@]}" --reporters=json --output-file="$SCRATCH/r.json" >"$SCRATCH/test.log" 2>&1)
  node -e '
    const fs = require("fs");
    if (!fs.existsSync(process.argv[1])) process.exit(0);
    const r = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    for (const file of r.testResults || []) for (const a of file.assertionResults || []) {
      const msg = (a.failureMessages || [])[0] || "";
      console.log([a.fullName || a.title, a.title, a.status, msg.split("\n")[0].slice(0, 200)].join("\t"));
    }' "$SCRATCH/r.json" >"$SCRATCH/results.tsv"
}
ran=yes
if [ "$STACK" = api ]; then run_api >"$SCRATCH/run.txt" 2>&1 || ran=no; else run_ui >"$SCRATCH/run.txt" 2>&1 || ran=no; fi

# 3. Restore, before anything else can go wrong; rebuild an API so no binary keeps the broken gate.
restore
if [ "$STACK" = api ] && [ "$ran" = yes ]; then
  proj="$(cd "$WT" && find . -name '*.Tests.csproj' -not -path '*/bin/*' -not -path '*/obj/*' | head -1)"
  (cd "$WT" && dotnet build "$proj" -nologo >"$SCRATCH/rebuild.log" 2>&1) || echo "rebuild after the restore failed (see a fresh dotnet build)" >>"$SCRATCH/run.txt"
fi

# 4. Judge each named test.
verdict=PASS
report="$SCRATCH/report.txt"; : >"$report"
judge() { # <name> <expected: failed|passed>
  local n="$1" want="$2" got="" msg=""
  if [ "$STACK" = api ]; then
    while IFS=$'\t' read -r full outcome m; do
      local bare="${full%%(*}"
      [[ "$bare" == *".$n" || "$bare" == "$n" ]] || continue
      case "$outcome" in Failed) got=failed ;; Passed) [ "$got" = failed ] || got=passed ;; *) [ -n "$got" ] || got="$outcome" ;; esac
      [ -n "$m" ] && msg="$m"
    done <"$SCRATCH/results.tsv"
  else
    while IFS=$'\t' read -r full title status m; do
      [ "$title" = "$n" ] || [ "$full" = "$n" ] || [[ "$full" == *" $n" ]] || continue
      case "$status" in failed) got=failed ;; passed) [ "$got" = failed ] || got=passed ;; *) [ -n "$got" ] || got="$status" ;; esac
      [ -n "$m" ] && msg="$m"
    done <"$SCRATCH/results.tsv"
  fi
  [ -n "$got" ] || got="not run"
  local mark="ok"; [ "$got" = "$want" ] || { mark="WRONG"; verdict=FAIL; }
  printf '  %-6s %-8s %s%s\n' "$mark" "$got" "$n" "${msg:+  ($msg)}" >>"$report"
}
for n in "${NEAR[@]}"; do judge "$n" failed; done
nearReport="$(cat "$report")"; : >"$report"
for n in "${ALLOWED[@]}"; do judge "$n" passed; done
allowedReport="$(cat "$report")"
[ "$ran" = yes ] || verdict=FAIL
[ "$restored" = yes ] || verdict=FAIL
nfailed=$(grep -c '^  ok     failed' <<<"$nearReport")

{
  echo "== break-gate $(date -u +%Y-%m-%dT%H:%M:%SZ) $STACK $APP"
  echo "tree $TREE_BEFORE"
  echo "gate $GATE"
  for s in "${SITES[@]}"; do echo "site $s"; done
  echo "edit:"; sed 's/^/  /' <<<"$DIFF"
  [ -s "$SCRATCH/run.txt" ] && { echo "run:"; sed 's/^/  /' "$SCRATCH/run.txt"; }
  echo "near misses (expected to fail with the gate broken):"; echo "$nearReport"
  [ ${#ALLOWED[@]} -gt 0 ] && { echo "allowed cases (expected to pass):"; echo "$allowedReport"; }
  echo "restored: $restored (each file byte-identical to its copy; git status as before)"
  echo "result: $verdict ($nfailed of ${#NEAR[@]} near misses failed)"
  echo
} | tee -a "$LOG"
echo "log: $LOG"
[ "$verdict" = PASS ]
