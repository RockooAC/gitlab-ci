FROM debian:bookworm-slim  

ENV \
    ANDROID_SDK_VERSION=commandlinetools-linux-9477386_latest.zip \
    GRADLE_VERSION=6.9 \
    JAVA17_HOME=/usr/lib/jvm/java-17-amazon-corretto \
    NODE_VERSION=20.18.1

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

RUN GRADLE_VERSION=$(curl -s https://services.gradle.org/versions/current | jq -r .version) && \
    curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip && \
    mkdir -p /opt/gradle && \
    unzip /tmp/gradle.zip -d /opt/gradle && \
    rm /tmp/gradle.zip && \
    ln -s /opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle /usr/bin/gradle

RUN wget https://r.dcs.redcdn.pl/file/o2/dsw/jenkins/packages/java-17-amazon-corretto-jdk_17.0.13.11-1_amd64.deb -O /tmp/java-17-amazon-corretto-jdk_17.0.13.11-1_amd64.deb && \
    apt-get update && apt-get install -y /tmp/java-17-amazon-corretto-jdk_17.0.13.11-1_amd64.deb && \
    rm -f /tmp/java-17-amazon-corretto-jdk_17.0.13.11-1_amd64.deb && \
    java -version

ENV JAVA_HOME=${JAVA17_HOME}

RUN wget https://dl.google.com/android/repository/${ANDROID_SDK_VERSION} -P /tmp && \
    mkdir -p /opt/android-sdk-linux && \
    unzip /tmp/${ANDROID_SDK_VERSION} -d /opt/android-sdk-linux && \
    mv /opt/android-sdk-linux/cmdline-tools /opt/android-sdk-linux/latest && \
    mkdir -p /opt/android-sdk-linux/cmdline-tools && \
    mv /opt/android-sdk-linux/latest /opt/android-sdk-linux/cmdline-tools/latest && \
    yes | /opt/android-sdk-linux/cmdline-tools/latest/bin/sdkmanager --licenses && \
    /opt/android-sdk-linux/cmdline-tools/latest/bin/sdkmanager "cmake;3.31.6" "ndk;28.0.13004108" "build-tools;34.0.0" "build-tools;35.0.1" "platforms;android-34" "platforms;android-35" "platform-tools" "emulator" && \
    rm /tmp/${ANDROID_SDK_VERSION}

RUN curl -fsSL https://nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz -o node.tar.gz && \
    tar -xzf node.tar.gz -C /usr/local --strip-components=1 && \
    rm node.tar.gz

RUN ln -sfn ${JAVA17_HOME} /usr/lib/jvm/java-17-openjdk-amd64

ENV PATH=${JAVA_HOME}/bin:/opt/gradle/bin:/opt/android-sdk-linux/cmdline-tools/latest/bin:/usr/local/bin:$PATH

RUN useradd -ms /bin/bash jenkins

USER jenkins
RUN mkdir -p /home/jenkins/.ssh
