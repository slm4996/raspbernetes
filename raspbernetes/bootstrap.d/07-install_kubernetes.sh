#!/bin/bash
set -euo pipefail

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

until apt-get update; do echo "Retrying due to unstable mirror"; done
apt-get install -y kubelet kubeadm kubectl kubectx
apt-mark hold kubelet kubeadm kubectl

if [ "${KUBE_NODE_TYPE}" == "master" ]; then
    echo "Pulling down all kubeadm images..."
    kubeadm config images pull
fi

# ensure bootstrap scripts don't run again on boot
systemctl disable kubernetes-bootstrap
systemctl daemon-reload
