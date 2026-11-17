#!/usr/bin/env python3
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

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
KEYWORDS = {"if", "then", "else", "elif", "do", "while", "until", "!", "{", "}", "time"}
# Commands that run another command, with the options of each that take a value.
WRAPPERS = {
    "env": {"-u", "--unset", "-C", "--chdir"},
    "timeout": {"-s", "--signal", "-k", "--kill-after"},
    "nice": {"-n", "--adjustment"},
    "sudo": {"-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-T", "-U", "--user", "--group", "--close-from",
             "--chdir", "--host", "--prompt", "--role", "--type", "--command-timeout", "--other-user"},
    "ionice": {"-c", "-n", "-p", "-P", "-u", "--class", "--classdata", "--pid", "--pgid", "--uid"},
    "stdbuf": {"-i", "-o", "-e", "--input", "--output", "--error"},
    "xargs": {"-a", "-d", "-E", "-I", "-L", "-l", "-n", "-P", "-s", "--arg-file", "--delimiter", "--eof",
              "--replace", "--max-lines", "--max-args", "--max-procs", "--max-chars", "--process-slot-var"},
    "nohup": set(), "exec": {"-a"}, "command": set(), "builtin": set(),
}
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


def split_heredocs(command: str):
    """The command without heredoc bodies, and the bodies bash expands (unquoted delimiter)."""
    out, expanded, ends = [], [], []
    for line in command.split("\n"):
        if ends:
            delimiter, quoted = ends[0]
            if line.strip() == delimiter:
                ends.pop(0)
            elif not quoted:
                expanded.append(line)
            continue
        out.append(line)
        ends.extend((m.group(2), bool(m.group(1))) for m in HEREDOC.finditer(line))
    return "\n".join(out), "\n".join(expanded)


def strip_heredocs(command: str) -> str:
    return split_heredocs(command)[0]


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
    while i < len(words) and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[i]) or words[i] in KEYWORDS):
        i += 1
    words = words[i:]
    name = os.path.basename(words[0]) if words else ""
    if name not in WRAPPERS:
        return words
    takes_value, i = WRAPPERS[name], 1
    while i < len(words):
        w = words[i]
        if name == "env" and (w in ("-S", "--split-string") or w.startswith(("-S", "--split-string="))):
            # env -S runs its argument as a command line, like sh -c.
            if w.startswith("--split-string="):
                value, rest = w.split("=", 1)[1], words[i + 1:]
            elif w in ("-S", "--split-string"):
                value, rest = (words[i + 1] if i + 1 < len(words) else ""), words[i + 2:]
            else:
                value, rest = w[2:], words[i + 1:]
            return ["sh", "-c", " ".join([value, shlex.join(rest)]).strip()]
        if w == "--":
            i += 1
            break
        if w.startswith("-"):
            i += 2 if w in takes_value else 1
        elif name == "env" and "=" in w:
            i += 1
        else:
            break
    if name == "timeout":
        i += 1  # the duration
    return command_words(words[i:])


def shell_script(words):
    """The script of `bash -c '...'` (or sh/zsh/dash, including clusters like -lc), else None."""
    if words and os.path.basename(words[0]) in SHELLS:
        for j, w in enumerate(words[1:], 1):
            if re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", w) and j + 1 < len(words):
                return words[j + 1]
    return None


def substitutions(command, quotes=True):
    """Bodies of $(...) and `...` command substitutions the shell would run: not inside single quotes or
    comments. With quotes=False (a heredoc body), quote characters are literal text."""
    bodies, i, quote = [], 0, None
    while i < len(command):
        c = command[i]
        if not quotes and c in "'\"":
            pass
        elif quotes and quote is None and c == "#" and (i == 0 or command[i - 1] in " \t\n;&|("):
            j = command.find("\n", i)
            i = len(command) if j == -1 else j
            continue
        elif quote == "'":
            if c == "'":
                quote = None
        elif c == "\\":
            i += 1
        elif c == "'" and quote is None:
            quote = "'"
        elif c == '"':
            quote = None if quote == '"' else '"'
        elif command.startswith("$(", i):
            depth, j = 1, i + 2
            while j < len(command) and depth:
                depth += {"(": 1, ")": -1}.get(command[j], 0)
                j += 1
            bodies.append(command[i + 2:j - 1])
            i = j
            continue
        elif c == "`":
            j = command.find("`", i + 1)
            if j == -1:
                break
            bodies.append(command[i + 1:j])
            i = j
        i += 1
    return bodies


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
    # For a fork head (owner:branch), the branch lives in the owner's copy of the repo.
    owner, _, _ = opts["--head"].rpartition(":")
    source = f"{owner}/{repo.split('/', 1)[1]}" if owner else repo
    try:
        lookup = subprocess.run(["git", "ls-remote", f"https://github.com/{source}.git", f"refs/heads/{head}"],
                                capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        deny(f"couldn't check the pushed {head} on {source} (timed out). Retry once it's reachable.")
    if lookup.returncode != 0:
        deny(f"couldn't check the pushed {head} on {source}: {lookup.stderr.strip()[:200]}")
    remote = lookup.stdout.split()
    if not remote:
        deny(f"{head} isn't pushed to {source}. Push the reviewed commit first.")
    if remote[0] != head_sha:
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
    command, expanded = split_heredocs(command)
    if depth < 3:
        for body in substitutions(command) + substitutions(expanded, quotes=False):
            check_command(body, cwd, depth + 1)
    for words in segments(command):
        words = command_words(words)
        if not words:
            continue
        if words[0] == "cd" and len(words) > 1:
            cwd = str(Path(cwd, os.path.expanduser(words[1])).resolve())
            continue
        script = shell_script(words)
        if script is not None and depth < 3:
            check_command(script, cwd, depth + 1)
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
    try:
        check_command(command, cwd)
    except SystemExit:
        raise
    except ValueError as err:
        # Unparsable (e.g. an unbalanced quote in text). Only a real gh command needs a decision.
        if GH_COMMAND.search(strip_heredocs(command)):
            deny(f"couldn't parse the command ({err}). Run gh pr create as a plain command.")
    except Exception as err:  # fail closed
        deny(f"the gate failed ({type(err).__name__}: {err}). {OVERRIDE_HINT}")


if __name__ == "__main__":
    main()
