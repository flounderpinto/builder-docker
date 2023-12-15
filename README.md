
# Builder Docker
A script to standardize and automate building docker images in CI/CD pipelines.

## Description
This repo contains a dockerBuild.sh script in this repo is a thin wrapper around the "docker build" (now buildx) command.  It also contains a Dockerfile that creates an image to contain the script's run environment.  The docker image of this repo lives at https://hub.docker.com/repository/docker/flounder5/builder-docker.  

This repo was born out of a desire to standardize docker image builds across a project/program/company/etc.  There was a need to handle 3 particular use-cases, as well as trying to simplify the process for developers that weren't docker experts.  The use cases are:
1. When building from a git branch that's the "main" branch, build/tag/push the image with the following tags:
	1. The full git version hash (i.e. the output from `git log -1 --pretty=%H` ).
 	2. The git branch name ('main').
	3. 'latest'.
2. When building from a git branch other than the "main" branch, build/tag/push the image with:
	1. The full git version hash.
	2. The git branch name.
3. When building from a git tag, build/tag/push the image with:
	1. The git tag name.

Using the option flags in the script, and modifications to the build pipeline file (Jenkinsfile, GitHub workflow file, etc.) the use cases can be tailored as needed.

## Usage

### Script syntax
```bash
Usage:
	dockerBuild.sh dockerBuild -e dockerRegistryName -r dockerRepoName -c buildContextDir -f dockerFile [-g gitRepoDir] [-p platform]... [-t tag]... [-b buildArg]... [-a arg]... [-n] [-o] [-h]
		-e - Docker registry name.
			e.g. "index.docker.io/my-registry"
		-r - Docker repo name.
			e.g. "builder-docker".
		-c - Docker build context.
		-f - Dockerfile location.
		-g - Git repo directory.
		-p - Target platform for build.
			Can be a comma-separated list or defined multiple times. 
			e.g. "linux/amd64", or "linux/amd64,linux/arm/v7"
		-t - Additional tags to apply to the image.
			Can be defined multiple times.
		-b - Build-arg values.
			Can be defined multiple times.
		-a - Additional docker build args passed directly to docker build.
			Can be a comma-separated list or defined multiple times.
		-h - Show this help.
```
There's 3 other functions in the script that simplify the 3 use cases above.
```bash
function dockerBuildStandardBranch 
{
    dockerBuild -c "." -f "./docker/Dockerfile" -g "." "$@"
}
function dockerBuildStandardMain
{
    dockerBuild -c "." -f "./docker/Dockerfile" -g "." -t "latest" "$@"
}
function dockerBuildStandardTag
{
    local TAG="$1"
    shift
    echo "${@}"
    dockerBuild -c "." -f "./docker/Dockerfile" -g "." -n -o -t "$TAG" "${@}"
}
```
### Script Makefile example
The commands to execute the script can be contained in a Makefile for ease of execution by either a human or a build pipeline.
```Makefile
DOCKER_REGISTRY=index.docker.io/flounder5

DOCKER_REPO=TODO-MY-DOCKER-REPO-NAME #Replace
DOCKER_BUILD_BRANCH_CMD=./src/dockerBuild.sh dockerBuildStandardBranch -e ${DOCKER_REGISTRY} -r ${DOCKER_REPO} ${ARGS}
DOCKER_BUILD_MAIN_CMD=./src/dockerBuild.sh dockerBuildStandardMain -e ${DOCKER_REGISTRY} -r ${DOCKER_REPO} ${ARGS}
DOCKER_BUILD_TAG_CMD=./src/dockerBuild.sh dockerBuildStandardTag ${TAG} -e ${DOCKER_REGISTRY} -r ${DOCKER_REPO} ${ARGS}

.PHONY: docker docker_main docker_tag

docker:
	${DOCKER_BUILD_BRANCH_CMD}

docker_main:
	${DOCKER_BUILD_MAIN_CMD}

docker_tag:
	test ${TAG}
	${DOCKER_BUILD_TAG_CMD}
```

### Docker Makefile example
The same Makefile that runs the builder-docker image instead.

```Makefile
ROOT_DIR:=$(shell dirname $(realpath  $(lastword  $(MAKEFILE_LIST))))

CONTAINER_CODE_DIR=/opt/code

DOCKER_REGISTRY=index.docker.io/flounder5

DOCKER_REPO=TODO-MY-DOCKER-REPO-NAME #TODO - Replace
DOCKER_BUILD_BRANCH_CMD=dockerBuildStandardBranch -e ${DOCKER_REGISTRY} -r ${DOCKER_REPO}  ${ARGS}
DOCKER_BUILD_MAIN_CMD=dockerBuildStandardMain -e ${DOCKER_REGISTRY} -r ${DOCKER_REPO}  ${ARGS}
DOCKER_BUILD_TAG_CMD=dockerBuildStandardTag ${TAG} -e ${DOCKER_REGISTRY} -r ${DOCKER_REPO}  ${ARGS}
DOCKER_BUILDER_IMAGE=flounder5/builder-docker:v0.0.9 #TODO - Set to latest release
DOCKER_BUILDER_PULL_CMD=docker pull ${DOCKER_BUILDER_IMAGE}
DOCKER_BUILDER_RUN_CMD=${DOCKER_BUILDER_PULL_CMD} && \
   docker run \
      --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v ${HOME}/.docker:/tmp/.docker:ro \
      -v ${ROOT_DIR}:${CONTAINER_CODE_DIR} \
      -w ${CONTAINER_CODE_DIR} \
      ${DOCKER_BUILDER_IMAGE}

.PHONY: docker docker_main docker_tag

docker:
	${DOCKER_BUILDER_RUN_CMD} ${DOCKER_BUILD_BRANCH_CMD}

docker_main:
	${DOCKER_BUILDER_RUN_CMD} ${DOCKER_BUILD_MAIN_CMD}

docker_tag:
	test ${TAG}
	${DOCKER_BUILDER_RUN_CMD} ${DOCKER_BUILD_TAG_CMD}
```

### GitHub workflow example
```yaml
name: CI

on:
  push:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.TODO }}#TODO - Insert username secret name here
          password: ${{ secrets.TODO }}#TODO - Insert access token secret name here

      - name: Docker build branch
        run: make docker
        if: ${{ github.ref_type == 'branch' && github.ref_name != 'main' }}

      - name: Docker build main
        run: make docker_main
        if: ${{ github.ref_type == 'branch' && github.ref_name == 'main' }}

      - name: Docker build tag
        run: make docker_tag TAG="${{github.ref_name}}"
        if: ${{ github.ref_type == 'tag' }}
```

## Issues/Shortcomings
1. The Docker image is hard-coded to a specific version of Docker.  Typically the entire product/project tracks a single version, so odds are that the version currently specified in this project is not going to map. Need to figure out the best way around that and provide examples.
	2. Maybe pull Docker out of the builder-docker image.  Then end-user creates a custom image `FROM flounder5/builder-docker:version` , and then installs their desired version.  In this scenario end-user could also specify DOCKER_REGISTRY value so that all users are pushing to same registry.

## License
Distributed under the MIT License. See `LICENSE.txt` for more information.