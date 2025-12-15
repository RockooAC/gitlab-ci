# GitLab CI pipeline for Docker images

This repository contains the automation that builds Docker images stored under `./images/*`, publishes them to Harbor, and optionally triggers PVC updates in Jenkins. The pipeline is driven by a generator script (`generate.sh`) that produces a child pipeline definition on the fly based on repository changes and declared dependencies.

## Workflow overview

- **When it runs**: the parent pipeline executes only on pushes to `main`; merge request pipelines are disabled. `generate.sh` runs in stage `gen` and emits `generated-child.yml`, which the `child-pipeline` job triggers in stage `child` using `strategy: depend` so the parent reflects the child status.【F:.gitlab-ci.yml†L1-L43】
- **Stages in the child pipeline**: every generated pipeline has two stages: `build` (image build/push and promotion) and `update-pvc` (optional Jenkins volume refresh).【F:generate.sh†L115-L149】

## Inputs and environment

- **Registry access**: Harbor credentials and registry coordinates are supplied via `ARTIFACTORY_URL`, `ARTIFACTORY_USER`, `ARTIFACTORY_PASS`, `DOCKER_REGISTRY`, and `DOCKER_REPOSITORY`. Jobs log in using `docker login --password-stdin` to avoid leaking secrets in process listings.【F:generate.sh†L261-L303】【F:.gitlab-ci.yml†L14-L30】
- **Proxy handling**: `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` are exported in each build/update job and passed as `--build-arg` values to Docker builds so proxy-aware images can be produced consistently.【F:generate.sh†L261-L303】

## Change detection and dependency expansion

1. **Detect changed images**: the generator diffs the current commit against the previous (`FROM_REF` vs `TO_REF`) and collects directories under `images/` that changed, validating names to `A-Za-z0-9._-`.【F:generate.sh†L27-L69】
2. **Discover parent-child links**: every `images/*/Dockerfile` is parsed for `FROM` directives. The base image path is truncated to its final component (e.g., `harbor/.../web-18:tag` → `web-18`), and if a matching directory exists under `images/`, a dependency pair `BASE:CHILD` is recorded. `FROM` entries that point to previously declared build stages (`FROM <stage>`) are ignored so stage names never become parents; all `--*` tokens are skipped; non-literal references (`$`/`${}`) emit warnings and are best-effort only—use literal `FROM` values for guaranteed detection.【F:generate.sh†L71-L115】
3. **Close the dependency graph**: any dependents of changed bases are added transitively so children rebuild when parents change, even if the child files were untouched.【F:generate.sh†L117-L147】
4. **Empty result handling**: if no images are selected after expansion, the generator emits a minimal child file with no stages and exits successfully.【F:generate.sh†L149-L157】

## Build modes

### Images without a matrix

- **Jobs produced**: `build-push-<dir>` builds and pushes `<dir>:latest`; `update-pvc-<dir>` (default branch only) triggers Jenkins with `IMAGE_NAME=<dir>:latest`. Parent needs are attached when the image depends on local parents.【F:generate.sh†L343-L409】
- **Promotion model**: there is no separate promotion step—`:latest` is built directly (no retry wrapper beyond Docker’s defaults).【F:generate.sh†L343-L377】

### Images with a matrix (`images/<dir>/build-matrix.env`)

- **Matrix parsing**: blank lines/comments are skipped; keys and values are trimmed; `default=<key>` optionally defines the variant to promote to `:latest` (otherwise the first key alphabetically). Duplicate keys are rejected. Keys must pass identifier validation.【F:generate.sh†L169-L242】
- **Variant jobs**: `build-push-<dir>-<key>` builds with `PYTHON_VERSION=<value>` and pushes `:<key>`. Each variant has matching `update-pvc-<dir>-<key>` gated to the default branch.【F:generate.sh†L244-L323】
- **Promotion job**: `build-push-<dir>` pulls the default variant with retries, retags it to `:latest`, and pushes. `update-pvc-<dir>` consumes the promoted tag.【F:generate.sh†L325-L409】

## Dependency handling with matrices

- **Variant-aware needs**: for each child variant job, parents with their own matrix are referenced by the same variant key (`build-push-<parent>-<key>`); parents without a matrix fall back to their single job (`build-push-<parent>`). This preserves variant-to-variant ordering where possible while keeping legacy images working.【F:generate.sh†L244-L303】
- **Promotion needs**: the promotion job always depends on the child’s default variant and, when parents exist, on their promotion jobs (`build-push-<parent>`), keeping all `:latest` tags aligned before downstream promotions run. Variant jobs themselves only use variant-to-variant needs when the parent has a matrix; otherwise they fall back to the parent’s single job.【F:generate.sh†L244-L380】

## Dockerfile conventions for dependency resolution

- **Local parents**: to link images, ensure the final path segment of the `FROM` image matches a directory under `images/` (e.g., `FROM .../jenkins/web-18:latest` ↔ `images/web-18`). Registry prefixes and tags are ignored for discovery.【F:generate.sh†L71-L115】
- **Template registry prefixes**: `FROM ${REGISTRY}/.../web-18` triggers a warning; the script still attempts to resolve the parent via the trailing component. Detection can be inaccurate for complex expansions, so prefer literal `FROM` values for local parents.【F:generate.sh†L71-L115】
- **Stage aliases**: internal build stages (`FROM builder AS base`, `FROM base`) are ignored as dependencies to avoid false positives.【F:generate.sh†L83-L115】

## Examples and common flows

### Single image without a matrix

```
images/web-18/
└── Dockerfile   # FROM ubuntu:22.04
```

Generated jobs:

- `build-push-web-18` → builds and pushes `.../web-18:latest`
- `update-pvc-web-18` → (default branch) calls Jenkins with `IMAGE_NAME=.../web-18:latest`

### Image with variants (matrix)

```
images/python/
├── Dockerfile
└── build-matrix.env

default=py311
py310=3.10
py311=3.11
```

Generated jobs:

- `build-push-python-py310`, `build-push-python-py311` (+ matching `update-pvc-*`)
- `build-push-python` → promotes default (`py311`) to `:latest`
- `update-pvc-python` → (default branch) Jenkins with `IMAGE_NAME=.../python:latest`

### Parent-child with matrices

```
images/web-18/build-matrix.env
default=py311
py311=3.11

images/android/build-matrix.env
default=py311
py311=3.11

images/android/Dockerfile
FROM harbor.redgelabs.com/jenkins/web-18:latest
```

- `build-push-android-py311` gets `needs: ["build-push-web-18-py311"]` because the parent has the same variant key.
- `build-push-android` (promotion) waits on `build-push-android-py311` plus parent promotions (`build-push-web-18`).

If you parameterize the tag (for example, `FROM .../web-18:$TAG`), the generator logs a warning and attempts to resolve the parent by trimming the tag and taking the trailing path component. This is best-effort only—use literal `FROM` values for reliable local dependency detection.【F:generate.sh†L71-L115】

### PVC update call (behavior reference)

For any job `update-pvc-<dir>[-<variant>]`:

1. Runs only on the default branch (`CI_DEFAULT_BRANCH`).
2. Calls Jenkins with:
   - `IMAGE_NAME=<DOCKER_REGISTRY>/<DOCKER_REPOSITORY>/<dir>:<tag>`
   - crumb fetched from `.../crumbIssuer/api/json`.
3. Exits non-zero if Jenkins does not return HTTP 201, printing the response for diagnostics.

## Jenkins PVC update stage

- **Purpose**: refreshes Persistent Volume contents so new Jenkins agent pods have the updated tools built into the image.
- **Invocation**: each build job has a paired `update-pvc` job that calls Jenkins’ `buildWithParameters` with `IMAGE_NAME=<registry>/<repo>/<image>:<tag>` after obtaining a crumb. Runs only on the default branch.【F:generate.sh†L277-L323】【F:generate.sh†L363-L409】

## Checklist for contributors

1. Place each image under `images/<name>/Dockerfile`; ensure `<name>` matches the trailing component of any local `FROM` references.
2. Use `build-matrix.env` to define variants when needed; keep keys consistent across parent/child images if variant-to-variant ordering matters.
3. Expect child variant jobs to wait on matching parent variants when parents have matrices; otherwise they wait on the parent’s promotion job.
4. Keep proxy settings and Harbor credentials configured via CI variables; no secrets in Dockerfile.
5. For PVC updates, ensure Jenkins jobs accept `IMAGE_NAME` and branch rules align with the default branch.
