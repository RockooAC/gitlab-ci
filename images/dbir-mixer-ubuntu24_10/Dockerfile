FROM harbor.redgelabs.com/dbir/ubuntu:24.10@sha256:6e24caf644e053a0daed545b70a081bfb0b798d7a4629f879e93d98330fb26cb

ARG GID=10001
ARG UID=10000
ARG USERNAME=jenkins

RUN set -eux \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
               clang \
               clang-format \
               clang-tidy \
               cmake \
               doxygen \
               g++ \
               git \
               graphviz \
               libgmock-dev \
               libgtest-dev \
               libpoco-dev \
               make \
    && groupadd -g $GID $USERNAME \
    && useradd -m -s /bin/bash -u $UID -g $GID -l $USERNAME \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME

WORKDIR /home/$USERNAME