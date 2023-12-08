#!/bin/sh
set -e

#It is expected that the user that runs this container maps
#  their ~/.docker directory to /tmp/.docker
#  This section then copies the config from there to the current (docker) user's .docker directory.
echo "Copying Docker Config..."
DOCKER_CONFIG_HOST="/tmp/.docker/config.json"
DOCKER_CONFIG_DESTINATION="${HOME}/.docker"
mkdir "$DOCKER_CONFIG_DESTINATION"
cp $DOCKER_CONFIG_HOST "$DOCKER_CONFIG_DESTINATION"

echo "Running..."
exec "${@}"
echo "...done"