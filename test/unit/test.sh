#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OUTPUT_FILE="$SCRIPT_DIR/output"

source ../../src/dockerBuild.sh

# Set up mocks
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
  rm "$OUTPUT_FILE"
}

testAllArgs()
{
  local REGISTRY=docker-registry
  local REPO=docker-repo
  local BUILD_CONTEXT=build-context-dir
  local DOCKERFILE=dockerfile
  local GIT_DIR=git-dir
  local TAGS=tag1,tag2
  local BUILD_ARG=build-arg
  local PLATFORM=target1,target2
  local ARGS=args

  result=$(dockerBuild -e $REGISTRY -r $REPO -d $BUILD_CONTEXT -f $DOCKERFILE -g $GIT_DIR -t $TAGS -b $BUILD_ARG -p $PLATFORM -a $ARGS)
  echo "$result"
  output=$(<"$OUTPUT_FILE")
  expected=$(<"$SCRIPT_DIR/expected/allArgs")
  assertEquals "$expected" "$output"
}

# Load and run shUnit2.
. shunit2
