# ucore-k3s

Adds k3s on top of the uCore:hci image. It also:

- disables swap
- disables firewalld
- adds k9s and kitty-terminfo

This repository is based on the Universal Blue image template: <https://github.com/ublue-os/image-template>

It builds on uCore and follows its documentation; see the uCore repository and README:

- <https://github.com/ublue-os/ucore>

## What Needs To Be Done

See `TODO.md` for details. Current focus:

- ensure the base uCore/CoreOS version is visible in `rpm-ostree status`
