FROM debian:bookworm-slim              

ENV PACKER_VERSION=1.9.2 \
    ANSIBLE_VERSION=2.14.0

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-boto3 \
    python3-pip \
    python3-requests \
    python3-fabric \
    python3-hvac \
    jq \
    nano \
    git \
    ssh \
    curl \
    atop \
    wget \
    unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip -P /tmp && \
    unzip /tmp/packer_${PACKER_VERSION}_linux_amd64.zip -d /usr/local/bin && \
    rm /tmp/packer_${PACKER_VERSION}_linux_amd64.zip

RUN apt-get update && apt-get install -y ansible

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

RUN curl -L https://raw.githubusercontent.com/warrensbox/terraform-switcher/master/install.sh -o /tmp/tfswitch-install && \
    chmod +x /tmp/tfswitch-install && \
    /tmp/tfswitch-install && \
    rm /tmp/tfswitch-install

RUN curl -L https://raw.githubusercontent.com/warrensbox/tgswitch/release/install.sh -o /tmp/tgswitch-install && \
    chmod +x /tmp/tgswitch-install && \
    /tmp/tgswitch-install && \
    rm /tmp/tgswitch-install

RUN useradd -ms /bin/bash jenkins

USER jenkins
RUN mkdir -p /home/jenkins/.ssh
