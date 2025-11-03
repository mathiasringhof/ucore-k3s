#!/bin/bash

set -ouex pipefail

mkdir -p /opt/bin
curl -sfL https://get.k3s.io | sh -
