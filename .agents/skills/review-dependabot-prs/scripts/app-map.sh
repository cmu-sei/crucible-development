#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Maps a GitHub repo to what is needed to validate a change to it locally: its clone,
# the Aspire resources built from that clone, and the crucible-tests e2e suites that
# exercise them. Nothing is tabulated here; it is all derived at run time from:
#   scripts/repos.json (+ repos.local.json)  repo -> group -> clone path (rule from clone-repos.sh)
#   Crucible.AppHost/*.cs                     resources rooted in, built from or mounted from a clone
#   AddDotnetProject("name", path, ...)       .NET project resource -> csproj path -> clone
#   <api>/Properties/launchSettings.json      API port (for the launch profile AppHost uses)
#   AppHost File.Copy of UI settings files    which UI clones call which API port
#   crucible-tests/run-tests.sh (+ .env)      suite names, UI ports and dependency lines
# Where parsing could silently miss something it prints warning= instead of guessing.
# Read-only. No gh calls.
#
# Usage: app-map.sh OWNER/REPO   (or a GitHub URL; a repo from scripts/repos.json, or this repo)
# Output: key=value lines (repo, group, clone, resource..., suites, suites_via, note, warning).

set -uo pipefail

arg=${1:?usage: app-map.sh OWNER/REPO}

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null) || root=$(cd "$here/../../../.." && pwd)
apphost_dir=$root/Crucible.AppHost
repos_json=$root/scripts/repos.json
repos_local=$root/scripts/repos.local.json
clone_sh=$root/scripts/clone-repos.sh

warnings=()
notes=()
warn() { warnings+=("$*"); }

# Lowercase OWNER/REPO from a URL or OWNER/REPO.
norm_repo() {
  local s=${1,,}
  s=${s#https://github.com/}; s=${s#http://github.com/}; s=${s#git@github.com:}
  s=${s%/}; s=${s%.git}; s=${s%/}
  printf '%s' "$s"
}
# Lowercase path with duplicate and trailing slashes removed.
norm_path() {
  local p=${1,,}
  while [[ $p == *//* ]]; do p=${p//\/\//\/}; done
  printf '%s' "${p%/}"
}

want=$(norm_repo "$arg")

# --- Meta-repo: this checkout itself (not in repos.json). -----------------------------
origin=$(git -C "$root" remote get-url origin 2>/dev/null || true)
if [[ -n $origin && $want == "$(norm_repo "$origin")" ]]; then
  echo "repo=$want"
  echo "clone=$root exists=yes"
  echo "suites=none reason=meta-repo: AppHost/devcontainer/script changes affect every app, so decide the full-stack validation by hand"
  exit 0
fi

# --- Manifest: merged the way clone-repos.sh and Moodle.cs merge it. -------------------
[[ -f $repos_json ]] || { echo "error=$repos_json not found" >&2; exit 2; }
if [[ -f $repos_local ]]; then
  manifest=$(jq -s '{groups: (.[0].groups + (.[1].groups // [])), repos: (.[0].repos + (.[1].repos // []))}' \
    "$repos_json" "$repos_local")
else
  manifest=$(cat "$repos_json")
fi

# Clone path rule, read from clone-repos.sh:
#   top-level repos   TARGET="<base>/$NAME"
#   grouped repos     TARGET="<base>/$GROUP/$NAME", except the moodle group, whose plugins
#                     go to <base>/<group>/<dir for the plugin type>/<rest of the name>
#                     (map_moodle_plugin_path; unknown types stay flat: <base>/<group>/<name>).
base=$(grep -oE 'TARGET="[^"$]+/\$NAME"' "$clone_sh" 2>/dev/null | head -1 | sed -E 's#^TARGET="##; s#/\$NAME"$##')
if [[ -z $base ]]; then
  base=/mnt/data/crucible
  warn "could not read the clone base path from $clone_sh; assuming $base"
fi
moodle_group=$(grep -oE '"\$GROUP" = "[^"]+"' "$clone_sh" 2>/dev/null | head -1 | sed -E 's/.*= "([^"]+)"/\1/')
declare -A plugin_dir=()
while read -r t d; do
  [[ -n $t ]] && plugin_dir[$t]=$d
done < <(sed -nE 's#^[[:space:]]*([a-z]+)\) echo "\$base_path/(.+)/\$plugin_subdir" ;;.*#\1 \2#p' "$clone_sh" 2>/dev/null)

clone_path() { # group name
  local g=$1 n=$2 t
  if [[ -z $g ]]; then printf '%s/%s' "$base" "$n"; return; fi
  if [[ -n $moodle_group && $g == "$moodle_group" && $n == *_* ]]; then
    t=${n%%_*}
    if [[ -n ${plugin_dir[$t]:-} ]]; then printf '%s/%s/%s/%s' "$base" "$g" "${plugin_dir[$t]}" "${n#*_}"; return; fi
  fi
  printf '%s/%s/%s' "$base" "$g" "$n"
}

# Top-level repos get group "-" (an empty first field would collapse under IFS=tab).
m_group=(); m_name=(); m_repo=(); m_disp=(); m_clone=(); m_norm=()
while IFS=$'\t' read -r g n u; do
  [[ $g == - ]] && g=""
  d=${u#https://github.com/}; d=${d%/}; d=${d%.git}
  m_group+=("$g"); m_name+=("$n"); m_repo+=("$(norm_repo "$u")"); m_disp+=("$d")
  c=$(clone_path "$g" "$n"); m_clone+=("$c"); m_norm+=("$(norm_path "$c")")
done < <(jq -r '(.groups[] | .name as $g | .repos[] | [$g, .name, .url]), (.repos[] | ["-", .name, .url]) | @tsv' <<<"$manifest")

target=-1
for i in "${!m_repo[@]}"; do [[ ${m_repo[$i]} == "$want" ]] && { target=$i; break; }; done
if ((target < 0)); then
  echo "error=$want is not in scripts/repos.json${origin:+ and is not this repo ($(norm_repo "$origin"))}" >&2
  exit 2
fi
t_group=${m_group[$target]}
t_clone=${m_clone[$target]}

# Index of the repos.json clone containing a path (longest prefix wins), or -1.
clone_of() {
  local p best=-1 len=0 i c
  p=$(norm_path "$1")
  for i in "${!m_norm[@]}"; do
    c=${m_norm[$i]}
    if [[ $p == "$c" || $p == "$c"/* ]] && ((${#c} > len)); then best=$i; len=${#c}; fi
  done
  printf '%s' "$best"
}

# --- AppHost: resources. ----------------------------------------------------------------
# All AppHost .cs files flattened to one line each, with // comments stripped (only when
# the // follows whitespace, so "http://..." survives), so multi-line calls parse as one.
flat() { sed -E 's#(^|[[:space:]])//.*$##' "$1" | tr '\n\t' '  ' | tr -s ' '; }
ah=""
for f in "$apphost_dir"/*.cs; do ah+="$(flat "$f");"; done
[[ -n $ah ]] || warn "no .cs files found in $apphost_dir"

id='[A-Za-z_][A-Za-z0-9_]*'
# String and int constants: var x = "..."; const string x = "..."; const int x = N;
declare -A strs=() ints=()
while IFS= read -r m; do
  k=$(sed -E "s/^(var|const string|string) ($id) = .*/\2/" <<<"$m"); v=${m#*= \"}; strs[$k]=${v%\"}
done < <(grep -oE "(var|const string|string) $id = \"[^\"]*\"" <<<"$ah")
while IFS= read -r m; do
  k=$(sed -E "s/^const int ($id) = .*/\1/" <<<"$m"); ints[$k]=${m##* }
done < <(grep -oE "const int $id = [0-9]+" <<<"$ah")
angular_default_dist=$(grep -oE 'string distPath = "[^"]*"' <<<"$ah" | head -1 | sed -E 's/.*"([^"]*)"/\1/')

resolve_str() { # token -> path: "literal", $"{builder.AppHostDirectory}/..." or $"{stringVar}/...", or a string variable
  local t=$1 v
  t=${t#"${t%%[! ]*}"}; t=${t%"${t##*[! ]}"}
  case $t in
    \$\"*) t=${t#\$\"}; t=${t%\"}; t=${t//\{builder.AppHostDirectory\}/$apphost_dir}
          for v in $(grep -oE "\\{$id\\}" <<<"$t" | tr -d '{}' | sort -u); do
            [[ -n ${strs[$v]:-} ]] && t=${t//\{$v\}/${strs[$v]}}
          done
          printf '%s' "$t" ;;
    \"*)   t=${t#\"}; printf '%s' "${t%\"}" ;;
    *)     printf '%s' "${strs[$t]:-}" ;;
  esac
}
resolve_int() { [[ $1 =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '%s' "${ints[$1]:-}"; }

# The mode a resource follows: AppHost gates each one with
#   if (!IsEnabled(xMode)) { ...; var.WithExplicitStart(); }   (or the brace-less form)
gate_of() {
  [[ -n $1 ]] || return 0
  grep -oE 'if \(!IsEnabled\([A-Za-z_]+\)\) ?(\{[^{}]*\}|[^;{]*;)' <<<"$ah" \
    | grep -E "(^|[^A-Za-z0-9_])$1\??\.WithExplicitStart\(" | head -1 \
    | sed -E 's/^if \(!IsEnabled\(([A-Za-z_]+)\).*/\1/'
}
# LaunchOptions name(s) behind a mode variable: var xMode = ResolveMode(options.X, ...),
# or one level of indirection (topoMojoMode = ... ? configuredTopoMojoMode : launchpointMode).
launch_of() {
  local m=$1 a sub out
  [[ -n $m ]] || return 0
  a=$(grep -oE "var $m = [^;]*" <<<"$ah" | head -1)
  out=$(grep -oE 'options\.[A-Za-z0-9]+' <<<"$a" | sed 's/options\.//')
  if [[ -z $out ]]; then
    for sub in $(grep -oE '\b[a-z][A-Za-z0-9]*Mode\b' <<<"${a#*=}" | sort -u); do
      [[ $sub == "$m" ]] && continue
      out+=" $(grep -oE "var $sub = [^;]*" <<<"$ah" | head -1 | grep -oE 'options\.[A-Za-z0-9]+' | sed 's/options\.//')"
    done
  fi
  # shellcheck disable=SC2086
  printf '%s' "$(printf '%s\n' $out | sort -u | paste -sd'|')"
}
# Dist dir of a non-AddAngularUI UI: "serve -s DIR" in the call, or in the string variable
# passed as `"-c", var` (one level).
find_dist() {
  local s=$1 depth=${2:-0} d v
  d=$(grep -oE 'serve -s [^ "{}]+' <<<"$s" | head -1)
  [[ -n $d ]] && { printf '%s' "${d#serve -s }"; return; }
  v=$(grep -oE "(serve -s \{|\"serve\", ?\"-s\", ?)$id" <<<"$s" | head -1 | grep -oE "$id\$")
  [[ -n $v ]] && { printf '%s' "${strs[$v]:-}"; return; }
  ((depth == 0)) || return 0
  v=$(grep -oE "\"-c\", ?$id\)" <<<"$s" | head -1 | grep -oE "$id\)\$" | tr -d ')')
  [[ -n $v ]] && find_dist "$(grep -oE "var $v = [^;]*" <<<"$ah" | head -1)" 1
}

# Resource records (deduplicated by name: topomojo-ui is added once per mode branch).
r_name=(); r_kind=(); r_port=(); r_dist=(); r_mode=(); r_launch=(); r_paths=(); r_clone=(); r_extra=(); r_var=()
declare -A r_idx=()
add_resource() { # name kind port dist mode var paths extra
  local n=$1 i
  if [[ -n ${r_idx[$n]:-} ]]; then
    i=${r_idx[$n]}
    [[ "|${r_kind[$i]}|" == *"|$2|"* ]] || r_kind[$i]+="|$2"
    [[ -n ${r_port[$i]} ]] || r_port[$i]=$3
    [[ -n ${r_dist[$i]} ]] || r_dist[$i]=$4
    [[ -n ${r_mode[$i]} ]] || r_mode[$i]=$5
    [[ " ${r_paths[$i]} " == *" $7 "* ]] || r_paths[$i]+=" $7"
    return
  fi
  i=${#r_name[@]}; r_idx[$n]=$i
  r_name+=("$n"); r_kind+=("$2"); r_port+=("$3"); r_dist+=("$4"); r_mode+=("$5"); r_var+=("$6")
  r_paths+=("$7"); r_extra+=("$8"); r_launch+=(""); r_clone+=("$(clone_of "${7%% *}")")
}

while IFS= read -r s; do
  var=$(grep -oE "^$id = " <<<"$s" | sed 's/ = $//')
  how=$(grep -oE 'builder\.Add[A-Za-z]+' <<<"$s" | head -1); how=${how#builder.Add}
  name=$(grep -oE 'builder\.Add[^(]*\( ?"[^"]+"' <<<"$s" | head -1 | grep -oE '"[^"]+"$' | tr -d '"')
  args=${s#*\"$name\"}; args=${args#,}
  IFS=',' read -r a1 a2 a3 a4 _ <<<"$args"
  port=$(grep -oE 'WithHttpEndpoint\( ?port: ?[A-Za-z0-9_]+' <<<"$s" | head -1 | sed -E 's/.*port: ?//')
  port=$(resolve_int "${port:-x}")
  case $how in
    AngularUI) # AddAngularUI("name", "app", appRoot, port: N, mode, ...)
      path=$(resolve_str "$a2")
      port=$(grep -oE 'port: ?[0-9]+' <<<"$a3" | grep -oE '[0-9]+')
      mode=$(tr -d ' ' <<<"$a4")
      dist=$(grep -oE 'distPath: ?"[^"]*"' <<<"$s" | sed -E 's/.*"([^"]*)"/\1/')
      add_resource "$name" angular-ui "$port" "${dist:-$angular_default_dist}" "$mode" "$var" "$path" "" ;;
    JavaScriptApp)
      add_resource "$name" js-app "$port" "$(find_dist "$s")" "$(gate_of "$var")" "$var" "$(resolve_str "$a1")" "" ;;
    Executable)
      path=$(resolve_str "$a2")
      [[ -n $path ]] && add_resource "$name" executable "$port" "$(find_dist "$s")" "$(gate_of "$var")" "$var" "$path" "" ;;
    Container)
      paths=$(grep -oE 'With(BindMount|Dockerfile)\( ?"/[^"]+"' <<<"$s" | sed -E 's/.*"([^"]+)"/\1/' | paste -sd' ')
      [[ -n $paths ]] && add_resource "$name" container "$port" "" "$(gate_of "$var")" "$var" "$paths" "" ;;
    DotnetProject) # AddDotnetProject("name", path[, project => project.LaunchProfileName = "X"])
      cs=$(resolve_str "${a1%%)*}")
      profile=$(grep -oE 'LaunchProfileName = "[^"]+"' <<<"$s" | head -1 | sed -E 's/.*"([^"]+)"/\1/')
      if [[ $cs != /*.csproj ]]; then
        warn "AppHost resource $name: can't resolve its project path from ${a1%%)*}"
        continue
      fi
      add_resource "$name" dotnet-project "$port" "" "$(gate_of "$var")" "$var" "$cs" "$(basename "$cs" .csproj)|$profile|$s" ;;
  esac
done < <(grep -oE "($id = )?builder\.Add(AngularUI|JavaScriptApp|Executable|Container|DotnetProject)\( ?\"[^\"]+\"[^;]*" <<<"$ah")

for i in "${!r_name[@]}"; do r_launch[$i]=$(launch_of "${r_mode[$i]}"); done

# Moodle plugins: Moodle.cs bind-mounts every repo of one repos.json group into each Moodle
# instance (new MoodleInstance(Name: "...", ..., Port: N, ..., Mode: ResolveMode(options.X, ...)).
moodle_cs=$apphost_dir/Moodle.cs
mounted_group=""; mi_name=(); mi_port=(); mi_launch=()
if [[ -f $moodle_cs ]]; then
  mounted_group=$(grep -oE 'groupName\.GetString\(\) != "[^"]+"' "$moodle_cs" | head -1 | sed -E 's/.*"([^"]+)"/\1/')
  while IFS=$'\t' read -r n p l; do mi_name+=("$n"); mi_port+=("$p"); mi_launch+=("$l"); done < <(
    flat "$moodle_cs" | grep -oE 'Name: "[^"]+"|Port: [0-9]+|Mode: ResolveMode\(options\.[A-Za-z0-9]+' \
      | awk '/^Name:/{gsub(/^Name: "|"$/,""); n=$0} /^Port:/{p=$2} /^Mode:/{sub(/.*options\./,""); if (n != "" && p != "") print n "\t" p "\t" $0; n=""; p=""}')
fi

# --- crucible-tests: suites, UI ports and dependency lines. ------------------------------
tests_clone=""
for i in "${!m_name[@]}"; do [[ ${m_name[$i]} == crucible-tests && -z ${m_group[$i]} ]] && tests_clone=${m_clone[$i]}; done
run_tests=${tests_clone:-$base/crucible-tests}/run-tests.sh
declare -A suite_port=() port_suite=() suite_deps=()
all_suites=""
if [[ -f $run_tests ]]; then
  all_suites=$(grep -oE '^ALL_APPS="[^"]*"' "$run_tests" | sed -E 's/^ALL_APPS="([^"]*)"/\1/')
  # A default run (no --target) loads .env then .env.local, and a UI URL set there wins over
  # the default. --target/CRUCIBLE_TARGET is ignored: only the Aspire topology has the
  # per-app localhost ports that AppHost resources can be matched against.
  envfiles=("$(dirname "$run_tests")/.env" "$(dirname "$run_tests")/.env.local")
  while read -r app envvar def; do
    url=""
    for ef in "${envfiles[@]}"; do
      [[ -f $ef ]] || continue
      v=$(grep -E "^$envvar=" "$ef" | tail -1 | cut -d= -f2- | tr -d "\"'")
      [[ -n $v ]] && url=$v
    done
    p=$(sed -nE 's#^[a-z]+://[^/:]+:([0-9]+).*#\1#p' <<<"$url")
    dp=$(sed -nE 's#^[a-z]+://[^/:]+:([0-9]+).*#\1#p' <<<"$def")
    if [[ -n $url && -n $dp && $p != "$dp" ]]; then
      warn "suite $app: $envvar=$url in crucible-tests/.env* differs from the default port $dp; using ${p:-$dp}"
    fi
    p=${p:-$dp}
    [[ -n $p ]] || continue
    suite_port[$app]=$p; port_suite[$p]=$app
  done < <(awk '/^get_app_url\(\)/{f=1; next} f && /^}/{f=0} f' "$run_tests" \
    | sed -nE 's/^[[:space:]]*([A-Za-z]+)\)[[:space:]]+echo "\$\{([A-Z_]+)(:-([^}]*))?\}";;.*/\1 \2 \4/p')
  while IFS='|' read -r app deps; do suite_deps[$app]=$deps; done < <(
    awk '/^get_app_deps\(\)/{f=1; next} f && /^}/{f=0} f' "$run_tests" \
      | sed -nE 's/^[[:space:]]*([A-Za-z]+)\) echo "([^"]+)";;.*/\1|\2/p')
  for s in $all_suites; do
    [[ -n ${suite_port[$s]:-} || $s == keycloak ]] || warn "suite $s has no parseable UI port in get_app_url; it can't be matched to a resource"
  done
else
  warn "$run_tests not found; suites can't be derived"
fi

# --- Output. ----------------------------------------------------------------------------
echo "repo=${m_disp[$target]}"
[[ -n $t_group ]] && echo "group=$t_group"
if [[ -d $t_clone ]]; then echo "clone=$t_clone exists=yes"
else echo "clone=$t_clone exists=no"; warn "not cloned at $t_clone (run scripts/clone-repos.sh); results below come from AppHost/repos.json only"
fi

if [[ -n $tests_clone && $(norm_path "$t_clone") == "$(norm_path "$tests_clone")" ]]; then
  echo "suites=none reason=this is the e2e test repo (run-tests.sh); validate with the suites whose specs or shared fixtures the change touches"
  exit 0
fi

declare -A suites=() via=()
add_suite() { suites[$1]=1; [[ -n ${via[$1]:-} ]] && via[$1]+=", $2" || via[$1]=$2; }
ui_suites_of_clone() { # clone index -> add suites for its UI resources; label prefix
  local c=$1 why=$2 i s
  for i in "${!r_name[@]}"; do
    [[ ${r_clone[$i]} == "$c" && -n ${r_port[$i]} && ${r_kind[$i]} != dotnet-project ]] || continue
    s=${port_suite[${r_port[$i]}]:-}
    [[ -n $s ]] && add_suite "$s" "$why${r_name[$i]} port ${r_port[$i]}"
  done
}

# UI settings files AppHost copies into UI clones: File.Copy($"{builder.AppHostDirectory}/X", $"{uiRoot}/...")
s_file=(); s_clone=()
while IFS= read -r m; do
  rel=$(sed -E 's#^File\.Copy\( ?\$"\{builder\.AppHostDirectory\}/([^"]+)".*#\1#' <<<"$m")
  rv=$(sed -E 's#.*, ?\$"\{([A-Za-z_][A-Za-z0-9_]*)\}$#\1#' <<<"$m")
  s_file+=("$apphost_dir/$rel"); s_clone+=("$(clone_of "${strs[$rv]:-/nonexistent}")")
done < <(grep -oE "File\.Copy\( ?\\\$\"\{builder\.AppHostDirectory\}/[^\"]+\", ?\\\$\"\{$id\}" <<<"$ah")

found=0
for i in "${!r_name[@]}"; do
  [[ ${r_clone[$i]} == "$target" ]] || continue
  found=1
  line="resource=${r_name[$i]} kind=${r_kind[$i]}"
  case ${r_kind[$i]} in
    dotnet-project)
      IFS='|' read -r proj profile stmt <<<"${r_extra[$i]}"
      cs=${r_paths[$i]}
      ls_json=$(dirname "$cs")/Properties/launchSettings.json
      ports=""
      if [[ -f $ls_json ]]; then
        # Aspire uses LaunchProfileName, else the first profile with commandName "Project".
        ports=$(jq -r --arg p "$profile" '.profiles | (if $p != "" then .[$p] else ([.[] | select(.commandName == "Project")] | first) end)
                 | .applicationUrl // "" | split(";")[]' "$ls_json" 2>/dev/null \
                 | sed -nE 's#^[a-z]+://[^/:]+:([0-9]+).*#\1#p' | paste -sd' ')
      fi
      if [[ -n $ports ]]; then
        grep -qE 'WithHttpEndpoint|WithEndpoint|ASPNETCORE_URLS|Kestrel__' <<<"$stmt" \
          && warn "${r_name[$i]}: AppHost overrides its endpoint, so the launchSettings port may be wrong"
      elif [[ -n ${r_port[$i]} ]]; then
        ports=${r_port[$i]} # no launchSettings.json port; the AppHost sets the endpoint itself
      else
        warn "${r_name[$i]}: no API port from $ls_json${profile:+ profile $profile}; caller UIs found by group only"
      fi
      line+=" project=$proj csproj=${cs#"$t_clone"/}${ports:+ port=${ports// /,}}"
      line+=" mode_var=${r_mode[$i]:--} launch=${r_launch[$i]:--}"
      echo "$line"

      # Callers: UI clones whose AppHost-copied settings file contains localhost:<api port>.
      callers=(); others=()
      for j in "${!s_file[@]}"; do
        [[ -f ${s_file[$j]} && -n $ports ]] || continue
        for p in $ports; do
          if grep -qE "localhost:$p([^0-9]|\$)" "${s_file[$j]}"; then
            c=${s_clone[$j]}; ((c >= 0)) || break
            if [[ ${m_group[$c]} == "$t_group" ]]; then callers+=("$c"); else others+=("$c"); fi
            break
          fi
        done
      done
      for c in $(printf '%s\n' "${others[@]}" | sort -u); do
        warn "${r_name[$i]} is also called by ${m_name[$c]} (group ${m_group[$c]}), outside group $t_group; its suites are not included"
      done
      if ((${#callers[@]} == 0)) && [[ -z $t_group ]]; then
        warn "${r_name[$i]}: no UI settings file references its port ${ports:-?}, and the repo has no group to fall back to"
      elif ((${#callers[@]} == 0)); then
        # Fallback: every UI in the same group.
        for c in "${!m_group[@]}"; do [[ ${m_group[$c]} == "$t_group" && $c != "$target" ]] && callers+=("$c"); done
        warn "${r_name[$i]}: no UI settings file references its port ${ports:-?}; assuming every UI in group $t_group calls it"
      fi
      # UI clones in the group with no copied settings file can't be checked.
      for c in "${!m_group[@]}"; do
        [[ -n $t_group && ${m_group[$c]} == "$t_group" && $c != "$target" ]] || continue
        has_ui=0; has_settings=0
        for k in "${!r_name[@]}"; do [[ ${r_clone[$k]} == "$c" && ${r_kind[$k]} != dotnet-project && -n ${r_port[$k]} ]] && has_ui=1; done
        for k in "${!s_clone[@]}"; do [[ ${s_clone[$k]} == "$c" ]] && has_settings=1; done
        ((has_ui && !has_settings)) && warn "${m_name[$c]} has a UI but no AppHost-copied settings file; can't tell whether it calls ${r_name[$i]}"
      done
      for c in $(printf '%s\n' "${callers[@]}" | sort -u); do
        ui_suites_of_clone "$c" "UI calling ${r_name[$i]}: "
      done
      ;;
    *)
      [[ -n ${r_port[$i]} ]] && line+=" port=${r_port[$i]}"
      [[ ${r_kind[$i]} == container ]] && line+=" mounts=${r_paths[$i]// /,}"
      [[ ${r_kind[$i]} != container && -n ${r_port[$i]} ]] && line+=" dist=${r_dist[$i]:-?}"
      line+=" mode_var=${r_mode[$i]:--} launch=${r_launch[$i]:--}"
      echo "$line"
      [[ ${r_kind[$i]} != container && -n ${r_port[$i]} && -z ${r_dist[$i]} ]] && warn "${r_name[$i]}: dist dir not found in its AppHost call"
      [[ -z ${r_mode[$i]} ]] \
        && notes+=("${r_name[$i]}: no if (!IsEnabled(xMode)) ...WithExplicitStart() gate found; it starts based on other launch options")
      if [[ -n ${r_port[$i]} ]]; then
        s=${port_suite[${r_port[$i]}]:-}
        if [[ -n $s ]]; then add_suite "$s" "${r_name[$i]} port ${r_port[$i]}"
        else notes+=("${r_name[$i]} (port ${r_port[$i]}) matches no run-tests.sh suite UI port")
        fi
      fi
      ;;
  esac
done

# Moodle plugin: mounted into every Moodle instance.
if [[ -n $mounted_group && $t_group == "$mounted_group" ]]; then
  t=${m_name[$target]%%_*}
  [[ ${m_name[$target]} == *_* && -n ${plugin_dir[$t]:-} ]] \
    || warn "plugin type '$t' is not in clone-repos.sh map_moodle_plugin_path; clone-repos.sh and Moodle.cs may disagree on its path"
  ((${#mi_name[@]})) || warn "no MoodleInstance(Name/Port/Mode) parsed from $moodle_cs"
  for k in "${!mi_name[@]}"; do
    found=1
    echo "resource=${mi_name[$k]} kind=container port=${mi_port[$k]} mounts=$t_clone mode_var=- launch=${mi_launch[$k]}"
    s=${port_suite[${mi_port[$k]}]:-}
    if [[ -n $s ]]; then add_suite "$s" "${mi_name[$k]} port ${mi_port[$k]} (plugin bind mount)"
    else notes+=("${mi_name[$k]} (port ${mi_port[$k]}) matches no run-tests.sh suite UI port")
    fi
  done
fi

# Safety net: AppHost paths inside this clone that no parsed resource accounts for.
while IFS= read -r hit; do
  lit=$(grep -oE "\"$base/[^\"]*\"" <<<"${hit#*:*:}" | head -1 | tr -d '"')
  [[ -n $lit && $(clone_of "$lit") == "$target" ]] || continue
  covered=0
  for i in "${!r_name[@]}"; do
    for p in ${r_paths[$i]}; do [[ $(norm_path "$p") == "$(norm_path "$lit")" ]] && covered=1; done
  done
  ((covered)) || warn "$(basename "${hit%%:*}"):$(cut -d: -f2 <<<"$hit") references $lit, which no parsed resource accounts for"
done < <(grep -nE "\"$base/" "$apphost_dir"/*.cs 2>/dev/null)

# Dependency lines: run-tests.sh's get_app_deps (e.g. `console) echo "player playerVm"`) is
# what check_services health-checks, besides the suite's own UI/API, before running that
# suite: the suite's tests drive those apps too (console specs open VM consoles through
# Player and Vm.Api; gameboard specs deploy TopoMojo challenges). So a change that affects
# suite S can break any suite that lists S as a dependency, and transitively
# (player -> playerVm -> console). Add those dependent suites until nothing changes.
if ((${#suites[@]})); then
  changed=1
  while ((changed)); do
    changed=0
    for app in "${!suite_deps[@]}"; do
      [[ -n ${suites[$app]:-} ]] && continue
      for d in ${suite_deps[$app]}; do
        if [[ -n ${suites[$d]:-} ]]; then add_suite "$app" "depends on $d (run-tests.sh get_app_deps)"; changed=1; break; fi
      done
    done
  done
fi

if ((${#suites[@]})); then
  ordered=""
  for s in $all_suites; do [[ -n ${suites[$s]:-} ]] && ordered+=" $s"; done
  echo "suites=${ordered# }"
  for s in $ordered; do echo "suites_via=$s: ${via[$s]}"; done
elif ((found)); then
  echo "suites=none reason=served by the AppHost, but no resource's port matches a run-tests.sh suite UI port (no e2e suite covers it)"
else
  echo "suites=none reason=not served by the AppHost: no resource in Crucible.AppHost/*.cs runs, builds or mounts this clone${t_group:+ (group $t_group)}"
fi

for n in "${notes[@]}"; do echo "note=$n"; done
for w in "${warnings[@]}"; do echo "warning=$w"; done
exit 0
