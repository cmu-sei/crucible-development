FROM mcr.microsoft.com/devcontainers/dotnet:9.0-bookworm

ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive

# Switch to root for configuring image
USER root

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

# Install Vale
ARG VALE_VERSION=3.12.0
RUN set -eux; \
    curl -fsSL -o /tmp/vale.tgz \
      "https://github.com/errata-ai/vale/releases/download/v${VALE_VERSION}/vale_${VALE_VERSION}_Linux_64-bit.tar.gz" \
    && tar -xzf /tmp/vale.tgz -C /usr/local/bin vale \
    && rm /tmp/vale.tgz \
    && chmod +x /usr/local/bin/vale \
    && vale --version

# Install k-alias
RUN git clone https://github.com/jaggedmountain/k-alias.git /tmp/k-alias && \
    cp /tmp/k-alias/[h,k]* /usr/local/bin

# Switch back to vscode user
USER vscode
