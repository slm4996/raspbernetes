#!/bin/bash
set -euo pipefail

FILE="${KUBE_NODE_USER_HOME}/reboot"
if [ ! -f "$FILE" ]; then
    echo "Updating core packages..."
    DEBIAN_FRONTEND=noninteractive apt-get update

    echo "Installing base packages..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apt-transport-https \
    software-properties-common \
    zip \
    jq \
    git \
    vim \
    curl

    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
    touch "${FILE}"

    echo "Reboot in progress..."
    reboot
fi