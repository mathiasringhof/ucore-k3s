# TODO

## Ensure base uCore/CoreOS version is visible in status

### Current State

[mathias@staging k3s]$ rpm-ostree status
State: idle
AutomaticUpdates: stage; rpm-ostreed-automatic.timer: no runs since boot
Deployments:
● ostree-image-signed:docker://ghcr.io/mathiasringhof/ucore-k3s:latest
                   Digest: sha256:32293d6edde6a3c3c5b9ecb2c5d30a95896e39411925361500e7971a3eec2804
                  Version: latest.20260101 (2026-01-01T14:47:13Z)

### uCore Status

State: idle
AutomaticUpdates: stage; rpm-ostreed-automatic.timer: no runs since boot
Deployments:
● ostree-image-signed:docker://ghcr.io/ublue-os/ucore:stable
                   Digest: sha256:c74bdaca34c24912101e187dfdccf07cf04064e540e279023371aa55083cc58e
                  Version: 43.20251120.3.0 (2025-12-15T14:31:28Z)
