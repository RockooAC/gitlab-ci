FROM artifactory.redlabs.pl:443/dsw-docker-jenkins-local/jenkins/web-18:latest       
USER root
RUN npm install -g @webos-tools/cli

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/tizen

RUN chmod 0777 /opt/tizen

RUN cd /tmp && \
    curl -LO https://download.tizen.org/sdk/Installer/tizen-studio_6.0/web-cli_Tizen_Studio_6.0_ubuntu-64.bin && \
    chmod +x web-cli_Tizen_Studio_6.0_ubuntu-64.bin && \
    ./web-cli_Tizen_Studio_6.0_ubuntu-64.bin --accept-license --no-java-check /opt/tizen && \
    rm web-cli_Tizen_Studio_6.0_ubuntu-64.bin

ENV PATH="/opt/tizen/tools/ide/bin:${PATH}"

USER jenkins 