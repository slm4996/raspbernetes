#!/bin/bash
set -euo pipefail

if sudo grep -Fq 'Raspbian' /etc/os-release; then
    # Update firmware for Pi - Needed for CNI (weave) to work correctly
    sudo SKIP_WARNING=1 rpi-update
fi