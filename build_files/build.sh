#!/usr/bin/env bash
set -ouex pipefail

# Install container-selinux for proper SELinux contexts
dnf5 install -y container-selinux

# firewalld is masked in base images; disabling is harmless but not required
systemctl disable firewalld || true

# make sure the symlink target exists
mkdir -p /var/usrlocal/bin

# Create a temporary directory for k3s installation
export TMPDIR=$(mktemp -d)

# install k3s without starting or enabling the service
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_SKIP_ENABLE=true \
  INSTALL_K3S_SKIP_START=true \
  INSTALL_K3S_BIN_DIR=/var/usrlocal/bin \
  INSTALL_K3S_SYSTEMD_DIR="${TMPDIR}" \
  sh -

# Move systemd files to /usr/lib/systemd/system (the proper location for bootc)
mkdir -p /usr/lib/systemd/system
if [ -f "${TMPDIR}/k3s.service" ]; then
    mv "${TMPDIR}/k3s.service" /usr/lib/systemd/system/
fi

# Create tmpfiles.d configuration for k3s symlinks and binary
#mkdir -p /usr/lib/tmpfiles.d
#cat > /usr/lib/tmpfiles.d/k3s.conf <<EOF
## k3s binary and symlinks
#f /var/usrlocal/bin/k3s 0755 root root - -
#L /var/usrlocal/bin/kubectl - - - - k3s
#L /var/usrlocal/bin/crictl - - - - k3s
#Z /var/usrlocal/bin/k3s - - - - container_runtime_exec_t
#EOF

# Clean up the k3s service environment file if it was created
ls -al /usr/etc
rm -rf /usr/etc

# Clean up temporary directory
rm -rf "${TMPDIR}"
