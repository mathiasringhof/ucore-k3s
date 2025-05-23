#!/usr/bin/env bash
set -ouex pipefail

# Example package
dnf5 install -y tmux

# firewalld is masked in base images; disabling is harmless but not required
systemctl disable firewalld || true

# make sure the symlink target exists
mkdir -p /var/usrlocal/bin

# install k3s without starting or enabling the service
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_SKIP_ENABLE=true \
  INSTALL_K3S_BIN_DIR=/var/usrlocal/bin \
  sh -
