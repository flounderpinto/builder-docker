USER=$(shell id -u):$(shell id -g)
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

CONTAINER_CODE_DIR=/opt/code

INIT_CMD=git submodule update --init --recursive
ANALYZE_CMD=cd ./src        && find . -name '*.sh' | xargs shellcheck -x && \
            cd ../test/unit && find . -name '*.sh' | xargs shellcheck -x
UNIT_TEST_CMD=cd ./test/unit && ./test.sh

DOCKER_REGISTRY=index.docker.io/flounder5

BUILDER_IMAGE=${DOCKER_REGISTRY}/builder-bash:v0.0.4
BUILDER_PULL_CMD=docker pull ${BUILDER_IMAGE}
BUILDER_RUN_CMD=${BUILDER_PULL_CMD} && \
    docker run \
        --rm \
        --user ${USER} \
        -v ${ROOT_DIR}:${CONTAINER_CODE_DIR} \
        -w ${CONTAINER_CODE_DIR} \
        ${BUILDER_IMAGE} /bin/bash -c

DOCKER_REPO=builder-docker

.PHONY: init analyze analyze_local unit_test unit_test_local docker

init:
	${INIT_CMD}

analyze:
	${BUILDER_RUN_CMD} "${ANALYZE_CMD}"

analyze_local:
	${ANALYZE_CMD}

unit_test:
	${BUILDER_RUN_CMD} "${UNIT_TEST_CMD}"

unit_test_local:
	${UNIT_TEST_CMD}

#To prevent the circular dependency, this repo calls the dockerBuild script directly
#  instead of through the builder-docker image.
docker:
	./src/dockerBuild.sh \
        dockerBuildStandardBranch \
        -e ${DOCKER_REGISTRY} \
        -r ${DOCKER_REPO} \
        ${ARGS}

#Everything right of the pipe is order-only prerequisites.
all: | init analyze unit_test docker
