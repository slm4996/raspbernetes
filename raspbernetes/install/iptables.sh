#!/bin/bash
set -euo pipefail

echo "Installing ebtables and arptables..."
apt-get install -y ebtables arptables

echo "Setting to use legacy tables for compatibility issues"
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
update-alternatives --set ebtables /usr/sbin/ebtables-legacy
update-alternatives --set arptables /usr/sbin/arptables-legacy

echo "Enable passing bridged IPv4 traffic to iptables’ chains."
echo "This is a requirement for some CNI plugins to work."
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
sysctl net.bridge.bridge-nf-call-arptables=1

echo "Reloading sysctl"
modprobe br_netfilter
sysctl -p
