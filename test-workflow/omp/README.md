# Running the Crucible test-workflow agents under Oh My Pi

There is one set of agent files, read by both harnesses. `scripts/setup-test-workflow.sh` links each of `test-workflow/agents/*.md` into `/mnt/data/crucible/.claude/agents/`, and `/mnt/data/crucible/.omp/agents` is a symlink to that directory. The "Harnesses" section of [../testing/README.md](../testing/README.md) maps the workflow's steps to both harnesses.

## What is in place

| Piece | Location | Notes |
| --- | --- | --- |
| Agent definitions (the only copy) | `test-workflow/agents/*.md`, linked into `/mnt/data/crucible/.claude/agents/` | Claude Code dialect plus one omp key, `thinkingLevel`, mirroring `effort`. Edit the files in `test-workflow/agents/`. |
| Symlink for omp | `/mnt/data/crucible/.omp/agents -> ../.claude/agents` | omp discovers project agents here from any cwd under the workspace. |
| Models | none pinned | No agent file names a `model` and `/mnt/data/crucible/.omp/config.yml` (from `test-workflow/dot-omp/config.yml`) has no `task.agentModelOverrides`, so every agent inherits the session's model. |
| Project settings | same file | Idle TTL off, `prompt` rules for `git commit`, `git push`, `gh pr`, `gh release`, `eval`. Applies only when `omp` starts in `/mnt/data/crucible`. |
| Check | `agent-docs/omp/check-agents.sh` | Exits 1 if the symlink is wrong, `thinkingLevel` differs from `effort`, an agent file names a `model`, or `.omp/config.yml` pins one. Run after edits to agent definitions. |

How one file serves both harnesses:

| Frontmatter | Claude Code | Oh My Pi |
| --- | --- | --- |
| `tools: Read, Grep, Glob, Edit, Write, Bash, WebFetch` | Used as written. | Lower-cased to `read, grep, glob, edit, write, bash`; `WebFetch` is dropped silently because `read` accepts URLs. The bodies that mention WebFetch also name the `read` tool. |
| `model` | Left out: the agent inherits the session's model (Claude Code also accepts `model: inherit`). | Left out: the agent inherits the parent session's model. `model: inherit` fails here ("No model selected"), because omp reads it as a model name. |
| `effort: high` | Effort level. | Ignored; without `thinkingLevel` a child runs at omp's default, `high`, even for `effort: medium`. |
| `thinkingLevel: high` | Ignored. | Honoured. |

### Model policy

No agent is pinned to a model: every agent runs on the model of the session that launches it, in both harnesses (RULES, "Agents run on the session's model"). Start the session on the model the round needs. Reasoning effort is per agent: Claude Code reads `effort`, omp reads `thinkingLevel`; keep the two equal. Writers, reviewers and the maintainer run at high, the triager, `jira-ticket-writer` and `ci-watcher` at medium.

## Behaviour to know

- The bash tool moves any command still running after 60 s into a background job (`bash.autoBackground.thresholdMs`), even with `timeout` passed; the agent collects it with `wait`. Its default timeout is 300 s, so `verify.sh` calls need `timeout`.
- The embedded shell sets `NO_COLOR=1`, `CI=true`, `TERM=dumb`. Scripts run through their `#!/usr/bin/env bash` shebang under the host bash; `dotnet`, `node`, `npm` and `docker` behave as in a normal shell. With the dev container's `FORCE_COLOR=3`, every node process warns `The 'NO_COLOR' env is ignored due to the 'FORCE_COLOR' env being set`; run UI checks with `env -u NO_COLOR` so the warning does not reach the UI `verify.sh` stderr check.
- `omp -p` started from a non-terminal without stdin waits for piped input. Redirect `< /dev/null` when running it in the background.
- RPC `get_subagents` lists only running agents; idle and parked ones are absent. Take the id from the `subagent_lifecycle` frame or the `task` result. Only `prompt_result` / `session_settled` frames say a main turn is finished.
- Every delivered child result starts a new main-session turn. Tell the orchestrator prompt what to do with it, or the main model acts on the report on its own.
- `agent://<id>` keeps only the latest yield; earlier reports are in `history://<id>` and the child's session JSONL.
- Bedrock 500s and 503s are retried automatically; a rejected empty `yield` is retried up to three times.
- `task.softRequestBudget` defaults to 200 requests per child (force-stop at 1.5×). A writer on a large repo can approach it.
- Pasting a long gate list into `write agent://` is slow for the main model. Point the writer at a file instead.
- Inside a repo, the group `AGENTS.md` is not loaded automatically (the context-file walk stops at the repo root). Name `/mnt/data/crucible/AGENTS.md` and `<group>/AGENTS.md` in the task `context`.

## Running a workflow round

Start in the workspace root so the project settings load:

```sh
cd /mnt/data/crucible
agent-docs/omp/check-agents.sh          # after any edit to the agent files
omp --model amazon-bedrock/us.anthropic.claude-fable-5-1
```

Vocabulary for the orchestrator (also in [../testing/README.md](../testing/README.md), "Harnesses"):

| The workflow says | In `omp` |
| --- | --- |
| Launch `<agent>` per repo, in parallel | One `task` call: `{ context, tasks: [{ agent: "<name>", task: "..." }, ...] }`. Background by default. |
| Wait for its report | Results arrive on their own; `wait` blocks for the next one. Full report at `agent://<id>`, transcript at `history://<id>`. |
| `SubagentHandback` | The hidden `yield` tool. |
| `SendMessage` the gate list to the writer | `write agent://<writer-id>` with the text. The writer keeps its transcript; its next `yield` arrives as another async result. |
| The permission classifier denied the reviewer's edits | Reviewers have no `edit` or `write` tool. Subagents run `yolo`; only `deny` carries into them, `prompt` fails their call. |
| Read the group `AGENTS.md` | Name it in the task `context` (see above). |
