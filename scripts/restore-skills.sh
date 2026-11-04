#!/usr/bin/env bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Installs the latest version of every AI agent skill listed in skills-lock.json
# into .agents/skills (gitignored). The committed .claude/skills symlinks point
# there.
#
# skills-lock.json is a list of skills, not a version pin: it records each
# skill's source and a content hash but no commit, so the install always pulls
# upstream's latest and rewrites the hashes. Those rewritten hashes are
# discarded so the file doesn't show as modified on every container start.
#
# poststart.sh runs this in the background (log: /tmp/restore-skills.log).
# Failures (offline, proxy) only warn; they never block container start.

set -uo pipefail

cd "$(dirname "$0")/.."

# One install at a time (e.g. the container restarts while one is running).
exec 9>/tmp/restore-skills.lock
if ! flock -n 9; then
  echo "Another skill install is already running; skipping."
  exit 0
fi

# Keep any skills-lock.json edit in progress (e.g. after `npx skills add`).
lock_was_clean=false
git diff --quiet -- skills-lock.json 2>/dev/null && lock_was_clean=true

echo "Installing AI agent skills from skills-lock.json..."
# --force: without it, skills already in .agents/skills are skipped, not updated.
npx --yes skills experimental_install --no-frozen-lockfile --force 2>&1 \
  | grep -v "Skipping symlink that points outside the skill directory"
status=${PIPESTATUS[0]}

if [[ "$lock_was_clean" == true ]]; then
  git checkout --quiet -- skills-lock.json 2>/dev/null || true
fi

if [[ $status -ne 0 ]]; then
  echo "WARNING: skill install failed (exit $status); run scripts/restore-skills.sh to retry." >&2
fi
exit 0
