#!/bin/bash
set -euo pipefail

echo "Installing docker"
curl -sSL get.docker.com | sh
usermod pi -aG docker

echo "Disabling swap"
dphys-swapfile swapoff
dphys-swapfile uninstall
update-rc.d dphys-swapfile remove
systemctl disable dphys-swapfile.service

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
