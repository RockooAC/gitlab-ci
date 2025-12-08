FROM harbor.redgelabs.com/dbir/debian:trixie-slim@sha256:e634dc321b952e16d90cf3fb4b447b730aa95103b6e791e30a76f2819c1a8c2a

LABEL org.opencontainers.image.authors="DBiR" \
      org.opencontainers.image.created="2025-02-13T12:00:00Z" \
      org.opencontainers.image.description="Slim Debian Trixie image providing a lightweight Python 3.13 environment with virtual environment support. Designed for running Python scripts and processes. Includes database tooling with psql-client for PostgreSQL." \
      org.opencontainers.image.licenses="Copyright (c), Redge Technologies, 2025" \
      org.opencontainers.image.title="Debian Trixie-slim with Python 3.13 image" \
      org.opencontainers.image.vendor="Redge Technologies" \
      org.opencontainers.image.version="1.0"

ARG PYTHON_VERSION=3.13.5
ARG DEBIAN_VERSION=2
ARG PGCLIENT17_VERSION=17.6-0+deb13u1
ARG GID=1001
ARG UID=1000
ARG USERNAME=jenkins

ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# hadolint ignore=DL3008
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
               curl \
               git \
               python3.13-minimal=$PYTHON_VERSION-$DEBIAN_VERSION \
               python3.13-venv=$PYTHON_VERSION-$DEBIAN_VERSION \
               python3.13-dev=$PYTHON_VERSION-$DEBIAN_VERSION \
               postgresql-client-17=$PGCLIENT17_VERSION \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.13 0 \
    && python -m venv $VIRTUAL_ENV \
    && groupadd -g $GID $USERNAME \
    && useradd -m -s /bin/bash -u $UID -g $GID -l $USERNAME \
    && chown -R $USERNAME:$USERNAME /opt/venv \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR /home/$USERNAME
