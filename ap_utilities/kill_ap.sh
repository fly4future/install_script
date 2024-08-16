#!/bin/bash

# Define your sudo password 
SUDO_PASSWORD="f4f"

# Define netplan configuration file paths
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
AP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.ap"
ORIGINAL_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.orig"

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

# Rename the current netplan configuration file to .ap
if [ -f "$CURRENT_NETPLAN_FILE" ]; then
  echo "Renaming current netplan configuration file to .ap..."
  echo "$SUDO_PASSWORD" | sudo -S mv "$CURRENT_NETPLAN_FILE" "$AP_NETPLAN_FILE"
else
  echo "Current netplan configuration file not found. Skipping rename to .ap."
fi

# Rename the .orig netplan configuration file to the current one
if [ -f "$ORIGINAL_NETPLAN_FILE" ]; then
  echo "Renaming .orig netplan configuration file to the classical one..."
  echo "$SUDO_PASSWORD" | sudo -S mv "$ORIGINAL_NETPLAN_FILE" "$CURRENT_NETPLAN_FILE"
else
  echo ".orig netplan configuration file not found. Exiting."
  exit 1
fi

# Apply the netplan configuration
echo "Applying netplan configuration..."
echo "$SUDO_PASSWORD" | sudo -S netplan apply

echo "Netplan configuration reverted. Script completed."
