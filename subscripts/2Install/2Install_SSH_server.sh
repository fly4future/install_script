#!/bin/bash

set -euo pipefail

sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
