#!/bin/bash
set -euo pipefail

## Only if running on a Pi
if grep -Fq 'raspbian' /etc/os-release; then
    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt install rpi-update -y
    SKIP_WARNING=1 rpi-update
fi
