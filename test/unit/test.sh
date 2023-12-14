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
  local E="docker-registry"
  local R="docker-repo"
  local C="build-context-dir"
  local D="dockerfile"
  local G="git-dir"
  local P="target"
  local T="tag"
  local B="build-arg"
  local A="--arg on"

  rm -f "$OUTPUT_FILE"

  stdout=$(dockerBuild \
     -e "$E" \
     -r "$R" \
     -c "$C" \
     -d "$D" \
     -g "$G" \
     -p "$P" \
     -t "$T" \
     -b "$B" \
     -a "$A")
  echo "$stdout"
  buildCmd=$(<"$OUTPUT_FILE")
  expected=$(<"$SCRIPT_DIR/expected/singleArgs")
  assertEquals "$expected" "$buildCmd"
  echo ""
}

testMultipleArgs()
{
  local E="docker-registry"
  local R="docker-repo"
  local C="build-context-dir"
  local D="dockerfile"
  local G="git-dir"
  local P1="platform1"
  local P2="platform2"
  local T1="tag1"
  local T2="tag2"
  local B1="build-arg1"
  local B2="build-arg2"
  local A1="--arg1 on"
  local A2="--arg2 off"

  rm -f "$OUTPUT_FILE"

  stdout=$(dockerBuild \
     -e "$E" \
     -r "$R" \
     -c "$C" \
     -d "$D" \
     -g "$G" \
     -p "$P1" \
     -p "$P2" \
     -t "$T1" \
     -t "$T2" \
     -b "$B1" \
     -b "$B2" \
     -a "$A1" \
     -a "$A2")
  echo "$stdout"
  buildCmd=$(<"$OUTPUT_FILE")
  expected=$(<"$SCRIPT_DIR/expected/multipleArgs")
  assertEquals "$expected" "$buildCmd"
  echo ""
}

testMultipleArgsCommaSeparated()
{
  local E="docker-registry"
  local R="docker-repo"
  local C="build-context-dir"
  local D="dockerfile"
  local G="git-dir"
  local P="platform1,platform2"
  local T1="tag1"
  local T2="tag2"
  local B1="build-arg1"
  local B2="build-arg2"
  local A="--arg1 on --arg2 off"

  rm -f "$OUTPUT_FILE"

  stdout=$(dockerBuild \
     -e "$E" \
     -r "$R" \
     -c "$C" \
     -d "$D" \
     -g "$G" \
     -p "$P" \
     -t "$T1" \
     -t "$T2" \
     -b "$B1" \
     -b "$B2" \
     -a "$A")
  echo "$stdout"
  buildCmd=$(<"$OUTPUT_FILE")
  expected=$(<"$SCRIPT_DIR/expected/multipleArgs")
  assertEquals "$expected" "$buildCmd"
  echo ""
}

# Load and run shUnit2.
# shellcheck disable=SC1091
. shunit2
