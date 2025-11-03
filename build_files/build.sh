#!/bin/bash

set -ouex pipefail

curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_SKIP_START=true INSTALL_K3S_BIN_DIR=/usr/bin sh -
