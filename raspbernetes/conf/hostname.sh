#!/bin/bash
set -euo pipefail

echo "Setting hostname to: ${RPI_HOSTNAME}"
hostnamectl --transient set-hostname "${RPI_HOSTNAME}"
hostnamectl --static set-hostname "${RPI_HOSTNAME}"
hostnamectl --pretty set-hostname "${RPI_HOSTNAME}"
sed -i "s/raspberrypi/${RPI_HOSTNAME}/g" /etc/hosts

echo "Setting timezone to: ${RPI_TIMEZONE}"
hostnamectl set-location "${RPI_TIMEZONE}"
timedatectl set-timezone "${RPI_TIMEZONE}"

echo "Restarting cron and rsyslog for timezone settings to take affect"
systemctl restart cron
systemctl restart rsyslog

echo "Restarting avahi-daemon (mDNS) daemon for new settings to take effect"
systemctl restart avahi-daemon
