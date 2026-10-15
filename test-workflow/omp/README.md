# Running the Crucible test-workflow agents under Oh My Pi

There is one set of agent files, read by both harnesses. `scripts/setup-test-workflow.sh` links each of `test-workflow/agents/*.md` into `/mnt/data/crucible/.claude/agents/`, and `/mnt/data/crucible/.omp/agents` is a symlink to that directory. The "Harnesses" section of [../testing/README.md](../testing/README.md) maps the workflow's steps to both harnesses.

## What is in place

| Piece | Location | Notes |
| --- | --- | --- |
| Agent definitions (the only copy) | `test-workflow/agents/*.md`, linked into `/mnt/data/crucible/.claude/agents/` | Claude Code dialect plus one omp key, `thinkingLevel`, mirroring `effort`. Edit the files in `test-workflow/agents/`. |
| Symlink for omp | `/mnt/data/crucible/.omp/agents -> ../.claude/agents` | omp discovers project agents here from any cwd under the workspace. |
| Model pins | `/mnt/data/crucible/.omp/config.yml` (from `test-workflow/dot-omp/config.yml`), `task.agentModelOverrides` | Provider-qualified omp model per agent; wins over frontmatter. Claude Code keeps using frontmatter `model`. |
| Project settings | same file | Idle TTL off, `prompt` rules for `git commit`, `git push`, `gh pr`, `gh release`, `eval`. Applies only when `omp` starts in `/mnt/data/crucible`. |
| Check | `agent-docs/omp/check-agents.sh` | Exits 1 if the symlink is wrong, `thinkingLevel` differs from `effort`, a frontmatter `model` has a provider prefix, or an omp pin is missing, unqualified or orphaned. Run after edits to agent definitions or pins. |

How one file serves both harnesses:

| Frontmatter | Claude Code | Oh My Pi |
| --- | --- | --- |
| `tools: Read, Grep, Glob, Edit, Write, Bash, WebFetch` | Used as written. | Lower-cased to `read, grep, glob, edit, write, bash`; `WebFetch` is dropped silently because `read` accepts URLs. The bodies that mention WebFetch also name the `read` tool. |
| `model: claude-opus-5-5` | Full model id, used as written. | Resolved against the active provider, inconsistently on Bedrock: `claude-sonnet-5-5` resolves to the usable `us.anthropic.claude-sonnet-5-5`, but `claude-opus-5-5` resolves to `anthropic.claude-opus-5-5`, which Bedrock rejects for on-demand use (HTTP 400). Hence the pins in `task.agentModelOverrides`, which take precedence. |
| `effort: high` | Effort level. | Ignored; without `thinkingLevel` a child runs at omp's default, `high`, even for `effort: medium`. |
| `thinkingLevel: high` | Ignored. | Honoured. |

### Model policy

Claude Code uses each agent file's `model` and `effort`; omp uses `task.agentModelOverrides` and the file's `thinkingLevel`. Keep `effort` and `thinkingLevel` aligned; change the omp model in the project config rather than adding another frontmatter model key. Agents that write code run on Opus 5.5, the others on Sonnet 5.5 where judgement allows, in both harnesses:

- `angular-test-writer`, `dotnet-test-writer`, `test-standard-maintainer`: Opus 5.5, high.
- `api-test-reviewer`, `ui-test-reviewer`: Opus 5.5, high.
- `test-bug-triager`: Opus 5.5, medium.
- `jira-ticket-writer`, `ci-watcher`: Sonnet 5.5, medium.

Start a fresh omp session from `/mnt/data/crucible` after changing pins. Existing agents keep their current sessions; the main session's model is independent of these child-agent pins.

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
agent-docs/omp/check-agents.sh          # after any edit to the agent files or the model pins
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
