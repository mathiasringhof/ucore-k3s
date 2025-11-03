#!/bin/bash

set -ouex pipefail

mkdir /opt/bin
curl -sfL https://get.k3s.io | sh -
