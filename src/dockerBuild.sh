#!/bin/bash

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
MAIN_BRANCH="main"
CODE_DIR="${CODE_DIR:-/opt/code}"

function dockerBuildUsage
{
    echo $'Usage:'
    echo $'\tdockerBuild.sh dockerBuild -e dockerRegistryName -r dockerRepoName -c buildContextDir -f dockerFile [-g gitRepoDir] [-p platform]... [-t tag]... [-b buildArg]... [-a arg]... [-n] [-o] [-h]'
    echo $'\t\t-e - Docker registry name.'
    echo $'\t\t\te.g. "index.docker.io/my-registry"'
    echo $'\t\t-r - Docker repo name.'
    echo $'\t\t\te.g. "builder-docker".'
    echo $'\t\t-c - Docker build context.'
    echo $'\t\t-f - Dockerfile location.'
    echo $'\t\t-g - Git repo directory.'
    echo $'\t\t-p - Target platform for build.'
    echo $'\t\t\tCan be a comma-separated list or defined multiple times. '
    echo $'\t\t\te.g. "linux/amd64", or "linux/amd64,linux/arm/v7"'
    echo $'\t\t-t - Additional tags to apply to the image.'
    echo $'\t\t\tCan be defined multiple times.'
    echo $'\t\t-b - Build-arg values.'
    echo $'\t\t\tCan be defined multiple times.'
    echo $'\t\t-a - Additional docker build args passed directly to docker build.'
    echo $'\t\t\tCan be a comma-separated list or defined multiple times.'
    echo $'\t\t-h - Show this help.'
}

function getGitVersion
{
    git --git-dir "$GIT_DIR" log -1 --pretty=%H
}

function getGitBranch
{
    git --git-dir "$GIT_DIR" branch --show-current
}

function createBuilder
{
    local createBuilderCmd="docker buildx create --use"
    eval "$createBuilderCmd"
    local status=$?
    if [ "$status" -ne 0 ]; then
        echo "Error creating builder instance"
        exit 1
    fi
}

function removeBuilder
{
    local removeBuilderCmd="docker buildx rm --force"
    eval "$removeBuilderCmd"
    local status=$?
    if [ "$status" -ne 0 ]; then
        echo "Error removing builder instance"
        exit 1
    fi
}

function build
{
    local buildCmd="$1"
    echo "Building: $buildCmd"
    #TODO - NEEDED?
    eval "$buildCmd" | tee "$THIS_DIR"/tmp
    #The exit code of 'docker build' is lost with $? because of the pipe.  Use PIPESTATUS instead.
    local buildSuccess=${PIPESTATUS[0]}
    if [ "$buildSuccess" -ne 0 ]; then
       echo "Docker build error.  Exiting."
       #Remove builder before exiting instance
       removeBuilder
       exit "$buildSuccess"
    fi
}

# Builds and tags a docker image.
function dockerBuild
{
    local DOCKER_REGISTRY=""
    local DOCKER_REPO=""
    local BUILD_CONTEXT_DIR=""
    local DOCKER_FILE=""
    local GIT_DIR=""
    local NO_GIT_VERSION=""
    local NO_GIT_BRANCH=""
    local PLATFORM=()
    local TAGS=()
    local BUILD_ARGS=()
    local ADDITIONAL_BUILD_FLAGS=()

    while getopts ":e:r:c:f:g:p:t:b:a:noh" opt; do
      case $opt in
        e)
          DOCKER_REGISTRY="$OPTARG"
          ;;
        r)
          DOCKER_REPO="$OPTARG"
          ;;
        c)
          BUILD_CONTEXT_DIR="$OPTARG"
          ;;
        f)
          DOCKER_FILE="$OPTARG"
          ;;
        g)
          GIT_DIR="$OPTARG"
          ;;
        p)
          PLATFORM+=("$OPTARG")
          ;;
        t)
          TAGS+=("$OPTARG")
          ;;
        b)
          BUILD_ARGS+=("$OPTARG")
          ;;
        a)
          ADDITIONAL_BUILD_FLAGS+=("$OPTARG")
          ;;
        n)
          NO_GIT_VERSION="true"
          ;;
        o)
          NO_GIT_BRANCH="true"
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

    #If not git repo provided, default to the code dir
    if [ -z "$GIT_DIR" ]; then
        GIT_DIR="$CODE_DIR"
    fi
    #The location of the .git directory is required.
    GIT_DIR="$GIT_DIR/.git"

    #Unless the NO_GIT_VERSION flag is set, get the git repo version
    #  and add to the tags list.
    if [ -z "$NO_GIT_VERSION" ]; then
        local gitVersion=""
        gitVersion=$(getGitVersion)
        if [ -z "$gitVersion" ]; then
            echo "Error, Could not determine git repo version."
            exit 1
        fi
        TAGS+=("$gitVersion")
    fi

    #Find the current git branch.
    #  Default to the main branch for caching.
    local gitBranch="$MAIN_BRANCH"
    if [ -z "$NO_GIT_BRANCH" ]; then
        gitBranch=$(getGitBranch)
        if [ -z "$gitBranch" ]; then
            echo "Could not determine git branch name."
            exit 1
        else
            #Tag with the branch name, so we have a tag that tracks the latest version of a branch,
            #  and also so that we have a location to push the build cache.
            TAGS+=("$gitBranch")
        fi
    fi

    echo "REGISTRY:$DOCKER_REGISTRY"
    echo "REPO:$DOCKER_REPO"
    echo "BUILD_CONTEXT_DIR:$BUILD_CONTEXT_DIR"
    echo "DOCKER_FILE:$DOCKER_FILE"
    echo "GIT_DIR:$GIT_DIR"
    echo "PLATFORM:${PLATFORM[*]}"
    echo "TAGS:${TAGS[*]}"
    echo "BUILD_ARGS:${BUILD_ARGS[*]}"
    echo "ADDITIONAL_BUILD_FLAGS:${ADDITIONAL_BUILD_FLAGS[*]}"

    #Put together the build command.
    #  Build args
    local buildCmd="docker buildx build -o type=registry"
    for buildArg in "${BUILD_ARGS[@]}"; do
        buildCmd="${buildCmd} --build-arg $buildArg"
    done
    #  Platform
    for i in "${!PLATFORM[@]}"; do
        if [ "$i" -eq 0 ]; then
            buildCmd="${buildCmd} --platform=${PLATFORM[$i]}"
        else
            buildCmd="${buildCmd},${PLATFORM[$i]}"
        fi
    done
    #Additional build flags
    for flag in "${ADDITIONAL_BUILD_FLAGS[@]}"; do
        buildCmd="${buildCmd} $flag"
    done
    #Tags
    for tag in "${TAGS[@]}"; do
        buildCmd="${buildCmd} -t $DOCKER_REGISTRY/$DOCKER_REPO:$tag"
    done
    #The caching location is a little tricky since multiple tags can be provided.
    #  So, store the cache in the branch name tag instead since the deltas on a
    #  single branch should be fairly minimal.
    #  https://docs.docker.com/build/cache/backends/#multiple-caches
    buildCmd="${buildCmd} --cache-from=type=registry,ref=$DOCKER_REGISTRY/$DOCKER_REPO:$gitBranch"
    buildCmd="${buildCmd} --cache-from=type=registry,ref=$DOCKER_REGISTRY/$DOCKER_REPO:$gitBranch"
    buildCmd="${buildCmd} -f $DOCKER_FILE $BUILD_CONTEXT_DIR 2>&1"

    #Create a new builder instance
    createBuilder

    #Build
    build "$buildCmd"

    #Remove builder instance
    removeBuilder

    exit 0
}

#When calling this script through docker, many arguments are
#  always the same.  This is a shortcut for calling dockerBuild()
function dockerBuildStandardBranch
{
    dockerBuild -c "$CODE_DIR" -f "$CODE_DIR/docker/Dockerfile" -g "$CODE_DIR" "$@"
}
function dockerBuildStandardMain
{
    dockerBuild -c "$CODE_DIR" -f "$CODE_DIR/docker/Dockerfile" -g "$CODE_DIR" -t "latest" "$@"
}
function dockerBuildStandardTag
{
    local TAG="$1"
    shift
    echo "${@}"
    #TODO - -n
    dockerBuild -c "$CODE_DIR" -f "$CODE_DIR/docker/Dockerfile" -g "$CODE_DIR" -n -o -t "$TAG" "${@}"
}

#Allows function calls based on arguments passed to the script
"$@"
