#!/bin/sh                  
#
# Skrypt generujący dynamiczny plik child pipeline: generated-child.yml
# Wywoływany przez job 'generate-jobs' w .gitlab-ci.yml

set -e 

echo "Identifying changed directories in ./images"

CHANGED_DIRS=$(git diff --name-only HEAD~1 HEAD ./images \
  | awk -F'/' '{print $2}' \
  | sort \
  | uniq)

if [ -z "$CHANGED_DIRS" ]; then
  echo "No changes in ./images. Not generating any jobs."
  echo "stages: []" > generated-child.yml
else
  echo "stages:" > generated-child.yml
  echo "  - build" >> generated-child.yml
  echo "  - push"  >> generated-child.yml
  echo "  - update-pvc"  >> generated-child.yml

  for DIR in $CHANGED_DIRS; do
    cat >> generated-child.yml <<EOF
build-${DIR}:
  stage: build
  image: docker:latest
  services:
    - name: docker:dind
  before_script:
    - export HTTP_PROXY=\$HTTP_PROXY
    - export HTTPS_PROXY=\$HTTPS_PROXY
    - export NO_PROXY=\$NO_PROXY
    - docker login -u "\$ARTIFACTORY_USER" -p "\$ARTIFACTORY_PASS" "\$ARTIFACTORY_URL"
  script:
    - echo "Building image for $DIR"
    - docker build --build-arg HTTP_PROXY=\$HTTP_PROXY \
                   --build-arg HTTPS_PROXY=\$HTTPS_PROXY \
                   --build-arg NO_PROXY=\$NO_PROXY \
                   -t "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/$DIR:latest" \
                   ./images/$DIR

push-${DIR}:
  stage: push
  image: docker:latest
  services:
    - name: docker:dind
  needs: ["build-${DIR}"]
  before_script:
    - export HTTP_PROXY=\$HTTP_PROXY
    - export HTTPS_PROXY=\$HTTPS_PROXY
    - export NO_PROXY=\$NO_PROXY
    - docker login -u "\$ARTIFACTORY_USER" -p "\$ARTIFACTORY_PASS" "\$ARTIFACTORY_URL"
  script:
    - echo "Pushing image for $DIR"
    - docker push "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/$DIR:latest"
  
update-pvc-${DIR}:
  stage: update-pvc
  image: ubuntu:22.04
  needs: ["push-${DIR}"]
  before_script:
    - export HTTP_PROXY=\$HTTP_PROXY
    - export HTTPS_PROXY=\$HTTPS_PROXY
    - export NO_PROXY=\$NO_PROXY
    - apt-get update -yq
    - apt-get install -yq curl jq git
  variables:
    JENKINS_URL: "https://jenkins.redge.com"
    JENKINS_JOB_PATH: "job/DSW/job/PVC-Updater"
  script:
    - |
      # Dynamic parameters
      IMAGE_REF="\${DOCKER_REGISTRY}/\${DOCKER_REPOSITORY}/${DIR}:latest"
      
      echo "=== 🚦 ETAP UPDATE-PVC ==="
      echo "📌 Zmienne:"
      echo "   IMAGE_REF: \$IMAGE_REF"
      echo "   JENKINS_JOB_PATH: \$JENKINS_JOB_PATH"

      # Get CRUMB for CSRF protection
      echo "=== 🔒 Pobieranie CRUMB ==="
      CRUMB_JSON=\$(curl -s -u "\${JENKINS_USER}:\${JENKINS_API_TOKEN}" \\
        "\${JENKINS_URL}/crumbIssuer/api/json")
      
      if ! CRUMB=\$(echo "\$CRUMB_JSON" | jq -r '.crumb'); then
        echo "❌ Błąd parsowania CRUMB:"
        exit 1
      fi
      CRUMB_HEADER=\$(echo "\$CRUMB_JSON" | jq -r '.crumbRequestField')

      # Trigger Jenkins job
      echo "===  Wywołanie Jenkinsa ==="
      FULL_URL="\${JENKINS_URL}/\${JENKINS_JOB_PATH}/buildWithParameters"
      echo " URL: \$FULL_URL"

      HTTP_STATUS=\$(curl -w "%{http_code}" -s -o /tmp/jenkins_response \\
        -X POST \\
        -u "\${JENKINS_USER}:\${JENKINS_API_TOKEN}" \\
        -H "\${CRUMB_HEADER}: \${CRUMB}" \\
        --data-urlencode "IMAGE_NAME=\${IMAGE_REF}" \\
        "\$FULL_URL")

      echo "📡 Status HTTP: \$HTTP_STATUS"
      
      if [ "\$HTTP_STATUS" = "201" ]; then
        echo "✅ Job uruchomiony pomyślnie!"
        echo "⚙️ Szczegóły: \${JENKINS_URL}/\${JENKINS_JOB_PATH}"
      else
        echo "❌ Błąd! Odpowiedź:"
        cat /tmp/jenkins_response
        exit 1
      fi
  rules:
    - if: \$CI_COMMIT_BRANCH == "main"

EOF
  done
fi
echo "Pipeline generated successfully"   