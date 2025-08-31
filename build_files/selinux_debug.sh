#!/bin/sh
set -euo pipefail

TARGET=/opt/k3s/k3s

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err() { printf '[ERR] %s\n' "$*"; }

info "==== SELinux debug start ===="
info "target: ${TARGET}"

# show SELinux runtime mode (may be Disabled during build)
if command -v getenforce >/dev/null 2>&1; then
  info "getenforce: $(getenforce 2>/dev/null || echo 'getenforce returned error')"
fi

# show capabilities available to process
if command -v capsh >/dev/null 2>&1; then
  info "capsh --print:"
  capsh --print | sed -n '1,200p'
else
  warn "capsh not found"
fi

# helpers to show current label/state of the file (if file exists)
show_labels() {
  echo "---- label checks for ${TARGET} ----"
  if [ ! -e "${TARGET}" ]; then
    warn "${TARGET} does not exist"
    return 0
  fi

  # 1) stat -c %C (shows SELinux context if available)
  if stat --version >/dev/null 2>&1; then
    info "stat -c %C: $(stat -c %C "${TARGET}" 2>&1 || echo 'stat failed')"
  fi

  # 2) ls -Z (if coreutils supports it)
  if ls -Z "${TARGET}" >/dev/null 2>&1; then
    info "ls -Z:"
    ls -Z "${TARGET}" 2>&1 | sed -n '1,200p'
  else
    warn "ls -Z unavailable or failed"
  fi

  # 3) getfattr for security.selinux xattr
  if command -v getfattr >/dev/null 2>&1; then
    info "getfattr -n security.selinux:"
    getfattr -n security.selinux --absolute-names "${TARGET}" 2>&1 || echo " (no security.selinux attribute or getfattr failed)"
  else
    warn "getfattr missing"
  fi

  echo "---- end label checks ----"
}

show_labels

# show semanage mapping (if semanage exists)
if command -v semanage >/dev/null 2>&1; then
  info "semanage fcontext lookup (existing mappings matching /opt/k3s):"
  semanage fcontext -l 2>/dev/null | grep -E '/opt/k3s|k3s' || echo "(no mapping found)"
else
  warn "semanage not present"
fi

# Attempt to add a fcontext mapping and run restorecon (this is the 'correct' approach)
if command -v semanage >/dev/null 2>&1 && command -v restorecon >/dev/null 2>&1; then
  info "Adding semanage fcontext mapping:"
  set +e
  semanage fcontext -a -t container_runtime_exec_t "${TARGET}" 2>&1
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    warn "semanage fcontext -a returned exit ${rc}"
  else
    info "semanage fcontext -a succeeded"
  fi

  info "Running restorecon -v ${TARGET}:"
  set +e
  restorecon -v "${TARGET}" 2>&1 || true
  set -e

  show_labels
else
  warn "semanage or restorecon not available; skipping semanage/restorecon attempt"
fi

# Try chcon with a full context (not partial). This may still fail if xattrs or caps are not allowed.
if command -v chcon >/dev/null 2>&1; then
  info "Attempting chcon with full context (system_u:object_r:container_runtime_exec_t:s0)"
  set +e
  chcon 'system_u:object_r:container_runtime_exec_t:s0' "${TARGET}" 2>&1 || {
    rc=$?
    warn "chcon full-context returned ${rc}:"
    chcon 'system_u:object_r:container_runtime_exec_t:s0' "${TARGET}" 2>&1 | sed -n '1,200p' || true
  }
  set -e
  show_labels
else
  warn "chcon not available"
fi

# Try writing a raw security.selinux xattr (low-level test)
if command -v setfattr >/dev/null 2>&1; then
  info "Attempting setfattr security.selinux test (may require CAP_SYS_ADMIN/CAP_MAC_ADMIN)"
  set +e
  setfattr -n security.selinux -v 'system_u:object_r:container_runtime_exec_t:s0' "${TARGET}" 2>&1 || {
    warn "setfattr failed:"
    setfattr -n security.selinux -v 'system_u:object_r:container_runtime_exec_t:s0' "${TARGET}" 2>&1 | sed -n '1,200p' || true
  }
  set -e
  show_labels
else
  warn "setfattr not available"
fi

info "==== SELinux debug end ===="
