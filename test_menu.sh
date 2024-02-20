#!/bin/bash
bold=$(tput bold)
normal=$(tput sgr0)
blink=$(tput blink)
red='\033[0;31m'
green='\033[0;32m'

if [[ "$1" == "skip" ]];
then
  echo "skip"
else
  wget -q --spider http://google.com

  if [ $? -eq 0 ]; then
    echo -e "${green}Online${normal}"
  else
    echo -e "${red}${bold}You are not connected to the internet!${normal} (No response from google.com)"
    exit 1
  fi


  sudo apt update

  dialog_installed=$(apt-cache policy dialog | grep Installed | grep none)

  if [ ! -z "$dialog_installed" ]
  then
    echo "Dialog NOT installed, will install now:"
    sudo apt install dialog
  fi
fi

cmd=(dialog --keep-tite --menu "MRS UAV System Install Utility" 0 0 0)

options=(
  1  "Clean up Linux installation"
  2  "Install basic packages (vim, ranger, net-tools, openssh-server, curl, git)"
  3  "Install ROS"
  4  "Install MRS UAV System"
  5  "Setup user ROS workspace (~/workspace) and basic packages"
)

choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

for choice in $choices
do
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
    *)
      exit
  esac
  echo ""
  read -p "${blink}${bold}Hit enter to continue ...${normal}"
  clear
  exec /bin/bash "$0" "$@" skip
done
