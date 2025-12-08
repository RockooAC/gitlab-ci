FROM sonarsource/sonar-scanner-cli:11

USER root

RUN groupadd -g 1000 jenkins || true \
 && useradd -u 1000 -g 1000 -m -s /bin/bash jenkins || true \
 && mkdir -p /home/jenkins/agent \
 && chmod 0755 /home/jenkins \
 && chown -R 1000:1000 /home/jenkins
 
USER 1000:1000

