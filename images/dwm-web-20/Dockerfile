FROM debian:bookworm-slim  

ENV NODE_VERSION=20.18.1

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-boto3 \
    python3-requests \
    python3-fabric \
    jq \
    nano \
    git \
    ssh \
    curl \
    atop \
    wget \
    unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws
 
RUN curl -fsSL https://nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz -o node.tar.gz && \
    tar -xzf node.tar.gz -C /usr/local --strip-components=1 && \
    rm node.tar.gz

RUN wget https://r.dcs.redcdn.pl/file/o2/dsw/jenkins/packages/yarn_1.22.17_all.deb -O /tmp/yarn_1.22.17_all.deb && dpkg -i /tmp/yarn_1.22.17_all.deb && rm /tmp/yarn_1.22.17_all.deb

RUN useradd -ms /bin/bash jenkins

USER jenkins
RUN mkdir -p /home/jenkins/.ssh

