#!/bin/bash

set -euo pipefail

mkdir -p ~/git
git clone https://github.com/klaxalk/linux-setup.git -b 24.04 ~/git/linux-setup
bash ~/git/linux-setup/install.sh --unattended

exit 0

