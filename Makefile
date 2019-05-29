VERSION=$(shell jq -r .variables.version ubuntu.json)

help:
	@echo type make build-libvirt, make build-virtualbox or make build-vsphere

build-libvirt: ubuntu-${VERSION}-amd64-libvirt.box
build-virtualbox: ubuntu-${VERSION}-amd64-virtualbox.box
build-vsphere: ubuntu-${VERSION}-amd64-vsphere.box

ubuntu-${VERSION}-amd64-libvirt.box: preseed.txt provision.sh ubuntu.json Vagrantfile.template
	rm -f $@
	PACKER_KEY_INTERVAL=10ms CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log \
		packer build -only=ubuntu-${VERSION}-amd64-libvirt -on-error=abort ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-libvirt.box

ubuntu-${VERSION}-amd64-virtualbox.box: preseed.txt provision.sh ubuntu.json Vagrantfile.template
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log \
		packer build -only=ubuntu-${VERSION}-amd64-virtualbox -on-error=abort ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-virtualbox.box

ubuntu-${VERSION}-amd64-vsphere.box: tmp/preseed-vsphere.txt provision.sh ubuntu-vsphere.json Vagrantfile.template dummy-vsphere.box
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$@.log \
		packer build -only=ubuntu-${VERSION}-amd64-vsphere ubuntu-vsphere.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f dummy dummy-vsphere.box

tmp/preseed-vsphere.txt: preseed.txt
	mkdir -p tmp
	sed -E 's,(d-i pkgsel/include string .+),\1 open-vm-tools,g' preseed.txt >$@

dummy-vsphere.box:
	echo '{"provider":"vsphere"}' >metadata.json
	tar cvf $@ metadata.json
	rm metadata.json

.PHONY: help buid-libvirt build-virtualbox build-vsphere
