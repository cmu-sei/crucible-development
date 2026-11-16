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
SEPARATORS = {"&&", "||", ";", "|", "&", "\n", "(", ")"}
# Words that can come before the real command: shell keywords and command wrappers.
PREFIXES = {"if", "then", "else", "elif", "do", "while", "until", "!", "{", "}", "time", "exec",
            "command", "builtin", "nohup", "nice", "sudo", "xargs"}
SHELLS = {"bash", "sh", "zsh", "dash"}
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
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|\n()")
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


def command_words(words):
    """The words of the real command, after env assignments, shell keywords and wrappers."""
    i = 0
    while i < len(words):
        w = words[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w) or w in PREFIXES or w.startswith("-") and i > 0 and words[i - 1] in ("env", "timeout", "nice", "sudo", "xargs"):
            i += 1
        elif w == "env":
            i += 1
        elif w == "timeout":
            i += 1
            while i < len(words) and words[i].startswith("-"):
                i += 1
            i += 1  # the duration
        else:
            break
    return words[i:]


def shell_script(words):
    """The script of `bash -c '...'` (or sh/zsh, including -lc), else None."""
    if words and os.path.basename(words[0]) in SHELLS:
        for j, w in enumerate(words[1:], 1):
            if w.startswith("-") and "c" in w[1:] and j + 1 < len(words):
                return words[j + 1]
    return None


def gh_args(words):
    """Return gh's arguments if this simple command runs gh, else None."""
    if words and os.path.basename(words[0]) == "gh":
        return words[1:]
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

    # gh opens the PR from the pushed branch, which must be the commit that was reviewed.
    try:
        remote = subprocess.run(["git", "ls-remote", f"https://github.com/{repo}.git", f"refs/heads/{head}"],
                                capture_output=True, text=True, timeout=30).stdout.split()
    except subprocess.TimeoutExpired:
        remote = []
    if remote and remote[0] != head_sha:
        deny(f"the pushed {head} is at {remote[0][:7]}, not the reviewed HEAD {head_sha[:7]}. Push it first.")


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


def check_command(command, cwd, depth=0):
    for words in segments(command):
        words = command_words(words)
        if not words:
            continue
        if words[0] == "cd" and len(words) > 1:
            cwd = str(Path(cwd, os.path.expanduser(words[1])).resolve())
            continue
        script = shell_script(words)
        if script is not None and depth < 3:
            check_command(strip_heredocs(script), cwd, depth + 1)
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


def main():
    event = json.load(sys.stdin)
    command = (event.get("tool_input") or {}).get("command") or ""
    cwd = event.get("cwd") or os.getcwd()
    command = strip_heredocs(command)
    try:
        check_command(command, cwd)
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
