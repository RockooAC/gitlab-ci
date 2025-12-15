#!/bin/sh
#
# Skrypt generujący dynamiczny plik child pipeline: generated-child.yml
# Wywoływany przez job 'generate-jobs' w .gitlab-ci.yml

set -eu

TMP_FILES=""

cleanup() {
  if [ -n "$TMP_FILES" ]; then
    # shellcheck disable=SC2086
    rm -f $TMP_FILES
  fi
}

trap cleanup EXIT

is_valid_identifier() {
  case "$1" in
    *[!A-Za-z0-9._-]*|"") return 1 ;;
    *) return 0 ;;
  esac
}

echo "Identifying changed directories in ./images"

FROM_REF="${CI_COMMIT_BEFORE_SHA:-HEAD~1}"
TO_REF="${CI_COMMIT_SHA:-HEAD}"

case "$FROM_REF" in
  0000000000000000000000000000000000000000)
    FROM_REF="${TO_REF}~1"
    ;;
esac

if ! git rev-parse --verify "$FROM_REF" >/dev/null 2>&1; then
  echo "Fallback: reference $FROM_REF not found, diffing against empty tree"
  FROM_REF=$(git hash-object -t tree /dev/null)
fi

CHANGED_DIRS=$(git diff --name-only "$FROM_REF" "$TO_REF" -- ./images \
  | awk -F'/' 'NF>=2 {print $2}' \
  | sort -u \
  | tr '\n' ' ' \
  | xargs)

echo "Base directories found in diff: ${CHANGED_DIRS:-"<none>"}"

echo "Scanning Dockerfiles for parent-child relationships (by local dir name)"
DEPENDENCY_PAIRS=""
for DOCKERFILE in images/*/Dockerfile; do
  [ -f "$DOCKERFILE" ] || continue
  CHILD_DIR=$(basename "$(dirname "$DOCKERFILE")")
  if ! is_valid_identifier "$CHILD_DIR"; then
    echo "Invalid directory name for job/image id: ${CHILD_DIR}" >&2
    exit 1
  fi
  while IFS= read -r IMAGE_REF; do
    REF_NO_TAG=${IMAGE_REF%%[:@]*}
    BASE_IMAGE=${REF_NO_TAG##*/}

    if ! is_valid_identifier "$BASE_IMAGE"; then
      echo "Skipping dependency with invalid parent name: ${BASE_IMAGE}" >&2
      continue
    fi

    if [ -d "images/${BASE_IMAGE}" ]; then
      PAIR="${BASE_IMAGE}:${CHILD_DIR}"
      case " $DEPENDENCY_PAIRS " in
        *" $PAIR "*) ;;
        *) DEPENDENCY_PAIRS="$DEPENDENCY_PAIRS $PAIR" ;;
      esac
    fi
  done <<EOF_FROM
$(
  awk '
    BEGIN { img_count=0 }
    toupper($1)=="FROM" {
      img=""; stage=""
      for (i=2; i<=NF; i++) {
        if ($i ~ /^--platform=/) { continue }
        if (img=="") { img=$i; continue }
        if (toupper($i)=="AS" && i+1<=NF) { stage=$(i+1); break }
      }
      if (img=="") { next }
      images[++img_count]=img
      if (stage!="") { stage_seen[stage]=1 }
    }
    END {
      for (i=1; i<=img_count; i++) {
        img=images[i]
        if (img in stage_seen) { continue }
        print img
      }
    }
  ' "$DOCKERFILE"
)
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

  MATRIX_FILE="images/${DIR}/build-matrix.env"

  if [ -f "$MATRIX_FILE" ]; then
    echo "Matrix file detected for ${DIR}: ${MATRIX_FILE}"

    EXPLICIT_DEFAULT_KEY=""
    VARIANT_TMP=$(mktemp)
    TMP_FILES="$TMP_FILES $VARIANT_TMP"

    while IFS= read -r MATRIX_LINE; do
      MATRIX_LINE=$(printf "%s" "$MATRIX_LINE" | tr -d '\r')
      MATRIX_LINE=${MATRIX_LINE%%#*}
      MATRIX_LINE=${MATRIX_LINE#${MATRIX_LINE%%[![:space:]]*}}
      MATRIX_LINE=${MATRIX_LINE%${MATRIX_LINE##*[![:space:]]}}

      [ -z "$MATRIX_LINE" ] && continue

      MATRIX_KEY_RAW=${MATRIX_LINE%%=*}
      MATRIX_VALUE_RAW=${MATRIX_LINE#*=}

      MATRIX_KEY=${MATRIX_KEY_RAW#${MATRIX_KEY_RAW%%[![:space:]]*}}
      MATRIX_KEY=${MATRIX_KEY%${MATRIX_KEY##*[![:space:]]}}

      MATRIX_VALUE=${MATRIX_VALUE_RAW#${MATRIX_VALUE_RAW%%[![:space:]]*}}
      MATRIX_VALUE=${MATRIX_VALUE%${MATRIX_VALUE##*[![:space:]]}}

      if [ "$MATRIX_KEY" = "default" ]; then
        if [ -z "$MATRIX_VALUE" ]; then
          echo "Skipping matrix line with empty default selector: ${MATRIX_LINE}"
          continue
        fi
        EXPLICIT_DEFAULT_KEY="$MATRIX_VALUE"
        continue
      fi

      if [ -z "$MATRIX_KEY" ] || [ "$MATRIX_KEY" = "$MATRIX_VALUE" ]; then
        echo "Skipping invalid matrix line: ${MATRIX_LINE}"
        continue
      fi

      if [ -z "$MATRIX_VALUE" ]; then
        echo "Skipping matrix line with empty value: ${MATRIX_LINE}"
        continue
      fi

      if ! is_valid_identifier "$MATRIX_KEY"; then
        echo "Skipping matrix line with unsafe key: ${MATRIX_LINE}"
        continue
      fi

      printf "%s=%s\n" "$MATRIX_KEY" "$MATRIX_VALUE" >> "$VARIANT_TMP"
    done < "$MATRIX_FILE"

    if [ ! -s "$VARIANT_TMP" ]; then
      echo "No valid matrix entries found in ${MATRIX_FILE}."
      exit 1
    fi

    DEFAULT_VARIANT_KEY=""
    DEFAULT_VARIANT_JOB=""

    VARIANT_KEYS=$(awk -F'=' 'NF>=2 {print $1}' "$VARIANT_TMP" | sort)

    if [ -n "$EXPLICIT_DEFAULT_KEY" ]; then
      if ! is_valid_identifier "$EXPLICIT_DEFAULT_KEY"; then
        echo "Invalid default selector: ${EXPLICIT_DEFAULT_KEY}" >&2
        exit 1
      fi
      if printf "%s\n" "$VARIANT_KEYS" | grep -qx "$EXPLICIT_DEFAULT_KEY"; then
        DEFAULT_VARIANT_KEY="$EXPLICIT_DEFAULT_KEY"
      else
        echo "Explicit default ${EXPLICIT_DEFAULT_KEY} not found for ${DIR}."
        exit 1
      fi
    else
      DEFAULT_VARIANT_KEY=$(printf "%s\n" "$VARIANT_KEYS" | head -n1)
    fi

    DEFAULT_VARIANT_JOB="build-push-${DIR}-${DEFAULT_VARIANT_KEY}"

    while IFS='=' read -r MATRIX_KEY MATRIX_VALUE; do
      [ -z "$MATRIX_KEY" ] && continue

      JOB_NAME="build-push-${DIR}-${MATRIX_KEY}"
      IMAGE_TAG="${MATRIX_KEY}"

      {
        echo "${JOB_NAME}:"
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
    - echo "Building image for ${DIR} (${IMAGE_TAG})"
    - docker build --build-arg HTTP_PROXY=\$HTTP_PROXY \
                   --build-arg HTTPS_PROXY=\$HTTPS_PROXY \
                   --build-arg NO_PROXY=\$NO_PROXY \
                   --build-arg PYTHON_VERSION=${MATRIX_VALUE} \
                   -t "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/${DIR}:${IMAGE_TAG}" \
                   ./images/${DIR}
    - echo "Pushing image for ${DIR}:${IMAGE_TAG}"
    - docker push "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/${DIR}:${IMAGE_TAG}"

update-pvc-${DIR}-${IMAGE_TAG}:
  stage: update-pvc
  image: ubuntu:22.04
  needs: ["${JOB_NAME}"]
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
      IMAGE_REF="\${DOCKER_REGISTRY}/\${DOCKER_REPOSITORY}/${DIR}:${IMAGE_TAG}"

      echo "=== 🚦 ETAP UPDATE-PVC (${DIR}:${IMAGE_TAG}) ==="
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
    - if: \$CI_COMMIT_BRANCH == \$CI_DEFAULT_BRANCH

EOF_JOB
      } >> generated-child.yml
    done < "$VARIANT_TMP"

    {
      echo "build-push-${DIR}:"
      echo "  stage: build"
      echo "  image: docker:latest"
      echo "  services:"
      echo "    - name: docker:dind"
      echo "  needs:"
      if [ -n "$NEED_PARENTS" ]; then
        for P in $NEED_PARENTS; do
          echo "    - \"build-push-${P}\""
        done
      fi
      echo "    - \"${DEFAULT_VARIANT_JOB}\""
      cat <<EOF_JOB
  before_script:
    - export HTTP_PROXY=\$HTTP_PROXY
    - export HTTPS_PROXY=\$HTTPS_PROXY
    - export NO_PROXY=\$NO_PROXY
    - docker login -u "\$ARTIFACTORY_USER" -p "\$ARTIFACTORY_PASS" "\$ARTIFACTORY_URL"
  script:
    - echo "Promoting default variant ${DEFAULT_VARIANT_KEY} of ${DIR} to :latest"
    - |
        RETRIES=5
        IMAGE_REF="\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/${DIR}:${DEFAULT_VARIANT_KEY}"
        for ATTEMPT in \$(seq 1 \$RETRIES); do
          if docker pull "\$IMAGE_REF"; then
            break
          fi
          if [ "\$ATTEMPT" -eq "\$RETRIES" ]; then
            echo "Failed to pull image after \$RETRIES attempts"
            exit 1
          fi
          SLEEP_SECONDS=$((2 ** (ATTEMPT - 1)))
          echo "Pull failed (attempt \$ATTEMPT/\$RETRIES), retrying in \${SLEEP_SECONDS}s for ${DIR}:${DEFAULT_VARIANT_KEY}..."
          sleep "\$SLEEP_SECONDS"
        done
    - docker tag "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/${DIR}:${DEFAULT_VARIANT_KEY}" \
                 "\$DOCKER_REGISTRY/\$DOCKER_REPOSITORY/${DIR}:latest"
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
    - if: \$CI_COMMIT_BRANCH == \$CI_DEFAULT_BRANCH

EOF_JOB
    } >> generated-child.yml

    continue
  fi

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
    - if: \$CI_COMMIT_BRANCH == \$CI_DEFAULT_BRANCH

EOF_JOB
  } >> generated-child.yml
done

echo "Pipeline generated successfully"

