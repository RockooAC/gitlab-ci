FROM debian:bookworm-slim  

ENV \
    ANDROID_SDK_VERSION=commandlinetools-linux-9477386_latest.zip \
    GRADLE_VERSION=6.9 \
    JAVA8_HOME=/usr/lib/jvm/java-8-amazon-corretto 

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

RUN wget https://dl.google.com/android/repository/${ANDROID_SDK_VERSION} -P /tmp && \
    mkdir -p /opt/android-sdk && \
    unzip /tmp/${ANDROID_SDK_VERSION} -d /opt/android-sdk && \
    rm /tmp/${ANDROID_SDK_VERSION}

RUN wget https://r.dcs.redcdn.pl/file/o2/dsw/jenkins/packages/java-1.8.0-amazon-corretto-jdk_8.432.06-1_amd64.deb -O /tmp/java-1.8.0-amazon-corretto-jdk_8.432.06-1_amd64.deb && \
    apt-get update && apt-get install -y /tmp/java-1.8.0-amazon-corretto-jdk_8.432.06-1_amd64.deb && \
    rm -f /tmp/java-1.8.0-amazon-corretto-jdk_8.432.06-1_amd64.deb && \
    java -version

RUN ln -sfn ${JAVA8_HOME} /usr/lib/jvm/java-8-openjdk-amd64

ENV JAVA_HOME=${JAVA8_HOME}
ENV PATH=${JAVA_HOME}/bin:/opt/gradle/bin:/opt/android-sdk/cmdline-tools/bin:$PATH

RUN useradd -ms /bin/bash jenkins

USER jenkins
RUN mkdir -p /home/jenkins/.ssh