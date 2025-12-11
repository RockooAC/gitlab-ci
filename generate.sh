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

echo "Base directories found in last commit: ${CHANGED_DIRS:-"<none>"}"

PREFIX="${DOCKER_REGISTRY:-harbor.redgelabs.com}/${DOCKER_REPOSITORY:-jenkins}/"
DEPENDENCY_PAIRS=""

echo "Scanning Dockerfiles for parent-child relationships (prefix: $PREFIX)"
for DOCKERFILE in images/*/Dockerfile; do
  DIR=$(basename "$(dirname "$DOCKERFILE")")
  while IFS= read -r IMAGE_REF; do
    case "$IMAGE_REF" in
      "$PREFIX"*)
        BASE_IMAGE=${IMAGE_REF#"$PREFIX"}
        BASE_IMAGE=${BASE_IMAGE%%[:@]*}
        DEPENDENCY_PAIRS="$DEPENDENCY_PAIRS ${BASE_IMAGE}:${DIR}"
        ;;
    esac
  done <<EOF_INNER
$(grep -E '^FROM[[:space:]]+' "$DOCKERFILE" | awk '{print $2}')
EOF_INNER
done

ALL_DIRS=""
DEPENDENTS_ADDED=""

append_unique() {
  VALUE="$1"
  case " $ALL_DIRS " in
    *" $VALUE "*) ;;
    *) ALL_DIRS="$ALL_DIRS $VALUE" ;;
  esac
}

for DIR in $CHANGED_DIRS; do
  append_unique "$DIR"
done

if [ -n "$ALL_DIRS" ]; then
  ADDED=1
  while [ $ADDED -eq 1 ]; do
    ADDED=0
    for PAIR in $DEPENDENCY_PAIRS; do
      BASE=${PAIR%%:*}
      DEPENDENT=${PAIR#*:}

      case " $ALL_DIRS " in
        *" $BASE "*)
          append_unique "$DEPENDENT"
          case " $DEPENDENTS_ADDED " in
            *" $DEPENDENT "*) ;;
            *) DEPENDENTS_ADDED="$DEPENDENTS_ADDED $DEPENDENT" ;;
          esac
          ADDED=1
          ;;
      esac
    done
  done
fi

if [ -n "$DEPENDENTS_ADDED" ]; then
  echo "Dependents added: $DEPENDENTS_ADDED"
fi

if [ -z "$ALL_DIRS" ]; then
  echo "No changes in ./images. Not generating any jobs."
  echo "stages: []" > generated-child.yml
else
  echo "stages:" > generated-child.yml
  echo "  - build" >> generated-child.yml
  echo "  - update-pvc"  >> generated-child.yml

  echo "Directories selected for build: $ALL_DIRS"

  for DIR in $ALL_DIRS; do
    NEEDS=""
    for PAIR in $DEPENDENCY_PAIRS; do
      BASE=${PAIR%%:*}
      DEP=${PAIR#*:}
      if [ "$DEP" = "$DIR" ]; then
        case " $ALL_DIRS " in
          *" $BASE "*) NEEDS="$NEEDS build-push-$BASE" ;;
        esac
      fi
    done

    cat >> generated-child.yml <<EOF_JOB
build-push-${DIR}:
  stage: build
  image: docker:latest
  services:
    - name: docker:dind
EOF_JOB

    if [ -n "$NEEDS" ]; then
      echo "  needs:" >> generated-child.yml
      for N in $NEEDS; do
        echo "    - \"$N\"" >> generated-child.yml
      done
    fi

    cat >> generated-child.yml <<EOF_JOB
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
    - echo "Pushing image for $DIR"
    - docker push "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/$DIR:latest"

update-pvc-${DIR}:
  stage: update-pvc
  image: ubuntu:22.04
  needs: ["build-push-${DIR}"]
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
      CRUMB_JSON=\$(curl -s -u "\${JENKINS_USER}:\${JENKINS_API_TOKEN}" \
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

      HTTP_STATUS=\$(curl -w "%{http_code}" -s -o /tmp/jenkins_response \
        -X POST \
        -u "\${JENKINS_USER}:\${JENKINS_API_TOKEN}" \
        -H "\${CRUMB_HEADER}: \${CRUMB}" \
        --data-urlencode "IMAGE_NAME=\${IMAGE_REF}" \
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

EOF_JOB
  done
fi
echo "Pipeline generated successfully"
