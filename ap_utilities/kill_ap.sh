#!/bin/bash

# Define constants and paths
CURRENT_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
BACKUP_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml.bak"
SERVICE_NAME="ap_startup.service"

# Check if the AP service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "AP startup service is running. Stopping it..."
  sudo systemctl stop "$SERVICE_NAME"
fi

# Check if any create_ap process is already running and stop it
if [ -n "$(create_ap --list-running)" ]; then
  echo "Stopping the running Access Point..."
  create_ap --stop wlan0
  if [ $? -ne 0 ]; then
    echo "Error: Failed to stop the Access Point. Exiting..."
    exit 1
  else
    echo "Access Point stopped successfully."
  fi
else
  echo "No running Access Point process found."
fi

# Restore the original netplan configuration
if [ -f "$BACKUP_NETPLAN_FILE" ]; then
  echo "Restoring original netplan configuration from $BACKUP_NETPLAN_FILE..."
  if ! sudo cp "$BACKUP_NETPLAN_FILE" "$CURRENT_NETPLAN_FILE"; then
    echo "Error: Failed to restore netplan configuration."
    exit 1
  fi
  sudo rm -f "$BACKUP_NETPLAN_FILE"
else
  echo "Backup netplan configuration file not found. Exiting."
  exit 1
fi

# Apply the restored netplan configuration
echo "Applying restored netplan configuration..."
if ! sudo netplan apply; then
  echo "Error: Failed to apply netplan changes."
  exit 1
fi

# Stop the haveged service if it's running
if systemctl is-active --quiet haveged; then
  echo "Stopping haveged service..."
  sudo systemctl stop haveged
fi

# Disable the AP startup service to prevent AP setup on next boot
if systemctl is-enabled --quiet "$SERVICE_NAME"; then
  echo "Disabling AP startup service..."
  sudo systemctl disable "$SERVICE_NAME"
fi

# Final status
echo "Access point deactivation completed."
