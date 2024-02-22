#!/bin/bash

yesno_def_yes () {
  whiptail --title "Netplan Config" --yesno "$1" --yes-button "No" --no-button "Yes" 0 0
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 0
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

yesno_def_no () {
  whiptail --title "Netplan Config" --yesno "$1"  0 0
  ret_val=$?

  if [ $ret_val -eq 255 ]; then
    exit 0
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

error_msg () {
  whiptail --title "Netplan config" --msgbox "$1" 0 0
}





# whiptail --title "Netplan configuration" --yesno "Delete any previous netplan configs? (Recommended)" 0 0
# ret_val=$?

# if [ $ret_val -eq 255 ]; then
#   exit 0
# elif [ $ret_val -eq 1 ]; then
#   echo "User hit No"
# elif [ $ret_val -eq 0 ]; then
#   sudo rm /etc/netplan/*
# else
#   echo "Error state"
# fi

FILENAME=/tmp/01-netcfg.yaml
rm $FILENAME
touch $FILENAME
echo "network:" >> /tmp/01-netcfg.yaml
echo "  version: 2:" >> /tmp/01-netcfg.yaml
echo "  renderer: networkd:" >> /tmp/01-netcfg.yaml
echo "  ethernets:" >> /tmp/01-netcfg.yaml

# interfaces=$(ls /sys/class/net)
interfaces="eth0 eth1 wlan0 wlan1"
eths=$(echo $interfaces | grep -o "\w*eth\w*")
wlans=$(echo $interfaces | grep -o "\w*wlan\w*")


if [ -z "${eths}" ]; then
  error_msg "No Ethernet interfaces found! (looking for eth0, eth1 ...).\nYour Ethernet interfaces may have different names, run the Network Interface Names Fix first.\n\n\n Continuing with Wi-Fi config. "
else
  for name in ${eths}; do
    echo "    $name:" >> /tmp/01-netcfg.yaml

    yesno_def_no "Do you want to use DHCP on $name?"
    ret_val=$?

    if [ $ret_val -eq 1 ]; then
      echo "      dhcp4: yes" >> /tmp/01-netcfg.yaml
      echo "      dhcp6: no" >> /tmp/01-netcfg.yaml
    elif [ $ret_val -eq 0 ]; then
      echo "      dhcp4: no" >> /tmp/01-netcfg.yaml
      echo "      dhcp6: no" >> /tmp/01-netcfg.yaml
      #TODO continue here with IP selection
    fi
  done
fi

# ret_val=
# if [[ "$ret_val" -eq 1 ]]; then
#   exit 1
# fi





