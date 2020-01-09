#!/bin/bash
set -euo pipefail

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
reboot
