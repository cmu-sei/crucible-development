# syntax=docker/dockerfile:1
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

# Install man pages and additional packages
# Use a docker cache mount to increase rebuild speed
# unminimize only runs apt-get update in its restore-documentation branch, so update explicitly or
# the cache-mounted index goes stale and installs 404. Again after, since unminimize is slow enough
# for the archive to rotate underneath it.
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    yes | unminimize && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    php \
    php-cli \
    # php-xml supplies SimpleXML, without which phpcs cannot parse the Moodle ruleset;
    # php-curl and php-zip are what composer needs to fetch and unpack packages
    php-xml \
    php-curl \
    php-zip \
    php-mbstring \
    libnss3-tools

# Install Composer, used to install the Moodle coding standard in postcreate.sh
# The release phar can be checksum-pinned; getcomposer.org/installer cannot. It is architecture
# independent, so no TARGETARCH case. Bump both ARGs together or sha256sum -c fails the build.
ARG COMPOSER_VERSION=2.10.3
ARG COMPOSER_SHA256=7a2d379d5b8ffdaa028580ef26494c36d2feef4b178d3dd1473a4dbc5e17c8d6
RUN set -eux; \
    curl -fsSL -o /tmp/composer.phar \
    "https://github.com/composer/composer/releases/download/${COMPOSER_VERSION}/composer.phar"; \
    echo "${COMPOSER_SHA256}  /tmp/composer.phar" | sha256sum -c -; \
    install -m 0755 /tmp/composer.phar /usr/local/bin/composer; \
    rm /tmp/composer.phar; \
    composer --version

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

# Install OMP
ARG OMP_VERSION=18.1.1
RUN set -eux; \
    case "${TARGETARCH}" in \
    amd64) OMP_ARCH="x64"; OMP_SHA256="04780b41fb33b658ca6e8449353911babc8c90332ac444e7e6562d041d3eae52" ;; \
    arm64) OMP_ARCH="arm64"; OMP_SHA256="a8bf4dcc47dcf3284a0f6c43ffeb94adc0a2f031dcd7f8ab8ed92d0215c89a9d" ;; \
    *)     echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/omp \
    "https://github.com/can1357/oh-my-pi/releases/download/v${OMP_VERSION}/omp-linux-${OMP_ARCH}"; \
    echo "${OMP_SHA256}  /tmp/omp" | sha256sum -c -; \
    install -m 0755 /tmp/omp /usr/local/bin/omp; \
    rm /tmp/omp; \
    omp --version

# Prepare persistent state directories before Docker initializes named volumes, so fresh volumes
# are owned by vscode. The ~/.data ones must exist before the cmu-sei features' postCreate hooks.
RUN install -d -o vscode -g vscode /home/vscode/.omp /home/vscode/.data \
    /home/vscode/.data/claude /home/vscode/.data/codex /home/vscode/.data/herdr \
    /home/vscode/.data/playwright /home/vscode/.data/shell-history

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
    dpkg -i /tmp/session-manager-plugin.deb && \
    rm -rf /tmp/awscliv2.zip /tmp/aws /tmp/session-manager-plugin.deb

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

# Codex system config is bind-mounted into this directory at container runtime.
RUN mkdir -p /etc/codex

# Install kubefwd
ARG KUBEFWD_VERSION=1.25.14
RUN set -eux; \
    case "${TARGETARCH}" in \
    amd64)  KUBEFWD_ARCH="x86_64" ;; \
    arm64)  KUBEFWD_ARCH="arm64"  ;; \
    *)      echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/kubefwd.tgz \
    "https://github.com/txn2/kubefwd/releases/download/v${KUBEFWD_VERSION}/kubefwd_Linux_${KUBEFWD_ARCH}.tar.gz" \
    && tar -xzf /tmp/kubefwd.tgz -C /usr/local/bin kubefwd \
    && rm /tmp/kubefwd.tgz \
    && chmod +x /usr/local/bin/kubefwd \
    && kubefwd version

# Export GitHub token from gh CLI for MCP server auth
RUN echo '' >> /home/vscode/.zshrc && \
    echo '# GitHub MCP token from gh CLI' >> /home/vscode/.zshrc && \
    echo 'export GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token 2>/dev/null)' >> /home/vscode/.zshrc
