This builds an up-to-date Vagrant Ubuntu Base Box as described at the [From Iso To Vagrant Box](http://blog.ruilopes.com/from-iso-to-vagrant-box.html) article.

Currently this targets [Ubuntu 16.04](https://help.ubuntu.com/16.04/installation-guide/amd64/index.html).

# Usage

Install [Packer](https://www.packer.io/), [Vagrant](https://www.vagrantup.com/) and [jq](https://stedolan.github.io/jq/).

## qemu-kvm usage

Install qemu-kvm:

```bash
apt-get install -y qemu-kvm
apt-get install -y sysfsutils
systool -m kvm_intel -v
```

Type `make build-libvirt` and follow the instructions.

Try the example guest:

```bash
cd example
apt-get install -y virt-manager libvirt-dev
vagrant plugin install vagrant-libvirt
vagrant up --provider=libvirt
vagrant ssh
exit
vagrant destroy -f
```

## VirtualBox usage

Install [VirtuaBox](https://www.virtualbox.org/).

Type `make build-virtualbox` and follow the instructions.

Try the example guest:

```bash
cd example
vagrant up --provider=virtualbox
vagrant ssh
exit
vagrant destroy -f
```
