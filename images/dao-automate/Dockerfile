FROM debian:bookworm-slim

ENV \
    OPENTOFU_VERSION=1.10.5 \
    TERRAGRUNT_VERSION=0.84.1 \
    KUBECTL_VERSION=1.33.3 \
    PACKER_VERSION=1.14.1 \
    PATH="/usr/local/bin:/usr/local/sbin:$SDKMAN_DIR/bin:$NVM_DIR/bin:$PATH"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-requests \
    python3-fabric \
    python3-dotenv \
    python3-venv \
    zip \
    git \
    curl \
    wget \
    unzip \
    openssh-client \
    software-properties-common && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/sdkman && \
    export SDKMAN_DIR=/usr/local/sdkman && \
    curl -s "https://get.sdkman.io" | bash

RUN mkdir -p /usr/local/nvm && \
    export NVM_DIR=/usr/local/nvm && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

RUN curl -fsSL https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.zip -o tofu.zip && \
    unzip tofu.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/tofu && \
    rm tofu.zip

RUN curl -fsSL https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip -o packer.zip && \
    unzip packer.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/packer && \
    rm packer.zip

RUN curl -L https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 -o /usr/local/bin/terragrunt && \
    chmod +x /usr/local/bin/terragrunt

RUN curl -fsSL https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

RUN pip3 install --break-system-packages ansible==11.8.0

RUN useradd -ms /bin/bash jenkins

USER jenkins
RUN mkdir -p /home/jenkins/.ssh && \
    echo "Host *\n    StrictHostKeyChecking no" > /home/jenkins/.ssh/config && \
    chmod 600 /home/jenkins/.ssh/config && \
    chown -R jenkins:jenkins /home/jenkins/.ssh && \
    chmod g+rx /home/jenkins/.ssh
