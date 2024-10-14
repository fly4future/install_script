#!/bin/bash

# Define your sudo password 
SUDO_PASSWORD="f4f"

# Define netplan configuration file paths
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
ORIGINAL_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.orig"
HOME_BACKUP_NETPLAN_FILE="/home/uav/.01-netcfg.yaml.orig"

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

# Delete the current netplan configuration file
if [ -f "$CURRENT_NETPLAN_FILE" ]; then
  echo "Deleting current netplan configuration file..."
  echo "$SUDO_PASSWORD" | sudo -S rm "$CURRENT_NETPLAN_FILE"
else
  echo "Current netplan configuration file not found. Skipping deletion."
fi

# Restore the original netplan configuration file or the backup if the original does not exist
if [ -f "$ORIGINAL_NETPLAN_FILE" ]; then
  echo "Restoring original netplan configuration file from $ORIGINAL_NETPLAN_FILE..."
  echo "$SUDO_PASSWORD" | sudo -S mv "$ORIGINAL_NETPLAN_FILE" "$CURRENT_NETPLAN_FILE"
elif [ -f "$HOME_BACKUP_NETPLAN_FILE" ]; then
  echo "Original file not found. Restoring from backup at $HOME_BACKUP_NETPLAN_FILE..."
  echo "$SUDO_PASSWORD" | sudo -S cp "$HOME_BACKUP_NETPLAN_FILE" "$CURRENT_NETPLAN_FILE"
else
  echo "Neither original nor backup netplan configuration files found. Exiting."
  exit 1
fi

# Apply the restored netplan configuration
echo "Applying restored netplan configuration..."
echo "$SUDO_PASSWORD" | sudo -S netplan apply

echo "Netplan configuration reverted. Script completed."
