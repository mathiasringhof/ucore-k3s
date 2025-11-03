#!/bin/bash

set -ouex pipefail

ls -ld /opt
ls -ld /var
ls -ld /var/opt
curl -sfL https://get.k3s.io | sh -
