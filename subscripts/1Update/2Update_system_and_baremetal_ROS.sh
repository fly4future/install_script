#!/bin/bash

set -euo pipefail

sudo apt-get -y update && rosdep update && sudo apt-get -y upgrade --with-new-pkgs --allow-downgrades

source ~/.bashrc

exit 0
