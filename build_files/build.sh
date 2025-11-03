#!/bin/bash

set -ouex pipefail

# 1) Is SELinux even enabled at build time?
(getenforce 2>/dev/null || echo "getenforce-missing")

# 2) Are policy packages there?
(rpm -q container-selinux 2>/dev/null || true)

# 3) Does the type string exist in shipped contexts/policy (no extra tools)?
grep -R --binary-files=text -n "container_runtime_exec_t" /usr/share/selinux /etc/selinux 2>/dev/null || true

curl -sfL https://get.k3s.io | INSTALL_K3S_SELINUX_WARN=true INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_SKIP_START=true INSTALL_K3S_BIN_DIR=/usr/bin sh -

# --- Post-install SELinux context verification (non-fatal) ---
{
  echo "== Post-install SELinux context check =="

  # Show config vs runtime
  SELINUX_CONFIG=$(awk -F= '/^SELINUX=/{print $2}' /etc/selinux/config 2>/dev/null || true)
  echo "SELINUX_CONFIG=${SELINUX_CONFIG:-<missing>}"
  (getenforce 2>/dev/null || echo "getenforce-missing")

  # Basic filesystem/mount info (some overlays don't support selinux xattrs)
  echo "-- mounts (overlay/usr/root) --"
  grep -E '(/usr | / | overlay)' /proc/mounts || true

  if [ -x /usr/bin/k3s ]; then
    echo "-- ls -lZ --"
    (ls -lZ /usr/bin/k3s || true)

    echo "-- security.selinux xattr (if available) --"
    if command -v getfattr >/dev/null 2>&1; then
      getfattr -d -m security.selinux /usr/bin/k3s 2>/dev/null || echo "no security.selinux xattr"
    else
      echo "getfattr not installed"
    fi

    WANT_T="container_runtime_exec_t"
    GOT_CTX=$(ls -Z /usr/bin/k3s 2>/dev/null | awk '{print $1}' || true)

    echo "-- expected vs actual type --"
    case "$GOT_CTX" in
    *:${WANT_T}:*)
      echo "OK: type is ${WANT_T}"
      ;;
    *)
      echo "MISMATCH: got '${GOT_CTX:-<none>}' expected type ${WANT_T}"

      echo "-- chcon probe (non-fatal) --"
      # Try to set the context; capture rc but never fail the build
      (
        set +e
        chcon -u system_u -r object_r -t "${WANT_T}" /usr/bin/k3s
        rc=$?
        echo "chcon rc=${rc}"
        set -e
      )

      echo "-- after-probe ls -lZ --"
      (ls -lZ /usr/bin/k3s || true)
      ;;
    esac

    echo "-- default context suggestion (if tool present) --"
    if command -v matchpathcon >/dev/null 2>&1; then
      matchpathcon /usr/bin/k3s || true
    else
      echo "matchpathcon not installed"
    fi
  else
    echo "/usr/bin/k3s not found"
  fi
} || true
