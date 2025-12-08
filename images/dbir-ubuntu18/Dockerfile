FROM ubuntu:18.04
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
        apache2-dev \
        clang \
        clang-tidy \
        cmake \
        doxygen \
        g++ \
        git \
        googletest \
        graphviz \
        libfuse-dev \
        libjemalloc-dev \
        libjsoncpp-dev \
        libpq-dev \
        libssl-dev \
        libxml2-dev \
        make \
        pkg-config \
        qtbase5-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash jenkins

USER jenkins
RUN mkdir -p /home/jenkins/.ssh