#!/bin/bash

whiptail --title "Disable Network Manager" --yesno "This script will disable Network Manager and apply your netplan config. If you are connected through SSH, you will probably lose connection. Also if you do not have a netplan config already set-up, the computer will not reconnect to your WiFi.\n\n\n                        Proceed?" --yes-button "No" --no-button "Yes" 15 60
ret_val=$?

if [ $ret_val -eq 255 ]; then
  exit 1
elif [ $ret_val -eq 1 ]; then

  sudo systemctl stop NetworkManager.service
  sudo systemctl disable NetworkManager.service

  sudo systemctl stop NetworkManager-wait-online.service
  sudo systemctl disable NetworkManager-wait-online.service

  sudo systemctl stop NetworkManager-dispatcher.service
  sudo systemctl disable NetworkManager-dispatcher.service

  sudo systemctl stop network-manager.service
  sudo systemctl disable network-manager.service

  sudo netplan apply

  echo "Network manager disabled"
  exit 0
elif [ $ret_val -eq 0 ]; then
  exit 1
else
  echo "Error state"
  exit 0
fi

