#!/usr/bin/env python3
"""PreToolUse gate for agent-created PRs (Claude Code and Codex CLI).

Reads the hook's JSON on stdin. For `gh pr create`/`gh pr new`, `gh stack submit` and
`gh stack link`, prints a deny decision unless the PR went through the crucible-pr skill.
Draft or ready is the user's choice, so it isn't checked.
Anything else gets no output, so the normal permission flow applies.

The hook command in the devcontainer config only calls this for commands that look like
those, and turns any failure of this script into a deny, so a broken gate fails closed.
"""
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

RECORD_SH = Path(__file__).resolve().with_name("record.sh")
SKILL_HINT = "Use the crucible-pr skill to review the change and open the PR."
OVERRIDE_HINT = (
    "If the user wants to open it without the review, give them the exact command to run "
    "in their own terminal, where this gate doesn't apply."
)
SEPARATORS = {"&&", "||", ";", "|", "&", "\n"}
AGENT_TRAILER = re.compile(r"^co-authored-by:.*(claude|anthropic|codex|openai|copilot)", re.I | re.M)
REQUIRED_SECTIONS = {
    "Summary": re.compile(r"^##\s*Summary\b", re.M | re.I),
    "User-facing changes": re.compile(r"^##\s*User[- ]facing changes\b", re.M | re.I),
    "Risk & review": re.compile(r"<summary>\s*Risk & review\b", re.I),
    "Technical details": re.compile(r"<summary>\s*Technical details\s*</summary>", re.I),
}


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": f"crucible-pr gate: {reason}",
    }}))
    sys.exit(0)


HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
# A gh PR or stack command at a command position (not just mentioned inside text).
GH_COMMAND = re.compile(
    r"(^|[;&|(`]|\$\()\s*([A-Za-z_][A-Za-z0-9_]*=\S*\s+)*(\S*/)?gh(\s+-{1,2}\S+(\s+[^-\s]\S*)?)*"
    r"\s+(pr\s+(create|new)|stack\s+(submit|link))\b", re.M)


def strip_heredocs(command: str) -> str:
    """Drop heredoc bodies: they're file content, not commands."""
    lines, out, ends = command.split("\n"), [], []
    for line in lines:
        if ends:
            if line.strip() == ends[0]:
                ends.pop(0)
            continue
        out.append(line)
        ends.extend(m.group(2) for m in HEREDOC.finditer(line))
    return "\n".join(out)


def segments(command: str):
    """Split a shell command into simple commands, tracking `cd` so we know each one's directory."""
    command = command.replace("\\\n", " ")  # line continuations
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    current = []
    for tok in lexer:
        if tok in SEPARATORS:
            if current:
                yield current
            current = []
        else:
            current.append(tok)
    if current:
        yield current


def gh_args(words):
    """Return gh's arguments if this simple command runs gh (after env assignments), else None."""
    i = 0
    while i < len(words) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[i]):
        i += 1
    if i < len(words) and os.path.basename(words[i]) == "gh":
        return words[i + 1:]
    return None


ALIASES = {"-R": "--repo", "-B": "--base", "-H": "--head", "-F": "--body-file", "-t": "--title", "-b": "--body"}
VALUE_OPTIONS = set(ALIASES) | set(ALIASES.values())


def options(args):
    """Values of gh pr create's value options, handling --opt=value and short forms."""
    found = {}
    i = 0
    while i < len(args):
        key, _, val = args[i].partition("=")
        if key in VALUE_OPTIONS:
            if val:
                found[ALIASES.get(key, key)] = val
            elif i + 1 < len(args):
                found[ALIASES.get(key, key)] = args[i + 1]
                i += 1
        i += 1
    return found


def git(cwd, *args):
    return subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, check=True).stdout.strip()


def check_pr_create(args, cwd):
    opts = options(args)
    missing = [f for f in ("--repo", "--base", "--head", "--body-file") if f not in opts]
    if missing:
        deny(f"gh pr create needs {', '.join(missing)}. {SKILL_HINT}")

    repo, base, body_file = opts["--repo"], opts["--base"], opts["--body-file"]
    head = opts["--head"].split(":", 1)[-1]
    body_path = Path(cwd, body_file).expanduser()
    if not body_path.is_file():
        deny(f"body file {body_file} not found.")
    body = body_path.read_text()

    try:
        branch = git(cwd, "symbolic-ref", "--short", "-q", "HEAD")
    except subprocess.CalledProcessError:
        deny(f"run gh pr create from a checkout of {head}.")
    if branch != head:
        deny(f"the checkout in {cwd} is on {branch}, not {head}. Run it from the {head} checkout.")

    git_path = git(cwd, "rev-parse", "--git-path", f"crucible-pr/{quote(head, safe='')}.json")
    record_path = Path(cwd, git_path)
    if not record_path.is_file():
        deny(f"no review record for {head}. {SKILL_HINT}")
    record = json.loads(record_path.read_text())
    if record.get("repo", "").lower() != repo.lower():
        deny(f"the review record is for {record.get('repo')}, not {repo}.")
    if record.get("base") != base:
        deny(f"the review record's base is {record.get('base')}, not {base}.")

    result = subprocess.run([str(RECORD_SH), "check"], cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        problems = "; ".join(result.stderr.strip().splitlines())
        deny(f"the review record isn't complete: {problems}. {SKILL_HINT}")

    head_sha = git(cwd, "rev-parse", "HEAD")
    marker = re.search(r"<!-- crucible-pr: head=([0-9a-f]{40}) -->", body)
    if not marker or marker.group(1) != head_sha:
        deny("the body's crucible-pr marker doesn't match HEAD. Regenerate it with record.sh summary.")
    absent = [name for name, pattern in REQUIRED_SECTIONS.items() if not pattern.search(body)]
    if absent:
        deny(f"the body is missing: {', '.join(absent)}. Follow the crucible-pr template.")

    merge_base = record["final"]["merge_base"]
    messages = git(cwd, "log", "--format=%B", f"{merge_base}..{head_sha}")
    if AGENT_TRAILER.search(messages):
        deny("a commit on this branch has an agent Co-Authored-By trailer. Ask the user how to remove it.")


def check_stack(args):
    sub = args[0] if args else ""
    if sub == "submit":
        deny("gh stack submit can open unreviewed PRs. Open each layer with the crucible-pr skill, "
             "then link them with gh stack link <pr> <pr> ... using PR numbers.")
    if sub == "link":
        targets = [a for a in args[1:] if not a.startswith("-")]
        bad = [t for t in targets if not re.fullmatch(r"\d+|https://github\.com/[^/]+/[^/]+/pull/\d+", t)]
        if bad:
            deny(f"gh stack link creates a PR for a branch name ({', '.join(bad)}). "
                 "Open that layer with the crucible-pr skill first, then link it by PR number.")


def main():
    event = json.load(sys.stdin)
    command = (event.get("tool_input") or {}).get("command") or ""
    cwd = event.get("cwd") or os.getcwd()
    command = strip_heredocs(command)
    try:
        for words in segments(command):
            if words[0] == "cd" and len(words) > 1:
                cwd = str(Path(cwd, os.path.expanduser(words[1])).resolve())
                continue
            args = gh_args(words)
            if args is None:
                continue
            # Skip gh's own global flags (-R/--repo before the subcommand).
            rest = list(args)
            global_repo = None
            while rest and rest[0].startswith("-"):
                flag = rest.pop(0)
                if flag in ("-R", "--repo") and rest:
                    global_repo = rest.pop(0)
            if rest[:2] in (["pr", "create"], ["pr", "new"]):
                sub_args = rest[2:] + (["--repo", global_repo] if global_repo else [])
                check_pr_create(sub_args, cwd)
            elif rest[:1] == ["stack"]:
                check_stack(rest[1:])
    except SystemExit:
        raise
    except ValueError as err:
        # Unparsable (e.g. an unbalanced quote in text). Only a real gh command needs a decision.
        if GH_COMMAND.search(command):
            deny(f"couldn't parse the command ({err}). Run gh pr create as a plain command.")
    except Exception as err:  # fail closed
        deny(f"the gate failed ({type(err).__name__}: {err}). {OVERRIDE_HINT}")


if __name__ == "__main__":
    main()
