#!/bin/bash

# Constants
AP_FLAG_FILE="/etc/ap_enabled"
SERVICE_NAME="ap_startup.service"
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
BACKUP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.bak"
BACKUP_DIR="/etc/netplan/backup"

# Function Definitions
yesno_def_no () {
  whiptail --title "Netplan Config" --yesno "$1" --yes-button "No" --no-button "Yes" 0 0
  return $?
}

yesno_def_yes () {
  whiptail --title "Netplan Config" --yesno "$1" 0 0
  return $?
}

input_box () {
  tmp=$(whiptail --inputbox "$1" 0 0 "$2" 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    exit 1
  else
    echo "$tmp"
  fi
}

error_msg () {
  whiptail --title "Netplan Config" --msgbox "$1" 0 0
}

# Ask to delete previous netplan configs
yesno_def_yes "Backup and delete any previous netplan configs? (Recommended)"
if [ $? -eq 0 ]; then
  # Create backup directory if it does not exist
  sudo mkdir -p "$BACKUP_DIR"
  timestamp=$(date +%Y%m%d_%H%M%S)
  sudo mv /etc/netplan/*.yaml "$BACKUP_DIR"/backup_"$timestamp".yaml 2>/dev/null
  echo "Previous netplan files backed up and deleted."
fi

# Generate new netplan config
FILENAME=/tmp/01-netcfg.yaml
rm -f "$FILENAME"
touch "$FILENAME"
echo "network:" >> "$FILENAME"
echo "  version: 2" >> "$FILENAME"
echo "  renderer: networkd" >> "$FILENAME"
echo "  ethernets:" >> "$FILENAME"

interfaces=$(ls /sys/class/net)
eths=$(echo $interfaces | grep -o "\w*eth\w*")
wlans=$(echo $interfaces | grep -o "\w*wlan\w*")

if [ -z "${eths}" ]; then
  error_msg "No Ethernet interfaces found! Continuing with Wi-Fi config."
else
  for name in ${eths}; do
    echo "    $name:" >> "$FILENAME"
    yesno_def_no "Do you want to use DHCP on $name?"
    if [ $? -eq 1 ]; then
      echo "      dhcp4: yes" >> "$FILENAME"
    else
      echo "      dhcp4: no" >> "$FILENAME"
      address=$(input_box "Enter your static IP address:" "10.10.20.101")
      echo "      addresses: [$address/24]" >> "$FILENAME"
    fi
  done
fi

if [ -n "${wlans}" ]; then
  echo "  wifis:" >> "$FILENAME"
  for name in ${wlans}; do
    echo "    $name:" >> "$FILENAME"
    yesno_def_no "Do you want to use DHCP on $name?"
    if [ $? -eq 1 ]; then
      echo "      dhcp4: yes" >> "$FILENAME"
    else
      echo "      dhcp4: no" >> "$FILENAME"
      address=$(input_box "Enter your static IP address:" "192.168.69.101")
      echo "      addresses: [$address/24]" >> "$FILENAME"
      gateway=$(input_box "Enter your gateway address:" "192.168.69.1")
      echo "      gateway4: $gateway" >> "$FILENAME"
    fi
    ap_name=$(input_box "Enter your access point name:" "mrs_ctu")
    echo "      access-points:" >> "$FILENAME"
    echo "        \"$ap_name\":" >> "$FILENAME"
    password=$(input_box "Enter your access point password:" "mikrokopter")
    echo "          password: \"$password\"" >> "$FILENAME"
  done
else
  error_msg "No Wi-Fi interfaces found."
fi

# Display the generated netplan config and apply if confirmed
netplan=$(cat "$FILENAME")
yesno_def_yes "This netplan was generated: \n\n $netplan \n\n Copy to /etc/netplan and Apply?"
if [ $? -eq 0 ]; then
  echo "Copying netplan ..."
  sudo cp "$FILENAME" "$CURRENT_NETPLAN_FILE"
  echo "Applying netplan ..."
  sudo netplan apply

  # Remove the backup netplan file after applying new configuration
  if [ -f "$BACKUP_NETPLAN_FILE" ]; then
    echo "Removing old netplan backup file..."
    sudo rm -f "$BACKUP_NETPLAN_FILE"
  fi
fi

# Remove the AP flag file
if [ -f "$AP_FLAG_FILE" ]; then
  echo "Removing AP enabled flag file..."
  sudo rm -f "$AP_FLAG_FILE"
fi

# Kill the Access Point Process
AP_PID=$(pgrep -f 'create_ap --no-virt -n --redirect-to-localhost wlan0')
if [ -n "$AP_PID" ]; then
  echo "Killing create_ap process with PID: $AP_PID"
  sudo kill "$AP_PID"
fi

# Disable the AP startup service to prevent AP setup on next boot
echo "Disabling AP startup service..."
sudo systemctl disable "$SERVICE_NAME"

# Stop the haveged service if it's running
if systemctl is-active --quiet haveged; then
  echo "Stopping haveged service..."
  sudo systemctl stop haveged
fi

echo "Netplan configuration applied, access point stopped, and services cleaned up."
