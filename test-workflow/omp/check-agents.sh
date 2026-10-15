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
#   - an agent's `model` carries a provider prefix (Claude Code would not
#     resolve it)
#   - .omp/config.yml has no task.agentModelOverrides entry for an agent, or
#     a pin is not provider/model qualified or names an unknown agent
# Claude Code frontmatter and omp pins deliberately may select different models.
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
  if [[ "$model" == */* ]]; then
    echo "MODEL    $name: model '$model' has a provider prefix"; status=1
  fi
  agent="${name%.md}"
  override="$(sed -n "s/^    ${agent}: *//p" "$cfg" | head -1)"
  if [[ -z "$override" ]]; then
    echo "PIN      $agent: no task.agentModelOverrides entry in .omp/config.yml"; status=1
  elif [[ ! "$override" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._:/-]+$ ]]; then
    echo "PIN      $agent: override '$override' must be provider/model qualified"; status=1
  fi
done
for agent in $(sed -n '/^  agentModelOverrides:$/,/^  [^ ]/p' "$cfg" | sed -n 's/^    \([a-z-]*\):.*/\1/p'); do
  [[ -f "$src/$agent.md" ]] || { echo "ORPHAN   $agent pinned in .omp/config.yml but no .claude/agents/$agent.md"; status=1; }
done

(( status == 0 )) && echo "OK one agent set, readable by Claude Code and omp"
exit $status
