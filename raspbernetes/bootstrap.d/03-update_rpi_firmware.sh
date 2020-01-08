#!/bin/bash
set -euo pipefail

## Only if running on a Pi
lsb_dist=$(get_distribution)
if "$lsb_dist" -eq 'raspbian'; then
    sudo SKIP_WARNING=1 rpi-update
fi
