#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)
blink=$(tput blink)
red='\033[0;31m'
green='\033[0;32m'

light=$(echo "$PROFILES" | grep COLORSCHEME_LIGHT)
if [ -z "$light" ]; then
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
else
  export NEWT_COLORS='
  root=green,white
  border=green,white
  title=green,white
  roottext=black,white
  window=green,white
  textbox=black,white
  button=white,green
  compactbutton=black,white
  listbox=black,white
  actlistbox=black,white
  actsellistbox=white,green
  checkbox=green,white
  actcheckbox=white,green
  entry=white,green
  '
fi

# export NEWT_COLORS='
# root=brightgreen,black
# border=brightgreen,black
# title=brightgreen,black
# roottext=white,black
# window=brightgreen,black
# textbox=white,black
# button=black,brightgreen
# compactbutton=white,black
# listbox=white,black
# actlistbox=black,white
# actsellistbox=black,brightgreen
# checkbox=brightgreen,black
# actcheckbox=black,brightgreen
# entry=black,brightgreen
# '
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

# Specify the folder path where your files are located
DIR="$(dirname "$(readlink -f "$0")")"
folder_path=""
first_run=true
if [ -z "$1" ]; then
  folder_path="$DIR/subscripts"

  # Make all .sh files in the subscripts folder executable
  find "$folder_path" -type f -name "*.sh" -exec chmod +x {} \;
else
  folder_path="$1"
  first_run=false
fi

# Create an array to store filenames
OPTIONS=()
FULL_FILEPATHS=()

show_main_menu() {
  whiptail --title "MRS UAV System Install Utility" --menu "Choose an option:" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}

show_f4f_mrs_switch_menu() {

  F4F_MRS_SWITCH_OPTIONS=(
    1 "Use F4F defaults"
    2 "Use MRS defaults"
  )

  whiptail --title "MRS UAV System Install Utility" --menu "Do you want to use F4F or MRS defaults?" 0 0 0 "${F4F_MRS_SWITCH_OPTIONS[@]}" 3>&1 1>&2 2>&3
}

main() {

  while true; do
    clear
    choice=$(show_main_menu)

    if [ $? -eq 0 ]; then
      echo ${FULL_FILEPATHS[$((choice - 1))]}
      # ${FULL_FILEPATHS[$((choice - 1))]}

      if [[ -d ${FULL_FILEPATHS[$((choice - 1))]} ]]; then
        echo "is a directory"
        ./$0 ${FULL_FILEPATHS[$((choice - 1))]} #Run this script again but in the selected folder
      else
        ${FULL_FILEPATHS[$((choice - 1))]}
      fi

      if [ $? -ne 0 ]; then
        # If the exit status is not 0, then there was an error, stop the wizard and wait for user input before continuing
        read -p "${blink}${bold}Hit enter to continue ...${normal}"
      fi
    else
      # echo "Menu canceled."
      exit 1
    fi
  done
}

# Read filenames from the folder and populate the array
index="1"
for file in "$folder_path"/*; do
  # Add each filename to the array
  disregard=$(echo $file | grep "DISREGARD")
  if [ ! -z "$disregard" ]; then
    continue
  fi

  OPTIONS+=("$index")
  let "index++"
  filename="${file##*"/"}"
  filename="${filename%.*}"
  filename="${filename//_/ }"
  filename="${filename#[[:digit:]]}" # removes the first digit from script name

  if [[ -d ${file} ]]; then
    OPTIONS+=("$filename ...")
  else
    OPTIONS+=("$filename")
  fi

  FULL_FILEPATHS+=("$file")
done

if [ "$first_run" = true ]; then
  # Check connection to the internet
  echo "Checking internet connection..."
  wget -q --spider http://google.com

  if [ $? -eq 0 ]; then
    echo -e "${green}Online${normal}"

    # Check if apt update was already successfully ran in the last 60 minutes and if so, do not run it again
    if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
      last_update=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp)
      now=$(date +%s)
      if [ $((now - last_update)) -lt 3600 ]; then
        echo "Apt update was already successfully ran in the last 60 minutes, not running it again"
      else
        sudo apt-get update
      fi
    fi
    if ! command -v git &>/dev/null; then
      echo "Git is not installed. Installing git..."
      sudo apt-get install -y git
    fi

    if ! git diff --quiet || ! git diff --cached --quiet; then
      echo "Error: Local changes detected. Commit or stash your changes before pulling."
      exit 1
    fi
    git pull
  else
    echo -e "${red}${bold}You are not connected to the internet!${normal} (No response from google.com)"
    echo -e "${red}${bold}You will not be to install/update any new software!${normal}"
    echo -e "${red}${bold}You can however still use some of the configuration scripts${normal}"
    read -p "${blink}${bold}Hit enter to continue ...${normal}"
  fi

  # Check for whiptail
  whiptail_installed=$(apt-cache policy whiptail | grep Installed | grep none)

  if [ ! -z "$whiptail_installed" ]; then
    echo "Whiptail NOT installed, will install now:"
    sudo apt-get install -y whiptail
  fi

  # Ask whether the user wants to use F4F or MRS defaults
  f4f_mrs_choice=$(show_f4f_mrs_switch_menu)
  case $f4f_mrs_choice in
  1)
    echo "Using F4F defaults"
    export USE_DEFAULTS_FOR="F4F"
    ;;
  2)
    echo "Using MRS defaults"
    export USE_DEFAULTS_FOR="MRS"
    ;;
  *) # the default case, also called when cancel is selected
    exit 1
    ;;
  esac
fi

main
