#!/bin/bash

whiptail --title "Reenable Network Manager" --yesno "This script will reenable Network Manager and delete all your netplan configs. If you are connected through SSH, you will lose connection and you will not regain it automatically. You willuprobably have to reconfigure all the network configurations.\n\n\n                        Proceed?" --yes-button "No" --no-button "Yes" 15 60
ret_val=$?

if [ $ret_val -eq 255 ]; then
  exit 1
elif [ $ret_val -eq 1 ]; then

  sudo systemctl enable NetworkManager.service
  sudo systemctl start NetworkManager.service

  sudo systemctl enable NetworkManager-wait-online.service
  sudo systemctl start NetworkManager-wait-online.service

  sudo systemctl enable NetworkManager-dispatcher.service
  sudo systemctl start NetworkManager-dispatcher.service

  sudo systemctl enable network-manager.service
  sudo systemctl start network-manager.service

  sudo rm /etc/netplan/*

  FILENAME=/tmp/01-network-manager-all.yaml
  rm $FILENAME
  touch $FILENAME
  echo "network:" >> $FILENAME
  echo "  version: 2" >> $FILENAME
  echo "  renderer: NetworkManager" >> $FILENAME
  sudo cp $FILENAME /etc/netplan

  echo "Network manager enabled"
  exit 0
elif [ $ret_val -eq 0 ]; then
  exit 1
else
  echo "Error state"
  exit 0
fi

