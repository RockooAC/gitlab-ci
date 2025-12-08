FROM debian:bookworm-slim

ENV \
    ANDROID_SDK_VERSION=commandlinetools-linux-9477386_latest.zip \
    RUBY_VERSION=3.4.1 \
    JAVA_HOME=/usr/lib/jvm/java-23-amazon-corretto \
    ANDROID_HOME=/home/jenkins/android/SDK \
    PATH="/usr/local/bin:/usr/local/sbin:/home/jenkins/android/SDK/tools/bin:/home/jenkins/android/SDK/cmdline-tools/latest/bin:/home/jenkins/android/SDK/platform-tools:/opt/gradle/bin:${JAVA_HOME}/bin:$PATH"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    unzip \
    sed \
    wget \
    ruby-full \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libreadline-dev \
    libyaml-dev \
    libsqlite3-dev \
    sqlite3 \
    libxml2-dev \
    libxslt-dev \
    autoconf \
    automake \
    libtool \
    bison && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget https://r.dcs.redcdn.pl/file/o2/dsw/jenkins/packages/java-23-amazon-corretto-jdk_23.0.1.8-1_amd64.deb -O /tmp/java-23-amazon-corretto-jdk_23.0.1.8-1_amd64.deb && \
    apt-get update && apt-get install -y /tmp/java-23-amazon-corretto-jdk_23.0.1.8-1_amd64.deb && \
    rm -f /tmp/java-23-amazon-corretto-jdk_23.0.1.8-1_amd64.deb && \
    java -version

RUN ln -sfn ${JAVA_HOME} /usr/lib/jvm/java-23-openjdk-amd64

RUN gem install bundler && gem install fastlane

RUN useradd -ms /bin/bash jenkins

USER jenkins

RUN mkdir -p /home/jenkins/android && \
    wget https://dl.google.com/android/repository/${ANDROID_SDK_VERSION} -P /tmp && \
    unzip /tmp/${ANDROID_SDK_VERSION} -d /home/jenkins/android/SDK && \
    rm /tmp/${ANDROID_SDK_VERSION} && \
    mkdir /home/jenkins/android/SDK/cmdline-tools/latest && \
    mv /home/jenkins/android/SDK/cmdline-tools/* /home/jenkins/android/SDK/cmdline-tools/latest/ | true && \
    yes | sdkmanager \
    "platform-tools" \
    "build-tools;33.0.0" \
    "platforms;android-33"

ENV NVM_DIR="/home/jenkins/.nvm"

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> /home/jenkins/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/jenkins/.bashrc && \
    . $NVM_DIR/nvm.sh && nvm install v22.17.0 && nvm use v22.17.0 && npm install -g firebase-tools


RUN mkdir -p /home/jenkins/.ssh && \
    echo "Host *\n    StrictHostKeyChecking no" > /home/jenkins/.ssh/config && \
    chmod 600 /home/jenkins/.ssh/config && \
    chown -R jenkins:jenkins /home/jenkins/.ssh && \
    chmod g+rx /home/jenkins/.ssh
