ubuntu-amd64-virtualbox.box: preseed.txt setup.sh ubuntu.json
	rm -f ubuntu-amd64-virtualbox.box
	packer build ubuntu.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box remove -f ubuntu-amd64
	@echo vagrant box add ubuntu-amd64 ubuntu-amd64-virtualbox.box

