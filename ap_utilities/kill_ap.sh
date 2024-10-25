#!/bin/bash

# Define constants and paths
AP_FLAG_FILE="/var/run/ap_enabled"
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
BACKUP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.bak"
SERVICE_NAME="ap_startup.service"

# Find the PID of the create_ap process matching the full command used in setup_ap.sh
AP_PID=$(pgrep -f 'create_ap --no-virt -n --redirect-to-localhost wlan0')

# Check if the process is running
if [ -z "$AP_PID" ]; then
  echo "No create_ap process found."
else
  # Kill the process
  echo "Killing create_ap process with PID: $AP_PID"
  sudo kill $AP_PID
  echo "Access point stopped."
fi

# Delete the current netplan configuration file and restore from backup
if [ -f "$BACKUP_NETPLAN_FILE" ]; then
  echo "Restoring original netplan configuration file from $BACKUP_NETPLAN_FILE..."
  sudo cp "$BACKUP_NETPLAN_FILE" "$CURRENT_NETPLAN_FILE"
  sudo rm -f "$BACKUP_NETPLAN_FILE"
else
  echo "Backup netplan configuration file not found. Exiting."
  exit 1
fi

# Apply the restored netplan configuration
echo "Applying restored netplan configuration..."
sudo netplan apply
echo "Netplan configuration reverted."

# Remove the AP enabled flag file
if [ -f "$AP_FLAG_FILE" ]; then
  echo "Removing AP enabled flag file..."
  sudo rm -f "$AP_FLAG_FILE"
fi

# Disable the AP startup service to prevent AP setup on next boot
echo "Disabling AP startup service..."
sudo systemctl disable "$SERVICE_NAME"

# Stop the haveged service if it's running
if systemctl is-active --quiet haveged; then
  echo "Stopping haveged service..."
  sudo systemctl stop haveged
fi

echo "Access point deactivation completed."
