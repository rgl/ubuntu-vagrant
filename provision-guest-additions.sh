#!/bin/bash
set -euxo pipefail

# install the Guest Additions.
if [ -n "$(lspci | grep VirtualBox)" ]; then
# install the VirtualBox Guest Additions.
# this will be installed at /opt/VBoxGuestAdditions-VERSION.
# NB You can unpack the VBoxLinuxAdditions.run file contents with:
#       VBoxLinuxAdditions.run --target /tmp/VBoxLinuxAdditions.run.contents --noexec
# NB REMOVE_INSTALLATION_DIR=0 is to fix a bug in VBoxLinuxAdditions.run.
#    See http://stackoverflow.com/a/25943638.
apt-get -y -q install gcc dkms
mkdir -p /mnt
mount /dev/sr1 /mnt
while [ ! -f /mnt/VBoxLinuxAdditions.run ]; do sleep 1; done
# NB we ignore exit code 2 (cannot find vboxguest module) because of what
#    seems to be a bug in VirtualBox 5.1.20. there isn't actually a problem
#    loading the module.
REMOVE_INSTALLATION_DIR=0 /mnt/VBoxLinuxAdditions.run --target /tmp/VBoxGuestAdditions || [ $? -eq 2 ]
rm -rf /tmp/VBoxGuestAdditions
umount /mnt
eject /dev/sr1
modinfo vboxguest
elif [ -n "$(lspci | grep 'Red Hat' | head -1)" ]; then
# install the qemu-kvm Guest Additions.
apt-get install -y qemu-guest-agent spice-vdagent
elif [ -n "$(lspci | grep VMware | head -1)" ]; then
# no need to install the VMware Guest Additions as they were
# already installed from tmp/preseed-vsphere.txt.
exit 0
elif [ "$(cat /sys/devices/virtual/dmi/id/sys_vendor)" == 'Microsoft Corporation' ]; then
# no need to install the Hyper-V Guest Additions (aka Linux Integration Services)
# as they were already installed from tmp/preseed-hyperv.txt.
# BUT we need to fix these journal entries:
#       hv_kvp_daemon[19271]: sh: 1: /usr/libexec/hypervkvpd/hv_get_dns_info: not found
#       hv_kvp_daemon[19271]: sh: 1: /usr/libexec/hypervkvpd/hv_get_dhcp_info: not found
# see https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1766857
install -d /usr/libexec
ln -s /usr/sbin /usr/libexec/hypervkvpd
exit 0
else
echo 'ERROR: Unknown VM host.'
exit 1
fi

# reboot.
nohup bash -c "ps -eo pid,comm | awk '/sshd/{print \$1}' | xargs kill; sync; reboot"
