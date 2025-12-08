FROM debian:bookworm-slim  

ENV NODE_VERSION=12.9.1 \
    JAVA17_HOME=/usr/lib/jvm/java-17-amazon-corretto

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-boto3 \
    python3-requests \
    python3-pip \
    jq \
    nano \
    git \
    ssh \
    curl \
    atop \
    wget \
    unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
 
#   python3-fabric \
RUN pip3 install --break-system-packages fabric2

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

RUN wget https://r.dcs.redcdn.pl/file/o2/dsw/jenkins/packages/java-17-amazon-corretto-jdk_17.0.13.11-1_amd64.deb -O /tmp/java-17-amazon-corretto-jdk_17.0.13.11-1_amd64.deb && \
    apt-get update && apt-get install -y /tmp/java-17-amazon-corretto-jdk_17.0.13.11-1_amd64.deb && \
    rm -f /tmp/java-17-amazon-corretto-jdk_17.0.13.11-1_amd64.deb && \
    java -version

RUN ln -sfn ${JAVA17_HOME} /usr/lib/jvm/java-17-openjdk-amd64

ENV JAVA_HOME=${JAVA17_HOME}

RUN useradd -ms /bin/bash jenkins
RUN echo 'export NODE_VERSION=${NODE_VERSION}}' >> /home/jenkins.bashrc

USER jenkins

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> /home/jenkins/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/jenkins/.bashrc

RUN mkdir -p /home/jenkins/.ssh
