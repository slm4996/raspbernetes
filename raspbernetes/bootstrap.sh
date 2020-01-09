#!/bin/bash
set -euo pipefail

#### Common setup
## Exit on any non-zero return value
## Script return value will be the exit value of the last command to exit iwth a zon-zero status
set -euo pipefail

## Check for root
if [[ ${EUID} -ne 0 ]]; then
    echo " !!! This tool must be run with sudo / as root"
    exit 1
fi

## Change to script directory
cd "${0%/*}"

## source the environment variables for hostname, IP addresses and node type
# shellcheck source=/dev/null
source ./config

#### Sub-Modules
## Load sub-modules from bootstrap.d directory
for file in ./bootstrap.d/*; do
    # shellcheck source=/dev/null
    source "$file"
done

echo "Finished booting! Kubernetes successfully running!"
