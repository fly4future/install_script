#!/bin/bash

OPTIONS=(
  1 "Use stable ppa (recommended)"
  2 "Use unstable ppa"
)

OPTIONS2=(
  1 "Setup as a UAV"
  2 "Setup as user's computer"
)


show_menu() {
  whiptail --title "MRS UAV System Install Utility" --menu "Choose an option:" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}
show_menu2() {
  whiptail --title "MRS UAV System Install Utility" --menu "Choose an option:" 0 0 0 "${OPTIONS2[@]}" 3>&1 1>&2 2>&3
}

main() {
  choice=$(show_menu)

        # Handle user choice
        case $choice in
          1)
            echo "Using stable ppa"
            curl https://ctu-mrs.github.io/ppa2-stable/add_ppa.sh | bash # add the ros jazzy ppa and install the system 
            sudo apt -y install ros-jazzy-mrs-uav-system-full
            ;;
          2)
            echo "Using unstable ppa"
            curl https://ctu-mrs.github.io/ppa2-unstable/add_ppa.sh | bash # add the mrs_uav_system ppa and install the system
            sudo apt -y install ros-noetic-mrs-uav-system-full
            ;;
          *)
            exit 1
            ;;
        esac
      }

link_tmux() {
  choice=$(show_menu2)

        # Handle user choice
        case $choice in
          1)
            echo "Setup as a UAV"
            ln -s /etc/ctu-mrs/tmux.conf ~/.tmux.conf
            ;;
          2)
            echo "Setup as user's computer"
            ;;
          *)
            exit 1
            ;;
        esac
      }

main
link_tmux
exit 0
