#!/bin/bash

# sudo apt update 
curl https://ctu-mrs.github.io/ppa-stable/add_ros_ppa.sh | bash # add the ROS ppa and install ROS
sudo apt -y install ros-noetic-desktop-full
exit 0
