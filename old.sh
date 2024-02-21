#!/bin/bash
bold=$(tput bold)
normal=$(tput sgr0)
blink=$(tput blink)
red='\033[0;31m'
green='\033[0;32m'


export NEWT_COLORS='
root=brightgreen,black
border=brightgreen,black
title=brightgreen,black
roottext=white,black
window=brightgreen,black
textbox=white,black
button=black,brightgreen
compactbutton=white,black
listbox=white,black
actlistbox=black,white
actsellistbox=black,brightgreen
checkbox=brightgreen,black
actcheckbox=black,brightgreen
entry=black,brightgreen
'
# root=white,black
# border=black,lightgray
# window=lightgray,lightgray
# shadow=black,gray
# title=black,lightgray
# button=black,cyan
# actbutton=white,cyan
# compactbutton=black,lightgray
# checkbox=black,lightgray
# actcheckbox=lightgray,cyan
# entry=black,lightgray
# disentry=gray,lightgray
# label=black,lightgray
# listbox=black,lightgray
# actlistbox=black,cyan
# sellistbox=lightgray,black
# actsellistbox=lightgray,black
# textbox=black,lightgray
# acttextbox=black,cyan
# emptyscale=,gray
# fullscale=,cyan
# helpline=white,black
# roottext=lightgrey,black


# Define menu options
OPTIONS=(
  1  "Clean up Linux installation"
  2  "Install basic packages (vim, ranger, net-tools, openssh-server, curl, git)"
  3  "Install ROS"
  4  "Install MRS UAV System"
  5  "Setup user ROS workspace (~/workspace) and basic packages"
  6  "Setup Bashrc variables"
  7  "Exit"
)

# Function to display menu
show_menu() {
  whiptail --title "MRS UAV System Install Utility" --menu "Choose an option:" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}

# Main function
main() {
  while true; do
    clear
    choice=$(show_menu)


        # Handle user choice
        case $choice in
          1)
            echo "Cleaning up Linux installation"
            ;;
          2)
            echo "Installing basic packages"
            ./subscripts/install_basic_packages.sh
            ;;
          3)
            echo "Installing ROS"
            ./subscripts/install_ROS.sh
            ;;
          4)
            echo "Installing MRS UAV SYSTEM"
            ./subscripts/install_MRS_UAV_System.sh
            ;;
          5)
            echo "Setting up user ROS workspace"
            ./subscripts/setup_ROS_workspace.sh
            ;;
          6)
            echo "Setting up bashrc"
            ./subscripts/setup_bashrc.sh
            ;;
          7)
            exit 0
            ;;
          *)
            exit 0
            ;;
        esac
        if [ $? -eq 0 ]; then
          read -p "${blink}${bold}Hit enter to continue ...${normal}"
        fi
      done
    }

#Check connection to the internet
wget -q --spider http://google.com

if [ $? -eq 0 ]; then
  echo -e "${green}Online${normal}"
else
  echo -e "${red}${bold}You are not connected to the internet!${normal} (No response from google.com)"
  exit 1
fi

sudo apt update

#Check for whiptail
whiptail_installed=$(apt-cache policy whiptail | grep Installed | grep none)

if [ ! -z "$whiptail_installed" ]
then
  echo "Whiptail NOT installed, will install now:"
  sudo apt install whiptail
fi

# Call the main function
main
