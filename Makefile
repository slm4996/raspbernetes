SHELL := /bin/bash -o pipefail
.SILENT:
.DEFAULT_GOAL := help

# Default variables
MNT_DEVICE				?= /dev/mmcblk0
MNT_ROOT				= /mnt/raspbernetes/root
MNT_BOOT				= /mnt/raspbernetes/boot
OUTPUT_PATH				= output

# Node specific configuration
KUBE_NODE_INTERFACE		?= eth0
KUBE_NODE_WIFI_SSID		?=
KUBE_NODE_WIFI_PASSWORD	?=
KUBE_NODE_HOSTNAME 		?=
KUBE_NODE_IP			?=
KUBE_NODE_GATEWAY		?=
KUBE_NODE_TIMEZONE		?= America/Indiana/Indianapolis
KUBE_NODE_TYPE			?= master
KUBE_NODE_USER			?= pi
KUBE_NODE_USER_HOME		?= /home/$(KUBE_NODE_USER)

# Cluster wide configuration
KUBE_MASTER_VIP			?= 192.168.2.10
KUBE_MASTER_IP_01		?= 192.168.2.11
KUBE_MASTER_IP_02		?= 192.168.2.12
KUBE_MASTER_IP_03		?= 192.168.2.13

# Raspbian image configuration
RASPBIAN_VERSION		= raspbian_lite-2019-09-30
RASPBIAN_IMAGE_VERSION	= 2019-09-26-raspbian-buster-lite
RASPBIAN_URL			= https://downloads.raspberrypi.org/raspbian_lite/images/$(RASPBIAN_VERSION)/$(RASPBIAN_IMAGE_VERSION).zip

.PHONY: build
build: format bootstrap configure clean ## Generate and pre-configure bootable media for a node
	echo "Image:"
	echo "- Hostname:			$(KUBE_NODE_HOSTNAME)"
	echo "- Static IP:			$(KUBE_NODE_IP)"
	echo "- Gateway address:	$(KUBE_NODE_GATEWAY)"
	echo "- Network adapter:	$(KUBE_NODE_INTERFACE)"
ifeq (,$(findstring wl,$(KUBE_NODE_INTERFACE)))
	echo "- WiFi SSID:			$(KUBE_NODE_WIFI_SSID)"
	echo "- WiFi Password:		$(KUBE_NODE_WIFI_PASSWORD)"
endif
	echo "- Node Type:			$(KUBE_NODE_TYPE)"
	echo "- Timezone:			$(KUBE_NODE_TIMEZONE)"
	echo "Kubernetes:"
	echo "- Control Plane IP:	$(KUBE_MASTER_VIP)"
	echo "- Master IP 01:		$(KUBE_MASTER_IP_01)"
	echo "- Master IP 02:		$(KUBE_MASTER_IP_02)"
	echo "- Master IP 03:		$(KUBE_MASTER_IP_03)"

.PHONY: prepare
prepare: ## Create all necessary directories to be used in build
	echo "Step - prepare"
	echo "Creating mountpoints:"
	echo "- $(MNT_BOOT)"
	echo "- $(MNT_ROOT)"
	echo "Creating staging folder:"
	echo "- ./$(OUTPUT_PATH)/ssh/"
	sudo mkdir -p $(MNT_BOOT)
	sudo mkdir -p $(MNT_ROOT)
	mkdir -p ./$(OUTPUT_PATH)/ssh/

.PHONY: format
format: $(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).img ## Format the SD card with Raspbian
	echo "Step - format"
	echo "Formatting $(MNT_DEVICE) with $(RASPBIAN_IMAGE_VERSION).img"
	sudo dd bs=4M if=./$(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).img of=$(MNT_DEVICE) status=progress conv=fsync

.PHONY: bootstrap
bootstrap: prepare mount $(OUTPUT_PATH)/ssh/id_ed25519 ## Install bootstrap scripts to mounted media
	echo "Step - bootstrap"
	sudo touch $(MNT_BOOT)/ssh
	mkdir -p $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap
	cp -r ./raspbernetes/* $(KUBE_NODE_USER_HOME)/bootstrap/
	mkdir -p $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/.ssh
	cp ./$(OUTPUT_PATH)/ssh/id_ed25519 $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/.ssh/
	cp ./$(OUTPUT_PATH)/ssh/id_ed25519.pub $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/.ssh/authorized_keys
	sudo rm -f $(MNT_ROOT)/etc/motd
	unmount

.PHONY: configure
configure: prepare mount $(KUBE_NODE_INTERFACE)## Apply configuration to mounted media
	echo "Step - configure"
	## Disable SSH password based login
	sudo sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication no/g" $(MNT_ROOT)/etc/ssh/sshd_config
	## Enable cgroups on boot
	sudo sed -i "s/^/cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory /" $(MNT_BOOT)/cmdline.txt
	## Add node custom configuration file to be sourced on boot
	echo "#!/bin/bash"													| sudo tee $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "## Node specific"												| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_INTERFACE=$(KUBE_NODE_INTERFACE)"			| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_WIFI_SSID=$(KUBE_NODE_WIFI_SSID)"			| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_WIFI_PASSWORD=$(KUBE_NODE_WIFI_PASSWORD)"	| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_HOSTNAME=$(KUBE_NODE_HOSTNAME)"				| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_IP=$(KUBE_NODE_IP)"							| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_GATEWAY=$(KUBE_NODE_GATEWAY)"				| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_TIMEZONE=$(KUBE_NODE_TIMEZONE)"				| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_TYPE=$(KUBE_NODE_TYPE)"						| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_USER=$(KUBE_NODE_USER)"						| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_NODE_USER_HOME=$(KUBE_NODE_USER_HOME)"			| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "## Cluster wide"												| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_MASTER_VIP=$(KUBE_MASTER_VIP)"					| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_MASTER_IP_01=$(KUBE_MASTER_IP_01)"				| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_MASTER_IP_02=$(KUBE_MASTER_IP_02)"				| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	echo "export KUBE_MASTER_IP_03=$(KUBE_MASTER_IP_03)"				| sudo tee -a $(MNT_ROOT)$(KUBE_NODE_USER_HOME)/bootstrap/env
	## Add dhcp configuration to set a static IP and gateway
	echo "interface $(KUBE_NODE_INTERFACE)" | sudo tee -a $(MNT_ROOT)/etc/dhcpcd.conf >/dev/null
	echo "static ip_address=$(KUBE_NODE_IP)/24" | sudo tee -a $(MNT_ROOT)/etc/dhcpcd.conf >/dev/null
	echo "static routers=$(KUBE_NODE_GATEWAY)" | sudo tee -a $(MNT_ROOT)/etc/dhcpcd.conf >/dev/null
	echo "static domain_name_servers=$(KUBE_NODE_GATEWAY)" | sudo tee -a $(MNT_ROOT)/etc/dhcpcd.conf >/dev/null
	## Ensure we are set to execute on reboot
	echo "[Service]" | sudo tee $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "Type=oneshot" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "RemainAfterExit=yes" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "ExecStart=/home/$KUBE_NODE_USER/bootstrap/bootstrap.sh" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "StandardOutput=syslog" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "StandardError=syslog" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "SyslogIdentifier=kubernetes-bootstrap" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "After=network-online.target" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "Wants=network-online.target" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "[Install]" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	echo "WantedBy=multi-user.target" | sudo tee -a $(MNT_ROOT)/etc/systemd/system/kubernetes-bootstrap.service
	unmount

## Helpers
.PHONY: wlan0
wlan0: prepare mount ## Install wpa_supplicant for auto network join
	echo "Step - wlan0"
	test -n "$(KUBE_NODE_WIFI_SSID)"
	test -n "$(KUBE_NODE_WIFI_PASSWORD)"
	sudo cp ./raspbernetes/template/wpa_supplicant.conf $(MNT_BOOT)/wpa_supplicant.conf
	sudo sed -i "s/<WIFI_SSID>/$(KUBE_NODE_WIFI_SSID)/" $(MNT_BOOT)/wpa_supplicant.conf
	sudo sed -i "s/<WIFI_PASSWORD>/$(KUBE_NODE_WIFI_PASSWORD)/" $(MNT_BOOT)/wpa_supplicant.conf
	unmount

.PHONY: eth0
eth0: ## Nothing to do for eth0
	echo "Step - eth0"

$(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).img: ## Download Raspbian image and extract to current directory
	echo "Downloading $(RASPBIAN_IMAGE_VERSION).img..."
	wget $(RASPBIAN_URL) -P ./$(OUTPUT_PATH)/
	unzip ./$(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).zip -d ./$(OUTPUT_PATH)/
	rm -f ./$(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).zip

$(OUTPUT_PATH)/ssh/id_ed25519: ## Generate SSH keypair to use in cluster communication
	ssh-keygen -t ed25519 -b 4096 -C "pi@raspberry" -f ./$(OUTPUT_PATH)/ssh/id_ed25519 -q -N ""

.PHONY: mount
mount: ## Mount the specified media device
	echo "Step - mount"
ifeq (,$(findstring mmcblk,$(MNT_DEVICE)))
	sudo mount $(MNT_DEVICE)1 $(MNT_BOOT)
	sudo mount $(MNT_DEVICE)2 $(MNT_ROOT)
else
	sudo mount $(MNT_DEVICE)p1 $(MNT_BOOT)
	sudo mount $(MNT_DEVICE)p2 $(MNT_ROOT)
endif

.PHONY: unmount
unmount: ## Unmount the specified media device
	echo "Step - unmount"
ifeq (,$(findstring mmcblk,$(MNT_DEVICE)))
	sudo umount $(MNT_DEVICE)1 || true
	sudo umount $(MNT_DEVICE)2 || true
else
	sudo umount $(MNT_DEVICE)p1 || true
	sudo umount $(MNT_DEVICE)p2 || true
endif

.PHONY: clean
clean: ## Cleanup mountpoints
	echo "Step - clean"
	sudo rm -rf $(MNT_BOOT)
	sudo rm -rf $(MNT_ROOT)

.PHONY: help
help: ## Display this help
	awk \
	  'BEGIN { \
	    FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n" \
	  } /^[a-zA-Z_-]+:.*?##/ { \
	    printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 \
	  } /^##@/ { \
	    printf "\n\033[1m%s\033[0m\n", substr($$0, 5) \
	  }' $(MAKEFILE_LIST)