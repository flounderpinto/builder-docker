#!/bin/bash

# Globals that can be overwritten with environment variables as needed
DOCKER_REGISTRY="${REGISTRY}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"

BUILDER=""

function dockerBuildUsage
{
    echo $'Usage:'
    echo $'\tdockerBuild.sh dockerBuild -e dockerRegistryName -r dockerRepoName -c buildContextDir -f dockerFile [-k tomlConfigFile] [-x buildxImage] [-g gitRepoDir] [-m gitBranchName] [-p platform]... [-t tag]... [-b buildArg]... [-a arg]... [-n] [-o] [-h]'
    echo $'\t\t-e - Docker registry name.'
    echo $'\t\t\te.g. "index.docker.io/my-registry"'
    echo $'\t\t-r - Docker repo name.'
    echo $'\t\t\te.g. "builder-docker".'
    echo $'\t\t-c - Docker build context.'
    echo $'\t\t-f - Dockerfile location.'
    echo $'\t\t-k - Toml config file.'
    echo $'\t\t-x - BuildX image location.'
    echo $'\t\t-g - Git repo directory.'
    echo $'\t\t-m - Git branch name.'
    echo $'\t\t\tThis script will attempt to determine this automatically.'
    echo $'\t\t\tTo override that behavior, use this flag to specify the branch name manually.'
    echo $'\t\t-p - Target platform for build.'
    echo $'\t\t\tCan be a comma-separated list or defined multiple times. '
    echo $'\t\t\te.g. "linux/amd64", or "linux/amd64,linux/arm/v7"'
    echo $'\t\t-t - Additional tags to apply to the image.'
    echo $'\t\t\tCan be defined multiple times.'
    echo $'\t\t-b - Build-arg values.'
    echo $'\t\t\tCan be defined multiple times.'
    echo $'\t\t-a - Additional docker build args passed directly to docker build.'
    echo $'\t\t\tCan be a comma-separated list or defined multiple times.'
    echo $'\t\t-n - Do not tag with the git version hash.'
    echo $'\t\t-o - Do not tag with the git branch name.'
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

#This function exits in order to intercept the command in unit tests.
function _create
{
    echo "Creating: $1"
    BUILDER=$(eval "$1")
    echo "CREATED BUILDER $BUILDER"
    local status=$?
    if [ "$status" -ne 0 ]; then
        echo "Error creating builder instance"
        exit 1
    fi
}

function createBuilder
{
    local buildxImage="$1"
    local tomlConfigFile="$2"
    local createBuilderCmd="docker buildx create --driver=docker-container --driver-opt=\"image=$buildxImage\""
    if [ -n "$tomlConfigFile" ]; then
        createBuilderCmd="${createBuilderCmd} --config ${tomlConfigFile}"
    fi
    _create "$createBuilderCmd"
}

#This function exits in order to intercept the command in unit tests.
function _remove
{
    eval "$1"
    local status=$?
    if [ "$status" -ne 0 ]; then
        echo "Error removing builder instance"
        exit 1
    fi
}

function removeBuilder
{
    local removeBuilderCmd="docker buildx rm $BUILDER --force"
    _remove "$removeBuilderCmd"
}

#This function exits in order to intercept the command in unit tests.
function _build
{
    echo "Building: $1"
    eval "$1"
    local buildSuccess=$?
    if [ "$buildSuccess" -ne 0 ]; then
       echo "Docker build error.  Exiting."
       #Remove builder before exiting instance
       removeBuilder "$BUILDER"
       exit "$buildSuccess"
    fi
}

function buildImage
{
    local buildCmd="BUILDX_BUILDER=$BUILDER $1"
    _build "$buildCmd"
}

# Builds and tags a docker image.
function dockerBuild
{
    local DOCKER_REPO=""
    local BUILD_CONTEXT_DIR=""
    local DOCKER_FILE=""
    local TOML_CONFIG_FILE=""
    local BUILDX_IMAGE=""
    local GIT_DIR=""
    local GIT_BRANCH=""
    local NO_GIT_VERSION=""
    local NO_GIT_BRANCH=""
    local PLATFORM=()
    local TAGS=()
    local BUILD_ARGS=()
    local ADDITIONAL_BUILD_FLAGS=()

    while getopts ":e:r:c:f:k:x:g:m:p:t:b:a:noh" opt; do
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
        k)
          TOML_CONFIG_FILE="$OPTARG"
          ;;
        x)
          BUILDX_IMAGE="$OPTARG"
          ;;
        g)
          GIT_DIR="$OPTARG"
          ;;
        m)
          GIT_BRANCH="$OPTARG"
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

    #If no buildx image location provided, use default.
    if [ -z "$BUILDX_IMAGE" ]; then
        BUILDX_IMAGE="moby/buildkit:buildx-stable-1"
    fi

    #If not git repo provided, default to the code dir
    if [ -z "$GIT_DIR" ]; then
        GIT_DIR="."
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
        if [ -n "$GIT_BRANCH" ]; then
           gitBranch="$GIT_BRANCH"
        else
            gitBranch=$(getGitBranch)
            if [ -z "$gitBranch" ]; then
                echo "Could not determine git branch name."
                exit 1
            fi
        fi
        #Tag with the branch name, so we have a tag that tracks the latest version of a branch,
        #  and also so that we have a location to push the build cache.
        TAGS+=("$gitBranch")
    fi

    echo "REGISTRY:$DOCKER_REGISTRY"
    echo "REPO:$DOCKER_REPO"
    echo "BUILD_CONTEXT_DIR:$BUILD_CONTEXT_DIR"
    echo "DOCKER_FILE:$DOCKER_FILE"
    echo "TOML_CONFIG_FILE:$TOML_CONFIG_FILE"
    echo "BUILDX_IMAGE:$BUILDX_IMAGE"
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
    buildCmd="${buildCmd} --cache-to=type=inline"
    buildCmd="${buildCmd} -f $DOCKER_FILE $BUILD_CONTEXT_DIR 2>&1"

    #Create a new builder instance
    createBuilder "$BUILDX_IMAGE" "$TOML_CONFIG_FILE"

    #Build
    buildImage "$buildCmd"

    #Remove builder instance
    removeBuilder

    exit 0
}

#When calling this script through docker, many arguments are
#  always the same.  These methods are shortcuts for calling dockerBuild().
#  Relative paths allow the script to work inside or outside of docker.
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

"$@"
