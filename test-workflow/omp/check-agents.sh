#!/usr/bin/env bash
# Check that the Crucible test-workflow agents are readable by both harnesses.
#
# There is ONE set of agent files, /mnt/data/crucible/.claude/agents/*.md, in
# Claude Code dialect. Oh My Pi reads the same files through the symlink
# /mnt/data/crucible/.omp/agents -> ../.claude/agents (verified 2026-10-08:
# omp lower-cases the tool names, drops `WebFetch` silently because `read`
# fetches URLs, resolves a bare `claude-*` model id against the active
# provider, ignores `effort`, and honours `thinkingLevel`; Claude Code ignores
# `thinkingLevel`). This script fails when that arrangement is broken:
#   - the symlink is missing or points elsewhere
#   - an agent has `effort` without a matching `thinkingLevel` (omp would run
#     it at its default level, high)
#   - an agent file names a `model` (agents inherit the session's model in both
#     harnesses; omp fails on `model: inherit`, so the line is left out)
#   - .omp/config.yml pins a model with task.agentModelOverrides
#
# Usage: check-agents.sh        exit 1 on any finding

set -euo pipefail
# The workspace the agents are installed in (CRUCIBLE_ROOT overrides /mnt/data/crucible).
root="${CRUCIBLE_ROOT:-/mnt/data/crucible}"
src="$root/.claude/agents"
link="$root/.omp/agents"
cfg="$root/.omp/config.yml"
status=0

if [[ ! -L "$link" ]]; then
  echo "MISSING  $link is not a symlink (expected -> ../.claude/agents)"; status=1
elif [[ "$(readlink -f "$link")" != "$(readlink -f "$src")" ]]; then
  echo "WRONG    $link -> $(readlink "$link") (expected ../.claude/agents)"; status=1
fi

for f in "$src"/*.md; do
  name="$(basename "$f")"
  fm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$f")"
  effort="$(sed -n 's/^effort: *//p' <<<"$fm" | head -1)"
  level="$(sed -n 's/^thinkingLevel: *//p' <<<"$fm" | head -1)"
  model="$(sed -n 's/^model: *//p' <<<"$fm" | head -1)"
  if [[ -n "$effort" && "$level" != "$effort" ]]; then
    echo "LEVEL    $name: effort=$effort thinkingLevel=${level:-<none>}"; status=1
  fi
  if [[ -n "$model" ]]; then
    echo "MODEL    $name: names model '$model'; leave the line out so the agent inherits the session's model"; status=1
  fi
done
if grep -q '^  agentModelOverrides:' "$cfg" 2>/dev/null; then
  echo "PIN      .omp/config.yml pins models (task.agentModelOverrides); agents inherit the session's model"; status=1
fi

(( status == 0 )) && echo "OK one agent set, readable by Claude Code and omp"
exit $status
