FROM mcr.microsoft.com/devcontainers/dotnet:2.0.5-10.0-noble

ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive
ARG AWS_CLI_VERSION="2.32.9"

# Switch to root for configuring image
USER root

# Add new Yarn GPG key
RUN mkdir -p /etc/apt/keyrings && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list

# Install man pages
RUN yes | unminimize

# Custom Cert Support
COPY ./certs /usr/local/share/ca-certificates/custom/
RUN find /usr/local/share/ca-certificates/custom -type f ! -name '*.crt' -delete \
    && if find /usr/local/share/ca-certificates/custom -type f -name '*.crt' -print -quit | grep -q .; then \
    update-ca-certificates; \
    fi

ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt

# required for those running ARM builds, possibly confined only to Angular 16. Try back later.
RUN apt update && apt install -y python3-dev

RUN apt install -y \
    php \
    php-cli

# Install Vale
ARG VALE_VERSION=3.12.0
RUN set -eux; \
    case "${TARGETARCH}" in \
    amd64)  VALE_ARCH="64-bit" ;; \
    arm64)  VALE_ARCH="arm64" ;; \
    *)      echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/vale.tgz \
    "https://github.com/errata-ai/vale/releases/download/v${VALE_VERSION}/vale_${VALE_VERSION}_Linux_${VALE_ARCH}.tar.gz" \
    && tar -xzf /tmp/vale.tgz -C /usr/local/bin vale \
    && rm /tmp/vale.tgz \
    && chmod +x /usr/local/bin/vale \
    && vale --version

# Install k-alias
RUN git clone https://github.com/jaggedmountain/k-alias.git /tmp/k-alias && \
    cp /tmp/k-alias/[h,k]* /usr/local/bin

# Install AWS CLI with Session Manager Plugin
RUN case "${TARGETARCH}" in \
    amd64)  AWSCLI_PKG="awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" \
    SSM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" ;; \
    arm64)  AWSCLI_PKG="awscli-exe-linux-aarch64-${AWS_CLI_VERSION}.zip" \
    SSM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb" ;; \
    *)      echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl "https://awscli.amazonaws.com/${AWSCLI_PKG}" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install --update && \
    curl "${SSM_URL}" -o /tmp/session-manager-plugin.deb && \
    dpkg -i /tmp/session-manager-plugin.deb

# Configure AWS CLI bash completion
RUN echo '' >> /home/vscode/.bashrc && \
    echo '# AWS CLI completion' >> /home/vscode/.bashrc && \
    echo 'bind "set show-all-if-ambiguous on"' >> /home/vscode/.bashrc && \
    echo 'complete -C /usr/local/bin/aws_completer aws' >> /home/vscode/.bashrc

# Configure AWS CLI zsh completion (using bashcompinit for AWS CLI v2 compatibility)
RUN echo '' >> /home/vscode/.zshrc && \
    echo '# AWS CLI completion' >> /home/vscode/.zshrc && \
    echo 'autoload -Uz bashcompinit && bashcompinit' >> /home/vscode/.zshrc && \
    echo 'complete -C /usr/local/bin/aws_completer aws' >> /home/vscode/.zshrc

# Configure ZSH History
RUN mkdir -p "/home/vscode/.history" && touch "/home/vscode/.history/zsh_history" && \
    chown -R vscode:vscode /home/vscode/.history && \
    cat >> /home/vscode/.zshrc <<'EOF'
# Persistent zsh history for devcontainer
# Use a dedicated history directory (backed by a Docker volume)
mkdir -p "/home/vscode/.history"
export HISTFILE="/home/vscode/.history/zsh_history"
export HISTSIZE=50000      # in-memory commands
export SAVEHIST=100000     # on-disk commands
# History behavior options
setopt APPEND_HISTORY          # append to history file, don't overwrite
setopt INC_APPEND_HISTORY      # write each command as it's entered
setopt SHARE_HISTORY           # share history across sessions
setopt HIST_IGNORE_DUPS        # ignore immediate duplicates
setopt HIST_IGNORE_ALL_DUPS    # drop older duplicates
setopt HIST_IGNORE_SPACE       # ignore commands starting with a space
setopt HIST_REDUCE_BLANKS      # trim extra spaces
setopt HIST_VERIFY             # don't immediately execute recalled commands
# DEVCONTAINER ZSH HISTORY END
EOF

# Switch back to vscode user
USER vscode

# Install Claude Code using native installer
RUN curl -fsSL https://claude.ai/install.sh | bash
