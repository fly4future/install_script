#!/bin/bash

sudo apt -y update && rosdep update && sudo apt -y upgrade --with-new-pkgs --allow-downgrades
source ~/.bashrc
exit 0


