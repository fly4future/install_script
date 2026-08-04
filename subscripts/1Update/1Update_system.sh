#!/bin/bash

set -euo pipefail

sudo apt-get -y update && sudo apt-get -y upgrade --with-new-pkgs --allow-downgrades

exit 0
