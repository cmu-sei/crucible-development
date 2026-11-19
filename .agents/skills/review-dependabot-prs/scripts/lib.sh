#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Shared helpers for the review-dependabot-prs scripts. Source it; don't run it.

# GHR_DELAYS: seconds to wait before each retry of a transient gh failure. The default makes 6
# attempts over about a minute (GitHub sometimes refuses connections for 20s or more). Tests can
# set e.g. GHR_DELAYS="0 0".

# gh_transient MESSAGE: is this gh error worth retrying (network, 5xx, rate limit)?
# Not found, permission and validation errors are not: retrying them only hides them.
gh_transient() {
  local msg=${1,,}
  [[ "$msg" =~ rate\ limit|abuse\ detection|http\ 408|http\ 429 ]] && return 0
  [[ "$msg" =~ http\ 40[0-9]|not\ found|could\ not\ resolve\ to|no\ pull\ requests\ found|permission|must\ have|resource\ not\ accessible|forbidden|unauthorized|bad\ credentials ]] && return 1
  [[ "$msg" =~ connection\ refused|connection\ reset|reset\ by\ peer|eof|timeout|timed\ out|tls\ handshake|no\ such\ host|network\ is\ unreachable|temporary\ failure|broken\ pipe|goaway|stream\ error|server\ closed|http\ 5[0-9][0-9]|bad\ gateway|service\ unavailable|gateway\ time|something\ went\ wrong|internal\ server\ error ]]
}

# ghr ARGS...: gh with retries of transient failures (see GHR_DELAYS and gh_transient). Prints
# gh's stdout on success. On failure, prints gh's error on stderr and returns gh's exit code.
ghr() {
  local out rc err i delays
  read -r -a delays <<<"${GHR_DELAYS:-2 4 8 15 30}"
  err=$(mktemp) || return 1
  for ((i = 0; ; i++)); do
    out=$(gh "$@" 2>"$err"); rc=$?
    if ((rc == 0)); then
      cat "$err" >&2; rm -f "$err"; printf '%s' "$out"; return 0
    fi
    if ((i >= ${#delays[@]})) || ! gh_transient "$(<"$err")"; then
      ((i > 0)) && printf 'gh %s: failed after %d attempts:\n' "$1 ${2:-}" "$((i + 1))" >&2
      cat "$err" >&2; rm -f "$err"; return "$rc"
    fi
    sleep "${delays[i]}"
  done
}

# gh_required_checks N REPO: prints the PR's required checks as a JSON array of {name, bucket}.
# "[]" (exit 0) only when gh says none are reported. gh exits non-zero with valid JSON when
# checks fail or are pending; that's still a result. Transport errors are retried like ghr, then
# return 1 with the error on stderr: never mistake a failed lookup for "no required checks".
gh_required_checks() {
  local n=$1 repo=$2 out rc err i msg delays
  read -r -a delays <<<"${GHR_DELAYS:-2 4 8 15 30}"
  err=$(mktemp) || return 1
  for ((i = 0; ; i++)); do
    out=$(gh pr checks "$n" -R "$repo" --required --json name,bucket 2>"$err"); rc=$?
    msg=$(<"$err")
    if [[ -n "$out" ]] && jq -e 'type == "array"' >/dev/null 2>&1 <<<"$out"; then
      rm -f "$err"; printf '%s\n' "$out"; return 0
    fi
    if [[ "$msg" =~ no\ (required\ )?checks\ reported ]]; then rm -f "$err"; echo "[]"; return 0; fi
    if ((i >= ${#delays[@]})) || ! gh_transient "$msg"; then
      ((i > 0)) && printf 'gh pr checks: failed after %d attempts:\n' "$((i + 1))" >&2
      printf '%s\n' "${msg:-gh pr checks exited $rc with no output}" >&2; rm -f "$err"; return 1
    fi
    sleep "${delays[i]}"
  done
}

# diff_version_pairs < DIFF: prints "name<TAB>from<TAB>to" for each version a unified diff
# changes: npm lockfile entries ("node_modules/x" blocks, one line per installed copy),
# package.json-style "name": "version" lines, and MSBuild PackageReference/PackageVersion.
# Range prefixes (^ ~ >= v) are dropped. Used to fill versions the PR text truncates.
diff_version_pairs() {
  perl -ne '
    our ($file, $lock, $pkg, %m, %p, %name, @order);
    sub rec { my ($sign, $key, $ver, $nm) = @_;
      push @order, $key unless exists $m{$key} || exists $p{$key};
      $name{$key} = $nm; if ($sign eq "-") { $m{$key} = $ver } else { $p{$key} = $ver } }
    sub flush { my %seen;
      for my $k (@order) { next unless exists $m{$k} && exists $p{$k} && $m{$k} ne $p{$k};
        my $l = "$name{$k}\t$m{$k}\t$p{$k}"; print "$l\n" unless $seen{$l}++ }
      %m = (); %p = (); %name = (); @order = () }
    chomp;
    if (m{^diff --git \S+ b/(\S+)}) { flush(); $file = $1; $lock = $file =~ m{(^|/)(package-lock\.json|npm-shrinkwrap\.json)$}; $pkg = ""; next }
    next if /^(\+\+\+|---) /;
    if ($lock) {
      if (/^[ +-]\s*"([^"]*node_modules\/([^"]+))": \{/) { $pkg = $1; $name{$pkg} = $2; next }
      rec($1, $pkg, $2, $name{$pkg}) if $pkg ne "" && /^([-+])\s*"version": "([^"]+)"/;
      next;
    }
    if (/^([-+])\s*"(\@?[A-Za-z0-9][^"\s]*)": "[\^~>=<v ]*(\d[^"\s]*)"/) { rec($1, "$file:$2", $3, $2) }
    elsif (/^([-+]).*<Package(?:Reference|Version)\b[^>]*\bInclude="([^"]+)"[^>]*\bVersion="\[?([^"\],]+)/i) { rec($1, "$file:$2", $3, $2) }
    elsif (/^([-+]).*<Package(?:Reference|Version)\b[^>]*\bVersion="\[?([^"\],]+)[^>]*\bInclude="([^"]+)"/i) { rec($1, "$file:$3", $2, $3) }
    END { flush() }'
}

# deps_json [DIFF_FILE]: reads `gh pr view --json body,commits` JSON on stdin and prints a JSON
# array of {name, from, to, type, update, source, via, conflict}, one entry per distinct
# (name, from, to) change:
#   - from/to come from the PR text: the body and the first commit's message, both the
#     "Bumps/Updates/Updated X from A to B" lines and the group table (| Package | From | To |),
#     which Dependabot keeps when it truncates the per-package lines; "Bumps X to A, B" and
#     "Pinned X at A" give a version with no from.
#   - name/to/type/update also come from the commit's `updated-dependencies` block.
#   - DIFF_FILE (optional, `gh pr diff` output) fills a missing from by matching the to
#     version, corroborates pairs, and flags metadata-only names the diff never mentions.
#   - via: which of "PR text", "commit metadata", "diff" support the pair.
#   - conflict: null, or why this name's entries need a look: the sources disagree (e.g. the
#     metadata names a version the PR text doesn't), or the PR has several pairs for the name
#     (one per project or nested copy). Every pair is kept; none is invented.
#   - source: the GitHub repo (owner/name) the body links for the dependency, if any.
deps_json() {
  local diff='[]' difffile=/dev/null hasdiff=false
  if [[ -n "${1:-}" && -r "$1" ]]; then
    diff=$(diff_version_pairs <"$1" | jq -R 'split("\t") | {name: .[0], from: .[1], to: .[2]}' | jq -s .)
    difffile=$1 hasdiff=true
  fi
  jq --argjson diff "${diff:-[]}" --argjson hasdiff "$hasdiff" --rawfile difftext "$difffile" '
    def unq: gsub("^[\"\u0027]|[\"\u0027]$"; "");
    def clean: if . == null then null else gsub("^[`\\s]+|[`\\s.,;:)]+$"; "") | if . == "" then null else . end end;
    def nm: .[0] // .[1] // .[2];
    def NAME: "(?:`([^`]+)`|\\[([^\\]]+)\\]\\([^)]*\\)|([^\\s\\[`|]+))";
    (.body // "") as $body
    | ([.commits[0]? // {} | (.messageHeadline // ""), (.messageBody // "")] | join("\n")) as $commit
    | ($body + "\n" + $commit) as $text
    | ([$text | scan("(?m)^(?:Updates|Updated|Bumps|Bump) " + NAME + " from (\\S+) to (\\S+)")
          | {name: (.[0:3] | nm), from: (.[3] | clean), to: (.[4] | clean)}]
       + [$text | scan("(?m)^\\| *" + NAME + " *\\| *`?([^`|\\s]*)`? *\\| *`?([^`|\\s]*)`? *\\| *$")
          | {name: (.[0:3] | nm), from: (.[3] | clean), to: (.[4] | clean)}
          | select(.name != "Package" and (.name | test("^[-:]+$") | not))]
       + [$text | scan("(?m)^(?:Updates|Updated|Bumps|Bump) " + NAME + " to ([0-9vV][^\\s,]*(?:, [0-9vV][^\\s,]*)*)")
          | (.[0:3] | nm) as $n | .[3] | split(", ")[] | {name: $n, from: null, to: clean}]
       + [$text | scan("(?m)^Pinned " + NAME + " at (\\S+)") | {name: (.[0:3] | nm), from: null, to: (.[3] | clean)}]
      ) as $P
    | ([$body | scan("\\[([^\\]]+)\\]\\(https://github\\.com/([^/)\\s]+/[^/)#\\s]+)")
        | {name: .[0], source: .[1]}]
       + [$body | scan("href=\"https://github\\.com/([^/\"]+/[^/\"]+)/[^\"]*\">([^<]+)\u0027s (?:releases|changelog)")
        | {name: (.[1] | gsub("\u200b"; "")), source: .[0]}]) as $links
    | ((.commits[0].messageBody // "") | [splits("\n")]
        | reduce .[] as $l ([];
            if ($l | test("^- dependency-name: ")) then . + [{name: ($l | sub("^- dependency-name: "; "") | unq)}]
            elif length == 0 then .
            elif ($l | test("^  dependency-version:")) then .[-1].to = ($l | sub("^  dependency-version: ?"; "") | unq | clean)
            elif ($l | test("^  dependency-type:")) then .[-1].type = ($l | sub("^  dependency-type: ?"; ""))
            elif ($l | test("^  update-type:")) then .[-1].update = ($l | sub("^  update-type: ?"; ""))
            else . end)) as $M
    | (if ($M | length) > 0 then [$M[].name] else [$P[].name] end | reduce .[] as $n ([]; if index([$n]) then . else . + [$n] end)) as $names
    | [ $names[] as $n
        | ($P | map(select(.name == $n))) as $ps
        | ($M | map(select(.name == $n))) as $ms
        | ($diff | map(select(.name == $n))) as $ds
        # PR-text pairs; a to-only pair is dropped when another pair has that to with a from.
        | ($ps | map({from, to}) | unique) as $pp
        | ($pp | map(select(.from != null or (.to as $t | $pp | any(.from != null and .to == $t) | not)))) as $pp
        | [$pp[] | . + {via: ["PR text"]}] as $c
        # Metadata versions the PR text does not mention.
        | ($c + [$ms[] | select(.to != null) | .to as $t | select($pp | any(.to == $t) | not)
                 | {from: null, to: $t, via: ["commit metadata"]}] | unique_by([.from, .to])) as $c
        | (if ($c | length) == 0 then [{from: null, to: null, via: ["commit metadata"]}] else $c end) as $c
        # Mark metadata support; fill a missing from from the diff; mark diff support.
        | [$c[] | . as $e
            | (if ($e.via | index("commit metadata")) == null and ($ms | any(.to == $e.to and $e.to != null))
               then .via += ["commit metadata"] else . end)
            | if .from == null and .to != null and ($ds | any(.to == $e.to)) then
                ([$ds[] | select(.to == $e.to) | .from] | unique) as $fs | . as $x | $fs[] | $x + {from: ., via: ($x.via + ["diff"])}
              elif ($ds | any(.from == $e.from and .to == $e.to)) then .via += ["diff"]
              else . end] as $c
        | ($c | sort_by(if (.via | index("PR text")) != null then 0 else 1 end)) as $c
        # Dependabot rebuilds PRs without always refreshing the commit metadata. When the PR text and
        # the diff agree on a pair, a metadata-only version is stale: drop it and note it, rather
        # than doubling the entry and calling it a conflict.
        | ([$c[] | select(.via == ["commit metadata"]) | .to]) as $stale
        | (($c | any((.via | index("PR text")) != null and (.via | index("diff")) != null)) and ($stale | length) > 0) as $isstale
        | (if $isstale then [$c[] | select(.via != ["commit metadata"])] else $c end) as $c
        | ([$c[] | select(($ds | length) > 0 and (.via | index("diff")) == null) | "\(.from // "?") -> \(.to)"] | join(", ")) as $notdiff
        | ($c | map(.via | index("PR text") != null) | any) as $hastext
        | ([$c[] | select(.via | index("diff") != null) | "\(.from // "?") -> \(.to)"] | join(", ")) as $indiff
        | (if $isstale and ($c | length) == 1 then null
           elif ($c | length) > 1 and $hastext and ($c | any(.via == ["commit metadata"]))
           then "sources disagree: the commit metadata names \([$c[] | select(.via == ["commit metadata"]) | .to] | join(", ")), the PR text does not; "
                + (if $indiff != "" then "the diff has \($indiff)" else "check the diff" end)
           elif ($c | length) > 1 and $notdiff != "" then "\($c | length) version pairs for \($n); not in the diff: \($notdiff)"
           elif $hasdiff and ($c | length) == 1 and $c[0].via == ["commit metadata"] and $c[0].to != null
                and ($difftext | index($n)) == null
           then "only the commit metadata lists \($n); neither the PR text nor the diff mentions it"
           else null end) as $conflict
        | ($links | map(select(.name == $n)) | first) as $s
        | $c[] | . as $e
        | ($ms | map(select(.to == $e.to)) | first // ($ms | first) // {}) as $m
        | {name: $n, from, to, type: ($m.type // null), update: ($m.update // null),
           source: ($s.source // null | if . then sub("\\.git$"; "") else . end),
           via, conflict: $conflict,
           note: (if $isstale then "commit metadata is stale (names \($stale | join(", "))); PR text and diff agree"
                  elif ($c | length) > 1 and $conflict == null then "\($c | length) version pairs for \($n) (one per project or installed copy); each is shown"
                  else null end)}
      ]
  '
}

# jq function definitions shared by the scripts (prepend to a jq program).
JQ_DELTA='
  def nums: [scan("[0-9]+") | tonumber] + [0,0,0] | .[0:3];
  def delta($f; $t):
    if ($t // "") == "" then "removed"
    elif ($f // "") == "" then "?"
    else ($f | nums) as $a | ($t | nums) as $b
      | if $a == $b then "same"
        elif $a[0] != $b[0] then "MAJOR"
        elif $a[0] == 0 and $a[1] != $b[1] then "MAJOR (0.x minor)"
        elif $a[1] != $b[1] then "minor"
        else "patch" end
    end;
'

# Platforms: frameworks, runtimes and servers whose major upgrades are planned projects, not
# Dependabot merges (see SKILL.md "Platform upgrades"). Matched against dependency names
# (Oniguruma regex, used by jq). Minor and patch bumps of these stay in scope.
# typescript and zone.js are not platforms by name: a bump of either needs a planned upgrade
# only when the new version is outside the repo's @angular/core peer range (angular_peer below).
PLATFORM_RE='^(@angular/|@angular-devkit/|@angular-eslint/|@schematics/angular$'\
'|Microsoft\.AspNetCore\.|Microsoft\.EntityFrameworkCore|Microsoft\.Extensions\.|Microsoft\.NET\.|System\.(?!IdentityModel)|Npgsql\.EntityFrameworkCore\.PostgreSQL$'\
'|Aspire\.|@aspire/'\
'|dotnet/(sdk|aspnet|runtime|runtime-deps)$|node$|postgres$|keycloak/keycloak$|quay\.io/keycloak/keycloak$|golang$|go$)'
export PLATFORM_RE

# jq: platform_major(name; delta) is true for a major bump of a platform package.
# angular_peer(name; delta) is true for a non-patch typescript or zone.js bump, whose new version
# must be checked against @angular/core's peerDependencies for the repo's Angular version.
JQ_PLATFORM='
  def platform_major($name; $delta): ($delta | startswith("MAJOR")) and ($name | test($ENV.PLATFORM_RE));
  def angular_peer($name; $delta): ($name | test("^(typescript|zone\\.js)$")) and ($delta != "patch" and $delta != "same" and $delta != "removed");
'
