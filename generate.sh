#!/bin/sh
#
# Skrypt generujący dynamiczny plik child pipeline: generated-child.yml
# Wywoływany przez job 'generate-jobs' w .gitlab-ci.yml

set -eu

echo "Identifying changed directories in ./images"

FROM_REF="${CI_COMMIT_BEFORE_SHA:-HEAD~1}"
TO_REF="${CI_COMMIT_SHA:-HEAD}"

CHANGED_DIRS=$(git diff --name-only "$FROM_REF" "$TO_REF" -- ./images \
  | awk -F'/' 'NF>=2 {print $2}' \
  | sort -u)

echo "Base directories found in diff: ${CHANGED_DIRS:-"<none>"}"

echo "Scanning Dockerfiles for parent-child relationships (by local dir name)"
DEPENDENCY_PAIRS=""
for DOCKERFILE in images/*/Dockerfile; do
  [ -f "$DOCKERFILE" ] || continue
  CHILD_DIR=$(basename "$(dirname "$DOCKERFILE")")
  while IFS= read -r IMAGE_REF; do
    BASE_IMAGE=${IMAGE_REF##*/}
    BASE_IMAGE=${BASE_IMAGE%%@*}
    BASE_IMAGE=${BASE_IMAGE%%:*}

    if [ -d "images/${BASE_IMAGE}" ]; then
      PAIR="${BASE_IMAGE}:${CHILD_DIR}"
      case " $DEPENDENCY_PAIRS " in
        *" $PAIR "*) ;;
        *) DEPENDENCY_PAIRS="$DEPENDENCY_PAIRS $PAIR" ;;
      esac
    fi
  done <<EOF_FROM
$(grep -E '^FROM[[:space:]]+' "$DOCKERFILE" | awk '{print $2}')
EOF_FROM
done

echo "Dependency pairs (BASE:CHILD): ${DEPENDENCY_PAIRS:-"<none>"}"

ALL_DIRS="$CHANGED_DIRS"
DEPENDENTS_ADDED=""

if [ -n "$ALL_DIRS" ]; then
  ADDED=1
  while [ $ADDED -eq 1 ]; do
    ADDED=0
    for PAIR in $DEPENDENCY_PAIRS; do
      BASE=${PAIR%%:*}
      DEPENDENT=${PAIR#*:}

      case " $ALL_DIRS " in
        *" $BASE "*)
          case " $ALL_DIRS " in
            *" $DEPENDENT "*) ;;
            *)
              ALL_DIRS="$ALL_DIRS $DEPENDENT"
              DEPENDENTS_ADDED="$DEPENDENTS_ADDED $DEPENDENT"
              ADDED=1
              ;;
          esac
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
  echo "Pipeline generated successfully (empty)."
  exit 0
fi

echo "Directories selected for build: $ALL_DIRS"

cat > generated-child.yml <<EOF_YML
stages:
  - build
  - update-pvc

EOF_YML

for DIR in $ALL_DIRS; do
  NEED_PARENTS=""
  for PAIR in $DEPENDENCY_PAIRS; do
    BASE=${PAIR%%:*}
    DEP=${PAIR#*:}
    if [ "$DEP" = "$DIR" ]; then
      case " $ALL_DIRS " in
        *" $BASE "*) NEED_PARENTS="$NEED_PARENTS $BASE" ;;
      esac
    fi
  done

  {
    echo "build-push-${DIR}:"
    echo "  stage: build"
    echo "  image: docker:latest"
    echo "  services:"
    echo "    - name: docker:dind"
    if [ -n "$NEED_PARENTS" ]; then
      echo "  needs:"
      for P in $NEED_PARENTS; do
        echo "    - \"build-push-${P}\""
      done
    fi
    cat <<EOF_JOB
  before_script:
    - export HTTP_PROXY=\$HTTP_PROXY
    - export HTTPS_PROXY=\$HTTPS_PROXY
    - export NO_PROXY=\$NO_PROXY
    - docker login -u "\$ARTIFACTORY_USER" -p "\$ARTIFACTORY_PASS" "\$ARTIFACTORY_URL"
  script:
    - echo "Building image for ${DIR}"
    - docker build --build-arg HTTP_PROXY=\$HTTP_PROXY \
                   --build-arg HTTPS_PROXY=\$HTTPS_PROXY \
                   --build-arg NO_PROXY=\$NO_PROXY \
                   -t "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/${DIR}:latest" \
                   ./images/${DIR}
    - echo "Pushing image for ${DIR}"
    - docker push "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/${DIR}:latest"

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
      IMAGE_REF="\${DOCKER_REGISTRY}/\${DOCKER_REPOSITORY}/${DIR}:latest"

      echo "=== 🚦 ETAP UPDATE-PVC (${DIR}) ==="
      echo "📌 Zmienne:"
      echo "   IMAGE_REF: \$IMAGE_REF"
      echo "   JENKINS_JOB_PATH: \$JENKINS_JOB_PATH"

      echo "=== 🔒 Pobieranie CRUMB ==="
      CRUMB_JSON=\$(curl -s -u "\${JENKINS_USER}:\${JENKINS_API_TOKEN}" \
        "\${JENKINS_URL}/crumbIssuer/api/json")

      if ! CRUMB=\$(echo "\$CRUMB_JSON" | jq -r '.crumb'); then
        echo "❌ Błąd parsowania CRUMB:"
        exit 1
      fi
      CRUMB_HEADER=\$(echo "\$CRUMB_JSON" | jq -r '.crumbRequestField')

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
  } >> generated-child.yml
done

echo "Pipeline generated successfully"

