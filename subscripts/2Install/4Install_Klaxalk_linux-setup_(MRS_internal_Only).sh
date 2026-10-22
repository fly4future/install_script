#!/bin/bash

set -euo pipefail

mkdir -p ~/git
if [ -d ~/git/linux-setup ]; then
  git -C ~/git/linux-setup pull
else
  git clone https://github.com/klaxalk/linux-setup.git -b 24.04 ~/git/linux-setup
fi
bash ~/git/linux-setup/install.sh --unattended

exit 0

