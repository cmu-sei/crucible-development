#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

scripts/sync-repos.sh --pull

# The crucible-pr, crucible-review and crucible-merge-risk skills, installed for every session
# whatever directory it starts in. The PR gate hooks in /etc call scripts through these links.
for dir in "$HOME/.agents/skills" "$HOME/.claude/skills"; do
  mkdir -p "$dir"
  for skill in .devcontainer/skills/*/; do
    ln -sfn "$PWD/${skill%/}" "$dir/$(basename "$skill")"
  done
done

# Detached so the ~40s install doesn't hold up the rest of container start.
setsid nohup scripts/restore-skills.sh > /tmp/restore-skills.log 2>&1 < /dev/null &
echo "Installing AI agent skills in the background (log: /tmp/restore-skills.log)"

# Personal startup scripts. Git-ignored; see .devcontainer/hooks/README.md.
for hook in .devcontainer/hooks/*.sh; do
  [ -f "$hook" ] || continue
  echo "Running personal startup script ${hook}"
  bash -l "$hook" || echo "Warning: ${hook} failed (exit $?); continuing" >&2
done

# Welcome message
cat <<'EOF'

                         @@@@
                       @@@@@@@@
                     @@@@@@@@@@@@
                    @@@@@@@@@@@@@@@
                  @@@@@@@@@@@@@@@@@@@
                @@@@@@           @@@@@@
              @@@@@                 @@@@
            @@@@@                   @@@@@@
          @@@@@@         @@@@@     @@@@@@@@@
         @@@@@@       @@@@@@@@@@@@@@@@@@@@@@@@
       @@@@@@@@      @@@@@@@@@@@@@@@@@@@@@@@@@@
      @@@@@@@@       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      @@@@@@@@       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@@@@@@      @@@@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@@@@@@       @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@@@@@@@         @@@@@     @@@@@@@@@@
     @@@@@@@@@@@@                   @@@@@@@
     @@@@@@@@@@@@@@                 @@@@@
      @@@@@@@@@@@@@@@@           @@@@@@
       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@
          @@@@@@@@@@@@@@@@@@@@@@@@
            @@@@@@@@@@@@@@@@@@@@
               @@@@@@@@@@@@@@

      Welcome to the Crucible Dev Container!

Getting started:
  - Open Run and Debug (Ctrl+Shift+D) to select a launch profile or press F5
    to run the Default or last selected profile.
  - Default admin credentials: admin / admin
  - See the README for more details.

Type Ctrl-Shift-` (backtick) to open a new terminal.

EOF
