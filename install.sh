#!/bin/bash
set -euo pipefail

#### Common setup
## Exit on any non-zero return value
## Script return value will be the exit value of the last command to exit iwth a zon-zero status
set -euo pipefail

## Check for root
if [[ ${EUID} -ne 0 ]]; then
    echo " !!! This tool must be run with sudo / as root"
    exit 1
fi

## Change to script directory
cd "${0%/*}"

if [ ! -f "./config" ]; then
    echo "Copy config.example to config and update values before running!"
    exit 1
fi

## source the configuration variables
# shellcheck source=/dev/null
source ./config

## Confirmation of settings
echo "Image:"
echo "- Hostname:		${KUBE_NODE_HOSTNAME}"
echo "- Static IP:		${KUBE_NODE_IP}"
echo "- Gateway address:	${KUBE_NODE_GATEWAY}"
echo "- Network adapter:	${KUBE_NODE_INTERFACE}"
if [[ $KUBE_NODE_INTERFACE == *"wl"* ]]; then
    echo "- WiFi SSID:		${KUBE_NODE_WIFI_SSID}"
    echo "- WiFi Password:	${KUBE_NODE_WIFI_PASSWORD}"
fi
echo "- Node Type:		${KUBE_NODE_TYPE}"
echo "- Timezone:		${KUBE_NODE_TIMEZONE}"
echo "Kubernetes:"
echo "- Control Plane IP:	${KUBE_MASTER_VIP}"
echo "- Master IP 01:		${KUBE_MASTER_IP_01}"
echo "- Master IP 02:		${KUBE_MASTER_IP_02}"
echo "- Master IP 03:		${KUBE_MASTER_IP_03}"

read -p "Do these settings look correct? {y/n}" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    ## Create all necessary directories to be used in build
    echo "Step - prepare"
    echo "- Creating staging folder:"
    echo "-- ./${OUTPUT_PATH}/ssh/"
    mkdir -p "./${OUTPUT_PATH}/ssh/"

    ## Install bootstrap scripts
    echo "Step - bootstrap"
    mkdir -p "${KUBE_NODE_USER_HOME}/bootstrap"
    cp -r ./raspbernetes/* "${KUBE_NODE_USER_HOME}/bootstrap/"
    mkdir -p "${KUBE_NODE_USER_HOME}/.ssh"
    cp "./${OUTPUT_PATH}/ssh/id_ed25519" "${KUBE_NODE_USER_HOME}/.ssh/"
    cp "./${OUTPUT_PATH}/ssh/id_ed25519.pub" "${KUBE_NODE_USER_HOME}/.ssh/authorized_keys"
    rm -f "/etc/motd"

    echo "Step - configure"
    echo "- Disable SSH password based login"
    sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication no/g" "/etc/ssh/sshd_config"
    echo "- Enable cgroups on boot"
    sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory quiet"'
    echo "- Add node custom configuration file to be sourced on boot"
    cat << EOF > "${KUBE_NODE_USER_HOME}/bootstrap/config"
#!/bin/bash

## Node specific
export KUBE_NODE_INTERFACE=${KUBE_NODE_INTERFACE}
export KUBE_NODE_WIFI_COUNTRY=${KUBE_NODE_WIFI_COUNTRY}
export KUBE_NODE_WIFI_SSID=${KUBE_NODE_WIFI_SSID}
export KUBE_NODE_WIFI_PASSWORD=${KUBE_NODE_WIFI_PASSWORD}
export KUBE_NODE_HOSTNAME=${KUBE_NODE_HOSTNAME}
export KUBE_NODE_IP=${KUBE_NODE_IP}
export KUBE_NODE_GATEWAY=${KUBE_NODE_GATEWAY}
export KUBE_NODE_TIMEZONE=${KUBE_NODE_TIMEZONE}
export KUBE_NODE_TYPE=${KUBE_NODE_TYPE}
export KUBE_NODE_USER=${KUBE_NODE_USER}
export KUBE_NODE_USER_HOME=${KUBE_NODE_USER_HOME}

## Cluster wide
export KUBE_MASTER_VIP=${KUBE_MASTER_VIP}
export KUBE_MASTER_IP_01=${KUBE_MASTER_IP_01}
export KUBE_MASTER_IP_02=${KUBE_MASTER_IP_02}
export KUBE_MASTER_IP_03=${KUBE_MASTER_IP_03}
EOF
    echo "- Add dhcp configuration to set a static IP and gateway"
    cat << EOF >> "/etc/dhcpcd.conf"
interface ${KUBE_NODE_INTERFACE}
static ip_address=${KUBE_NODE_IP}/24
static routers=${KUBE_NODE_GATEWAY}
static domain_name_servers=${KUBE_NODE_GATEWAY}
EOF
    ## Ensure we are set to execute on reboot
    cat << EOF > "/etc/systemd/system/kubernetes-bootstrap.service"
[Unit]
Description=Kubernetes Cluster Bootstrap
After=network.target

[Service]
ExecStart=/home/${KUBE_NODE_USER}/bootstrap/bootstrap.sh
WorkingDirectory=/home/${KUBE_NODE_USER}/bootstrap
StandardOutput=syslog+console
StandardError=syslog+console
SyslogIdentifier=kubernetes-bootstrap
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    echo "Step - wlan0"
    if test -n "${KUBE_NODE_WIFI_SSID}"; then
        cp ./raspbernetes/template/wpa_supplicant.conf "/wpa_supplicant.conf"
        sed -i "s/<WIFI_COUNTRY>/${KUBE_NODE_WIFI_COUNTRY}/" "/wpa_supplicant.conf"
        sed -i "s/<WIFI_SSID>/${KUBE_NODE_WIFI_SSID}/" "/wpa_supplicant.conf"
        sed -i "s/<WIFI_PASSWORD>/${KUBE_NODE_WIFI_PASSWORD}/" "/wpa_supplicant.conf"
    fi

    if [ ! -f "./${OUTPUT_PATH}/ssh/id_ed25519" ]; then
        echo "Step - ssh keygen"
        ssh-keygen -t ed25519 -b 4096 -C "pi@raspberry" -f "./${OUTPUT_PATH}/ssh/id_ed25519" -q -N ""
    fi
fi