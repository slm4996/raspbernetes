#!/bin/bash
set -euo pipefail

echo "Installing keepalived..."
apt-get install -y --no-install-recommends keepalived
apt-mark hold keepalived

# figure out a priority level based on IP
if [[ "${RPI_IP}" == "${KUBE_MASTER_IP_01}" ]]; then
  priority=150
elif [[ "${RPI_IP}" == "${KUBE_MASTER_IP_02}" ]]; then
  priority=100
else
  priority=50
fi

# generate configuration file
cat << EOF > /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    interface ${RPI_NETWORK_TYPE}
    virtual_router_id 1
    priority ${priority}
    advert_int 1
    nopreempt
    authentication {
        auth_type AH
        auth_pass kubernetes
    }
    virtual_ipaddress {
        ${KUBE_MASTER_VIP}
    }
}
EOF

echo "Enable and start keepalived"
systemctl enable --now keepalived
