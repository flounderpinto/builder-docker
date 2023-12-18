# Builder Docker
A script to standardize and automate building docker images in CI/CD pipelines.

## Description
This repo contains a dockerBuild.sh script that is a thin wrapper around the "docker build" (now buildx) command. 

This repo was born out of a desire to standardize docker image builds across a project/program/company/etc.  There was a need to handle 3 particular use-cases, as well as trying to simplify the docker build process for developers.  The use cases are:
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
DOCKER_REGISTRY=index.docker.io/flounderpinto

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

### Docker
Typically you'll want to put this script along with the Docker CLI into a Docker container in order to run in a fully containerized environment.  Since each project/program/company/etc. typically standardizes on a version of Docker, it doesn't make sense for that Dockerfile to live here.  See the https://github.com/flounderpinto/builder-docker-flounderpinto repo for an example.

## License
Distributed under the MIT License. See `LICENSE.txt` for more information.