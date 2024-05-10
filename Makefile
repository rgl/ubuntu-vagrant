SHELL=bash
.SHELLFLAGS=-euo pipefail -c

VERSION=22.04

help:
	@echo type make build-libvirt, make build-uefi-libvirt, make build-proxmox, make build-hyperv or make build-vsphere

build-libvirt: ubuntu-${VERSION}-amd64-libvirt.box
build-uefi-libvirt: ubuntu-${VERSION}-uefi-amd64-libvirt.box
build-proxmox: ubuntu-${VERSION}-amd64-proxmox.box
build-hyperv: ubuntu-${VERSION}-amd64-hyperv.box
build-vsphere: ubuntu-${VERSION}-amd64-vsphere.box

ubuntu-${VERSION}-amd64-libvirt.box: autoinstall-cloud-init-data/* provision.sh ubuntu.pkr.hcl Vagrantfile.template
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.init.log \
		packer init ubuntu.pkr.hcl
	PACKER_KEY_INTERVAL=10ms CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log PKR_VAR_vagrant_box=$@ \
		packer build -only=qemu.ubuntu-amd64 -on-error=abort -timestamp-ui ubuntu.pkr.hcl
	@./box-metadata.sh libvirt ubuntu-${VERSION}-amd64 $@

ubuntu-${VERSION}-uefi-amd64-libvirt.box: tmp/libvirt-uefi-autoinstall-cloud-init-data/user-data autoinstall-cloud-init-data/* provision.sh ubuntu.pkr.hcl Vagrantfile-uefi.template
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.init.log \
		packer init ubuntu.pkr.hcl
	PACKER_KEY_INTERVAL=10ms CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log PKR_VAR_vagrant_box=$@ \
		packer build -only=qemu.ubuntu-uefi-amd64 -on-error=abort -timestamp-ui ubuntu.pkr.hcl
	@./box-metadata.sh libvirt ubuntu-${VERSION}-uefi-amd64 $@

tmp/libvirt-uefi-autoinstall-cloud-init-data/user-data: autoinstall-cloud-init-data/user-data
	mkdir -p $(shell dirname $@)
	sed -E 's,\*storage-config-msdos,*storage-config-gpt,g' $< >$@

ubuntu-${VERSION}-amd64-proxmox.box: tmp/proxmox-autoinstall-cloud-init-data/user-data autoinstall-cloud-init-data/* provision.sh ubuntu.pkr.hcl
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.init.log \
		packer init ubuntu.pkr.hcl
	PACKER_KEY_INTERVAL=10ms CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log PKR_VAR_version=${VERSION} PKR_VAR_vagrant_box=$@ \
		packer build -only=proxmox-iso.ubuntu-amd64 -on-error=abort -timestamp-ui ubuntu.pkr.hcl

tmp/proxmox-autoinstall-cloud-init-data/user-data: autoinstall-cloud-init-data/user-data
	mkdir -p $(shell dirname $@)
	sed -E 's,\*storage-config-msdos,*storage-config-gpt,g' $< \
		| sed -E 's,((\s+)packages:),\1\n\2  - qemu-guest-agent,g' \
		>$@

ubuntu-${VERSION}-amd64-hyperv.box: tmp/hyperv-autoinstall-cloud-init-data/user-data autoinstall-cloud-init-data/* provision.sh ubuntu.pkr.hcl Vagrantfile.template
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.init.log \
		packer init ubuntu.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log PKR_VAR_version=${VERSION} PKR_VAR_vagrant_box=$@ \
		packer build -only=hyperv-iso.ubuntu-amd64 -on-error=abort -timestamp-ui ubuntu.pkr.hcl
	@./box-metadata.sh hyperv ubuntu-${VERSION}-amd64 $@

# see https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/supported-ubuntu-virtual-machines-on-hyper-v
tmp/hyperv-autoinstall-cloud-init-data/user-data: autoinstall-cloud-init-data/user-data
	mkdir -p $(shell dirname $@)
	cp -f $< $@
	sed -i -E 's,\*storage-config-msdos,*storage-config-gpt,g' $@
	sed -i -E 's,((.+)- openssh-server.*),\1\n\2- linux-image-virtual\n\2- linux-tools-virtual\n\2- linux-cloud-tools-virtual,g' $@

ubuntu-${VERSION}-amd64-vsphere.box: tmp/vsphere-autoinstall-cloud-init-data/user-data autoinstall-cloud-init-data/* provision.sh ubuntu-vsphere.pkr.hcl Vagrantfile.template
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.init.log \
		packer init ubuntu-vsphere.pkr.hcl
	PACKER_KEY_INTERVAL=10ms CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log PKR_VAR_version=${VERSION} \
		packer build -only=vsphere-iso.ubuntu-amd64 -on-error=abort -timestamp-ui ubuntu-vsphere.pkr.hcl
	rm -rf tmp/$@-contents
	mkdir -p tmp/$@-contents
	echo '{"provider":"vsphere"}' >tmp/$@-contents/metadata.json
	cp Vagrantfile.template tmp/$@-contents/Vagrantfile
	tar cvf $@ -C tmp/$@-contents .
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 $@

tmp/vsphere-autoinstall-cloud-init-data/user-data: autoinstall-cloud-init-data/user-data
	mkdir -p $(shell dirname $@)
	sed -E 's,((.+)- openssh-server.*),\1\n\2- open-vm-tools,g' $< >$@

.PHONY: help build-libvirt build-uefi-libvirt build-proxmox build-hyperv build-vsphere
