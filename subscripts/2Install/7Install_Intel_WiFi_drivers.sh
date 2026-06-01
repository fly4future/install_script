#!/bin/bash

# Install correct WiFi drivers and holds them at this version - problem on new machines with ubuntu 20
sudo apt install linux-modules-iwlwifi-$(uname -r)
sudo apt-mark hold linux-modules-iwlwifi-$(uname -r)

exit 0
