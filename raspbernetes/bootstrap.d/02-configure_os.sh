#!/bin/bash
set -euo pipefail

## Ensure we are set to execute on reboot & check syslogs using "tail -f /var/log/syslog"
sed -i "s/^exit 0/\/home\/$KUBE_NODE_USER\/bootstrap.sh 2>\&1 | logger -t kubernetes-bootstrap \&/g" /etc/rc.local

echo "Setting hostname to: $KUBE_HOSTNAME"
hostnamectl --transient set-hostname "$KUBE_HOSTNAME"
hostnamectl --static set-hostname "$KUBE_HOSTNAME"
hostnamectl --pretty set-hostname "$KUBE_HOSTNAME"
sed -i "s/raspberrypi/$KUBE_HOSTNAME/g" /etc/hosts
if systemctl list-units --type service | grep -Fq 'avahi'; then
    echo "Restarting avahi-daemon (mDNS) daemon for new settings to take effect"
    systemctl restart avahi-daemon
fi

echo "Setting timezone to: $KUBE_TIMEZONE"
hostnamectl set-location "$KUBE_TIMEZONE"
timedatectl set-timezone "$KUBE_TIMEZONE"

echo "Restarting cron and rsyslog for timezone settings to take affect"
systemctl restart cron
systemctl restart rsyslog
