#!/bin/sh
set -euo pipefail
K3S_VERSION="v1.32.8+k3s1" # for debugging

# Minimal k3s installer for Fedora CoreOS image build (bootc container image).
# Define the version you want to install here (example: v1.30.4+k3s1)
K3S_VERSION="${K3S_VERSION:-}" # must be provided in the build environment
BIN_DIR="/opt/k3s"
mkdir /var/opt # create target directory for buildin symlink for /opt
SYMLINK_DIR="/usr/local/bin"
mkdir -p /var/usrlocal/bin
TMPDIR="$(mktemp -d -t k3s-install.XXXXXXXX)"
trap 'rm -rf "${TMPDIR}"' EXIT

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fatal() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

[ -n "${K3S_VERSION}" ] || fatal "K3S_VERSION must be set (e.g. K3S_VERSION=v1.30.4+k3s1)"

# Choose downloader: prefer curl, fallback to wget
if command -v curl >/dev/null 2>&1; then
  DOWNLOADER=curl
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER=wget
else
  fatal "Neither curl nor wget found; one is required to download k3s"
fi

# Map uname -m to upstream k3s archive suffix
ARCH="$(uname -m)"
case "${ARCH}" in
x86_64 | amd64)
  ARCH=amd64
  SUFFIX=
  ;;
aarch64 | arm64)
  ARCH=arm64
  SUFFIX=-${ARCH}
  ;;
s390x)
  ARCH=s390x
  SUFFIX=-${ARCH}
  ;;
armv7* | arm*)
  ARCH=arm
  SUFFIX=-${ARCH}hf
  ;;
*) fatal "Unsupported architecture: ${ARCH}" ;;
esac

# download helper: $1 = dest file, $2 = URL
download_file() {
  dest="$1"
  url="$2"
  info "Downloading ${url}"
  if [ "${DOWNLOADER}" = "curl" ]; then
    curl -fsSL -o "${dest}" "${url}"
  else
    wget -qO "${dest}" "${url}"
  fi
}

# compute URLs for release assets (GitHub releases)
RELEASE_BASE="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}"

HASH_FILE="${TMPDIR}/sha256-${ARCH}.txt"
BIN_TMP="${TMPDIR}/k3s.bin"

# 1) Download sha256sum list for the release and extract expected hash for the arch-specific k3s binary
download_file "${HASH_FILE}" "${RELEASE_BASE}/sha256sum-${ARCH}.txt"
# grep for the " k3s" filename exactly, extract the hash
HASH_EXPECTED="$(grep -E " k3s$" "${HASH_FILE}" | awk '{print $1}')"
[ -n "${HASH_EXPECTED}" ] || fatal "Could not determine expected SHA256 for k3s (arch ${ARCH}) in ${HASH_FILE}"

# 2) Download k3s binary for the arch
BIN_URL="${RELEASE_BASE}/k3s${SUFFIX}"
download_file "${BIN_TMP}" "${BIN_URL}"

# 3) Verify sha256
HASH_DOWNLOADED="$(sha256sum "${BIN_TMP}" | awk '{print $1}')"
if [ "${HASH_DOWNLOADED}" != "${HASH_EXPECTED}" ]; then
  fatal "SHA256 mismatch: expected ${HASH_EXPECTED}, got ${HASH_DOWNLOADED}"
fi
info "SHA256 verified"

# 4) Create target directory and install binary
info "Installing k3s to ${BIN_DIR}/k3s"
mkdir -p "${BIN_DIR}"
install -m 0755 "${BIN_TMP}" "${BIN_DIR}/k3s"
chown root:root "${BIN_DIR}/k3s"

# 5) Create symlinks for common tools (kubectl, crictl, ctr) in /usr/local/bin if they don't exist
for cmd in k3s kubectl crictl ctr; do
  target="${SYMLINK_DIR}/${cmd}"
  if [ -e "${target}" ] && [ ! -L "${target}" ]; then
    info "Skipping symlink ${target}: file already exists"
    continue
  fi
  rm -f "${target}" || true
  ln -s "${BIN_DIR}/k3s" "${target}"
  info "Created symlink ${target} -> ${BIN_DIR}/k3s"
done

# 6) Attempt to install or place k3s-selinux policy for CoreOS
# Try to fetch the latest k3s-selinux rpm that matches 'coreos' target names.
SELINUX_RPM_TMP="${TMPDIR}/k3s-selinux.rpm"
info "Attempting to obtain k3s-selinux RPM for coreos"
# Use GitHub API releases to find an asset that contains 'coreos.noarch.rpm'
if [ "${DOWNLOADER}" = "curl" ]; then
  assets_json="$(curl -fsSL "https://api.github.com/repos/k3s-io/k3s-selinux/releases/latest")"
else
  assets_json="$(wget -qO - "https://api.github.com/repos/k3s-io/k3s-selinux/releases/latest")"
fi

# parse browser_download_url entries and pick first matching 'coreos' (simple grep/awk approach)
SELINUX_RPM_URL="$(printf '%s\n' "${assets_json}" | grep browser_download_url | sed -E 's/.*"([^"]+)".*/\1/' | grep 'coreos.*noarch\.rpm' | head -n1 || true)"

if [ -n "${SELINUX_RPM_URL}" ]; then
  info "Found k3s-selinux RPM: ${SELINUX_RPM_URL}"
  download_file "${SELINUX_RPM_TMP}" "${SELINUX_RPM_URL}"

  if command -v rpm-ostree >/dev/null 2>&1; then
    info "Installing k3s-selinux RPM with rpm-ostree"
    # local rpm install with rpm-ostree is supported; use --idempotent to avoid rebuild errors
    rpm-ostree install --idempotent "${SELINUX_RPM_TMP}" || warn "rpm-ostree install failed (may require different image build flow)"
  elif command -v dnf >/dev/null 2>&1; then
    info "Installing k3s-selinux RPM with dnf"
    dnf install -y "${SELINUX_RPM_TMP}"
  else
    warn "No rpm-ostree or dnf found; saved ${SELINUX_RPM_TMP} but did not install k3s-selinux"
  fi
else
  warn "Unable to locate a k3s-selinux RPM for coreos from GitHub releases; skipping automatic RPM install"
fi

# 7) Try to apply SELinux file context to the installed binary and check for installed policy file
if command -v chcon >/dev/null 2>&1; then
  if chcon -u system_u -r object_r -t container_runtime_exec_t "${BIN_DIR}/k3s" >/dev/null 2>&1; then
    info "Applied container_runtime_exec_t to ${BIN_DIR}/k3s"
  else
    warn "Failed to apply SELinux label to ${BIN_DIR}/k3s (tool returned non-zero)"
  fi
fi

### debugging
semanage fcontext -a -t container_runtime_exec_t '/opt/k3s/k3s'
restorecon -v /opt/k3s/k3s
getenforce || echo "getenforce not available"
# requires libcap package
capsh --print
### end

if [ -f /usr/share/selinux/packages/k3s.pp ]; then
  info "k3s-selinux policy appears present (/usr/share/selinux/packages/k3s.pp)"
else
  warn "k3s-selinux policy not found at /usr/share/selinux/packages/k3s.pp. Ensure the policy is installed in your image if required."
fi

info "k3s ${K3S_VERSION} installation to ${BIN_DIR} complete (binary: ${BIN_DIR}/k3s)"
info "Clean up temporary files in ${TMPDIR} handled by trap"
