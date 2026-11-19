#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Gathers what you need to judge one Dependabot PR's version changes, per dependency:
#   - registry metadata for the new version vs the old one: license, and what it requires
#     (npm peerDependencies/engines, NuGet target frameworks)
#   - every upstream GitHub release in the bumped range (old, new], not just the newest few
#     that Dependabot pastes (it truncates), with full notes for each new major's first release
#     and for minors, and breaking-change keyword hits for the rest
#   - Dependabot's own notes for the dependency when no GitHub releases are found
# Read-only. Uses gh pr/gh release (no `gh api`), npm view, nuget.org and git ls-remote.
#
# A fetch that fails prints an "ERROR: could not fetch ..." line where its output would have
# been, and the script exits 1 at the end: missing notes never mean "no notes" silently.
# In a grouped PR, release lists and notes are fetched once per source repo; a dependency whose
# releases were already printed for another one says so instead of repeating them.
#
# Platform majors (Angular, .NET, Node, ...; see PLATFORM_RE in lib.sh) are out of scope for
# Dependabot merges, so their notes are skipped unless --include-platform is given.
#
# Usage: release-notes.sh OWNER/REPO PR_NUMBER [--dep NAME] [--max-lines N] [--include-platform]
#   --dep NAME          only this dependency (repeatable)
#   --max-lines N       lines of each release body to print (default 80)
#   --include-platform  read notes for platform majors too

set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"

repo=${1:?usage: release-notes.sh OWNER/REPO PR_NUMBER [--dep NAME] [--max-lines N]}
pr=${2:?usage: release-notes.sh OWNER/REPO PR_NUMBER [--dep NAME] [--max-lines N]}
shift 2
only=() max_lines=80 include_platform=false
while (($#)); do
  case $1 in
    --dep) only+=("$2"); shift 2 ;;
    --max-lines) max_lines=$2; shift 2 ;;
    --include-platform) include_platform=true; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

keywords='breaking|removed|no longer|deprecat|drop(ped|s)? support|requires? (node|\.net|angular|typescript|go )|minimum (supported|required|node|version)|license|migrat|peer ?dep|incompatib'
list_limit=300

errf=$(mktemp)
trap 'rm -f "$errf"' EXIT
failed=0
# err MESSAGE: report a failed fetch in place of its output, and count it for the exit status.
err() { echo "  ERROR: $*"; failed=$((failed + 1)); }
# reason: ": <last line of the failed command's stderr>", or nothing.
reason() { local r; r=$(grep -v '^[[:space:]]*$' "$errf" | tail -1 | cut -c1-200); [[ -n "$r" ]] && printf ': %s' "$r"; }

json=$(ghr pr view "$pr" -R "$repo" --json title,body,commits,headRefName 2>"$errf") || {
  echo "ERROR: could not fetch PR #$pr from $repo (network?)$(reason)"; exit 1; }
eco=$(jq -r '.headRefName | split("/")[1] // "unknown"' <<<"$json")
# The diff lets deps_json fill unknown from-versions and drop stale commit metadata (as inventory.sh does).
difff=$(mktemp); trap 'rm -f "$difff"' EXIT
if ! ghr pr diff "$pr" -R "$repo" >"$difff" 2>"$errf"; then
  echo "  note: could not read the PR diff$(reason); versions come from the PR text and metadata only"; : >"$difff"
fi
deps=$(deps_json "$difff" <<<"$json")
body=$(jq -r .body <<<"$json")

echo "#$pr $(jq -r .title <<<"$json")  [ecosystem: $eco]"

core() { grep -oE '[0-9]+(\.[0-9]+){0,3}' <<<"$1" | head -1; }
ver_le() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]; }
ver_lt() { [[ "$1" != "$2" ]] && ver_le "$1" "$2"; }
# line_key VERSION: the release line a version is on: its major, or 0.minor for 0.x.
line_key() { local ma mi; IFS=. read -r ma mi _ <<<"$1"; if [[ "$ma" == 0 ]]; then echo "0.${mi:-0}"; else echo "$ma"; fi; }
indent() { awk '{ print "    " $0 }'; }

strip_html() {
  perl -0pe 's{<summary>Commits</summary>.*?</details>}{}gs; s{<[^>]+>}{}g; s/&quot;/"/g; s/&#39;/\x27/g; s/&lt;/</g; s/&gt;/>/g; s/&amp;/&/g; s/\x{200b}//g' 2>/dev/null \
    | sed -E '/^[[:space:]]*$/N;/^\s*\n\s*$/D'
}

# Dependabot's notes for one dependency: only its own section of the body (from its
# "Updates/Updated/Bumps" line to the next one), never the whole body of a grouped PR.
dependabot_notes() {
  local name=$1
  NAME="$name" perl -0ne '
    my $n = quotemeta $ENV{NAME};
    my @parts = split /(?=^(?:Updates|Updated|Bumps) )/m, $_;
    my @hit = grep { /^(?:Updates|Updated|Bumps) (?:`$n`|\[$n\]|$n )/ } @parts;
    print @hit ? join("", @hit) : "(no section for $ENV{NAME} in the PR body)\n";' <<<"$body" \
    | perl -0pe 's{\[!\[Dependabot compatibility score\].*}{}s; s{Dependabot will resolve any conflicts.*}{}s' | strip_html
}

# dep_notes NAME LINES: dependabot_notes, capped, printed once per dependency name per run.
declare -A notes_printed
dep_notes() {
  if [[ -n "${notes_printed[$1]+x}" ]]; then echo "    (Dependabot's notes for $1 printed above)"; return; fi
  notes_printed[$1]=1
  dependabot_notes "$1" | head -n "$2" | indent
}

registry_npm() {
  local name=$1 from=$2 to=$3 new old
  new=$(timeout 30 npm view "$name@$to" license peerDependencies engines --json 2>"$errf") || {
    err "could not fetch npm metadata for $name@$to (network?)$(reason)"; return; }
  old=$(timeout 30 npm view "$name@$from" license peerDependencies --json 2>"$errf") || {
    err "could not fetch npm metadata for $name@$from (network?)$(reason)"; old=""; }
  [[ -n "$new" ]] || { echo "  registry: npm has no metadata for $name@$to"; return; }
  # With only one requested field present, npm prints that value alone (e.g. "MIT"), not an object.
  jq -rn --argjson n0 "$new" --argjson o0 "${old:-{\}}" '
    def norm: if type == "object" then . elif type == "string" then {license: .} else {} end;
    ($n0 | norm) as $n | ($o0 | norm) as $o |
    def lic(x): (x.license // "?");
    "  license: \(lic($o)) -> \(lic($n))",
    "  peerDependencies (new): " + (($n.peerDependencies // {}) | to_entries | map("\(.key) \(.value)") | join(", ") | if . == "" then "none" else . end),
    "  peerDependencies (old): " + (($o.peerDependencies // {}) | to_entries | map("\(.key) \(.value)") | join(", ") | if . == "" then "none" else . end),
    "  engines (new): " + (($n.engines // {}) | to_entries | map("\(.key) \(.value)") | join(", ") | if . == "" then "none" else . end)'
}

# nuspec ID VERSION: prints the nuspec; curl's exit code 22 means nuget.org answered 404.
nuspec() {
  local id=${1,,} v=${2,,}
  curl -fsS --max-time 30 "https://api.nuget.org/v3-flatcontainer/$id/$v/$id.nuspec" 2>"$errf"
}
registry_nuget() {
  local name=$1 from=$2 to=$3 new old rc lic_new lic_old
  new=$(nuspec "$name" "$to"); rc=$?
  if ((rc == 22)); then echo "  registry: nuspec for $to not found on nuget.org"; return
  elif ((rc)); then err "could not fetch the nuspec for $name $to (network?)$(reason)"; return; fi
  old=$(nuspec "$name" "$from"); rc=$?
  if ((rc && rc != 22)); then err "could not fetch the nuspec for $name $from (network?)$(reason)"; fi
  lic() { grep -oE '<license[^>]*>[^<]+</license>|<licenseUrl>[^<]+' <<<"$1" | sed -E 's/<[^>]+>//g; s/^<licenseUrl>//' | head -1; }
  lic_new=$(lic "$new"); lic_old=$(lic "$old")
  echo "  license: ${lic_old:-?} -> ${lic_new:-?}"
  echo "  target frameworks (new): $(grep -oE 'targetFramework="[^"]+"' <<<"$new" | cut -d'"' -f2 | sort -u | tr '\n' ' ')"
  echo "  target frameworks (old): $(grep -oE 'targetFramework="[^"]+"' <<<"$old" | cut -d'"' -f2 | sort -u | tr '\n' ' ')"
}

# Per-run caches, so a grouped PR fetches each source's release list and each release body once.
declare -A list_cache list_error body_cache printed_by
# fetch_list SRC: sets REL_LIST to "tag<TAB>publishedAt<TAB>isPrerelease" lines; 1 on failure.
fetch_list() {
  local src=$1 out
  if [[ -n "${list_error[$src]+x}" ]]; then return 1; fi
  if [[ -z "${list_cache[$src]+x}" ]]; then
    if ! out=$(ghr release list -R "$src" --limit "$list_limit" --json tagName,publishedAt,isPrerelease \
      -q '.[] | "\(.tagName)\t\(.publishedAt)\t\(.isPrerelease)"' 2>"$errf"); then
      list_error[$src]=$(reason); return 1
    fi
    list_cache[$src]=$out
  fi
  REL_LIST=${list_cache[$src]}
}
# fetch_body SRC TAG: sets BODY to the release's notes; 1 on failure (not cached, so retried).
fetch_body() {
  local key="$1 $2" out
  if [[ -z "${body_cache[$key]+x}" ]]; then
    out=$(ghr release view "$2" -R "$1" --json body -q .body 2>"$errf" </dev/null) || return 1
    body_cache[$key]=$out
  fi
  BODY=${body_cache[$key]}
}

re_esc() { sed -E 's/[][\.^$*+?(){}|]/\\&/g' <<<"$1"; }
# Monorepos tag per package (name@1.2.3, name-v1.2.3, name/v1.2.3, name-1.2.3, Name.1.2.3).
tag_prefix_re() { printf '^(%s|%s)(@|-v|/v|-|\\.)' "$(re_esc "$1")" "$(re_esc "${1##*/}")"; }
is_pre_tag() { [[ "$1" =~ [-.](rc|beta|alpha|next|pre|preview|canary|dev)[.0-9]*$ ]]; }

# package_tags NAME: REL_LIST lines as "version<TAB>tag<TAB>publishedAt<TAB>isPrerelease", keeping
# only NAME's tags when the repo tags per package.
package_tags() {
  local pfx tags tag date isp rest
  pfx=$(tag_prefix_re "$1")
  tags=$(grep -E "$pfx[0-9]" <<<"$REL_LIST") || { tags=$REL_LIST; pfx=""; }
  while IFS=$'\t' read -r tag date isp; do
    [[ -n "$tag" ]] || continue
    if [[ -n "$pfx" && "$tag" =~ $pfx(.*)$ ]]; then rest=${BASH_REMATCH[3]}; else rest=${tag##*@}; fi
    # Not every project marks prereleases as such on GitHub.
    is_pre_tag "$tag" && isp=true
    printf '%s\t%s\t%s\t%s\n' "$(core "$rest")" "$tag" "$date" "$isp"
  done <<<"$tags"
}

# releases_in_range NAME FROM TO: "version<TAB>tag<TAB>publishedAt" for releases in (FROM, TO].
releases_in_range() {
  local f t v tag date isp
  f=$(core "$2"); t=$(core "$3")
  package_tags "$1" | while IFS=$'\t' read -r v tag date isp; do
    [[ -n "$v" && "$isp" != true ]] || continue
    if ver_lt "$f" "$v" && ver_le "$v" "$t"; then printf '%s\t%s\t%s\n' "$v" "$tag" "$date"; fi
  done | sort -V -k1,1
}

# prereleases_of NAME VERSION: prerelease tags leading up to VERSION on its major (X.0.0-beta1,
# X.0.2-rc.1, ...). Some projects put a major's breaking changes in its prerelease notes and
# leave the final release almost empty.
prereleases_of() {
  local m v tag date isp
  m=$(cut -d. -f1 <<<"$2")
  package_tags "$1" | while IFS=$'\t' read -r v tag date isp; do
    [[ "$isp" == true && "${v%%.*}" == "$m" ]] && ver_le "$v" "$2" && printf '%s\t%s\n' "$tag" "$date"
  done | sort -V
}

is_dotnet_boilerplate() { grep -qE 'You can build \.NET [0-9.]+.*from the repository' <<<"$1"; }

# show TAG DATE KIND LINES [VERSION]: print one release's notes (uses $src and $name).
show() {
  local tag=$1 date=$2 kind=$3 lines=$4 v=${5:-} key="$src $1" rbody ptag pdate
  echo "  --- $tag (${date:0:10}) [$kind]"
  if [[ -n "${printed_by[$key]:-}" ]]; then echo "    (notes printed above, under ${printed_by[$key]})"; return; fi
  if ! fetch_body "$src" "$tag"; then
    err "could not fetch release notes for $tag from $src (network?)$(reason); read them with: gh release view $tag -R $src"
    return
  fi
  rbody=$BODY
  printed_by[$key]=$name
  if is_dotnet_boilerplate "$rbody"; then
    echo "    (source-build boilerplate, no change notes: read https://github.com/dotnet/core/tree/main/release-notes)"
    return
  fi
  if ! grep -q '[^[:space:]]' <<<"$rbody"; then
    echo "    (this release has no notes; read its commits: https://github.com/$src/commits/$tag)"
  else
    head -n "$lines" <<<"$rbody" | indent
    (($(wc -l <<<"$rbody") > lines)) && echo "    ... (more: gh release view $tag -R $src)"
  fi
  # A short major with no breaking-change keyword: the changes are likely written up elsewhere.
  if [[ "$kind" == major ]] && (($(grep -c . <<<"$rbody") < 15)) && ! grep -qiE "$keywords" <<<"$rbody"; then
    echo "    (short notes for a major, no breaking-change keywords: its breaking changes may be in its"
    echo "     prereleases or in an upgrade guide in the repo, e.g. BreakingChanges.md, MIGRATION.md, UPGRADING.md)"
    while IFS=$'\t' read -r ptag pdate; do
      [[ -n "$ptag" ]] || continue
      echo "  --- $ptag (${pdate:0:10}) [prerelease of $tag]"
      if [[ -n "${printed_by[$src $ptag]:-}" ]]; then echo "    (notes printed above, under ${printed_by[$src $ptag]})"; continue; fi
      if ! fetch_body "$src" "$ptag"; then
        err "could not fetch release notes for $ptag from $src (network?)$(reason); read them with: gh release view $ptag -R $src"
        continue
      fi
      printed_by[$src $ptag]=$name
      head -n "$lines" <<<"$BODY" | indent
    done < <([[ -n "$v" ]] && prereleases_of "$name" "$v")
  fi
}

# Devcontainer features (ghcr.io/OWNER/REPO/FEATURE) are versioned per feature in one repo, which
# tags each one feature_FEATURE_VERSION (the devcontainers/action convention) and has no releases.
devcontainer_feature() {
  local feature=$1 from=$2 to=$3 refs="" i v k prev tags=() majors=()
  echo "  versions are per feature, not GitHub releases: see the git log of src/$feature/devcontainer-feature.json"
  echo "  notes: https://github.com/$src/tree/main/src/$feature (NOTES.md, README.md)"
  for i in 1 2 3; do
    refs=$(GIT_TERMINAL_PROMPT=0 timeout 60 git ls-remote --tags --refs "https://github.com/$src" "feature_${feature}_*" 2>"$errf") && break
    refs="__failed__"; sleep $((i * 3))
  done
  if [[ "$refs" == "__failed__" ]]; then
    err "could not list the tags of https://github.com/$src (network?)$(reason)"; return
  fi
  prev=$(line_key "$(core "$from")")
  while read -r v; do
    [[ -n "$v" ]] || continue
    ver_lt "$from" "$v" && ver_le "$v" "$to" || continue
    tags+=("$v")
    k=$(line_key "$v")
    [[ "$k" != "$prev" ]] && majors+=("$v")
    prev=$k
  done < <(sed -nE "s#.*refs/tags/feature_${feature}_([0-9][0-9.]*)\$#\\1#p" <<<"$refs" | sort -V)
  if ((${#tags[@]} == 0)); then
    echo "  no feature_${feature}_* tags found in range"; return
  fi
  echo "  versions in range (${#tags[@]}): ${tags[*]}"
  for v in "${majors[@]}"; do
    echo "  first release of a new major, $v: read its commits for breaking changes:"
    echo "    https://github.com/$src/commits/feature_${feature}_$v/src/$feature"
  done
  if grep -q "feature_${feature}_${from}\$" <<<"$refs"; then
    echo "  changes: https://github.com/$src/compare/feature_${feature}_${from}...feature_${feature}_${to}"
  else
    echo "  changes: https://github.com/$src/commits/main/src/$feature"
  fi
}

count=$(jq length <<<"$deps")
for ((i = 0; i < count; i++)); do
  dep=$(jq -c ".[$i]" <<<"$deps")
  name=$(jq -r .name <<<"$dep"); from=$(jq -r '.from // ""' <<<"$dep"); to=$(jq -r '.to // ""' <<<"$dep")
  type=$(jq -r '.type // ""' <<<"$dep"); src=$(jq -r '.source // ""' <<<"$dep")
  if ((${#only[@]})) && [[ ! " ${only[*]} " == *" $name "* ]]; then continue; fi
  delta=$(jq -rn --arg f "$from" --arg t "$to" "$JQ_DELTA"' delta($f; $t)')

  echo
  echo "== $name ${from:-?} -> ${to:-(removed)}  [$delta] $type"
  conflict=$(jq -r '.conflict // ""' <<<"$dep"); note=$(jq -r '.note // ""' <<<"$dep")
  [[ -n "$conflict" ]] && echo "  CONFLICT: $conflict"
  [[ -n "$note" ]] && echo "  note: $note"
  if [[ -z "$to" ]]; then echo "  removed by this PR; nothing to read"; continue; fi
  # Stale commit metadata names a package the PR doesn't change: nothing to review.
  if [[ "$conflict" == "only the commit metadata lists"* ]]; then
    echo "  not changed by this PR (stale commit metadata); skipping its notes"; continue
  fi
  if ! $include_platform && [[ $(jq -rn --arg n "$name" --arg d "$delta" "$JQ_PLATFORM"' platform_major($n; $d)') == true ]]; then
    echo "  PLATFORM major: out of scope for Dependabot merges (needs a planned upgrade)."
    echo "  Notes not read; pass --include-platform to read them anyway."
    continue
  fi

  # Source repo: the PR body's link, corrected where Dependabot links the wrong repo.
  feature=""
  [[ "$eco" == "github_actions" && -z "$src" ]] && src=$(cut -d/ -f1-2 <<<"$name")
  if [[ "$eco" == devcontainers && "$name" =~ ^ghcr\.io/([^/]+)/([^/]+)/([^/:@]+)$ ]]; then
    src=${src:-${BASH_REMATCH[1]}/${BASH_REMATCH[2]}}; feature=${BASH_REMATCH[3]}
  fi
  if [[ -z "$src" && "$eco" == "npm_and_yarn" ]]; then
    url=$(timeout 30 npm view "$name@$to" repository.url 2>"$errf") || err "could not fetch npm metadata for $name@$to (network?)$(reason)"
    src=$(grep -oE 'github\.com[/:][^/]+/[^/#]+' <<<"$url" | sed -E 's#github\.com[/:]##; s#\.git$##' | head -1)
  fi
  # EF Core packages are built in dotnet/dotnet but released (with real notes) in dotnet/efcore.
  [[ "$src" == dotnet/dotnet && "$name" =~ ^(Microsoft\.EntityFrameworkCore|dotnet-ef$) ]] && src=dotnet/efcore
  # cmu-sei API clients link the umbrella repo; they're built and tagged in their API's repo.
  [[ "$src" == cmu-sei/crucible && "$name" =~ ^(.+)\.Client$ ]] && src=cmu-sei/${BASH_REMATCH[1]}
  if [[ -n "$src" ]]; then echo "  source: https://github.com/$src"; else echo "  source: unknown"; fi
  [[ "$src" == dotnet/dotnet ]] &&
    echo "  (dotnet/dotnet releases are source-build notes, tagged by SDK version; the change notes are in https://github.com/dotnet/core/tree/main/release-notes)"

  if [[ -z "$from" ]]; then
    echo "  old version unknown (not in the PR's text, metadata or diff); read the manifest diff: gh pr diff $pr -R $repo"
    echo "  Dependabot's notes for this dependency (may be truncated):"
    dep_notes "$name" "$max_lines"
    continue
  fi

  if [[ -n "$feature" ]]; then devcontainer_feature "$feature" "$from" "$to"; continue; fi

  case $eco in
    npm_and_yarn) registry_npm "$name" "$from" "$to" ;;
    nuget) registry_nuget "$name" "$from" "$to" ;;
  esac

  rel=""
  if [[ -n "$src" ]]; then
    if ! fetch_list "$src"; then
      err "could not fetch the release list of $src (network?)${list_error[$src]}; releases in range unknown, not absent"
      echo "  Dependabot's notes follow as a stopgap (they may be truncated):"
      dep_notes "$name" "$max_lines"
      continue
    fi
    if (($(grep -c . <<<"$REL_LIST") >= list_limit)); then
      oldest=$(package_tags "$name" | cut -f1 | grep . | sort -V | head -1)
      # Only when the cut-off falls inside the range (tags on another scheme don't count).
      [[ -n "$oldest" ]] && ver_lt "$(core "$from")" "$oldest" && ver_le "$oldest" "$(core "$to")" &&
        echo "  note: only the newest $list_limit releases of $src were listed (oldest $oldest); releases in range before it may be missing"
    fi
    rel=$(releases_in_range "$name" "$from" "$to")
  fi
  if [[ -z "$rel" ]]; then
    echo "  no GitHub releases found in range${src:+ (the release list of $src was read)}; Dependabot's notes follow (they may be truncated)."
    echo "  if they are, read the project's changelog: a CHANGELOG file in its repo${src:+ (https://github.com/$src)},"
    echo "  its docs site, or the source listed for this ecosystem in ecosystems.md."
    dep_notes "$name" $((max_lines * 2))
    continue
  fi

  n_rel=$(wc -l <<<"$rel")
  echo "  releases in range ($n_rel): $(cut -f2 <<<"$rel" | tr '\n' ' ')"

  # Each release line (major, or 0.minor) in range: its lowest version and when that was published.
  fline=$(line_key "$(core "$from")")
  declare -A first_ver=() first_date=()
  lines_seen=()
  while IFS=$'\t' read -r v tag date; do
    k=$(line_key "$v")
    if [[ -z "${first_ver[$k]+x}" ]]; then first_ver[$k]=$v; first_date[$k]=$date; lines_seen+=("$k"); fi
  done <<<"$rel"
  # Classify each release, then print majors first (in full), minors as excerpts, and only
  # breaking-change keyword hits for patches, so the releases that matter come first.
  majors=() minors=() patches=() maint=()
  while IFS=$'\t' read -r v tag date; do
    IFS=. read -r ma mi pa _ <<<"$v"
    k=$(line_key "$v")
    # A release on an older line published after the next line's first release is a backport to
    # the older line, not on the path to the new version: list it without reading it. Releases
    # on the older line published before that are on the upgrade path and read normally.
    nxt=""
    for ((j = 0; j < ${#lines_seen[@]} - 1; j++)); do
      [[ "${lines_seen[j]}" == "$k" ]] && nxt=${lines_seen[j + 1]}
    done
    if [[ -n "$nxt" && "$date" > "${first_date[$nxt]}" ]]; then maint+=("$tag"); continue; fi
    if [[ "$k" != "$fline" && "$v" == "${first_ver[$k]}" ]]; then majors+=("$tag"$'\t'"$date"$'\t'"$v")
    elif [[ "${pa:-0}" == 0 ]]; then minors+=("$tag"$'\t'"$date"$'\t'"$v")
    else patches+=("$tag"$'\t'"$date"$'\t'"$v"); fi
  done <<<"$rel"
  budget=40
  toread=("${majors[@]}" "${minors[@]}" "${patches[@]}")
  # Every release this dependency would read was already covered for another dependency.
  same=""
  for r in "${toread[@]:0:$budget}"; do
    same=${printed_by[$src ${r%%$'\t'*}]:-}
    [[ -n "$same" ]] || break
  done
  if [[ -n "$same" ]]; then
    echo "  (same releases as $same above)"
    continue
  fi
  minor_lines=$((max_lines / 4 > 15 ? max_lines / 4 : 15))
  ((n_rel <= 5)) && minor_lines=$max_lines
  for r in "${majors[@]}"; do ((budget-- > 0)) || break; IFS=$'\t' read -r tag date v <<<"$r"; show "$tag" "$date" major "$max_lines" "$v"; done
  for r in "${minors[@]}"; do ((budget-- > 0)) || break; IFS=$'\t' read -r tag date v <<<"$r"; show "$tag" "$date" minor "$minor_lines"; done
  hits=""
  for r in "${patches[@]}"; do
    ((budget-- > 0)) || break
    IFS=$'\t' read -r tag date v <<<"$r"
    if ((n_rel <= 5)); then show "$tag" "$date" patch "$max_lines"; continue; fi
    [[ -n "${printed_by[$src $tag]:-}" ]] && continue
    if ! fetch_body "$src" "$tag"; then
      err "could not fetch release notes for $tag from $src (network?)$(reason); read them with: gh release view $tag -R $src"
      continue
    fi
    printed_by[$src $tag]=$name
    h=$(grep -iE "$keywords" <<<"$BODY" | head -8)
    [[ -n "$h" ]] && hits+="  $tag:"$'\n'"$(indent <<<"$h")"$'\n'
  done
  ((budget < 0)) && echo "  (read 40 releases; the rest: gh release view <tag> -R $src)"
  ((${#maint[@]})) && echo "  --- backports to older lines, published after the next line's first release (not read): ${maint[*]}"
  if [[ -n "$hits" ]]; then
    echo "  --- breaking-change keywords in patch releases"
    printf '%s' "$hits"
  fi
done

if ((failed)); then
  echo
  echo "ERROR: $failed fetch(es) failed (network?); the notes above are incomplete where marked ERROR."
  echo "Re-run this script (one at a time: parallel runs make GitHub refuse connections)."
  exit 1
fi
