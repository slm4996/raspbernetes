#!/bin/bash

## Check if given command exists
function command_exists() {
  command -v "$@" >/dev/null 2>&1
}

## Get distribution
function get_distribution() {
  lsb_dist=""
  if [ -r /etc/os-release ]; then
    # shellcheck source=/dev/null
    lsb_dist="$(. /etc/os-release && echo "$ID")"
    echo "$lsb_dist"
  fi
}
