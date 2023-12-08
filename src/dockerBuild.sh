#!/bin/bash

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function dockerBuildUsage
{
    echo $'Usage:'
    echo $'\tdockerBuild.sh dockerBuild [-t tag1,tag2,tagN] [-a] [-h] <-e dockerRegistryName> <-r dockerRepoName> <-d buildContextDir> <-f dockerFile> <-g gitRepoDir>'
    echo $'\t\t-t - A comma-separated list of additional tags to apply to the image'
    echo $'\t\t-e - Docker registry name.  e.g. "index.docker.io/my-registry"'
    echo $'\t\t-r - Docker repo name. e.g. "builder-docker"'
    echo $'\t\t-d - Docker build context'
    echo $'\t\t-f - Dockerfile'
    echo $'\t\t-g - Git repo directory'
    echo $'\t\t-p - Build platform'
    echo $'\t\t-b - Build-arg values.  Can be defined multiple times.'
    echo $'\t\t-a - Additional docker build args passed directly to docker build'
    echo $'\t\t-h - Show this help.'
}

# Builds and tags a docker image.
function dockerBuild
{
    local TAGS=()
    local DOCKER_REGISTRY=""
    local DOCKER_REPO=""
    local BUILD_CONTEXT_DIR=""
    local DOCKER_FILE=""
    local GIT_DIR=""
    local PLATFORM=""
    local BUILD_ARGS=()
    local ADDITIONAL_BUILD_FLAGS=""

    while getopts ":t:e:r:d:f:g:p:b:a:h" opt; do
      case $opt in
        t)
          IFS=',' read -ra TAG_LIST <<< "$OPTARG"
          for i in "${TAG_LIST[@]}"; do
            TAGS+=("$i")
          done
          ;;
        e)
          DOCKER_REGISTRY=$OPTARG
          ;;
        r)
          DOCKER_REPO=$OPTARG
          ;;
        d)
          BUILD_CONTEXT_DIR=$OPTARG
          ;;
        f)
          DOCKER_FILE=$OPTARG
          ;;
        g)
          GIT_DIR=$OPTARG
          #The location of the .git directory is required.
          GIT_DIR="$GIT_DIR/.git"
          ;;
        p)
          PLATFORM=$OPTARG
          ;;
        b)
          BUILD_ARGS+=("$OPTARG")
          ;;
        a)
          ADDITIONAL_BUILD_FLAGS="$OPTARG"
          echo "$OPTARG"
          ;;
        h)
          dockerBuildUsage
          exit 1
          ;;
        \?)
          echo "Invalid option: -$OPTARG" >&2
          dockerBuildUsage
          exit 1
          ;;
        :)
          echo "Option -$OPTARG requires an argument." >&2
          dockerBuildUsage
          exit 1
          ;;
      esac
    done

    if [ -z "$DOCKER_REGISTRY" ]; then
        echo "Error, the docker registry name (-e) is required."
        dockerBuildUsage
        exit 1
    fi

    if [ -z "$DOCKER_REPO" ]; then
        echo "Error, the docker repo name (-r) is required."
        dockerBuildUsage
        exit 1
    fi

    if [ -z "$BUILD_CONTEXT_DIR" ]; then
        echo "Error, the build context directory (-d) is required."
        dockerBuildUsage
        exit 1
    fi

    if [ -z "$DOCKER_FILE" ]; then
        echo "Error, the docker file location (-f) is required."
        dockerBuildUsage
        exit 1
    fi

    #If not git repo provided, default to current directory
    if [ -z "$GIT_DIR" ]; then
        GIT_DIR="./.git"
    fi

    #Default is to just tag with the git version.
    if [ ${#TAGS[@]} -eq 0 ]; then
        local gitVersion=""
        gitVersion=$(git --git-dir "$GIT_DIR" log -1 --pretty=%H)
        if [ -z "$gitVersion" ]; then
            echo "Error, Could not determine git repo version"
            exit 1
        fi
        TAGS+=("$gitVersion")
    fi

    echo "REGISTRY:$DOCKER_REGISTRY"
    echo "REPO:$DOCKER_REPO"
    echo "BUILD_CONTEXT_DIR:$BUILD_CONTEXT_DIR"
    echo "DOCKER_FILE:$DOCKER_FILE"
    echo "PLATFORM:$PLATFORM"
    echo "ADDITIONAL_BUILD_FLAGS:$ADDITIONAL_BUILD_FLAGS"
    echo "TAGS:${TAGS[*]}"

    #Put together the build command.
    #  Freezes often sometimes occur in Jenkins without the --network host option.
    local buildCmd="docker buildx build -o type=registry"
    for buildArg in "${BUILD_ARGS[@]}"; do
        buildCmd="${buildCmd} --build-arg $buildArg"
    done
    if [ -n "$PLATFORM" ]; then
        buildCmd="${buildCmd} --platform=$PLATFORM"
    fi
    if [ -n "$ADDITIONAL_BUILD_FLAGS" ]; then
        buildCmd="${buildCmd} $ADDITIONAL_BUILD_FLAGS"
    fi
    for i in "${TAGS[@]}"; do
        buildCmd="${buildCmd} -t $DOCKER_REGISTRY/$DOCKER_REPO:$i"
    done
    buildCmd="${buildCmd} --cache-from type=registry,ref=$DOCKER_REGISTRY/$DOCKER_REPO"
    buildCmd="${buildCmd} --cache-to type=inline"
    buildCmd="${buildCmd} -f $DOCKER_FILE $BUILD_CONTEXT_DIR 2>&1"

    #Create a new builder instance
    local createBuilderCmd="docker buildx create --use"
    eval "$createBuilderCmd"
    local status=$?
    if [ "$status" -ne 0 ]; then
        echo "Error creating builder instance"
        exit 1
    fi

    #Build
    echo "Building: $buildCmd"
    eval "$buildCmd" | tee "$THIS_DIR"/tmp
    #The exit code of 'docker build' is lost with $? because of the pipe.  Use PIPESTATUS instead.
    local buildSuccess=${PIPESTATUS[0]}
    if [ "$buildSuccess" -ne 0 ]; then
       echo "Docker build error.  Exiting."
       exit "$buildSuccess"
    fi

    exit 0
}

#When calling this script through docker, many arguments are
#  always the same.  This is a shortcut for calling dockerBuild()
function dockerBuildStandard
{
    dockerBuild -d /opt/code -f /opt/code/docker/Dockerfile -g /opt/code "$@"
}

function dockerPushUsage
{
    echo $'Usage:'
    echo $'\tdockerBuild.sh dockerPush [-t tag1,tag2,tagN] [-h] <-r dockerRepoName> <-g gitRepoDir>'
    echo $'\t\t-t - A comma-separated list of tags to push'
    echo $'\t\t-e - Docker registry name.  e.g. "index.docker.io/my-registry"'
    echo $'\t\t-r - Docker repo name. e.g. "builder-docker"'
    echo $'\t\t-g - Git repo directory'
    echo $'\t\t-h - Show this help.'
}

function dockerPush
{
    local TAGS=()
    local DOCKER_REGISTRY=""
    local DOCKER_REPO=""
    local GIT_DIR=""

    while getopts ":t:e:r:g:h" opt; do
      case $opt in
        t)
          IFS=',' read -ra TAG_LIST <<< "$OPTARG"
          for i in "${TAG_LIST[@]}"; do
            TAGS+=("$i")
          done
          ;;
        e)
          DOCKER_REGISTRY=$OPTARG
          ;;
        r)
          DOCKER_REPO=$OPTARG
          ;;
        g)
          GIT_DIR=$OPTARG
          #The location of the .git directory is required.
          GIT_DIR="$GIT_DIR/.git"
          ;;
        h)
          dockerPushUsage
          exit 1
          ;;
        \?)
          echo "Invalid option: -$OPTARG" >&2
          dockerPushUsage
          exit 1
          ;;
        :)
          echo "Option -$OPTARG requires an argument." >&2
          dockerPushUsage
          exit 1
          ;;
      esac
    done

    if [ -z "$DOCKER_REGISTRY" ]; then
        echo "Error, the docker registry name (-e) is required."
        dockerBuildUsage
        exit 1
    fi

    if [ -z "$DOCKER_REPO" ]; then
        echo "Error, the docker repo name (-r) is required."
        dockerBuildUsage
        exit 1
    fi

    #If not git repo provided, default to current directory
    if [ -z "$GIT_DIR" ]; then
        GIT_DIR="./.git"
    fi

    #Default is to just push the git version tag.
    if [ ${#TAGS[@]} -eq 0 ]; then
        local gitVersion=""
        gitVersion=$(git --git-dir "$GIT_DIR" log -1 --pretty=%H)
        if [ -z "$gitVersion" ]; then
            echo "Error, Could not determine git repo version"
            exit 1
        fi
        TAGS+=("$gitVersion")
    fi

    docker login

    local retVal=0

    for i in "${TAGS[@]}"; do
        echo "Pushing: $DOCKER_REGISTRY/$DOCKER_REPO:$i"
        docker push "$DOCKER_REGISTRY"/"$DOCKER_REPO":"$i"
        local pushStatus=$?
        if [ "$pushStatus" -ne 0 ]; then
            echo "Error pushing $DOCKER_REGISTRY/$DOCKER_REPO:$i"
            retVal=1
        fi
    done

    exit $retVal
}

#When calling this script through docker, many arguments are
#  always the same.  This is a shortcut for calling dockerPush()
function dockerPushStandard
{
    dockerPush -g /opt/code "$@"
}

#Allows function calls based on arguments passed to the script
"$@"
