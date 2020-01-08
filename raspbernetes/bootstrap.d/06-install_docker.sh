#!/bin/bash
set -euo pipefail

if command_exists docker; then
    apt update
    apt install --only-upgrade docker-ce-cli
    apt install --only-upgrade docker-ce
else
    echo "Installing docker"
    curl -sSL get.docker.com | sh
    usermod pi -aG docker
fi

lsb_dist=$(get_distribution)
if "$lsb_dist" -eq 'raspbian'; then
    ## Only if running on a Pi
    echo "Disabling swap"
    dphys-swapfile swapoff
    dphys-swapfile uninstall
    update-rc.d dphys-swapfile remove
    systemctl disable dphys-swapfile.service
else
    ## Other systems
    swapoff -a
    sudo sed -i '/ swap / s/^/#/' /etc/fstab
fi

echo "Setup docker daemon to user systemd as per kubernetes best practices"
cat << EOF >> /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

echo "Restarting docker"
systemctl daemon-reload
systemctl restart docker
