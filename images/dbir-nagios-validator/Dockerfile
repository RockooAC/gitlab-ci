FROM harbor.redgelabs.com/dbir/ubuntu:noble@sha256:4cb659d7f718777d9844fb1c2eaff36665d329c840b77b4a7b42767d91b5af93
LABEL org.opencontainers.image.authors="DBiR" \
      org.opencontainers.image.created="2025-10-29T12:00:00Z" \
      org.opencontainers.image.title="Nagios Core on Ubuntu Noble Config Validator" \
      org.opencontainers.image.description="Docker image for validating Nagios Core configuration files" \
      org.opencontainers.image.base.name="harbor.redgelabs.com/dbir/ubuntu:noble" \
      org.opencontainers.image.base.digest="sha256:4cb659d7f718777d9844fb1c2eaff36665d329c840b77b4a7b42767d91b5af93" \
      org.opencontainers.image.licenses="Copyright (c), Redge Technologies, 2025" \
      org.opencontainers.image.vendor="Redge Technologies" \
      org.opencontainers.image.version="1.0"

ARG NAGIOS_VERSION=4.4.6-4ubuntu0.24.04.1

ARG NAGIOS_DIR_NAME=nagios4

ARG GID=1001
ARG UID=1000
ARG USERNAME=jenkins

# hadolint ignore=DL3008
RUN set -eux && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
            git \
            nagios4=$NAGIOS_VERSION \
            openssh-client \
            rsync && \
    rm -rf /var/lib/apt/lists/*


# Remove default 'ubuntu' user if present.
# Jenkins always checks out repositories as UID 1000, so we replace 'ubuntu' with a custom user.
RUN userdel -r ubuntu || true

RUN groupadd -g $GID $USERNAME && \
    useradd -m -u $UID -g $GID -s /bin/bash -l $USERNAME

RUN mkdir -p /home/$USERNAME/.ssh && \
    printf "Host *\n StrictHostKeyChecking no\n" > /home/$USERNAME/.ssh/config && \
    chmod 600 /home/$USERNAME/.ssh/config && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh && \
    chmod g+rx /home/$USERNAME/.ssh

RUN chown -R "${USERNAME}:${USERNAME}" \
          /etc/${NAGIOS_DIR_NAME} \
          /var/lib/${NAGIOS_DIR_NAME} \
          /var/log/${NAGIOS_DIR_NAME} && \
    chmod -R 770 \
          /etc/${NAGIOS_DIR_NAME}/conf.d \
          /var/lib/${NAGIOS_DIR_NAME}

USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR /home/$USERNAME
