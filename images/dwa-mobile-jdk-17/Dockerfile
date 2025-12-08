FROM debian:bookworm-slim  

ENV \
    GRADLE_VERSION=6.9 \
    JAVA17_HOME=/usr/lib/jvm/java-17-amazon-corretto

USER root

LABEL sdk.version="android/android-34"

RUN apt-get update && apt-get install -y --no-install-recommends \
    atop \
    autoconf \
    automake \
    bison \
    build-essential \
    ccache \
    curl \
    git \
    jq \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libtool \
    libxml2-dev \
    libxml2-utils \
    libxslt-dev \
    libyaml-dev \
    nano \
    python3 \
    python3-boto3 \
    python3-fabric \ 
    python3-requests \
    ruby-full \
    sed \
    sqlite3 \
    ssh \
    unzip \
    wget \
    zlib1g-dev \
    && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN gem install bundler && gem install fastlane

RUN useradd -ms /bin/bash jenkins

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

RUN mkdir -p /home/jenkins/android/android-34 && \
    cd /home/jenkins/android/android-34 && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O cmdtools.zip && \
    unzip cmdtools.zip -d temp && \
    mkdir -p cmdline-tools/latest && \
    mv temp/cmdline-tools/* cmdline-tools/latest/ && \
    rm -rf temp cmdtools.zip && \
    export ANDROID_SDK_ROOT=/home/jenkins/android/android-34 && \
    yes | ./cmdline-tools/latest/bin/sdkmanager --licenses && \
    ./cmdline-tools/latest/bin/sdkmanager "cmake;3.31.6" "ndk;28.0.13004108" "build-tools;34.0.0" "build-tools;35.0.1" "platforms;android-34" "platforms;android-35" "platform-tools" "emulator" "ndk;26.1.10909125"

RUN ln -sfn ${JAVA17_HOME} /usr/lib/jvm/java-17-openjdk-amd64

ENV PATH=${JAVA_HOME}/bin:/opt/gradle/bin:/home/jenkins/android/android-34/cmdline-tools/latest/bin:/usr/local/bin:$PATH
ENV ANDROID_HOME=/home/jenkins/android/android-34

USER jenkins

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> /home/jenkins/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/jenkins/.bashrc

RUN mkdir -p /home/jenkins/.ssh
