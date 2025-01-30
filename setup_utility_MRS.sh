#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)
blink=$(tput blink)
red='\033[0;31m'
green='\033[0;32m'

light=$(echo $PROFILES | grep COLORSCHEME_LIGHT)
if [ -z "$light" ]
then
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
if [ -z "$1" ]
then
  folder_path="$DIR/subscripts"
  sudo chmod -R +x "$DIR/subscripts"
  sudo chmod -R -x "$DIR/subscripts/5Udev_rules/DISREGARD_udev_rules"
  sudo chmod +x "$DIR/subscripts/5Udev_rules/DISREGARD_udev_rules"
else
  folder_path="$1"
  first_run=false
fi

# Create an array to store filenames
OPTIONS=()
FULL_FILEPATHS=()

show_menu() {
  whiptail --title "MRS UAV System Install Utility" --menu "Choose an option:" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}

main() {
  while true; do
    clear
    choice=$(show_menu)

    if [ $? -eq 0 ]; then
      echo ${FULL_FILEPATHS[$((choice - 1))]}
      # ${FULL_FILEPATHS[$((choice - 1))]}

      if [[ -d ${FULL_FILEPATHS[$((choice - 1))]} ]]; then
        echo "is a directory"
        ./$0 ${FULL_FILEPATHS[$((choice - 1))]} #Run this script again but in the selected folder
      else
        ${FULL_FILEPATHS[$((choice - 1))]}
      fi
      if [ $? -eq 0 ]; then
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
  if [ ! -z "$disregard" ]
  then
    continue
  fi

  OPTIONS+=("$index")
  let "index++"
  filename="${file##*"/"}"
  filename="${filename%.*}"
  filename="${filename//_/ }"
  filename="${filename#[[:digit:]]}" #removes the first digit from script name

  if [[ -d ${file} ]]; then
    OPTIONS+=("$filename ...")
  else
    OPTIONS+=("$filename")
  fi

  FULL_FILEPATHS+=("$file")
done

if [ "$first_run" = true ] ; then
  #Check connection to the internet
  wget -q --spider http://google.com

  if [ $? -eq 0 ]; then
    echo -e "${green}Online${normal}"
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Error: Local changes detected. Commit or stash your changes before pulling."
        exit 1
    fi
    sudo apt install git
    sudo apt update
    git pull
  else
    echo -e "${red}${bold}You are not connected to the internet!${normal} (No response from google.com)"
    echo -e "${red}${bold}You will not be to install/update any new software!${normal}"
    echo -e "${red}${bold}You can however still use some of the configuration scripts${normal}"
    read -p "${blink}${bold}Hit enter to continue ...${normal}"
  fi

  #Check for whiptail
  whiptail_installed=$(apt-cache policy whiptail | grep Installed | grep none)

  if [ ! -z "$whiptail_installed" ]
  then
    echo "Whiptail NOT installed, will install now:"
    sudo apt install whiptail
  fi

fi
main
