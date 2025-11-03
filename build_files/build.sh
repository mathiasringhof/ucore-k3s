#!/bin/bash

set -ouex pipefail

mkdir /var/opt/bin
curl -sfL https://get.k3s.io | sh -
