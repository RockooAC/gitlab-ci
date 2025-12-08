FROM harbor.redgelabs.com/dbir/ubuntu:22.04

ARG USERNAME=jenkins

RUN apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get install -y --no-install-recommends \
        git \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash $USERNAME && \
    mkdir -p /home/$USERNAME/.ssh && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

USER $USERNAME

WORKDIR /home/$USERNAME
