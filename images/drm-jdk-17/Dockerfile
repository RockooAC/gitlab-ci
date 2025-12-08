FROM harbor.redgelabs.com/jenkins/jdk-17:latest

# Add mediainfo for DAM application
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    mediainfo
USER jenkins
