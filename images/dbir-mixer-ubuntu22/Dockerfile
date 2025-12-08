FROM harbor.redgelabs.com/dbir/ubuntu:22.04@sha256:b43574218e853af5049fad3404845cb47259f8745ea2cbe83b5b4f268cf8217c

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