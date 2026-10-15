#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Installs the Crucible test workflow (test-workflow/README.md) into the workspace on the /mnt/data volume:
# links the method kept in this repo's test-workflow/ into /mnt/data/crucible/agent-docs, .claude/agents
# and .omp, and creates the empty state folders the workflow writes to. The state itself never comes
# from, or goes into, this repo.
#
#   scripts/setup-test-workflow.sh [--dry-run]
#
#   --dry-run   print what it would do and change nothing
#
# Safe to rerun: a link that already points at this checkout is left as it is. It never overwrites,
# moves or deletes anything: a real file or folder, or a link pointing elsewhere, that is in the way is
# reported with what the script would have done, and skipped. Move it aside and rerun to use the repo's
# copy instead.
#
# CRUCIBLE_ROOT overrides the workspace root, /mnt/data/crucible (for a scratch test). The workflow's
# scripts read the same variable.
set -euo pipefail

if [ -n "${CRUCIBLE_CI_SKIP_CLONE:-}" ]; then
  echo "CRUCIBLE_CI_SKIP_CLONE set; skipping test workflow setup."
  exit 0
fi

DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '5,20p' "$0"; exit 0 ;;
    *) echo "setup-test-workflow.sh: unknown argument $a (usage: setup-test-workflow.sh [--dry-run])" >&2; exit 2 ;;
  esac
done

METHOD="$(cd "$(dirname "${BASH_SOURCE[0]}")/../test-workflow" && pwd)"
ROOT="${CRUCIBLE_ROOT:-/mnt/data/crucible}"
DOCS="$ROOT/agent-docs"
linked=0; present=0; skipped=0; made=0
declare -A MADE=()

say() { printf '%-8s %s\n' "$1" "$2"; }
run() { if [ "$DRY" -eq 1 ]; then return 0; fi; "$@"; }

# dir <path>: create a folder if nothing is there. Fails (and reports) when something else is.
dir() {
  local d="$1"
  if [ -d "$d" ] || [ -n "${MADE[$d]:-}" ]; then return 0; fi
  if [ -e "$d" ] || [ -L "$d" ]; then
    say SKIP "$d is not a folder; would create the folder $d"; skipped=$((skipped + 1)); return 1
  fi
  dir "$(dirname "$d")" || return 1
  run mkdir "$d"; say mkdir "$d"; MADE[$d]=1; made=$((made + 1))
}

# resolved <target> <path>: where a link at <path> to <target> leads (a relative target is relative to
# the link's folder).
resolved() {
  case "$1" in /*) readlink -f "$1" ;; *) readlink -f "$(dirname "$2")/$1" ;; esac
}

# link <target> <path>: make <path> a symlink to <target>, unless something is already there.
link() {
  local target="$1" path="$2" what
  if [ -e "$path" ] && [ "$(readlink -f "$path")" = "$(resolved "$target" "$path")" ]; then
    present=$((present + 1)); return 0
  fi
  if [ -L "$path" ]; then
    say SKIP "$path is a link to $(readlink "$path"); would link it to $target"; skipped=$((skipped + 1)); return 0
  fi
  if [ -e "$path" ]; then
    if [ -d "$path" ]; then what="a real folder"; else what="a real file"; fi
    if diff -rq "$path" "$(resolved "$target" "$path")" >/dev/null 2>&1; then what="$what, the same as the repo's copy"; else what="$what that differs from the repo's copy"; fi
    say SKIP "$path is $what; would replace it with a link to $target"; skipped=$((skipped + 1)); return 0
  fi
  dir "$(dirname "$path")" || return 0
  run ln -s "$target" "$path"; say link "$path -> $target"; linked=$((linked + 1))
}

[ "$DRY" -eq 1 ] && echo "Dry run: nothing is changed."
echo "Method: $METHOD"
echo "Workspace: $ROOT"

# The method: standards, scripts, glossary, orchestration guides.
for d in testing api-testing ui-testing omp; do link "$METHOD/$d" "$DOCS/$d"; done
link "$METHOD/GLOSSARY.md" "$DOCS/GLOSSARY.md"
for f in RULES.md ORCHESTRATOR.md ci-check.sh; do
  link "$METHOD/orchestration/$f" "$DOCS/orchestration/$f"
done

# The agents, one link per file, so agents of your own in .claude/agents stay as they are.
for f in "$METHOD"/agents/*.md; do link "$f" "$ROOT/.claude/agents/$(basename "$f")"; done

# Oh My Pi: the project settings and model pins, and its agent folder, which is .claude/agents.
link "$METHOD/dot-omp/config.yml" "$ROOT/.omp/config.yml"
link "../.claude/agents" "$ROOT/.omp/agents"

# The state: empty folders on the volume, never in this repo.
for d in api-test-bugs ui-test-bugs api-test-gaps ui-test-gaps api-test-triage ui-test-triage test-work jira \
         orchestration/rounds orchestration/reviews orchestration/archive; do
  dir "$DOCS/$d" || true
done

echo
echo "linked $linked, already linked $present, folders created $made, skipped $skipped"
[ "$skipped" -eq 0 ] || echo "Each SKIP above left something of yours in place; move it aside and rerun to use the repo's copy."
[ "$DRY" -eq 1 ] && echo "Dry run: nothing was changed."
echo
echo "To set this up on every container create, add this line to .devcontainer/postcreate.sh, after scripts/clone-repos.sh:"
echo "  scripts/setup-test-workflow.sh"
