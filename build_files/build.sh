#!/bin/bash

set -ouex pipefail

# Install k3s into /usr/bin - don't start, don't enable the service, warn but not build fail when SELinux step fails
# correct context will be applied at boot
curl -sfL https://get.k3s.io | INSTALL_K3S_SELINUX_WARN=true INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_SKIP_START=true INSTALL_K3S_BIN_DIR=/usr/bin sh -

# Recommended by https://docs.k3s.io/installation/requirements?os=rhel
systemctl disable firewalld

# Kitty is a very common terminal emulator, k9s really nice for adhoc cluster management
dnf install kitty-terminfo k9s
