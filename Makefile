SHELL := /bin/bash -o pipefail
.SILENT:
.DEFAULT_GOAL := help

# Default variables
MNT_DEVICE	?= /dev/mmcblk0
MNT_ROOT	= /mnt/raspbernetes/root
MNT_BOOT	= /mnt/raspbernetes/boot
RPI_HOME	= $(MNT_ROOT)/home/pi
OUTPUT_PATH	= output

# Raspberry PI host and IP configuration
RPI_NETWORK_TYPE 	?= eth0
RPI_HOSTNAME     	?= rpi-kube-master-01
RPI_IP           	?= 192.168.2.11
RPI_DNS          	?= 192.168.2.1
RPI_TIMEZONE     	?= America/Indiana/Indianapolis
RPI_WIFI_SSID    	?=
RPI_WIFI_PASSWORD	?=

# Kubernetes configuration
KUBE_NODE_TYPE		?= master
KUBE_MASTER_VIP		?= 192.168.2.10
KUBE_MASTER_IP_01	?= 192.168.2.11
KUBE_MASTER_IP_02	?= 192.168.2.12
KUBE_MASTER_IP_03	?= 192.168.2.13

# Raspbian image configuration
RASPBIAN_VERSION       = raspbian_lite-2019-09-30
RASPBIAN_IMAGE_VERSION = 2019-09-26-raspbian-buster-lite
RASPBIAN_URL           = https://downloads.raspberrypi.org/raspbian_lite/images/$(RASPBIAN_VERSION)/$(RASPBIAN_IMAGE_VERSION).zip

.PHONY: deploy
build: prepare format bootstrap configure unmount ## Generate and pre-configure bootable media for a node
	echo "Image:"
	echo "- Hostname:			$(RPI_HOSTNAME)"
	echo "- Static IP:			$(RPI_IP)"
	echo "- Gateway address:	$(RPI_DNS)"
	echo "- Network adapter:	$(RPI_NETWORK_TYPE)"
ifeq ($(RPI_NETWORK_TYPE),wlan0)
	echo "- WiFi SSID:			$(RPI_WIFI_SSID)"
	echo "- WiFi Password:		$(RPI_WIFI_PASSWORD)"
endif
	echo "- Timezone:			$(RPI_TIMEZONE)"
	echo "Kubernetes:"
	echo "- Node Type:			$(KUBE_NODE_TYPE)"
	echo "- Control Plane IP:	$(KUBE_MASTER_VIP)"
	echo "- Master IP 01:		$(KUBE_MASTER_IP_01)"
	echo "- Master IP 02:		$(KUBE_MASTER_IP_02)"
	echo "- Master IP 03:		$(KUBE_MASTER_IP_03)"

.PHONY: prepare
prepare: ## Create all necessary directories to be used in build
	sudo mkdir -p $(MNT_BOOT)
	sudo mkdir -p $(MNT_ROOT)
	mkdir -p ./$(OUTPUT_PATH)/ssh/

.PHONY: format
format: $(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).img unmount ## Format the SD card with Raspbian
	echo "Formatting SD card with $(RASPBIAN_IMAGE_VERSION).img"
	sudo dd bs=4M if=./$(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).img of=$(MNT_DEVICE) status=progress conv=fsync

.PHONY: bootstrap
bootstrap: $(OUTPUT_PATH)/ssh/id_ed25519 mount ## Install bootstrap scripts to mounted media
	sudo touch $(MNT_BOOT)/ssh
	mkdir -p $(RPI_HOME)/bootstrap/
	cp -r ./raspbernetes/* $(RPI_HOME)/bootstrap/
	mkdir -p $(RPI_HOME)/.ssh
	cp ./$(OUTPUT_PATH)/ssh/id_ed25519 $(RPI_HOME)/.ssh/
	cp ./$(OUTPUT_PATH)/ssh/id_ed25519.pub $(RPI_HOME)/.ssh/authorized_keys
	sudo rm -f $(MNT_ROOT)/etc/motd

.PHONY: configure
configure: $(RPI_NETWORK_TYPE) mount## Apply configuration to mounted media
	## Add default start up script
	sudo sed -i "/^exit 0$$/i /home/pi/bootstrap/bootstrap.sh 2>&1 | logger -t kubernetes-bootstrap &" $(MNT_ROOT)/etc/rc.local
	## Disable SSH password based login
	sudo sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication no/g" $(MNT_ROOT)/etc/ssh/sshd_config
	## Enable cgroups on boot
	sudo sed -i "s/^/cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory /" $(MNT_BOOT)/cmdline.txt
	## Add node custom configuration file to be sourced on boot
	echo "export RPI_HOSTNAME=$(RPI_HOSTNAME)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export RPI_IP=$(RPI_IP)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export RPI_DNS=$(RPI_DNS)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export RPI_NETWORK_TYPE=$(RPI_NETWORK_TYPE)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export RPI_TIMEZONE=$(RPI_TIMEZONE)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export KUBE_MASTER_VIP=$(KUBE_MASTER_VIP)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export KUBE_NODE_TYPE=$(KUBE_NODE_TYPE)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export KUBE_MASTER_IP_01=$(KUBE_MASTER_IP_01)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export KUBE_MASTER_IP_02=$(KUBE_MASTER_IP_02)" >> $(RPI_HOME)/bootstrap/rpi-env
	echo "export KUBE_MASTER_IP_03=$(KUBE_MASTER_IP_03)" >> $(RPI_HOME)/bootstrap/rpi-env
	## Add dhcp configuration to set a static IP and gateway
	echo "interface $(RPI_NETWORK_TYPE)" | sudo tee -a $(MNT_ROOT)/etc/dhcpcd.conf >/dev/null
	echo "static ip_address=$(RPI_IP)/24" | sudo tee -a $(MNT_ROOT)/etc/dhcpcd.conf >/dev/null
	echo "static routers=$(RPI_DNS)" | sudo tee -a $(MNT_ROOT)/etc/dhcpcd.conf >/dev/null
	echo "static domain_name_servers=$(RPI_DNS)" | sudo tee -a $(MNT_ROOT)/etc/dhcpcd.conf >/dev/null

## Helpers
.PHONY: wlan0
wlan0: ## Install wpa_supplicant for auto network join
	test -n "$(RPI_WIFI_SSID)"
	test -n "$(RPI_WIFI_PASSWORD)"
	sudo cp ./raspbernetes/template/wpa_supplicant.conf $(MNT_BOOT)/wpa_supplicant.conf
	sudo sed -i "s/<WIFI_SSID>/$(RPI_WIFI_SSID)/" $(MNT_BOOT)/wpa_supplicant.conf
	sudo sed -i "s/<WIFI_PASSWORD>/$(RPI_WIFI_PASSWORD)/" $(MNT_BOOT)/wpa_supplicant.conf

.PHONY: eth0
eth0: ## Nothing to do for eth0

$(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).img: ## Download Raspbian image and extract to current directory
	echo "Downloading $(RASPBIAN_IMAGE_VERSION).img..."
	wget $(RASPBIAN_URL) -P ./$(OUTPUT_PATH)/
	unzip ./$(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).zip -d ./$(OUTPUT_PATH)/
	rm -f ./$(OUTPUT_PATH)/$(RASPBIAN_IMAGE_VERSION).zip

$(OUTPUT_PATH)/ssh/id_ed25519: ## Generate SSH keypair to use in cluster communication
	ssh-keygen -t ed25519 -b 4096 -C "pi@raspberry" -f ./$(OUTPUT_PATH)/ssh/id_ed25519 -q -N ""

.PHONY: mount
mount: ## Mount the specified media device
ifeq (,$(findstring mmcblk,$(MNT_DEVICE)))
	sudo mount $(MNT_DEVICE)1 $(MNT_BOOT)
	sudo mount $(MNT_DEVICE)2 $(MNT_ROOT)
else
	sudo mount $(MNT_DEVICE)p1 $(MNT_BOOT)
	sudo mount $(MNT_DEVICE)p2 $(MNT_ROOT)
endif

.PHONY: unmount
unmount: ## Unmount the specified media device
ifeq (,$(findstring mmcblk,$(MNT_DEVICE)))
	sudo umount $(MNT_DEVICE)1 || true
	sudo umount $(MNT_DEVICE)2 || true
else
	sudo umount $(MNT_DEVICE)p1 || true
	sudo umount $(MNT_DEVICE)p2 || true
endif
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