VERSION=$(shell jq -r .variables.version ubuntu.json)

ubuntu-${VERSION}-amd64-virtualbox.box: preseed.txt provision.sh ubuntu.json
	rm -f ubuntu-${VERSION}-amd64-virtualbox.box
	packer build ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f ubuntu-${VERSION}-amd64 ubuntu-${VERSION}-amd64-virtualbox.box
