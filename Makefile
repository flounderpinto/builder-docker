ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

DOCKER_REGISTRY=index.docker.io/flounder5
DOCKER_REPO=builder-docker
DOCKER_PLATFORM=linux/amd64,linux/arm/v7

.PHONY: docker

#To prevent the circular dependency, this repo calls the dockerBuild script directly
#  instead of through the builder-docker image.
docker:
	./src/dockerBuild.sh dockerBuild -e ${DOCKER_REGISTRY} -r ${DOCKER_REPO} -p ${DOCKER_PLATFORM} -d "." -f ./docker/Dockerfile ${ARGS}

#Everything right of the pipe is order-only prerequisites.
all: | docker
