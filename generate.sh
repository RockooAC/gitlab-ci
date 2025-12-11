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
  done <<EOF
$(grep -E '^FROM[[:space:]]+' "$DOCKERFILE" | awk '{print $2}')
EOF
done

ALL_DIRS=""
DEPENDENTS_ADDED=""
DEPTH_MAP=""

append_unique() {
  VALUE="$1"
  case " $ALL_DIRS " in
    *" $VALUE "*) ;;
    *) ALL_DIRS="$ALL_DIRS $VALUE" ;;
  esac
}

get_depth() {
  KEY="$1"
  for ENTRY in $DEPTH_MAP; do
    NAME=${ENTRY%%:*}
    DEPTH=${ENTRY#*:}
    if [ "$NAME" = "$KEY" ]; then
      echo "$DEPTH"
      return
    fi
  done
  echo ""
}

set_depth() {
  KEY="$1"
  VALUE="$2"

  UPDATED=""
  FOUND="0"
  for ENTRY in $DEPTH_MAP; do
    NAME=${ENTRY%%:*}
    DEPTH=${ENTRY#*:}
    if [ "$NAME" = "$KEY" ]; then
      UPDATED="$UPDATED ${NAME}:$VALUE"
      FOUND="1"
    else
      UPDATED="$UPDATED $ENTRY"
    fi
  done

  if [ "$FOUND" = "0" ]; then
    UPDATED="$UPDATED ${KEY}:$VALUE"
  fi

  DEPTH_MAP="$UPDATED"
}

for DIR in $CHANGED_DIRS; do
  append_unique "$DIR"
  set_depth "$DIR" 0
done

if [ -n "$ALL_DIRS" ]; then
  ADDED=1
  while [ $ADDED -eq 1 ]; do
    ADDED=0
    for PAIR in $DEPENDENCY_PAIRS; do
      BASE=${PAIR%%:*}
      DEPENDENT=${PAIR#*:}

      BASE_DEPTH=$(get_depth "$BASE")
      if [ -n "$BASE_DEPTH" ]; then
        DEPTH_CANDIDATE=$((BASE_DEPTH + 1))
        CURRENT_DEPTH=$(get_depth "$DEPENDENT")

        if [ -z "$CURRENT_DEPTH" ] || [ $DEPTH_CANDIDATE -lt $CURRENT_DEPTH ]; then
          append_unique "$DEPENDENT"
          set_depth "$DEPENDENT" "$DEPTH_CANDIDATE"
          case " $DEPENDENTS_ADDED " in
            *" $DEPENDENT "*) ;;
            *) DEPENDENTS_ADDED="$DEPENDENTS_ADDED $DEPENDENT" ;;
          esac
          ADDED=1
        fi
      fi
    done
  done
fi

if [ -n "$DEPENDENTS_ADDED" ]; then
  echo "Dependents added: $DEPENDENTS_ADDED"
fi

MAX_DEPTH=0
for ENTRY in $DEPTH_MAP; do
  DEPTH=${ENTRY#*:}
  if [ "$DEPTH" -gt "$MAX_DEPTH" ]; then
    MAX_DEPTH="$DEPTH"
  fi
done

if [ -z "$ALL_DIRS" ]; then
  echo "No changes in ./images. Not generating any jobs."
  echo "stages: []" > generated-child.yml
else
  echo "stages:" > generated-child.yml
  DEPTH=0
  while [ $DEPTH -le $MAX_DEPTH ]; do
    echo "  - build-$DEPTH" >> generated-child.yml
    echo "  - push-$DEPTH" >> generated-child.yml
    DEPTH=$((DEPTH + 1))
  done
  echo "  - update-pvc"  >> generated-child.yml

  echo "Directories selected for build: $ALL_DIRS"

  for DIR in $ALL_DIRS; do
    DIR_DEPTH=$(get_depth "$DIR")
    cat >> generated-child.yml <<EOF
build-${DIR}:
  stage: build-${DIR_DEPTH}
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
  stage: push-${DIR_DEPTH}
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