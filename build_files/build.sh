#!/bin/bash

set -ouex pipefail

K3S_CHANNEL="${K3S_CHANNEL:-stable}"
if [[ "${K3S_CHANNEL}" =~ ^[0-9]+\.[0-9]+ ]]; then
    K3S_CHANNEL="v${K3S_CHANNEL}"
fi

# Install k3s into /usr/bin - don't start, don't enable the service, warn but not build fail when SELinux step fails
# correct context will be applied at boot
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL="${K3S_CHANNEL}" INSTALL_K3S_SELINUX_WARN=true INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_SKIP_START=true INSTALL_K3S_BIN_DIR=/usr/bin sh -
command -v k3s >/dev/null

# Recommended by https://docs.k3s.io/installation/requirements?os=rhel
systemctl disable firewalld

# Disable swap for Kubernetes
systemctl mask dev-zram0.swap

# Kitty is a very common terminal emulator, k9s really nice for adhoc cluster management
dnf install -y kitty-terminfo k9s

# Optimize inotify limits for Kubernetes
# We write to /usr/lib/sysctl.d/ because we are defining the "vendor/image default".
# /etc/sysctl.d/ should be reserved for local administrator overrides on the running node.
cat <<EOF >/usr/lib/sysctl.d/99-kubernetes-inotify.conf
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288
EOF
