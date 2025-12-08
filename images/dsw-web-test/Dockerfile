FROM ubuntu:22.04

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

ENV http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    no_proxy=${NO_PROXY} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY} \
    DEBIAN_FRONTEND=noninteractive \
    CI=true \
    NODE_ENV=production

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg apt-transport-https unzip jq xvfb \
    software-properties-common python3 python3-pip \
    # Playwright deps + fonty
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libdrm2 libxkbcommon0 libgbm1 \
    libxshmfence1 libxcomposite1 libxrandr2 libxdamage1 libpango-1.0-0 libcairo2 \
    fonts-noto-color-emoji \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
 && apt-get update && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends chromium-browser firefox \
 && rm -rf /var/lib/apt/lists/*

ARG PW_VERSION=1.47.2
ARG LHCI_VERSION=0.13.0
ARG ALLURE_VERSION=2.29.0

ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

RUN npm i -g @playwright/test@${PW_VERSION} @lhci/cli@${LHCI_VERSION} allure-commandline@${ALLURE_VERSION} --location=global --no-update-notifier

RUN mkdir -p /opt/allure && \
    curl -fsSL https://github.com/allure-framework/allure2/releases/download/${ALLURE_VERSION}/allure-${ALLURE_VERSION}.zip -o /tmp/allure.zip && \
    unzip /tmp/allure.zip -d /opt/allure && \
    ln -s /opt/allure/allure-${ALLURE_VERSION}/bin/allure /usr/local/bin/allure && \
    rm /tmp/allure.zip

RUN useradd -ms /bin/bash jenkins
USER jenkins

