FROM harbor.redgelabs.com/dbir/debian:trixie-slim@sha256:e634dc321b952e16d90cf3fb4b447b730aa95103b6e791e30a76f2819c1a8c2a

LABEL org.opencontainers.image.authors="DBiR" \
      org.opencontainers.image.created="2025-11-27T09:00:00Z" \
      org.opencontainers.image.description="Slim Debian Trixie image with essential developer tools: curl and git." \
      org.opencontainers.image.licenses="Copyright (c), Redge Technologies, 2025" \
      org.opencontainers.image.title="Debian Trixie-slim image" \
      org.opencontainers.image.vendor="Redge Technologies" \
      org.opencontainers.image.version="1.0"

ARG GID=1001
ARG UID=1000
ARG USERNAME=jenkins

# hadolint ignore=DL3008
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
               ca-certificates \
               curl \
               git \
    && groupadd -g $GID $USERNAME \
    && useradd -m -s /bin/bash -u $UID -g $GID -l $USERNAME \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
WORKDIR /home/$USERNAME
