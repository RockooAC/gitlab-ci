FROM harbor.redgelabs.com/dbir/python:3.11.14-slim@sha256:87a8b67155544c025acd814a9dfe3f4ed761cbe3db91ef9f099de2c46ec79eb1

LABEL org.opencontainers.image.authors="DBiR" \
      org.opencontainers.image.created="2025-10-28T12:00:00Z" \
      org.opencontainers.image.description="Lightweight Python 3.11 image with git for use in CI/CD pipelines and containerized environments." \
      org.opencontainers.image.licenses="Copyright (c), Redge Technologies, 2025" \
      org.opencontainers.image.title="Python 3.11 slim image with git" \
      org.opencontainers.image.vendor="Redge Technologies" \
      org.opencontainers.image.version="1.0"

ARG GID=10001
ARG UID=10000
ARG USERNAME=jenkins

# hadolint ignore=DL3013,DL3008
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
               git \
    && pip install --no-cache-dir --upgrade pip \
    && groupadd -g $GID $USERNAME \
    && useradd -m -s /bin/bash -u $UID -g $GID -l $USERNAME \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

WORKDIR /home/$USERNAME
