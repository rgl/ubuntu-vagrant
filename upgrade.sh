#!/bin/bash
set -euxo pipefail

# wait for cloud-init to finish.
cloud-init status --long --wait

# let the sudo group members use root permissions without a password.
# NB d-i automatically added the vagrant user into the sudo group.
sed -i -E 's,^%sudo\s+.+,%sudo ALL=(ALL) NOPASSWD:ALL,g' /etc/sudoers

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# upgrade.
apt-get update
apt-get dist-upgrade -y
