SHELL=bash
.SHELLFLAGS=-euo pipefail -c

VERSION=$(shell jq -r .variables.version ubuntu.json)

help:
	@echo type make build-libvirt, make build-virtualbox, make build-hyperv or make build-vsphere

build-libvirt: ubuntu-${VERSION}-amd64-libvirt.box
build-virtualbox: ubuntu-${VERSION}-amd64-virtualbox.box
build-hyperv: ubuntu-${VERSION}-amd64-hyperv.box
build-vsphere: ubuntu-${VERSION}-amd64-vsphere.box

ubuntu-${VERSION}-amd64-libvirt.box: preseed.txt provision.sh ubuntu.json Vagrantfile.template
	rm -f $@
	PACKER_KEY_INTERVAL=10ms CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log \
		packer build -only=ubuntu-${VERSION}-amd64-libvirt -on-error=abort -timestamp-ui ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-libvirt.box

ubuntu-${VERSION}-amd64-virtualbox.box: preseed.txt provision.sh ubuntu.json Vagrantfile.template
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log \
		packer build -only=ubuntu-${VERSION}-amd64-virtualbox -on-error=abort -timestamp-ui ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-virtualbox.box

ubuntu-${VERSION}-amd64-hyperv.box: tmp/preseed-hyperv.txt provision.sh ubuntu.json Vagrantfile.template
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log \
		packer build -only=ubuntu-${VERSION}-amd64-hyperv -on-error=abort -timestamp-ui ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-hyperv.box

# see https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/supported-ubuntu-virtual-machines-on-hyper-v
tmp/preseed-hyperv.txt: preseed.txt
	mkdir -p tmp
	sed -E 's,(d-i pkgsel/include string .+),\1 linux-image-virtual linux-tools-virtual linux-cloud-tools-virtual,g' preseed.txt >$@

ubuntu-${VERSION}-amd64-vsphere.box: tmp/preseed-vsphere.txt provision.sh ubuntu-vsphere.json Vagrantfile.template
	rm -f $@
	PACKER_KEY_INTERVAL=10ms CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log \
		packer build -only=ubuntu-${VERSION}-amd64-vsphere -timestamp-ui ubuntu-vsphere.json
	rm -rf tmp/$@-contents
	mkdir -p tmp/$@-contents
	echo '{"provider":"vsphere"}' >tmp/$@-contents/metadata.json
	cp Vagrantfile.template tmp/$@-contents/Vagrantfile
	tar cvf $@ -C tmp/$@-contents .
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-vsphere.box

tmp/preseed-vsphere.txt: preseed.txt
	mkdir -p tmp
	sed -E 's,(d-i pkgsel/include string .+),\1 open-vm-tools,g' preseed.txt >$@

.PHONY: help buid-libvirt build-virtualbox build-vsphere
