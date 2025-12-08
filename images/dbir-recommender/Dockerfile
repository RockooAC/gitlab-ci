FROM harbor.redgelabs.com/dbir/debian:bookworm-slim@sha256:b8ede64076f4741ab37528108a39982e308b46cc00d08bcf6a198dea6efd07ff

LABEL org.opencontainers.image.authors="DBiR" \
      org.opencontainers.image.created="2025-02-13T12:00:00Z" \
      org.opencontainers.image.description="Base Debian Bookworm image that sets up a Python 3.11 environment with virtual environment support. Enables running python scripts and processes. Includes additional database tools: psql-client for PostgreSQL and redis-cli for Redis." \
      org.opencontainers.image.licenses="Copyright (c), Redge Technologies, 2025" \
      org.opencontainers.image.title="Debian Bookworm-slim with python 3.11 image" \
      org.opencontainers.image.vendor="Redge Technologies" \
      org.opencontainers.image.version="1.0"

ARG PYTHON_VERSION=3.11.2-6
ARG CELERY_VERSION=5.2.6-5
ARG KAFKACAT_VERSION=1.7.1-2
ARG DEBIAN_VERSION=deb12u6
ARG POSTGRESSQL_CLIENT_VERSION=15+248+deb12u1
ARG REDIS_VERSION=5:7.0.15-1
ARG GID=1001
ARG UID=1000
ARG USERNAME=jenkins

ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# hadolint ignore=DL3008
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
               celery=$CELERY_VERSION \
               curl \
               git \
               jq \
               kafkacat=$KAFKACAT_VERSION \
               python3.11-minimal=$PYTHON_VERSION+$DEBIAN_VERSION \
               python3.11-venv=$PYTHON_VERSION+$DEBIAN_VERSION \
               python3.11-dev=$PYTHON_VERSION+$DEBIAN_VERSION \
               postgresql-client=$POSTGRESSQL_CLIENT_VERSION \
               redis-tools=$REDIS_VERSION~$DEBIAN_VERSION \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.11 0 \
    && python -m venv $VIRTUAL_ENV \
    && groupadd -g $GID $USERNAME \
    && useradd -m -s /bin/bash -u $UID -g $GID -l $USERNAME \
    && chown -R $USERNAME:$USERNAME /opt/venv \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR /home/$USERNAME
