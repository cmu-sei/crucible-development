#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

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

Type Ctrl-Shift-` (backtick) to open a new terminal and get started building. 🤓

EOF
