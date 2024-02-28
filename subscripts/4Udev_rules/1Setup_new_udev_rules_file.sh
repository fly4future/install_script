#!/bin/bash
show_menu() {
  whiptail --title "Udev config" --menu "$1:" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}

yesno_def_no () {
  whiptail --title "Netplan Config" --yesno "$1" --yes-button "No" --no-button "Yes" 0 0
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 1
  elif [ $ret_val -eq 1 ]; then
    # echo "User hit Yes"
    return 1
  elif [ $ret_val -eq 0 ]; then
    # echo "User hit No"
    return 0
  else
    echo "Error state"
  fi
}

yesno_def_yes () {
  whiptail --title "Netplan Config" --yesno "$1"  0 0
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 1
  elif [ $ret_val -eq 0 ]; then
    # echo "User hit Yes"
    return 1
  elif [ $ret_val -eq 1 ]; then
    # echo "User hit No"
    return 0
  else
    echo "Error state"
  fi
}

input_box () {
  tmp=$(whiptail --inputbox "$1" 0 0 "$2" 3>&1 1>&2 2>&3)
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    # User hit Escape
    exit 1
  elif [ $ret_val -eq 1 ]; then
    # User hit Cancel
    exit 1
  elif [ $ret_val -eq 0 ]; then
    # valid input
    echo $tmp #this will output the string that is user input, and we can capture it into a variable - e.g. foo=$(input_box)
    return 0
  else
    echo "Error state"
    exit 0
  fi
}

error_msg () {
  whiptail --title "Netplan config" --msgbox "$1" 0 0
}

yesno_def_no "Delete some selected previous udev rules files? (Remanants from previous setups etc.)"
ret_val=$?

if [ $ret_val -eq 1 ]; then
  OPTIONS=()
  FULL_FILEPATHS=()

  folder_path="/etc/udev/rules.d"
  index="1"
  for file in "$folder_path"/*; do
    filename=$file
    filename="${file##*"/"}"
    # filename="${filename%.*}"
    # filename="${filename//_/ }"

    if [[ ! -d ${file} ]]; then
      OPTIONS+=("$index")
      let "index++"
      has_99=$(echo $filename | grep "99")
      OPTIONS+=("$filename")
      OPTIONS+=("OFF")
      FULL_FILEPATHS+=("$file")
    fi
  done

  SELECTIONS=$(whiptail --separate-output --title "Udev rules setup" --checklist "Delete any previous udev rules file?\nCAUTION - this can break things! Only delete files if you know what you are doing.\n\nChoose options by pressing the spacebar" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

  ret_val=$?

  if [[ "$ret_val" -eq 1 ]]; then
    exit 1
  fi
  if [[ "$ret_val" -eq 255 ]]; then
    exit 1
  fi

  for CHOICE in $SELECTIONS; do
    sudo rm ${FULL_FILEPATHS[$((CHOICE - 1))]}
  done
fi

FILENAME=/tmp/99-usb-serial-MRS.rules
sudo rm $FILENAME

yesno_def_yes "Are you using an MRS distribution board?"
ret_val=$?

if [ $ret_val -eq 1 ]; then

  OPTIONS=()
  FULL_FILEPATHS=()

  folder_path="$(dirname "$0")/DISREGARD_udev_rules"
  index="1"
  for file in "$folder_path"/*; do
    filename=$file
    filename="${file##*"/"}"
    # filename="${filename%.*}"
    # filename="${filename//_/ }"

    if [[ ! -d ${file} ]]; then
      OPTIONS+=("$index")
      let "index++"
      has_99=$(echo $filename | grep "99")
      OPTIONS+=("$filename")
      FULL_FILEPATHS+=("$file")
    fi
  done
  # echo $OPTIONS

  chosen_filename=""
  choice=$(show_menu "What frame udev rules do you want to use?")
  if [ $? -eq 0 ]; then
    chosen_filename=$(echo ${FULL_FILEPATHS[$((choice - 1))]})
  else
    # echo "Menu canceled."
    exit 1
  fi

  cp $chosen_filename $FILENAME

else
  touch $FILENAME
fi

hostname=$(cat /etc/hostname)
sudo chown root:root $FILENAME

sudo sed -i -e "s/TO_BE_REPLACED/$hostname/g" $FILENAME

devices=$(ls /dev | grep -e ttyUSB -e ttyACM)

if [ -z "${devices}" ]; then
  error_msg "No devices matching the ttyUSBx or ttyACMx pattern found."
else


  for device in ${devices}; do

    device_info=$(udevadm info /dev/$device | grep "S: serial/by-id/")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "DEVNAME")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_VENDOR_FROM_DATABASE")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_MODEL_FROM_DATABASE")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_VENDOR_ID")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_MODEL_ID")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_MODEL=")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_SERIAL=")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_SERIAL_SHORT")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_PCI_CLASS_FROM_DATABASE")
    device_info="${device_info}\n"$(udevadm info /dev/$device | grep "ID_PCI_SUBCLASS_FROM_DATABASE")

    idVendor=$(udevadm info /dev/$device | grep "ID_VENDOR_ID")
    idVendor="${idVendor##*"="}"
    idProduct=$(udevadm info /dev/$device | grep "ID_MODEL_ID")
    idProduct="${idProduct##*"="}"
    Serial=$(udevadm info /dev/$device | grep "ID_SERIAL_SHORT")
    Serial="${Serial##*"="}"


    yesno_def_yes "Do you want to add udev rule for this device? $device:\n$device_info"
    ret_val=$?

    if [ ! $ret_val -eq 1 ]; then
      continue
    fi

    symlink=$(input_box "What should this device be named?") # NOTE - when called like this, we cannot "exit 0" from within the inputbox() function, as it is ran in a sub-shell, and the exit will only exit the sub-shell
    ret_val=$?

    if [ $ret_val -eq 255 ]; then
      exit 1
    fi
    if [ $ret_val -eq 1 ]; then
      exit 1
    else
      echo -e "\n#Following line was added by MRS UAV System Intall utility:" | sudo tee -a $FILENAME > /dev/null

      if [ -z "${Serial}" ]; then
        echo -e "SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$idVendor\", ATTRS{idProduct}==\"$idProduct\", SYMLINK+=\"$symlink\", OWNER=\"$hostname\", MODE=\"0666\"" | sudo tee -a $FILENAME > /dev/null
      else
        echo -e "SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$idVendor\", ATTRS{idProduct}==\"$idProduct\", ATTRS{serial}==\"$Serial\", SYMLINK+=\"$symlink\", OWNER=\"$hostname\", MODE=\"0666\"" | sudo tee -a $FILENAME > /dev/null
      fi
    fi
  done
fi

sudo cp $FILENAME /etc/udev/rules.d/
