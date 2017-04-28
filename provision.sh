#!/bin/bash
# abort this script when a command fails or a unset variable is used.
set -eu
# echo all the executed commands.
set -x

# let our user use root permissions without sudo asking for a password (because
# d-i adds us into the sudo group, but we must be on the admin group instead).
# alternatively: echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant
groupadd -r admin
usermod -a -G admin vagrant
gpasswd -d vagrant sudo
sed -i -e 's,%admin ALL=(ALL) ALL,%admin ALL=(ALL) NOPASSWD:ALL,g' /etc/sudoers

# install the vagrant public key.
# NB vagrant will replace it on the first run.
install -d -m 700 /home/vagrant/.ssh
pushd /home/vagrant/.ssh
wget --no-check-certificate https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -O authorized_keys
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
else
# install the qemu-kvm Guest Additions.
apt-get install -y qemu-guest-agent spice-vdagent
fi

# install rsync to support "rsync shared" folders in vagrant.
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

# clean packages.
apt-get -y autoremove
apt-get -y clean

# zero the free disk space -- for better compression of the box file.
dd if=/dev/zero of=/EMPTY bs=1M || true ; rm -f /EMPTY
