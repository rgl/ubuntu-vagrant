This builds an up-to-date Vagrant Ubuntu Base Box as described at the [From Iso To Vagrant Box](http://blog.ruilopes.com/from-iso-to-vagrant-box.html) article.

Currently this targets [Ubuntu 18.04](https://help.ubuntu.com/18.04/installation-guide/amd64/index.html).

# Usage

## Ubuntu Host

On a Ubuntu host, install the dependencies by running the file at:

    https://github.com/rgl/xfce-desktop-vagrant/blob/master/provision-virtualization-tools.sh

And you should also install and configure the NFS server. E.g.:

```bash
# install the nfs server.
sudo apt-get install -y nfs-kernel-server

# enable password-less configuration of the nfs server exports.
sudo bash -c 'cat >/etc/sudoers.d/vagrant-synced-folders' <<'EOF'
Cmnd_Alias VAGRANT_EXPORTS_CHOWN = /bin/chown 0\:0 /tmp/*
Cmnd_Alias VAGRANT_EXPORTS_MV = /bin/mv -f /tmp/* /etc/exports
Cmnd_Alias VAGRANT_NFSD_CHECK = /etc/init.d/nfs-kernel-server status
Cmnd_Alias VAGRANT_NFSD_START = /etc/init.d/nfs-kernel-server start
Cmnd_Alias VAGRANT_NFSD_APPLY = /usr/sbin/exportfs -ar
%sudo ALL=(root) NOPASSWD: VAGRANT_EXPORTS_CHOWN, VAGRANT_EXPORTS_MV, VAGRANT_NFSD_CHECK, VAGRANT_NFSD_START, VAGRANT_NFSD_APPLY
EOF
```

For more information see the [Vagrant NFS documentation](https://www.vagrantup.com/docs/synced-folders/nfs.html).

## Windows Host

On a Windows host, install [Chocolatey](https://chocolatey.org/install), then execute the following PowerShell commands in a Administrator PowerShell window:

```powershell
choco install -y virtualbox --params "/NoDesktopShortcut /ExtensionPack"
choco install -y packer vagrant jq msys2
```

Then open a bash shell by starting `C:\tools\msys64\mingw64.exe` and install the remaining dependencies:

```bash
pacman --noconfirm -Sy make zip unzip tar dos2unix netcat procps xorriso mingw-w64-x86_64-libcdio
for n in /*.ini; do
    sed -i -E 's,^#?(MSYS2_PATH_TYPE)=.+,\1=inherit,g' $n
done
exit
```

**NB** The commands described in this README should be executed in a mingw64 bash shell.

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

## VMware vSphere usage

Download [govc](https://github.com/vmware/govmomi/releases/latest) and place it inside your `/usr/local/bin` directory.

Install the [vsphere vagrant plugin](https://github.com/nsidc/vagrant-vsphere), set your vSphere details, and test the connection to vSphere:

```bash
sudo apt-get install build-essential patch ruby-dev zlib1g-dev liblzma-dev
vagrant plugin install vagrant-vsphere
cd example
cat >secrets.sh <<EOF
export GOVC_INSECURE='1'
export GOVC_HOST='vsphere.local'
export GOVC_URL="https://$GOVC_HOST/sdk"
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='password'
export GOVC_DATACENTER='Datacenter'
export GOVC_CLUSTER='Cluster'
export GOVC_DATASTORE='Datastore'
export VSPHERE_ESXI_HOST='esxi.local'
export VSPHERE_TEMPLATE_FOLDER='test/templates'
export VSPHERE_TEMPLATE_NAME="$VSPHERE_TEMPLATE_FOLDER/ubuntu-18.04-amd64-vsphere"
export VSPHERE_VM_FOLDER='test'
export VSPHERE_VM_NAME='ubuntu-vagrant-example'
export VSPHERE_VLAN='packer'
EOF
source secrets.sh
# see https://github.com/vmware/govmomi/blob/master/govc/USAGE.md
govc version
govc about
govc datacenter.info # list datacenters
govc find # find all managed objects
```

Download the Ubuntu ISO (you can find the full iso URL in the [ubuntu.json](ubuntu.json) file) and place it inside the datastore as defined by the `vsphere_iso_url` user variable that is inside the [packer template](ubuntu-vsphere.json).

See the [example Vagrantfile](example/Vagrantfile) to see how you could use a cloud-init configuration to configure the VM.

Type `make build-vsphere` and follow the instructions.

Try the example guest:

```bash
source secrets.sh
vagrant up --provider=vsphere
vagrant ssh
exit
vagrant destroy -f
```
