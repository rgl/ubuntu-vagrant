#!/bin/bash
set -euxo pipefail

# let the sudo group members use root permissions without a password.
# NB d-i automatically adds vagrant into the sudo group.
sed -i -E 's,^%sudo\s+.+,%sudo ALL=(ALL) NOPASSWD:ALL,g' /etc/sudoers

# install the vagrant public key.
# NB vagrant will replace it on the first run.
install -d -m 700 /home/vagrant/.ssh
pushd /home/vagrant/.ssh
wget -qOauthorized_keys https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
chmod 600 authorized_keys
chown -R vagrant:vagrant .

# install cloud-init.
apt-get install -y --no-install-recommends cloud-init
if [ -n "$(lspci | grep VMware | head -1)" ]; then
# only install when the current cloud-init does not have the VMware datasource.
if [ ! -f /usr/lib/python3/dist-packages/cloudinit/sources/DataSourceVMware.py ]; then
# add support for the vmware vmx guestinfo cloud-init datasource.
# NB there is plans to include this datasource in the upstream cloud-init project at
#    https://github.com/vmware/cloud-init-vmware-guestinfo/issues/2 but in the meantime
#    we are really installing from an internet pipe.
# see https://github.com/vmware/cloud-init-vmware-guestinfo
apt-get install -y --no-install-recommends curl
apt-get install -y --no-install-recommends python3-pip
export GIT_REF='v1.4.1'
wget -qO- https://raw.githubusercontent.com/vmware/cloud-init-vmware-guestinfo/$GIT_REF/install.sh \
    | bash -x -
unset GIT_REF
apt-get remove -y --purge curl
fi
fi

# only enable the supported cloud-init datasources.
# NB this is especially required for not waiting for datasources that try to
#    contact the metadata service at http://169.254.169.254 (like the AWS
#    datasource) that do not exist in our supported hypervisors.
# NB you cannot use debconf-set-selections with dpkg-reconfigure (it ignores
#    debconf), so we have to directly edit the configuration.
echo 'datasource_list: [NoCloud, ConfigDrive, VMware, None]' >/etc/cloud/cloud.cfg.d/95_datasources.cfg

# install the nfs client to support nfs synced folders in vagrant.
apt-get install -y nfs-common

# install the smb client to support cifs/smb/samba synced folders in vagrant.
apt-get install -y --no-install-recommends cifs-utils

# install rsync to support rsync synced folders in vagrant.
apt-get install -y rsync

# disable the DNS reverse lookup on the SSH server. this stops it from
# trying to resolve the client IP address into a DNS domain name, which
# is kinda slow and does not normally work when running inside VB.
echo UseDNS no >> /etc/ssh/sshd_config

# remove the boot/shutdown splash.
apt-get remove --purge -y plymouth

# show boot messages.
# NB the default is "quiet splash".
sed -i -E 's,^(GRUB_CMDLINE_LINUX_DEFAULT\s*=).*,\1"",g' /etc/default/grub

# disable the graphical terminal. its kinda slow and useless on a VM.
sed -i -E 's,#(GRUB_TERMINAL\s*=).*,\1console,g' /etc/default/grub

# apply the grub configuration.
update-grub

# use the up/down arrows to navigate the bash history.
# NB to get these codes, press ctrl+v then the key combination you want.
cat<<"EOF">>/etc/inputrc
"\e[A": history-search-backward
"\e[B": history-search-forward
set show-all-if-ambiguous on
set completion-ignore-case on
EOF

# reset the machine-id.
# NB systemd will re-generate it on the next boot.
# NB machine-id is indirectly used in DHCP as Option 61 (Client Identifier), which
#    the DHCP server uses to (re-)assign the same or new client IP address.
# see https://www.freedesktop.org/software/systemd/man/machine-id.html
# see https://www.freedesktop.org/software/systemd/man/systemd-machine-id-setup.html
echo '' >/etc/machine-id
rm -f /var/lib/dbus/machine-id

# reset the random-seed.
# NB systemd-random-seed re-generates it on every boot and shutdown.
# NB you can prove that random-seed file does not exist on the image with:
#       sudo virt-filesystems -a ~/.vagrant.d/boxes/ubuntu-20.04-amd64/0/libvirt/box.img
#       sudo mkdir /mnt/ubuntu-20.04-amd64
#       sudo guestmount -a ~/.vagrant.d/boxes/ubuntu-20.04-amd64/0/libvirt/box.img -m /dev/sda1 --pid-file guestmount.pid --ro /mnt/ubuntu-20.04-amd64
#       sudo bash -c 'unmkinitramfs /mnt/ubuntu-20.04-amd64/boot/initrd.img /tmp/ubuntu-20.04-amd64-initrd' # NB prefer unmkinitramfs over cpio.
#       sudo ls -laF /mnt/var/lib/systemd
#       sudo guestunmount /mnt/ubuntu-20.04-amd64
#       sudo bash -c 'while kill -0 $(cat guestmount.pid) 2>/dev/null; do sleep .1; done; rm guestmount.pid' # wait for guestmount to finish.
# see https://www.freedesktop.org/software/systemd/man/systemd-random-seed.service.html
# see https://manpages.ubuntu.com/manpages/bionic/man4/random.4.html
# see https://manpages.ubuntu.com/manpages/bionic/man7/random.7.html
# see https://github.com/systemd/systemd/blob/master/src/random-seed/random-seed.c
# see https://github.com/torvalds/linux/blob/master/drivers/char/random.c
systemctl stop systemd-random-seed
rm -f /var/lib/systemd/random-seed

# clean packages.
apt-get -y autoremove --purge
apt-get -y clean

# zero the free disk space -- for better compression of the box file.
# NB prefer discard/trim (safer; faster) over creating a big zero filled file
#    (somewhat unsafe as it has to fill the entire disk, which might trigger
#    a disk (near) full alarm; slower; slightly better compression).
root_dev="$(findmnt -no SOURCE /)"
if [ "$(lsblk -no DISC-GRAN $root_dev | awk '{print $1}')" != '0B' ]; then
    while true; do
        output="$(fstrim -v /)"
        cat <<<"$output"
        sync && sync && sync && blockdev --flushbufs $root_dev && sleep 15
        if [ "$output" == '/: 0 B (0 bytes) trimmed' ]; then
            break
        fi
    done
else
    dd if=/dev/zero of=/EMPTY bs=1M || true; rm -f /EMPTY
fi
