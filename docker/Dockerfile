FROM ubuntu:22.04

ARG DOCKER_VERSION=5:24.0.7-1~ubuntu.22.04~jammy
ARG BUILDX_VERSION=0.11.2-1~ubuntu.22.04~jammy

RUN \
# Add Docker's official GPG key:
    apt-get update && \
    apt-get install -y \
       ca-certificates \
       curl \
       gnupg && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
# Add the repository to Apt sources:
    echo \
       "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
       $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
       tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
# Install
    apt-get install -y \
#      Only the docker executable is needed, not an entire install.
       docker-ce-cli=$DOCKER_VERSION \
       docker-buildx-plugin=$BUILDX_VERSION \
       git && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

#Copy script
ARG INSTALL_DIR=/opt
ENV INSTALL_DIR_ENV $INSTALL_DIR
RUN mkdir -p $INSTALL_DIR
COPY src/dockerBuild.sh $INSTALL_DIR

#Entrypoint
COPY docker/entrypoint.sh /bin/entrypoint.sh
RUN chmod +x /bin/entrypoint.sh

#Run
WORKDIR ${INSTALL_DIR_ENV}
ENTRYPOINT ["/bin/entrypoint.sh", "/opt/dockerBuild.sh"]
