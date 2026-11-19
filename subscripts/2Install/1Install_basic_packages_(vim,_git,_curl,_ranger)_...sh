#!/bin/bash

set -euo pipefail

sudo apt-get update
sudo apt-get -y install vim nano ranger net-tools curl git netplan.io

exit 0
