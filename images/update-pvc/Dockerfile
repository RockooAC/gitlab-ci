FROM ubuntu:20.04     

# 🏷️ JEDYNA RZECZ WYMAGANA OD DEVELOPERA!
# LABEL sdk.version="android/android-34"

# Instalacja zależności systemowych  
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip openjdk-17-jdk curl && \
    rm -rf /var/lib/apt/lists/*

# 🚀 INSTALACJA SDK - developer może instalować gdzie chce!
# Pipeline automatycznie znajdzie pliki
RUN mkdir -p /home/jenkins/android/android-34 && \
    cd /home/jenkins/android/android-34 && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O cmdtools.zip && \
    unzip cmdtools.zip -d temp && \
    mkdir -p cmdline-tools/latest && \
    mv temp/cmdline-tools/* cmdline-tools/latest/ && \
    rm -rf temp cmdtools.zip && \
    export ANDROID_SDK_ROOT=/home/jenkins/android/android-34 && \
    yes | ./cmdline-tools/latest/bin/sdkmanager --licenses && \
    ./cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Cleanup
RUN rm -rf /root/.android
