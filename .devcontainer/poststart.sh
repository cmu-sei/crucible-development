#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

claude update &
$HOME/.opencode/bin/opencode upgrade &
npm update -g @gitlawb/openclaude &

scripts/sync-repos.sh --pull

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
