This builds an up-to-date Vagrant Ubuntu Base Box as described at the [From Iso To Vagrant Box](http://blog.ruilopes.com/from-iso-to-vagrant-box.html) article.

Currently this targets [Ubuntu 22.04 (Jammy Jellyfish)](https://wiki.ubuntu.com/JammyJellyfish/ReleaseNotes).

Other Ubuntu versions might be available in a [separate branch](https://github.com/rgl/ubuntu-vagrant/branches).

# Usage

Install Packer 1.7+ and Vagrant 2.2.14+.

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
# NB if you want to use Hyper-V see the Hyper-V section in this document.
choco install -y packer vagrant jq msys2
```

Then open a bash shell by starting `C:\tools\msys64\mingw64.exe` and install the remaining dependencies:

```bash
pacman --noconfirm -Sy make zip unzip tar dos2unix netcat procps xorriso mingw-w64-x86_64-libcdio openssh
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
vagrant up --provider=libvirt --no-destroy-on-error --no-tty
vagrant ssh
exit
vagrant destroy -f
```

## Proxmox usage

Set the Proxmox VE details:

```bash
cat >secrets-proxmox.sh <<EOF
export PROXMOX_URL='https://192.168.1.21:8006/api2/json'
export PROXMOX_USERNAME='root@pam'
export PROXMOX_PASSWORD='vagrant'
export PROXMOX_NODE='pve'
EOF
source secrets-proxmox.sh
```

Create the template:

```bash
make build-proxmox
```

**NB** There is no way to use the created template with vagrant (the [vagrant-proxmox plugin](https://github.com/telcat/vagrant-proxmox) is no longer compatible with recent vagrant versions). Instead, use packer (e.g. see this repository) or terraform (e.g. see [rgl/terraform-proxmox-ubuntu-example](https://github.com/rgl/terraform-proxmox-ubuntu-example)).

## Hyper-V usage

Install [Hyper-V](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v)
and also install the `Windows Sandbox` feature (for some reason,
installing this makes DHCP work properly in the vEthernet Default Switch).

Make sure your user is in the `Hyper-V Administrators` group
or you run with Administrative privileges.

Make sure your Virtual Switch (its vEthernet network adapter) is excluded
from the Windows Firewall protected network connections by executing the
following commands in a bash shell with Administrative privileges:

```bash
PowerShell -Command 'Get-NetFirewallProfile | Select-Object -Property Name,DisabledInterfaceAliases'
PowerShell -Command 'Set-NetFirewallProfile -DisabledInterfaceAliases (Get-NetAdapter -name "vEthernet*" | Where-Object {$_.ifIndex}).InterfaceAlias'
```

Create the base image in a bash shell with Administrative privileges:

```bash
cat >secrets-hyperv.sh <<EOF
# set this value when you need to set the VM Switch Name.
export HYPERV_SWITCH_NAME='Default Switch'
# set this value when you need to set the VM VLAN ID.
export HYPERV_VLAN_ID=''
# set the credentials that the guest will use
# to connect to this host smb share.
# NB you should create a new local user named _vagrant_share
#    and use that one here instead of your user credentials.
# NB it would be nice for this user to have its credentials
#    automatically rotated, if you implement that feature,
#    let me known!
export VAGRANT_SMB_USERNAME='_vagrant_share'
export VAGRANT_SMB_PASSWORD=''
# remove the virtual switch from the windows firewall.
# NB execute if the VM fails to obtain an IP address from DHCP.
PowerShell -Command 'Set-NetFirewallProfile -DisabledInterfaceAliases (Get-NetAdapter -name "vEthernet*" | Where-Object {$_.ifIndex}).InterfaceAlias'
EOF
source secrets-hyperv.sh
make build-hyperv
```

Try the example guest:

**NB** You will need Administrative privileges to create the SMB share.

```bash
cd example
# grant $VAGRANT_SMB_USERNAME full permissions to the
# current directory.
# NB you must first install the Carbon PowerShell module
#    with choco install -y carbon.
# TODO set VM screen resolution.
PowerShell -Command '&"$env:ChocolateyInstall/lib/Carbon/Carbon/Import-Carbon.ps1"; Grant-CPermission . $env:VAGRANT_SMB_USERNAME FullControl'
vagrant up --provider=hyperv --no-destroy-on-error --no-tty
vagrant ssh
exit
vagrant destroy -f
```

## VMware vSphere usage

Download [govc](https://github.com/vmware/govmomi/releases/latest) and place it inside your `/usr/local/bin` directory.

Set your VMware vSphere details and test the connection:

```bash
sudo apt-get install build-essential patch ruby-dev zlib1g-dev liblzma-dev
vagrant plugin install vagrant-vsphere
cat >secrets-vsphere.sh <<'EOF'
export GOVC_INSECURE='1'
export GOVC_HOST='vsphere.local'
export GOVC_URL="https://$GOVC_HOST/sdk"
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='password'
export GOVC_DATACENTER='Datacenter'
export GOVC_CLUSTER='Cluster'
export GOVC_DATASTORE='Datastore'
export VSPHERE_OS_ISO="[$GOVC_DATASTORE] iso/ubuntu-22.04.4-live-server-amd64.iso"
export VSPHERE_ESXI_HOST='esxi.local'
export VSPHERE_TEMPLATE_FOLDER='test/templates'
export VSPHERE_TEMPLATE_NAME="$VSPHERE_TEMPLATE_FOLDER/ubuntu-22.04-amd64-vsphere"
export VSPHERE_VM_FOLDER='test'
export VSPHERE_VM_NAME='ubuntu-vagrant-example'
export VSPHERE_VLAN='packer'
export VSPHERE_IP_WAIT_ADDRESS='0.0.0.0/0'
# set the credentials that the guest will use
# to connect to this host smb share.
# NB you should create a new local user named _vagrant_share
#    and use that one here instead of your user credentials.
# NB it would be nice for this user to have its credentials
#    automatically rotated, if you implement that feature,
#    let me known!
export VAGRANT_SMB_USERNAME='_vagrant_share'
export VAGRANT_SMB_PASSWORD=''
EOF
source secrets-vsphere.sh
# see https://github.com/vmware/govmomi/blob/master/govc/USAGE.md
govc version
govc about
govc datacenter.info # list datacenters
govc find # find all managed objects
```

Download the Ubuntu ISO (you can find the full iso URL in the [ubuntu.pkr.hcl](ubuntu.pkr.hcl) file) and place it inside the datastore as defined by the `iso_paths` property that is inside the [packer template](ubuntu-vsphere.pkr.hcl) file.

See the [example Vagrantfile](example/Vagrantfile) to see how you could use a cloud-init configuration to configure the VM.

Type `make build-vsphere` and follow the instructions.

Try the example guest:

```bash
source secrets-vsphere.sh
cd example
vagrant up --provider=vsphere --no-destroy-on-error --no-tty
vagrant ssh
exit
vagrant destroy -f
```
