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
  fi
}

## Get release information
function get_release() {
  get_distribution

  # Check for lsb_release command existence
  if command_exists lsb_release; then
    # Get the upstream release info
    dist_version=$(lsb_release -a 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[:space:]')

    # Print info about upstream distro
    echo "Detected $lsb_dist $dist_version"
  else
    if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "raspbian" ]; then
      if [ "$lsb_dist" = "osmc" ]; then
        # OSMC runs Raspbian
        lsb_dist=raspbian
      else
        # We're Debian and don't even know it!
        lsb_dist=debian
      fi
      dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
      case "$dist_version" in
      10)
        dist_version="buster"
        ;;
      9)
        dist_version="stretch"
        ;;
      8 | 'Kali Linux 2')
        dist_version="jessie"
        ;;
      esac
      echo "Detected $lsb_dist $dist_version"
    fi
  fi
}

get_release
