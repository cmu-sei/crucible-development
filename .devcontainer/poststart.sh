#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

claude update &
opencode upgrade &
npm update -g @gitlawb/openclaude &

scripts/sync-repos.sh --pull

# Load local LLM provider env vars if configured
LLM_ENV="/workspaces/crucible-development/.devcontainer/local-llm.env"
if [ -f "$LLM_ENV" ] && [ -s "$LLM_ENV" ]; then
  if ! grep -q "source.*local-llm.env" ~/.zshrc 2>/dev/null; then
    echo "source $LLM_ENV" >> ~/.zshrc
  fi
fi

# Shell aliases for local LLM provider support
if ! grep -q 'alias opencode=' ~/.zshrc 2>/dev/null; then
cat >> ~/.zshrc <<'ALIASES'
alias opencode='CLAUDE_CODE_USE_BEDROCK= AWS_REGION= command opencode'
alias openclaude='CLAUDE_CODE_USE_OPENAI=1 OPENAI_BASE_URL=${LOCAL_LLM_BASE_URL} OPENAI_API_KEY=${LOCAL_LLM_API_KEY} OPENAI_MODEL=${LOCAL_LLM_MODEL} command openclaude'
ALIASES
fi

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
