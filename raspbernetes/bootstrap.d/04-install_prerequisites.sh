#!/bin/bash
set -euo pipefail

function install_prerequisites() {
    echo "Updating core packages..."
    apt-get update

    echo "Installing base packages..."
    apt-get install -y --no-install-recommends \
    apt-transport-https \
    software-properties-common \
    zip \
    jq \
    git \
    vim \
    curl
}
