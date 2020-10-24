#!/bin/bash
set -euxo pipefail

# wait for cloud-init to finish.
cloud-init status --long --wait

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# upgrade.
apt-get update
apt-get dist-upgrade -y

# reboot.
nohup bash -c "ps -eo pid,comm | awk '/sshd/{print \$1}' | xargs kill; sync; reboot"
