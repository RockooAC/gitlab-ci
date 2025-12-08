FROM debian:bookworm-slim

ENV \
    PATH="/usr/local/bin:/usr/local/sbin:/opt/android-sdk/tools/bin:/opt/android-sdk/cmdline-tools/bin:/opt/android-sdk/platform-tools:/opt/gradle/bin:${JAVA_HOME}/bin:${NVM_DIR}/bin:$PATH"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-requests \
    python3-fabric \
    python3-dotenv \
    zip \
    git \
    curl \
    wget \
    unzip \
    software-properties-common \
    nodejs \
    npm \
    dbus \
    dbus-x11 \
    gnome-keyring && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g @tizentv/tools @webosose/ares-cli
RUN pip3 install --break-system-packages fabric2

RUN useradd -ms /bin/bash jenkins

USER jenkins

RUN mkdir -p /home/jenkins/tizen-sdk && \
    wget https://r.dcs.redcdn.pl/file/o2/dsw/jenkins/packages/web-cli_Tizen_Studio_6.1_ubuntu-64.bin -O /tmp/tizen-studio.bin && \
    chmod +x /tmp/tizen-studio.bin && \
    /tmp/tizen-studio.bin --accept-license /home/jenkins/tizen-studio && \
    rm /tmp/tizen-studio.bin && \
    chown -R jenkins:jenkins /home/jenkins/tizen-studio

ENV \
    NVM_DIR="/home/jenkins/.nvm" \
    PATH="/home/jenkins/tizen-studio/tools/ide/bin:$PATH"

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> /home/jenkins/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/jenkins/.bashrc

RUN mkdir -p /home/jenkins/.ssh && \
    echo "Host *\n    StrictHostKeyChecking no" > /home/jenkins/.ssh/config && \
    chmod 600 /home/jenkins/.ssh/config && \
    chown -R jenkins:jenkins /home/jenkins/.ssh && \
    chmod g+rx /home/jenkins/.ssh
