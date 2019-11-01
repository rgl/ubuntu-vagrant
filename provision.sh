#!/bin/bash
# abort this script when a command fails or a unset variable is used.
set -eu
# echo all the executed commands.
set -x

# let the sudo group members use root permissions without a password.
# NB d-i automatically adds vagrant into the sudo group.
sed -i -E 's,^%sudo\s+.+,%sudo ALL=(ALL) NOPASSWD:ALL,g' /etc/sudoers

# install the vagrant public key.
# NB vagrant will replace it on the first run.
install -d -m 700 /home/vagrant/.ssh
pushd /home/vagrant/.ssh
wget -qOauthorized_keys https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
chmod 600 ~/.ssh/authorized_keys
chown -R vagrant:vagrant .

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
# install the VMware Guest Additions.
true # NB open-vm-tools is (and must be) installed from preseed.txt.
else
echo 'ERROR: Unknown VM host.' || exit 1
fi

# install cloud-init.
apt-get install -y --no-install-recommends cloud-init cloud-initramfs-growroot
if [ -n "$(lspci | grep VMware | head -1)" ]; then
# add support for the vmware vmx guestinfo cloud-init datasource.
# NB there is plans to include this datasource in the upstream cloud-init project at
#    https://github.com/vmware/cloud-init-vmware-guestinfo/issues/2 but in the meantime
#    we are really installing from an internet pipe.
# see https://github.com/vmware/cloud-init-vmware-guestinfo
apt-get install -y --no-install-recommends curl
apt-get install -y --no-install-recommends python3-pip
export GIT_REF='242f539c80fb6167c023a0098993fcdb71a19e54'
wget -qO- https://raw.githubusercontent.com/vmware/cloud-init-vmware-guestinfo/$GIT_REF/install.sh \
    | bash -x -
unset GIT_REF
apt-get remove -y --purge curl
fi

# install the nfs client to support nfs synced folders in vagrant.
apt-get install -y nfs-common

# install rsync to support rsync synced folders in vagrant.
apt-get install -y rsync

# disable the DNS reverse lookup on the SSH server. this stops it from
# trying to resolve the client IP address into a DNS domain name, which
# is kinda slow and does not normally work when running inside VB.
echo UseDNS no >> /etc/ssh/sshd_config

# disable the graphical terminal. its kinda slow and useless on a VM.
sed -i -E 's,#(GRUB_TERMINAL\s*=).*,\1console,g' /etc/default/grub
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
#       sudo virt-filesystems -a ~/.vagrant.d/boxes/ubuntu-18.04-amd64/0/libvirt/box.img
#       sudo guestmount -a ~/.vagrant.d/boxes/ubuntu-18.04-amd64/0/libvirt/box.img -m /dev/sda1 --pid-file guestmount.pid --ro /mnt
#       sudo ls -laF /mnt/var/lib/systemd
#       sudo guestunmount /mnt
#       sudo bash -c 'while kill -0 $(cat guestmount.pid) 2>/dev/null; do sleep .1; done; rm guestmount.pid' # wait for guestmount to finish.
# see https://www.freedesktop.org/software/systemd/man/systemd-random-seed.service.html
# see https://manpages.ubuntu.com/manpages/bionic/man4/random.4.html
# see https://manpages.ubuntu.com/manpages/bionic/man7/random.7.html
# see https://github.com/systemd/systemd/blob/master/src/random-seed/random-seed.c
# see https://github.com/torvalds/linux/blob/master/drivers/char/random.c
systemctl stop systemd-random-seed
rm -f /var/lib/systemd/random-seed

# clean packages.
apt-get -y autoremove
apt-get -y clean

# zero the free disk space -- for better compression of the box file.
# NB prefer discard/trim (safer; faster) over creating a big zero filled file
#    (somewhat unsafe as it has to fill the entire disk, which might trigger
#    a disk (near) full alarm; slower; slightly better compression).
if [ "$(lsblk -no DISC-GRAN $(findmnt -no SOURCE /) | awk '{print $1}')" != '0B' ]; then
    fstrim -v /
else
    dd if=/dev/zero of=/EMPTY bs=1M || true; rm -f /EMPTY
fi
