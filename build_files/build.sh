#!/bin/bash

set -ouex pipefail

# 1) Is SELinux even enabled at build time?
(getenforce 2>/dev/null || echo "getenforce-missing")

# 2) Are policy packages there?
(rpm -q container-selinux 2>/dev/null || true)

# 3) Does the type string exist in shipped contexts/policy (no extra tools)?
grep -R --binary-files=text -n "container_runtime_exec_t" /usr/share/selinux /etc/selinux 2>/dev/null || true

curl -sfL https://get.k3s.io | INSTALL_K3S_SELINUX_WARN=true INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_SKIP_START=true INSTALL_K3S_BIN_DIR=/usr/bin sh -
