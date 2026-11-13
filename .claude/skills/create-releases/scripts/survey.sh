#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Resolve /create-releases targets to cmu-sei repositories and report, for each one, its
# latest application release and what main has gained since. Read-only: it never creates
# anything.
#
# Usage:
#   survey.sh [--resolve-only] <target> [<target>...]
#
# Targets (case-insensitive):
#   all                      every API and UI below
#   <project>                the project's API and UI (console and topomojo-ui have no pair)
#   <project>.api|<project>.ui   one repository
# Projects: alloy blueprint caster cite gallery player vm console steamfitter topomojo
#
# Output: APIs first, then UIs, each in project order, so releasing in output order puts an
# API before the UI that needs it.

set -uo pipefail

ORG=cmu-sei
CRUCIBLE_ROOT=${CRUCIBLE_ROOT:-/mnt/data/crucible}
PROJECTS=(alloy blueprint caster cite gallery player vm console steamfitter topomojo)

declare -A API=(
  [alloy]=Alloy.Api [blueprint]=Blueprint.Api [caster]=Caster.Api [cite]=CITE.Api
  [gallery]=Gallery.Api [player]=Player.Api [vm]=Vm.Api [steamfitter]=Steamfitter.Api
  [topomojo]=TopoMojo
)
declare -A UI=(
  [alloy]=Alloy.Ui [blueprint]=Blueprint.Ui [caster]=Caster.Ui [cite]=CITE.Ui
  [gallery]=Gallery.Ui [player]=Player.Ui [vm]=Vm.Ui [console]=Console.Ui
  [steamfitter]=Steamfitter.Ui [topomojo]=topomojo-ui
)
# Local clones under $CRUCIBLE_ROOT, keyed by repository name.
declare -A CLONE=(
  [Alloy.Api]=alloy/alloy.api [Alloy.Ui]=alloy/alloy.ui
  [Blueprint.Api]=blueprint/blueprint.api [Blueprint.Ui]=blueprint/blueprint.ui
  [Caster.Api]=caster/caster.api [Caster.Ui]=caster/caster.ui
  [CITE.Api]=cite/cite.api [CITE.Ui]=cite/cite.ui
  [Gallery.Api]=gallery/gallery.api [Gallery.Ui]=gallery/gallery.ui
  [Player.Api]=player/player.api [Player.Ui]=player/player.ui
  [Vm.Api]=player/vm.api [Vm.Ui]=player/vm.ui [Console.Ui]=player/console.ui
  [Steamfitter.Api]=steamfitter/steamfitter.api [Steamfitter.Ui]=steamfitter/steamfitter.ui
  [TopoMojo]=topomojo/topomojo [topomojo-ui]=topomojo/topomojo-ui
)

resolve_only=false
if [[ ${1:-} == --resolve-only ]]; then resolve_only=true; shift; fi
if [[ $# -eq 0 ]]; then
  echo "usage: survey.sh [--resolve-only] <all|project|project.api|project.ui>..." >&2
  exit 2
fi

declare -A want=()
for raw in "$@"; do
  t=${raw,,}
  case $t in
    all)
      for p in "${PROJECTS[@]}"; do
        [[ -n ${API[$p]:-} ]] && want[${API[$p]}]=1
        [[ -n ${UI[$p]:-} ]] && want[${UI[$p]}]=1
      done ;;
    *.api)
      p=${t%.api}
      [[ -n ${API[$p]:-} ]] || { echo "error: '$raw' has no API repository" >&2; exit 2; }
      want[${API[$p]}]=1 ;;
    *.ui)
      p=${t%.ui}
      [[ -n ${UI[$p]:-} ]] || { echo "error: '$raw' has no UI repository" >&2; exit 2; }
      want[${UI[$p]}]=1 ;;
    *)
      if [[ -z ${API[$t]:-} && -z ${UI[$t]:-} ]]; then
        echo "error: unknown target '$raw' (projects: ${PROJECTS[*]})" >&2; exit 2
      fi
      [[ -n ${API[$t]:-} ]] && want[${API[$t]}]=1
      [[ -n ${UI[$t]:-} ]] && want[${UI[$t]}]=1 ;;
  esac
done

repos=()
for p in "${PROJECTS[@]}"; do [[ -n ${API[$p]:-} && -n ${want[${API[$p]}]:-} ]] && repos+=("${API[$p]}"); done
for p in "${PROJECTS[@]}"; do [[ -n ${UI[$p]:-} && -n ${want[${UI[$p]}]:-} ]] && repos+=("${UI[$p]}"); done

if $resolve_only; then printf '%s\n' "${repos[@]}"; exit 0; fi

for r in "${repos[@]}"; do
  echo "=== $ORG/$r"
  clone="$CRUCIBLE_ROOT/${CLONE[$r]}"
  [[ -d $clone/.git ]] && echo "clone: $clone" || echo "clone: (none at $clone)"

  # Latest application release: skip drafts, prereleases and client-package tags
  # (e.g. Steamfitter.Api.Client.3.11.0), which GitHub may mark as "latest".
  rel=$(gh api "repos/$ORG/$r/releases?per_page=40" --jq \
    '[.[] | select(.draft|not) | select(.prerelease|not) | select(.tag_name|test("Client")|not)][0]
     | select(. != null) | "\(.tag_name) \(.published_at[0:10])"')
  if [[ -z $rel ]]; then echo "last release: NONE"; echo; continue; fi
  tag=${rel%% *}
  echo "last release: $rel"

  head=$(gh api "repos/$ORG/$r/commits/main" --jq .sha)
  echo "main: $head"

  gh api "repos/$ORG/$r/compare/$tag...main" --jq '
    "ahead: \(.ahead_by)  behind: \(.behind_by)  files: \(.files|length)\(if (.files|length) >= 300 then " (TRUNCATED at 300: use the local clone for the file list)" else "" end)",
    (.commits[] | "  \(.sha[0:7]) \(.commit.author.date[0:10]) \(.commit.message|split("\n")[0])")'

  # CI on main HEAD. "Dependabot" runs are Dependabot's own update jobs, not CI; a failure
  # there doesn't block a release. A HEAD made by a Dependabot merge often has no CI runs
  # of its own, so the merged PR's checks are the ones to read.
  ci=$(gh api "repos/$ORG/$r/commits/$head/check-runs?per_page=100" --jq \
    '[.check_runs[] | select(.name != "Dependabot") | "\(.name)=\(.conclusion // .status)"] | unique | join(", ")')
  [[ -n $ci ]] || ci="(no CI runs on HEAD: read the checks of the PR that was merged)"
  echo "ci on HEAD: $ci"
  echo
done
