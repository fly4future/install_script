#!/bin/bash

# sudo apt update 
sudo apt-get -y install software-properties-common curl bash
curl https://ctu-mrs.github.io/ppa2-stable/add_ros_ppa.sh | bash
sudo apt -y install ros-jazzy-desktop-full ros-dev-tools
exit 0
