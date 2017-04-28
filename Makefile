VERSION=$(shell jq -r .variables.version ubuntu.json)

build-libvirt: ubuntu-${VERSION}-amd64-libvirt.box

build-virtualbox: ubuntu-${VERSION}-amd64-virtualbox.box

ubuntu-${VERSION}-amd64-libvirt.box: preseed.txt provision.sh ubuntu.json Vagrantfile.template
	rm -f ubuntu-${VERSION}-amd64-libvirt.box
	PACKER_KEY_INTERVAL=10ms packer build -only=ubuntu-${VERSION}-amd64-libvirt -on-error=abort ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-libvirt.box

ubuntu-${VERSION}-amd64-virtualbox.box: preseed.txt provision.sh ubuntu.json Vagrantfile.template
	rm -f ubuntu-${VERSION}-amd64-virtualbox.box
	packer build -only=ubuntu-${VERSION}-amd64-virtualbox -on-error=abort ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-virtualbox.box

.PHONY: buid-libvirt build-virtualbox
