#!/bin/bash

# sudo apt update

cmd=(dialog --keep-tite --menu "MRS UAV System Install Utility" 30 160 16)

options=(1  "Use stable ppa (recommended)"
         2  "Use unstable ppa"
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
