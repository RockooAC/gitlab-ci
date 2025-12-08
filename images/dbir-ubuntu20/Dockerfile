FROM ubuntu:20.04
# needed on Ubuntu 20
ENV TZ=PL \
    DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
        apache2-dev \
        bison \
        clang \
        clang-tidy \
        cmake \
        doxygen \
        flex \
        g++ \
        git \
        googletest \
        graphviz \
        libboost-program-options-dev \
        libfuse-dev \
        libjemalloc-dev \
        libjsoncpp-dev \
        libluajit-5.1-dev \
        libpq-dev \
        libssl-dev \
        libxml2-dev \
        make \
        pkg-config \
        qtbase5-dev \
        ragel \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash jenkins

USER jenkins
RUN mkdir -p /home/jenkins/.ssh