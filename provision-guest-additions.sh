#!/bin/bash
set -euxo pipefail

# wait for cloud-init to finish.
if [ "$(cloud-init status | perl -ne '/^status: (.+)/ && print $1')" != 'disabled' ]; then
    cloud-init status --long --wait
fi

# install the Guest Additions.
if [ -n "$(lspci | grep 'Red Hat' | head -1)" ]; then
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
