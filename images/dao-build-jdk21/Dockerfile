FROM debian:bookworm-slim

ENV PATH="/usr/local/bin:/usr/local/sbin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-requests \
    python3-fabric \
    python3-dotenv \
    python3-boto3 \
    zip \
    git \
    sed \
    curl \
    wget \
    unzip \
    openssh-client \
    software-properties-common && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget https://r.dcs.redcdn.pl/file/o2/dsw/jenkins/packages/java-21-amazon-corretto-jdk_21.0.5.11-1_amd64.deb -O /tmp/java-21-amazon-corretto-jdk_21.0.5.11-1_amd64.deb && \
    apt-get update && apt-get install -y /tmp/java-21-amazon-corretto-jdk_21.0.5.11-1_amd64.deb && \
    rm -f /tmp/java-21-amazon-corretto-jdk_21.0.5.11-1_amd64.deb && \
    java -version

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

RUN useradd -ms /bin/bash jenkins

RUN pip3 install --break-system-packages fabric2

USER jenkins
ENV NVM_DIR="/home/jenkins/.nvm"

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> /home/jenkins/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/jenkins/.bashrc

RUN mkdir -p /home/jenkins/.ssh && \
    echo "Host *\n    StrictHostKeyChecking no\n    PubkeyAcceptedKeyTypes +ssh-rsa" > /home/jenkins/.ssh/config && \
    chmod 600 /home/jenkins/.ssh/config && \
    chown -R jenkins:jenkins /home/jenkins/.ssh && \
    chmod g+rx /home/jenkins/.ssh
