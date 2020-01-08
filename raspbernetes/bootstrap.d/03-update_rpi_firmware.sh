#!/bin/bash
set -euo pipefail

## Only if running on a Pi
if grep -Fq 'raspbian' /etc/os-release; then
    apt update
    apt install rpi-update -y
    SKIP_WARNING=1 rpi-update
fi
