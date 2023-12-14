#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OUTPUT_FILE="$SCRIPT_DIR/output"

source ../../src/dockerBuild.sh

# ------------------
# Begin Mocks
#   These methods override methods by the same name in the dockerBuild.sh script
# ------------------
function getGitVersion
{
  echo "mocked-git-version"
}
export -f getGitVersion

function getGitBranch
{
  echo "mocked-git-branch"
}
export -f getGitBranch

function createBuilder
{
  echo "createBuilder" >> "$OUTPUT_FILE"
}
export -f createBuilder

function removeBuilder
{
  echo "removeBuilder" >> "$OUTPUT_FILE"
}
export -f removeBuilder

function build
{
  echo "$1" >> "$OUTPUT_FILE"
}
export -f build


function oneTimeSetUp()
{
  echo "oneTimeSetUp"
}

function oneTimeTearDown()
{
  echo "oneTimeTearDown"
  rm -f "$OUTPUT_FILE"
}
# ------------------
# End Mocks
# ------------------

testSingleArgs()
{
  local REGISTRY="docker-registry"
  local REPO="docker-repo"
  local BUILD_CONTEXT="build-context-dir"
  local DOCKERFILE="dockerfile"
  local GIT_DIR="git-dir"
  local PLATFORM="target"
  local TAG="tag"
  local BUILD_ARG="build-arg"
  local ARGS="--arg on"

  rm -f "$OUTPUT_FILE"

  stdout=$(dockerBuild \
     -e "$REGISTRY" \
     -r "$REPO" \
     -d "$BUILD_CONTEXT" \
     -f "$DOCKERFILE" \
     -g "$GIT_DIR" \
     -p "$PLATFORM" \
     -t "$TAG" \
     -b "$BUILD_ARG" \
     -a "$ARGS")
  echo "$stdout"
  buildCmd=$(<"$OUTPUT_FILE")
  expected=$(<"$SCRIPT_DIR/expected/singleArgs")
  assertEquals "$expected" "$buildCmd"
  echo ""
}

testMultipleArgs()
{
  local REGISTRY="docker-registry"
  local REPO="docker-repo"
  local BUILD_CONTEXT="build-context-dir"
  local DOCKERFILE="dockerfile"
  local GIT_DIR="git-dir"
  local PLATFORM1="platform1"
  local PLATFORM2="platform2"
  local TAG1="tag1"
  local TAG2="tag2"
  local BUILD_ARG1="build-arg1"
  local BUILD_ARG2="build-arg2"
  local ARG1="--arg1 on"
  local ARG2="--arg2 off"

  rm -f "$OUTPUT_FILE"

  stdout=$(dockerBuild \
     -e "$REGISTRY" \
     -r "$REPO" \
     -d "$BUILD_CONTEXT" \
     -f "$DOCKERFILE" \
     -g "$GIT_DIR" \
     -p "$PLATFORM1" \
     -p "$PLATFORM2" \
     -t "$TAG1" \
     -t "$TAG2" \
     -b "$BUILD_ARG1" \
     -b "$BUILD_ARG2" \
     -a "$ARG1" \
     -a "$ARG2")
  echo "$stdout"
  buildCmd=$(<"$OUTPUT_FILE")
  expected=$(<"$SCRIPT_DIR/expected/multipleArgs")
  assertEquals "$expected" "$buildCmd"
  echo ""
}

testMultipleArgsCommaSeparated()
{
  local REGISTRY="docker-registry"
  local REPO="docker-repo"
  local BUILD_CONTEXT="build-context-dir"
  local DOCKERFILE="dockerfile"
  local GIT_DIR="git-dir"
  local PLATFORM="platform1,platform2"
  local TAG1="tag1"
  local TAG2="tag2"
  local BUILD_ARG1="build-arg1"
  local BUILD_ARG2="build-arg2"
  local ARG="--arg1 on --arg2 off"

  rm -f "$OUTPUT_FILE"

  stdout=$(dockerBuild \
     -e "$REGISTRY" \
     -r "$REPO" \
     -d "$BUILD_CONTEXT" \
     -f "$DOCKERFILE" \
     -g "$GIT_DIR" \
     -p "$PLATFORM" \
     -t "$TAG1" \
     -t "$TAG2" \
     -b "$BUILD_ARG1" \
     -b "$BUILD_ARG2" \
     -a "$ARG")
  echo "$stdout"
  buildCmd=$(<"$OUTPUT_FILE")
  expected=$(<"$SCRIPT_DIR/expected/multipleArgs")
  assertEquals "$expected" "$buildCmd"
  echo ""
}

# Load and run shUnit2.
# shellcheck disable=SC1091
. shunit2
