#!/bin/bash

set -ouex pipefail

ls -ld /usr
ls -ld /usr/local
ls -ld /usr/local/bin
curl -sfL https://get.k3s.io | sh -
