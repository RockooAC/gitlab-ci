FROM debian:bookworm-slim  

ENV NODE_VERSION=18.20.5

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

#if newest gratest is required 
#RUN npm install -g @webos-tools/cli

#This will install webos-tool/cli from DCS
RUN wget https://r.dcs.redcdn.pl/file/o2/dsw/jenkins/packages/webOS_TV_CLI_linux_1.12.4-j27_1.tgz -O /tmp/webOS_TV_CLI.tgz && mkdir -p /usr/local/share/webOS_TV_CLI && tar -xzf /tmp/webOS_TV_CLI.tgz -C /usr/local/share/webOS_TV_CLI/ && \
    rm /tmp/webOS_TV_CLI.tgz


RUN useradd -ms /bin/bash jenkins

USER jenkins
RUN mkdir -p /home/jenkins/.ssh

ENV PATH=$PATH:/usr/local/share/webOS_TV_CLI/CLI/bin/
