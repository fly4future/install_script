#!/bin/bash

sudo apt -y update && rosdep update && sudo apt -y upgrade --with-new-pkgs --allow-downgrades
sudo apt install linux-modules-iwlwifi-$(uname -r) #Install correct wi-fi drivers - problem on new machines with ubuntu 20j
sudo apt-mark hold linux-modules-iwlwifi-$(uname -r) #Hold the wifi driver at this version
source ~/.bashrc
exit 0


