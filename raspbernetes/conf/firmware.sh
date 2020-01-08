#!/bin/bash
set -euo pipefail

# Update firmware for Pi - Needed for CNI (weave) to work correctly
sudo SKIP_WARNING=1 rpi-update