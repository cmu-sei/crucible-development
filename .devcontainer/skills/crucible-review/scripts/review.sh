#!/usr/bin/env bash
# Run or resume one independent reviewer (a profile from reviewers.json) and save its structured findings.
#
#   review.sh run <profile> <lens> <repo> <base>..<head>|uncommitted <task-file> [out-dir]
#   review.sh resume <run-dir> <prompt-file>
#
# <profile> is a key in reviewers.json, or an inline <cli>:<model>:<effort> (e.g. codex:us.openai.gpt-6-astra:medium).
# <lens> is a file in references/lenses (without .md).
# Prints the run directory on success. Exits non-zero when the review is incomplete
# (CLI failed, or no valid structured output): an incomplete review is never a clean one.
# Sessions are kept on disk (no --ephemeral / --no-session-persistence) so usage tools see their cost.
set -euo pipefail

SKILL_DIR=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
# Each lens can have its own output schema (assets/<lens>.schema.json); the rest use review.schema.json.
schema_for() { local f="$SKILL_DIR/assets/$1.schema.json"; [[ -f $f ]] || f="$SKILL_DIR/assets/review.schema.json"; echo "$f"; }
SCHEMA=""
CLAUDE_TOOLS=(Read Grep Glob "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git status:*)" "Bash(git merge-base:*)")

die() { echo "review.sh: $*" >&2; exit 2; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Runs the CLI for a fresh run or a resume. Args: cli model effort repo prompt out-dir [session-id-to-resume]
invoke() {
  local cli=$1 model=$2 effort=$3 repo=$4 prompt=$5 out=$6 resume=${7:-}
  local rc=0 sid=""
  case $cli in
    codex)
      if [[ -z $resume ]]; then
        (cd "$repo" && codex exec -C "$repo" -m "$model" -c model_reasoning_effort="$effort" --json \
          --output-schema "$SCHEMA" -o "$out/findings.json" - <"$prompt" >"$out/events.jsonl" 2>"$out/stderr.log") || rc=$?
      else
        # codex exec resume has no -C: run from the repo, global flags before the subcommand.
        (cd "$repo" && codex exec -m "$model" -c model_reasoning_effort="$effort" --json resume "$resume" \
          --output-schema "$SCHEMA" -o "$out/findings.json" - <"$prompt" >"$out/events.jsonl" 2>"$out/stderr.log") || rc=$?
      fi
      sid=$(grep '^{' "$out/events.jsonl" 2>/dev/null | jq -r 'select(.type=="thread.started") | .thread_id' | head -1)
      [[ -z $sid ]] && sid=$resume
      ;;
    claude)
      local session_args
      if [[ -z $resume ]]; then sid=$(cat /proc/sys/kernel/random/uuid); session_args=(--session-id "$sid")
      else sid=$resume; session_args=(--resume "$resume"); fi
      # A /code-review run keeps its context in context.md, and each re-check gets a copy.
      # A resumed session doesn't keep an appended system prompt, so every turn passes it again.
      local ctx=()
      [[ -f $out/context.md ]] && ctx=(--append-system-prompt "$(cat "$out/context.md")")
      if [[ -z $resume && -f $out/context.md ]]; then
        # Code review through Claude Code's built-in /code-review, with the task as context.
        # It answers in its own format, so a second turn in the same session returns our schema.
        (cd "$repo" && claude -p "${session_args[@]}" --model "$model" --effort "$effort" --output-format stream-json --verbose \
          "${ctx[@]}" --allowedTools "${CLAUDE_TOOLS[@]}" \
          <"$prompt" >"$out/code-review.jsonl" 2>"$out/stderr.log") || rc=$?
        if ! jq -s -e 'any(.[]; .type == "system" and .subtype == "init" and (.slash_commands | index("code-review")))' \
            "$out/code-review.jsonl" >/dev/null 2>&1; then
          echo "review.sh: this Claude Code has no /code-review; update Claude Code" >>"$out/stderr.log"; [[ $rc -ne 0 ]] || rc=3
        fi
        session_args=(--resume "$sid")
        prompt="$out/to-schema.md"
        printf 'Return every finding from your review above in the provided JSON schema, one entry per finding, keeping your wording. Give each an id (F1, F2, ...), a severity (blocker, major, minor, nit), a category, and the fix in suggestion. Include anything you mentioned as optional, a follow-up or a nice-to-have, as a minor or nit finding. Put a one-sentence overall verdict in summary.\n' >"$prompt"
      fi
      if [[ $rc -eq 0 ]]; then
        (cd "$repo" && claude -p "${session_args[@]}" --model "$model" --effort "$effort" \
          --output-format json --json-schema "$(cat "$SCHEMA")" "${ctx[@]}" --allowedTools "${CLAUDE_TOOLS[@]}" \
          <"$prompt" >"$out/result.json" 2>>"$out/stderr.log") || rc=$?
      fi
      jq '.structured_output // empty' "$out/result.json" >"$out/findings.json" 2>/dev/null || true
      ;;
    *) die "unknown cli '$cli'" ;;
  esac
  local status=complete
  # Complete = exit 0 and output with the shape the pass needs (keys present and the right types).
  if [[ $rc -ne 0 ]] || ! jq -e --slurpfile s "$SCHEMA" '. as $o | type == "object"
        and all($s[0].required[]; . as $k | $o | has($k))
        and (if has("findings") then (.findings | type == "array") and all(.findings[]; type == "object" and (.id | type == "string")) else true end)
        and (if has("tier") then (.tier | IN("low", "medium", "high")) and (.categories | type == "object") else true end)' \
        "$out/findings.json" >/dev/null 2>&1; then
    status=incomplete
  fi
  echo "$sid $status $rc"
}

cmd=${1:-}; shift || true
case $cmd in
  run)
    [[ $# -ge 5 ]] || die "usage: review.sh run <profile> <lens> <repo> <base>..<head>|uncommitted <task-file> [out-dir]"
    profile=$1 lens=$2 repo=$(cd "$3" && pwd) range=$4 task=$5 out=${6:-}
    lens_file="$SKILL_DIR/references/lenses/$lens.md"
    [[ -f $lens_file ]] || die "no lens '$lens'"
    [[ -f $task ]] || die "no task file '$task'"
    SCHEMA=$(schema_for "$lens")
    if [[ $profile == *:*:* ]]; then
      cli=${profile%%:*} effort=${profile##*:} model=${profile#*:} model=${model%:*}
      [[ $cli == codex || $cli == claude ]] || die "no adapter for CLI '$cli'"
      profile="$cli-$model-$effort"
    else
      read -r cli model effort < <(jq -r --arg p "$profile" '.profiles[$p] | select(.) | "\(.cli) \(.model) \(.effort)"' "$SKILL_DIR/reviewers.json") || true
      [[ -n ${cli:-} ]] || die "no profile '$profile' in reviewers.json"
    fi

    if [[ $range == uncommitted ]]; then
      scope="the uncommitted changes in the working tree: \`git diff HEAD\` plus any untracked files (\`git status --porcelain\`)"
      head_sha=$(git -C "$repo" rev-parse HEAD)
    else
      base=${range%%..*} head=${range##*..}
      mb=$(git -C "$repo" merge-base "$base" "$head") || die "can't find a merge base for $range"
      head_sha=$(git -C "$repo" rev-parse "$head")
      scope="\`git diff $mb..$head_sha\` (commits: \`git log $mb..$head_sha\`)"
      range="$mb..$head_sha"
    fi

    if [[ -z $out ]]; then
      gp=$(cd "$repo" && git rev-parse --git-path crucible-review)
      [[ $gp = /* ]] || gp="$repo/$gp"
      out="$gp/$(date -u +%Y%m%dT%H%M%SZ)-$profile-$lens"
    fi
    mkdir -p "$out"; out=$(cd "$out" && pwd)

    if [[ $cli == claude && $lens == review && $range != uncommitted ]]; then
      # Claude Code's built-in /code-review finds more than a single pass with the review lens.
      printf '/code-review %s %s\n' "$effort" "$range" >"$out/prompt.md"
      { printf '## The task this change is for\n\n'; cat "$task"; printf '\n\n'
        cat "$SKILL_DIR/references/lenses/code-review-context.md"
        printf '\n## Rules\n\n- Don'\''t modify files, commit, push, or open a browser.\n'; } >"$out/context.md"
    else {
      sed "s|{{MERGE_RISK_SKILL}}|$SKILL_DIR/../crucible-merge-risk/SKILL.md|g" "$lens_file"
      printf '\n## The change\n\nRepository: `%s`\n\nReview %s. Read the surrounding code as needed.\n' "$repo" "$scope"
      printf '\n## The task\n\n'; cat "$task"
      printf '\n\n## Rules\n\n- Don'\''t modify files, commit, push, or open a browser.\n- Return your result as JSON matching the provided schema.\n'
    } >"$out/prompt.md"; fi

    started=$(now)
    read -r sid status rc < <(invoke "$cli" "$model" "$effort" "$repo" "$out/prompt.md" "$out")
    jq -n --arg profile "$profile" --arg cli "$cli" --arg model "$model" --arg effort "$effort" --arg lens "$lens" \
      --arg repo "$repo" --arg range "$range" --arg head "$head_sha" --arg sid "$sid" --arg status "$status" --argjson rc "$rc" \
      --arg started "$started" --arg finished "$(now)" \
      '{profile:$profile, cli:$cli, model:$model, effort:$effort, lens:$lens, repo:$repo, range:$range, head:$head,
        session_id:$sid, status:$status, exit_code:$rc, started:$started, finished:$finished}' >"$out/meta.json"
    echo "$out"
    [[ $status == complete ]] || { echo "review.sh: incomplete review, see $out/stderr.log" >&2; exit 1; }
    ;;

  resume)
    [[ $# -eq 2 ]] || die "usage: review.sh resume <run-dir> <prompt-file>"
    run=$(cd "$1" && pwd) prompt=$2
    [[ -f $run/meta.json ]] || die "no meta.json in $run"
    read -r cli model effort repo sid lens < <(jq -r '"\(.cli) \(.model) \(.effort) \(.repo) \(.session_id) \(.lens)"' "$run/meta.json")
    SCHEMA=$(schema_for "$lens")
    n=1; while [[ -d $run/recheck-$n ]]; do n=$((n + 1)); done
    out="$run/recheck-$n"; mkdir -p "$out"
    if [[ -f $run/context.md ]]; then cp "$run/context.md" "$out/"; fi
    head=$(git -C "$repo" rev-parse HEAD)
    { cat "$prompt"
      jq -r --arg h "$head" 'if (.range | contains("..")) then "\n\nThe change is now `git diff \(.range | split("..")[0])..\($h)`." else "" end' "$run/meta.json"
    } >"$out/prompt.md"
    started=$(now)
    read -r _ status rc < <(invoke "$cli" "$model" "$effort" "$repo" "$out/prompt.md" "$out" "$sid")
    jq --arg status "$status" --argjson rc "$rc" --arg started "$started" --arg finished "$(now)" --arg head "$head" \
      '. + {status:$status, exit_code:$rc, started:$started, finished:$finished, head:$head}
         | if (.range | contains("..")) then .range = ((.range | split("..")[0]) + ".." + $head) else . end' \
      "$run/meta.json" >"$out/meta.json"
    echo "$out"
    [[ $status == complete ]] || { echo "review.sh: incomplete re-check, see $out/stderr.log" >&2; exit 1; }
    ;;

  *) die "usage: review.sh run|resume ..." ;;
esac
