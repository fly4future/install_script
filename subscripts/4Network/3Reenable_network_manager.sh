#!/bin/bash

set -euo pipefail

ret_val=0
whiptail --title "Reenable Network Manager" --yesno "This script will reenable Network Manager and delete all your netplan configs. If you are connected through SSH, you will lose connection and you will not regain it automatically. You will probably have to reconfigure all the network configurations.\n\n\n                        Proceed?" --yes-button "No" --no-button "Yes" 15 60 || ret_val=$?

if [ $ret_val -eq 255 ]; then
  exit 1
elif [ $ret_val -eq 1 ]; then

  sudo systemctl unmask NetworkManager NetworkManager-wait-online NetworkManager-dispatcher
  sudo systemctl enable --now NetworkManager NetworkManager-wait-online NetworkManager-dispatcher

  sudo systemctl disable --now systemd-networkd.socket systemd-networkd
  sudo systemctl mask systemd-networkd.socket systemd-networkd
  sudo systemctl unmask systemd-resolved
  sudo systemctl enable --now systemd-resolved

  sudo rm -f /etc/netplan/*.yaml

  FILENAME=/tmp/01-network-manager-all.yaml
  rm -f -- "$FILENAME"
  touch $FILENAME
  echo "network:" >> $FILENAME
  echo "  version: 2" >> $FILENAME
  echo "  renderer: NetworkManager" >> $FILENAME
  sudo cp $FILENAME /etc/netplan
  sudo chmod 600 /etc/netplan/01-network-manager-all.yaml

  sudo netplan generate
  sudo netplan apply

  # netplan does not clean up after the networkd config. The leftover udev rules mark the interfaces as unmanaged by NetworkManager
  # and the netplan wpa_supplicant keeps running, so remove them and let NetworkManager pick up the interfaces.
  sudo rm -f /run/udev/rules.d/90-netplan.rules
  sudo systemctl stop 'netplan-wpa-*.service'
  sudo udevadm control --reload
  sudo udevadm trigger --action=change --subsystem-match=net
  sudo udevadm settle
  sudo systemctl restart NetworkManager

  echo "Network manager enabled"
  exit 0
else
  exit 1
fi

