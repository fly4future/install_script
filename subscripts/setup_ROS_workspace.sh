#!/bin/bash

cmd=(dialog --keep-tite --menu "MRS UAV System Install Utility" 30 160 16)

options=(
  1  "Setup user ROS workspace"
  2  "Add mrs_uav_deployment (Necessary for real UAVs)"
  3  "Add mrs_core_examples (example nodes which demonstrate system functionality)"
)

choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

for choice in $choices
do
  case $choice in
    1)
      echo "Using stable ppa"
      curl https://ctu-mrs.github.io/ppa-stable/add_ppa.sh | bash # add the mrs_uav_system ppa and install the system
      ;;
    2)
      echo "Using unstable ppa"
      curl https://ctu-mrs.github.io/ppa-unstable/add_ppa.sh | bash # add the mrs_uav_system ppa and install the system
      ;;
    *)
      exit
  esac
done

sudo apt -y install ros-noetic-mrs-uav-system-full






























source /opt/ros/noetic/setup.bash             # source the general ROS workspace so that the local one will extend it and see all the packages
mkdir -p ~/workspace/src && cd ~/workspace    # create the workspace folder in home and cd to it
catkin init -w ~/workspace                    # initialize the new workspace
# setup basic compilation profiles
catkin config --profile debug --cmake-args -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17 -Og' -DCMAKE_C_FLAGS='-Og'
catkin config --profile release --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17'
catkin config --profile reldeb --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_FLAGS='-std=c++17'
catkin profile set reldeb                     # set the reldeb profile as active
