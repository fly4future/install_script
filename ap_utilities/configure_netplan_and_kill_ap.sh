#!/bin/bash

# Constants
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
eths=$(echo $interfaces | grep -o '\beth\w*')
wlans=$(echo $interfaces | grep -o '\bwlan\w*')

if [ -z "${eths}" ]; then
  error_msg "No Ethernet interfaces found! Continuing with Wi-Fi config."
else
  for name in ${eths}; do
    echo "    $name:" >> "$FILENAME"
    yesno_def_no "Do you want to use DHCP on $name?"
    if [ $? -eq 1 ]; then
      echo "      dhcp4: yes" >> "$FILENAME"
      echo "      dhcp6: no" >> "$FILENAME"
    else
      echo "      dhcp4: no" >> "$FILENAME"
      echo "      dhcp6: no" >> "$FILENAME"
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
    dhcp=$?
    if [ $dhcp -eq 1 ]; then
      echo "      dhcp4: yes" >> "$FILENAME"
      echo "      dhcp6: no" >> "$FILENAME"
    else
      echo "      dhcp4: no" >> "$FILENAME"
      echo "      dhcp6: no" >> "$FILENAME"
      address=$(input_box "Enter your static IP address:" "192.168.69.101")
      echo "      addresses: [$address/24]" >> "$FILENAME"
      gateway=$(input_box "Enter your gateway address:" "192.168.69.1")
      echo "      gateway4: $gateway" >> "$FILENAME"
      dns=$(input_box "Enter your DNS server address:" "8.8.8.8")
      echo "      nameservers:" >> "$FILENAME"
      echo "        addresses: [$dns]" >> "$FILENAME"
    fi
    ap_name=$(input_box "Enter your access point name:" "my_wifi")
    echo "      access-points:" >> "$FILENAME"
    echo "        \"$ap_name\":" >> "$FILENAME"
    password=$(input_box "Enter your access point password:" "my_password")
    echo "          password: \"$password\"" >> "$FILENAME"
  done
else
  error_msg "No Wi-Fi interfaces found."
fi

# Display the generated netplan config and apply if confirmed
netplan=$(cat "$FILENAME")
yesno_def_yes "This netplan was generated: \n\n $netplan \n\n Copy to /etc/netplan and Apply?"
if [ $? -eq 0 ]; then
  # Check if the AP service is running
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "AP startup service is running. Stopping it..."
    sudo systemctl stop "$SERVICE_NAME"
  fi

  # Check if any create_ap process is already running and stop it
  if [ -n "$(sudo create_ap --list-running)" ]; then
    echo "Stopping the running Access Point..."
    sudo create_ap --stop wlan0
    if [ $? -ne 0 ]; then
      error_msg "Error: Failed to stop the Access Point. Exiting..."
      exit 1
    else
      echo "Access Point stopped successfully."
    fi
  else
    echo "No running Access Point process found."
  fi

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

# Disable the AP startup service to prevent AP setup on next boot
echo "Disabling AP startup service..."
sudo systemctl disable "$SERVICE_NAME"

# Stop the haveged service if it's running
if systemctl is-active --quiet haveged; then
  echo "Stopping haveged service..."
  sudo systemctl stop haveged
fi
