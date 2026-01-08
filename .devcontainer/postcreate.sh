#!/bin/bash

# Show git dirty status in zsh prompt
git config devcontainers-theme.show-dirty 1

sudo chown -R $(whoami): /home/vscode/.microsoft
sudo chown -R $(whoami): /mnt/data/
sudo chown -R $(whoami): /home/vscode/.claude

scripts/clone-repos.sh
scripts/add-moodle-mounts.sh

dotnet tool install -g Aspire.Cli
# Install dotnet-ef globally
dotnet tool install --global dotnet-ef --version 10
dotnet dev-certs https --trust

npm config -g set fund false
npm install -g @angular/cli@latest

# Stage custom CA certs so Minikube trusts them
CUSTOM_CERT_SOURCE="/usr/local/share/ca-certificates/custom"
MINIKUBE_CERT_DEST="${HOME}/.minikube/files/etc/ssl/certs/custom"
MOODLE_CERT_DEST="/workspaces/crucible-development/Crucible.AppHost/resources/moodle/certs"
if compgen -G "${CUSTOM_CERT_SOURCE}"'/*.crt' > /dev/null; then
  mkdir -p "${MINIKUBE_CERT_DEST}"
  cp "${CUSTOM_CERT_SOURCE}"/*.crt "${MINIKUBE_CERT_DEST}/"
  echo "Copied custom CA certificates to ${MINIKUBE_CERT_DEST}"
  mkdir -p "${MOODLE_CERT_DEST}"
  cp "${CUSTOM_CERT_SOURCE}"/*.crt "${MOODLE_CERT_DEST}/"
  echo "Copied custom CA certificates to ${MOODLE_CERT_DEST}"
else
  echo "No custom CA certificates found in ${CUSTOM_CERT_SOURCE}; skipping copy."
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

Type Ctrl-Shift-` (backtick) to open a new terminal and get started building. 🤓

EOF
