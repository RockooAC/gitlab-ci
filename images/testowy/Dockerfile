FROM ubuntu:20.04 


RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      iputils-ping \
      dnsutils \
      traceroute \
      telnet \
      net-tools \
      iproute2 \
      curl \
      wget \
      openssh-client \
      netcat-openbsd \
      tcpdump && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash jenkins && \
    mkdir -p /home/jenkins/.ssh    

USER jenkins