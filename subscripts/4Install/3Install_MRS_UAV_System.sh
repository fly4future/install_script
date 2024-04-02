#!/bin/bash

OPTIONS=(
  1 "Use stable ppa (recommended)"
  2 "Use unstable ppa"
)

show_menu() {
  whiptail --title "MRS UAV System Install Utility" --menu "Choose an option:" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}

main() {
  choice=$(show_menu)

        # Handle user choice
        case $choice in
          1)
            echo "Using stable ppa"
            curl https://ctu-mrs.github.io/ppa-stable/add_ppa.sh | bash # add the mrs_uav_system ppa and install the system
            sudo apt -y install ros-noetic-mrs-uav-system-full
            ;;
          2)
            echo "Using unstable ppa"
            curl https://ctu-mrs.github.io/ppa-unstable/add_ppa.sh | bash # add the mrs_uav_system ppa and install the system
            sudo apt -y install ros-noetic-mrs-uav-system-full
            ;;
          *)
            exit 1
            ;;
        esac
      }

main
exit 0
