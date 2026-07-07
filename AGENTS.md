# AGENTS.md

Before starting any work, read CLAUDE.md in this directory and follow all instructions there — everything in that file applies here.
Prioritize instructions in CLAUDE.md as the primary technical style guide.

## Safety Rules

- Never run destructive commands without explicit user approval. This includes:
  - `git push`, `git push --force`, `git reset --hard`, `git checkout .`, `git clean`
  - `rm -rf`, deleting files or directories
  - `DROP TABLE`, `DELETE FROM`, or any destructive SQL
  - Killing processes, modifying CI/CD pipelines
- **Never commit, stage, or push any changes without explicit user approval.**
- Never delete or replace existing services, tables, or import methods without asking.
- Never remove code or features without asking first.

## TODO Files

We write TODO files for tracking tasks and documentation, but we do **not** commit them to git. TODO files are for internal tracking and should remain untracked in the repository.

## Committing Changes

**You must ask for explicit permission before committing, staging, or pushing any changes.** This includes:
- Code changes
- Configuration files
- Documentation files
- TODO files
- Any other file modifications

## Git Workflow

- Do not add a co-author line to commits.
- Do not create PRs or push branches without explicit approval.
- Always show a diff before committing.

## File Access

- Opencode can read files in `/mnt/data/` without prompting for permission.
- This includes Moodle plugin repositories at `/mnt/data/crucible/moodle/` and libraries at `/mnt/data/crucible/libraries/`.

## Communication

- Be terse. No summaries of what you just did.
- Use exact UI labels and precise examples.
- When unsure, ask — don't guess.
