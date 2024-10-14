#!/bin/bash

# Define your sudo password 
SUDO_PASSWORD="f4f"

# Netplan Configuration Functions
yesno_def_no () {
  whiptail --title "Netplan Config" --yesno "$1" --yes-button "No" --no-button "Yes" 0 0
  ret_val=$?
  if [ $ret_val -eq 255 ]; then exit 1; elif [ $ret_val -eq 1 ]; then return 1; else return 0; fi
}

yesno_def_yes () {
  whiptail --title "Netplan Config" --yesno "$1"  0 0
  ret_val=$?
  if [ $ret_val -eq 255 ]; then exit 1; elif [ $ret_val -eq 0 ]; then return 1; else return 0; fi
}

input_box () {
  tmp=$(whiptail --inputbox "$1" 0 0 "$2" 3>&1 1>&2 2>&3)
  ret_val=$?
  if [ $ret_val -eq 255 ]; then exit 1; elif [ $ret_val -eq 1 ]; then exit 1; else echo $tmp; return 0; fi
}

error_msg () {
  whiptail --title "Netplan config" --msgbox "$1" 0 0
}

# Ask to delete previous netplan configs
yesno_def_yes "Delete any previous netplan configs? (Recommended)"
ret_val=$?
if [ $ret_val -eq 1 ]; then sudo rm /etc/netplan/*; fi

# Generate new netplan config
FILENAME=/tmp/01-netcfg.yaml
rm -f $FILENAME
touch $FILENAME
echo "network:" >> $FILENAME
echo "  version: 2" >> $FILENAME
echo "  renderer: networkd" >> $FILENAME
echo "  ethernets:" >> $FILENAME

interfaces=$(ls /sys/class/net)
eths=$(echo $interfaces | grep -o "\w*eth\w*")
wlans=$(echo $interfaces | grep -o "\w*wlan\w*")

if [ -z "${eths}" ]; then
  error_msg "No Ethernet interfaces found! Continuing with Wi-Fi config."
else
  for name in ${eths}; do
    echo "    $name:" >> $FILENAME
    yesno_def_no "Do you want to use DHCP on $name?"
    ret_val=$?
    if [ $ret_val -eq 1 ]; then
      echo "      dhcp4: yes" >> $FILENAME
      echo "      dhcp6: no" >> $FILENAME
    else
      echo "      dhcp4: no" >> $FILENAME
      echo "      dhcp6: no" >> $FILENAME
      address=$(input_box "Enter your static IP address:" "10.10.20.101")
      echo "      addresses: [$address/24]" >> $FILENAME
    fi
  done
fi

echo "  wifis:" >> $FILENAME
if [ -z "${wlans}" ]; then
  error_msg "No Wlan interfaces found!"
else
  for name in ${wlans}; do
    echo "    $name:" >> $FILENAME
    yesno_def_no "Do you want to use DHCP on $name?"
    dhcp=$?
    if [ $dhcp -eq 1 ]; then
      echo "      dhcp4: yes" >> $FILENAME
      echo "      dhcp6: no" >> $FILENAME
    else
      echo "      dhcp4: no" >> $FILENAME
      echo "      dhcp6: no" >> $FILENAME
      address=$(input_box "Enter your static IP address:" "192.168.69.101")
      echo "      addresses: [$address/24]" >> $FILENAME
      gateway=$(input_box "Enter your gateway address:" "192.168.69.1")
      echo "      gateway4: $gateway" >> $FILENAME
    fi
    ap_name=$(input_box "Enter your access point name:" "mrs_ctu")
    echo "      access-points:" >> $FILENAME
    echo "        \"$ap_name\":" >> $FILENAME
    password=$(input_box "Enter your access point password:" "mikrokopter")
    echo "          password: \"$password\"" >> $FILENAME
    if [ $dhcp -eq 0 ]; then
      dns=$(input_box "Enter your DNS server address:" "8.8.8.8")
      echo "      nameservers:" >> $FILENAME
      echo "        addresses: [$dns]" >> $FILENAME
    fi
  done
fi

# Display the generated netplan config and apply if confirmed
netplan=$(cat /tmp/01-netcfg.yaml)
yesno_def_yes "This netplan was generated: \n\n $netplan \n\n Copy to /etc/netplan and Apply?"
ret_val=$?
if [ $ret_val -eq 1 ]; then
  echo "Copying netplan ..."
  sudo cp /tmp/01-netcfg.yaml /etc/netplan
  echo "Applying netplan ..."
  sudo netplan apply
fi

# Kill the Access Point Process
# Find the PID of the create_ap process matching the full command used in setup_ap.sh
AP_PID=$(pgrep -f 'create_ap -n --redirect-to-localhost wlan0')

# Check if the process is running
if [ -z "$AP_PID" ]; then
  echo "No create_ap process found."
else
  # Kill the process
  echo "Killing create_ap process with PID: $AP_PID"
  echo "$SUDO_PASSWORD" | sudo -S kill $AP_PID
  echo "Access point stopped."
fi

echo "Netplan configuration applied, and access point stopped."
