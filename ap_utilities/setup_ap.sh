#!/bin/bash

# Check if the ap0 interface is up
if ip a show ap0 up > /dev/null 2>&1; then
    echo "Access point ap0 is already running."
    exit 0
fi

# Define your sudo password (maybe use visudo instead ? To be discussed)
SUDO_PASSWORD="f4f"

# Define the netplan configuration files
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
BACKUP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.orig"
HOME_BACKUP_NETPLAN_FILE="/home/uav/.01-netcfg.yaml.orig"

# Check if the current netplan file exists
if [ -f "$CURRENT_NETPLAN_FILE" ]; then
    # Backup the current netplan configuration fileNo worries
    echo "$SUDO_PASSWORD" | sudo -S cp "$CURRENT_NETPLAN_FILE" "$HOME_BACKUP_NETPLAN_FILE"
    echo "$SUDO_PASSWORD" | sudo -S mv "$CURRENT_NETPLAN_FILE" "$BACKUP_NETPLAN_FILE"
else
    echo "Current netplan configuration file not found: $CURRENT_NETPLAN_FILE. Skipping backup..."
fi

# Create the AP netplan configuration directly in the current netplan file
echo "Creating AP netplan configuration..."

echo "$SUDO_PASSWORD" | sudo -S tee "$CURRENT_NETPLAN_FILE" > /dev/null <<EOL
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
EOL

# Apply the new netplan configuration
echo "Applying new netplan configuration..."
echo "$SUDO_PASSWORD" | sudo -S netplan apply

# Source the /etc/uav_name file
source /etc/uav_name

# Use UAV_NAME environment variable or default to "uav00"
UAV_NAME="${UAV_NAME:-uav00}"

# Create the access point using create_ap
AP_PASSWORD="${UAV_NAME}@F4F2024"
echo "$SUDO_PASSWORD" | sudo -S create_ap -n --redirect-to-localhost wlan0 "${UAV_NAME}_WIFI" "$AP_PASSWORD"
